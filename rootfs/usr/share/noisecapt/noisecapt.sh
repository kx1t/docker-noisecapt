#!/command/with-contenv bash
#shellcheck shell=bash disable=SC2154,SC1091

source /scripts/common
"${s6wrap[@]}" echo "deployment started"

# NOISECAPT - a Bash shell script to continuously capture audio levels from a standard audio device
#
# Note: this script is meant to be run as a daemon using SYSTEMD
# If run manually, it will continuously loop to listen for new planes
#
# This script is distributed as part of the PlaneFence package.
#
# Copyright 2020-2024 Ramon F. Kolb - licensed under the terms and conditions
# of GPLv3. The terms and conditions of this license are included with the Github
# distribution of this package, and are also available here:
# https://github.com/kx1t/planefence
#
# The output is written in headerless CSV format to the file defined below.
# The format of the output is:
# secs_since_epoch,capture_absolute_level,capture_dB,avg_dB_5_mins,avg_dB_10_mins, avg_dB_1_hour,avg_dB_midnight_to_now
#
# -----------------------------------------------------------------------------------
# Feel free to make changes to the variables between these two lines. However, it is# STRONGLY RECOMMENDED to RTFM! See README.md for explanation of what these do.
#
# CAPTURETIME is the duration of a single audio capture, in seconds
# CLEANUPINT is the number of runs before we clean up the log file (as it often gets corrupten for no apparent reason)
CAPTURETIME="${PF_CAPTURETIME:-5}"

CLEANUPINT="${PF_CLEANUPTIME:+$((PF_CLEANUPTIME / CAPTURETIME))}"
CLEANUPINT="${CLEANUPINT:-10}"
if (( CLEANUPINT < 1 )); then CLEANUPINT=10; fi
# OUTFILE contains the base part of the output file for the captured data,
# including the directory. Please make sure that this directory is accessable
# for the script as it won't attempt to create or CHMOD it. If the script
# can't write to the directory, it will silently fail / appear to do nothing
OUTFILE="/run/noisecapt/noisecapt-"
OUTFILEEXT=".log"
TEMPFILE="/run/noisecapt/noisecapt.tmp"
# If you don't want logging, simply set  the VERBOSE=1 line below to VERBOSE=0
VERBOSE=1
LOOPCOUNTER=0
# The script will attempt to figure out by itself what your audio device is
# However, it may get it wrong, especially if you have more than
# 1 soundcard ,webcam, etc
# in that case, please give this command: 'arecord -l' and fill in the values
# for Card and Devuce here.
# If you uncomment the variables bekow, you MUST provide BOTH the Card and the Device numbers
# CARD=1
# DEVICE=0
# -----------------------------------------------------------------------------------
#
# some global stuff:
# IFS is needed to read data lines into an array
# IFS=','
# Create an function to write to the log:
LOG ()
{
    if chk_enabled "$VERBOSE";
    then
        "${s6wrap[@]}" echo "$1"
    fi
}

LOG "-----------------------------------------------------------------------------------"
LOG "Starting NoiseCapt"

# Try to get the card/device for the audio input device
if [[ -z "$PF_AUDIOCARD" ]]; then
    CARD="$(arecord -l |grep -oP "card\s+\K\w+")"
    DEVICE="$(arecord -l |grep -oP "device\s+\K\w+")"
    LOG "Audio device Card,Device auto-set to \"$CARD,$DEVICE\""
else
    CARD=$PF_AUDIOCARD
    DEVICE=$PF_AUDIODEVICE
    LOG "Audio device Card,Device manually set to \"$CARD,$DEVICE\""
fi

# Calc how many records we need from the past logs
(( ONEHOUR= 3600 / CAPTURETIME ))

LOG "Need $ONEHOUR loglines"

# And here we go, Loop forevah:
while true; do
    # determine which file we need to write to
    LOGTODAY="$OUTFILE$(date +'%y%m%d')$OUTFILEEXT"
    LOGYSTRDAY="$OUTFILE$(date -d yesterday +'%y%m%d')$OUTFILEEXT"
    LOG "Logfiles today=$LOGTODAY yesterday=$LOGYSTRDAY"

    # and determine if yesterday's file exists
    if [[ ! -f "$LOGYSTRDAY" ]]; then
        LOGYSTRDAY=""
        LOG "Yesterday log doesnt exist"
    fi

    AUDIOTIME="$(date +%s)"

    # capture audio and put the results in an array
    # All dB levels are dBFS, or dB where the loudest (="full scale") is 0 dB

    if chk_enabled "$RECORD_MP3"; then
        RMSREC="$(arecord -D hw:"$CARD,$DEVICE" -d "$CAPTURETIME" --fatal-errors --buffer-size=192000 -f dat -t raw -c 1 --quiet 2>/dev/null \
                  | tee >(lame --quiet -r --preset phone -s 48 - "${OUTFILE}recording-$(date -d @"$AUDIOTIME" +%y%m%d-%H%M%S).mp3" >/dev/null 2>&1) \
                  | sox -V -t raw -b 16 -r 48000 -c 1 -e signed-integer - -n sinc 200-10000 stats rate 16000 spectrogram -o "${OUTFILE}spectro-$(date -d @"$AUDIOTIME" +%y%m%d-%H%M%S).png"  -Z -10 -z 60 -t "Audio Spectrogram for $(date -d @"$AUDIOTIME")" -c "PlaneFence (C) 2020-2024 by kx1t" -p 1 2>&1 \
                  | grep 'RMS lev dB')"
    else
        RMSREC="$(arecord -D hw:"$CARD,$DEVICE" -d "$CAPTURETIME" --fatal-errors --buffer-size=192000 -f dat -t raw -c 1 --quiet 2>/dev/null \
                  | sox -V -t raw -b 16 -r 48000 -c 1 -e signed-integer - -n sinc 200-10000 stats rate 16000 spectrogram -o "${OUTFILE}spectro-$(date -d @"$AUDIOTIME" +%y%m%d-%H%M%S).png"  -Z -10 -z 60 -t "Audio Spectrogram for $(date -d @"$AUDIOTIME")" -c "PlaneFence (C) 2020-2024 by kx1t" -p 1 2>&1 \
                  | grep 'RMS lev dB')"
    fi
    # put the dB value into LEVEL as an integer. BASH arithmatic doesn't like
    # float values, so we need to do some trickery to convert the number:
    LC_ALL=C printf -v LEVEL '%.0f' "${RMSREC##* }"

    # check if $LEVEL is less than zero. If it's zero, there was a read error and we should skip.
    if [[ "$LEVEL" == "0" ]]
    then
        "${s6wrap[@]}" echo "Zero sample - skipping"
        continue
    fi

    LOG "Level=$LEVEL Audiotime=$AUDIOTIME"
    # capture and calculate the averages
    # determine the number of records in today's log
    if [ -f "$LOGTODAY" ]
    then
        LOGLINES="$(wc -l "$LOGTODAY")"
        LOGLINES=${LOGLINES% *}
    else
        LOGLINES=0
    fi
    LOG "Today's log has $LOGLINES lines"

    # create a TMP file with the records we need
    if (( ONEHOUR > LOGLINES )); then
        # we have too few records in today's log and we need a few from yesterday's log if it exists
        if [[ -f "$LOGYSTRDAY" ]]; then
            (( UNDERFLOW="$ONEHOUR - $LOGLINES" ))
            tail --lines="$UNDERFLOW" "$LOGYSTRDAY" > $TEMPFILE
            if [[ -f "LOGTODAY" ]]; then
                cat "$LOGTODAY" >> $TEMPFILE
            fi
        elif  [[ -f "$LOGTODAY" ]]; then
            # yesterday's file doesn't exist and we'll have to make do with today's
            cat "$LOGTODAY" > $TEMPFILE
        fi
    elif [[ -f "$LOGTODAY" ]]; then
        # we need $LOGLINES records from the $LOGTODAY
        tail --lines="$LOGLINES" "$LOGTODAY" > $TEMPFILE
    fi

    # there is a chance that no $TEMPFILE was created if there was no logfile
    # for either today or yesterday, so let's touch the file so we can be sure
    # it exists
    touch $TEMPFILE

    # Now we can read the TEMPFILE and determine the averages
    (( ONEMINCT = 1 ))
    (( FIVEMINCT = 1 ))
    (( TENMINCT = 1 ))
    (( ONEHRCT = 1 ))

    (( ONEMINTL = LEVEL ))
    (( FIVEMINTL = LEVEL ))
    (( TENMINTL = LEVEL ))
    (( ONEHRTL = LEVEL ))

    if [[ -f $TEMPFILE ]]; then
        while IFS= read -r ONELINE; do
            # split $LINE into an array:
            unset LINE
            IFS=',' read -ra LINE <<< "$ONELINE"
            if (( AUDIOTIME - LINE[0] < 3600 )); then
                (( ONEHRCT++ ))
                (( ONEHRTL += LINE[1] ))
            fi
            if (( AUDIOTIME - LINE[0] < 600 )); then
                (( TENMINCT++ ))
                (( TENMINTL += LINE[1] ))
            fi

            if (( AUDIOTIME - LINE[0] < 300 )); then
                (( FIVEMINCT++ ))
                (( FIVEMINTL += LINE[1] ))
            fi

            if (( AUDIOTIME - LINE[0] < 60 )); then
                (( ONEMINCT++ ))
                (( ONEMINTL += LINE[1] ))
            fi

        done < "$TEMPFILE"
    fi

    (( ONEMINAVG = ONEMINTL / ONEMINCT ))
    (( FIVEMINAVG = FIVEMINTL / FIVEMINCT ))
    (( TENMINAVG = TENMINTL / TENMINCT ))
    (( ONEHRAVG = ONEHRTL / ONEHRCT ))

    # Now we have all the averages, we can write them to the file
    printf "%s,%s,%s,%s,%s,%s\n" "$AUDIOTIME" "$LEVEL" "$ONEMINAVG" "$FIVEMINAVG" "$TENMINAVG" "$ONEHRAVG" >> "$LOGTODAY"

    # Link latest spectrogram to PNG file
    ln -sf "${OUTFILE}spectro-$(date -d @"$AUDIOTIME" +%y%m%d-%H%M%S).png" "${OUTFILE}spectro-latest.png"
    # LOG "ln -sf ${OUTFILE}pectro-$(date -d @"$AUDIOTIME" +%y%m%d-%H%M%S).png ${OUTFILE}/spectro-latest.png"
    # clean up any PNG spectrograms older than 12 hours (720 minutes):
    DTIME="$(( ${PF_DELETEAFTER:-1} * 60 ))"
	find "${OUTFILE%/*}" -name 'noisecapt-spectro-*.png' -mmin +"$DTIME" -delete
    find "${OUTFILE%/*}" -name 'noisecapt-recording-*.mp3' -mmin +"$DTIME" -delete

    # clean up log file if necessary:
    (( LOOPCOUNTER++ ))
    if (( LOOPCOUNTER > CLEANUPINT ))
    then
        LOOPCOUNTER=0
        tmpfile=$(mktemp)
        awk -F, -v st="$(date -d "$(date +"%Y-%m-%d 00:00:00")" +%s)" -v et="$(date -d "$(date +"%Y-%m-%d 23:59:59")" +%s)"  '$1 >= st && $1 <= et && substr($2,1,1) == "-" && length($2) <= 3 && substr($3,1,1) == "-" && length($3) <= 3 && substr($4,1,1) == "-" && length($4) <= 3 && substr($5,1,1) == "-" && length($5) <= 3 && substr($6,1,1) == "-" && length($6) <= 3 {print}' "$LOGTODAY" > "$tmpfile"
        mv -f "$tmpfile" "$LOGTODAY"
        chmod a+r "$LOGTODAY"
    fi
done
