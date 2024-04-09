# Docker-NoiseCapt

## What is it?

This repository contains an add-on to [Planefence](http://www.github.com/sdr-enthusiasts/docker-planefence) to collect audio/noise samples and make them available to planefence.
It does not have any functionality on its own.

Note - it (purposely) does NOT store ambient audio recordings. The container **only** stores peak audio level measurements and creates graphs and spectrograms of them. The audio itself is never retained.

NoiseCapt is deployed as a Docker container and is pre-built for the following architectures:

- linux/ARM64: Raspberry Pi 4B with Ubuntu 64 bits OS
- linux/AMD64: 64-bits PC architecture (Intel or AMD) running Debian Linux (incl. Ubuntu)

The Docker container can be accessed on [GHCR (kx1t/docker-noisecapt)]([https://hub.docker.com/repository/docker/kx1t/noisecapt](https://github.com/kx1t/docker-noisecapt/pkgs/container/docker-noisecapt)) and can be pulled directy using this Docker command: `docker pull ghcr.io/kx1t/docker-noisecapt`.

## Who is it for?

If you are already running a ADS-B Feeder station with the containerized version of [Planefence](http://www.github.com/sdr-enthusiasts/docker-planefence), and you are interested in adding audio level measurements to your station, this container may be of interest to you.
It basically "listens" to audio from an audio card/dongle connected to your Raspberry Pi and integrates the output with the [Planefence](http://www.github.com/sdr-enthusiasts/docker-planefence) application.

Note that this container on itself does not have user-visible output. All output is integrated with [Planefence](http://www.github.com/sdr-enthusiasts/docker-planefence).

## Deploying `docker-noisecapt`

### Hardware requirements and considerations

#### Same or different Raspberry Pi?

NoiseCapt continuously listen for, and processes audio from a soundcard. This can become quite processor-intensive and you may run into the limits of what a Raspberry Pi can handle if you also run multiple RTL-SDR dongles and instances of dump1090(-fa)/readsb at the same time. As such, you can choose to run NoiseCapt on the same Raspberry Pi or you can put it on a separate Raspberry Pi or other machine.

#### Sound Card for your Raspberry Pi

- The RPi does not come with a sound card or microphone input. Any cheap devices will work. I've had luck with simple USB lavalier microphones from Amazon.
- You need to hang the microphone outside, preferably near your antenna and away from other noise sources (like air conditioner units). Make sure to waterproof the microphone. It's OK to completely seal it in a plastic bag, as long as you regularly check for deterioration of the bag caused by UV light.

### Configuration

- Take a look at the [`docker-compose.yml`](https://github.com/kx1t/docker-noisecapt/blob/main/docker-compose.yml) file and edit it to your liking. Copy it on the host machine to (for example) `/opt/adsb`, or add it to your existing `docker-compose.yml`
- If you don't deploy it in the same docker compose stack as Planefence, make sure to uncomment the `ports:` section in `docker-compose.yml`. This exposes the NoiseCapt files through a web interface on port 30088, which is needed by Planefence. You can change this to another port of your liking.
- In your `planefence.config` file, make sure to set the PF_NOISECAPT variable to the URL of your exposed port, for example "`PF_NOISECAPT=http://noisecapt`"

## Advanced configuration

### Multiple audio cards, or no card found

- NoiseCapt will attempt to automatically identify your audio card, but sometimes it can get confused. If you have multiple audio cards on your system (which is often the case on larger machines), it will pick the first one it can find. If this is not what you want, you can manually configure which audio card to pick. Here's how it works:
  1. Deploy the NoiseCapt container. It's OK if things aren't working (yet)
  2. From the host machine, give this command: `docker exec -t noisecapt arecord -l`
  3. The output will look like this:

      ```text
      **** List of CAPTURE Hardware Devices ****
      card 2: Device [USB PnP Sound Device], device 0: USB Audio [USB Audio]
      ...
      ```

  4. Note that your Audio Card = 2 and your Audio Device = 0 in this case
  5. Update your `docker-compose.yml` file and uncomment / enter these values at the lines with `PF_AUDIOCARD=` and `PF_AUDIODEVICE=`
  6. Restart your container (`docker-compose up -d`)

### Everything appears to work but all volumes are around -75 - -80 dB and the spectrograms appear empty

Most probably, your soundcard is muted. The script does an attempt to unmute the card, crank up the volume, and switch off AGC but apparently it wasn't successful.
Here's how to do this manually

1. Do `docker exec -it noisecapt amixer --card 2 contents`. Replace the card number with the one you figure out in the section above.
2. Look for something like this:

    ```text
    numid=3,iface=MIXER,name='Mic Capture Switch'
      ; type=BOOLEAN,access=rw------,values=1
      : values=ffn
    ```

    `Mic Capture Switch` means muted when off. If it's set to `values=off`, use this to switch it on. Replace `numid=3` by the value on your screen and `--card 2` with the correct card value: `docker exec -it noisecapt amixer --card 2 cset numid=3 on`

3. Do the same for AGC:

    ```text
    numid=9,iface=MIXER,name='Auto Gain Control'
      ; type=BOOLEAN,access=rw------,values=1
      : values=off
    ```

    `Auto Gain Control` should be set to off. If `values=on`, then do this: `docker exec -it noisecapt amixer --card 2 cset numid=9 off`. Again, your card number and numid may vary.

4. Finally, max out the microphone volume. Look for the line below `Mic Capture Volume` where it says `...,min=0,max=nnn`. You want to set it to whatever the stated max value is:

    ```text
    numid=8,iface=MIXER,name='Mic Capture Volume'
      ; type=INTEGER,access=rw---R--,values=1,min=0,max=16,step=0
      : values=16
      | dBminmax-min=0.00dB,max=23.81dB
    ```

    In our case, it's card 2, numid=8, and max value is 16:
    `docker exec -it noisecapt amixer --card 2 cset numid=8 16`

5. Make it permanent

- execute this command: `docker exec -it noisecapt alsactl store`
- add this variable to your `docker-compose.yml` in the environment section: `PF_ALSA_MANUAL=ON`. With that, the system won't try to do its own thing next time the container is booted.

## Acknowledgements, Attributions, and License

I would never have been able to do this without the huge contributions of [Mikenye](http://github.com/mikenye), [Fredclausen](http://github.com/fredclausen), and [Wiedehopf](http://github.com/wiedehopf). Thank you very much!

### Attributions

### License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.
