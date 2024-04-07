#!/bin/bash

# This script is used to migrate the S6-v3-Examples to the new directory structure

# The user should pass in one argument, which is the path to the directory structure to migrate.
# The script will then copy the files from the old directory structure to the new one.


# function to move the services.d directory
# should take in the name of the directory to move

cont_init_files=()

function move_services_d {
    service=$(basename $1)
    echo "Creating etc/s6-overlay/s6-rc.d/user/contents.d/$service" || exit 1
    touch $dir/etc/s6-overlay/s6-rc.d/user/contents.d/$service || exit 1
    echo "Creating etc/s6-overlay/s6-rc.d/$service" || exit 1
    mkdir -p $dir/etc/s6-overlay/s6-rc.d/$service || exit 1
    echo "Creating etc/s6-overlay/s6-rc.d/$service/type" || exit 1
    echo "longrun" > $dir/etc/s6-overlay/s6-rc.d/$service/type || exit 1
    echo "Creating etc/s6-overlay/s6-rc.d/$service/run" || exit 1
    echo "#!/bin/sh" > $dir/etc/s6-overlay/s6-rc.d/$service/run || exit 1
    echo "exec /etc/s6-overlay/scripts/$service" >> $dir/etc/s6-overlay/s6-rc.d/$service/run || exit 1
    echo "Moving $file to etc/s6-overlay/scripts/$service" || exit 1
    # if there is a run file, move it to the scripts directory
    if [ -f $1/run ]
    then
        cp $1/run $dir/etc/s6-overlay/scripts/$service || exit 1
        # replace #!/command/with-contenv bash with #!/command/with-contenv bash
        sed -i 's/#!\/usr\/bin\/with-contenv bash/#!\/command\/with-contenv bash/g' $dir/etc/s6-overlay/scripts/$service || exit 1
        echo "Making $dir/etc/s6-overlay/scripts/$service executable" || exit 1
        chmod +x $dir/etc/s6-overlay/scripts/$service || exit 1
    else
        echo "No run file. Skipping"
        # create a .blank file in $dir/etc/s6-overlay/s6-rc.d/services
        touch $dir/etc/s6-overlay/s6-rc.d/$service/.blank || exit 1
    fi

    echo "Creating $dir/etc/s6-overlay/s6-rc.d/$service/dependencies.d" || exit 1
    mkdir -p $dir/etc/s6-overlay/s6-rc.d/$service/dependencies.d || exit 1
    # if we have any cont-init files, add them to the dependencies.d directory, else add base
    if [ ${#cont_init_files[@]} -eq 0 ]
    then
        echo "Creating $dir/etc/s6-overlay/s6-rc.d/$service/dependencies.d/base" || exit 1
        touch $dir/etc/s6-overlay/s6-rc.d/$service/dependencies.d/base || exit 1
    else
        for cont_init_file in ${cont_init_files[@]}
        do
            echo "Creating $dir/etc/s6-overlay/s6-rc.d/$service/dependencies.d/$cont_init_file" || exit 1
            touch $dir/etc/s6-overlay/s6-rc.d/$service/dependencies.d/$cont_init_file || exit 1
        done
    fi
}

# get the path to the directory structure to migrate
if [ $# -eq 0 ]
then
    echo "Please pass in the path to the directory structure to migrate."
    exit 1
fi

# save the dir to a variable and ensure it exists

dir=$1
if [ ! -d $dir ]
then
    echo "The directory $dir does not exist."
    exit 1
fi

# ensure the directory structure is correct. It should have etc/services.d

if [ ! -d $dir/etc/services.d ]
then
    echo "The directory $dir does not have etc/services.d"
    exit 1
fi

if [ -d $dir/etc/services.d/cont-finish.d ]
then
    echo "*********************************************************************"
    echo "WARNING: The directory $dir/etc/services.d/cont-finish.d exists."
    echo "This directory will be moved to $dir/back. Please ensure that you"
    echo "move the files in this directory to the appropriate location in"
    echo "the new directory structure."
    echo "*********************************************************************"
fi

echo "Migrating $dir"

echo "Ensuring $dir/etc/s6-overlay is cleaned out and (re)create the structure"
rm -rf $dir/etc/s6-overlay || exit 1

# create the new directory structure

mkdir -p $dir/etc/s6-overlay/s6-rc.d/user/contents.d || exit 1
mkdir -p $dir/etc/s6-overlay/scripts || exit 1

# check and see if there are etc/cont-init.d files. if so, move them to etc/s6-overlay/s6-rc/scripts
# for every file we find, create a file with the name of the service in etc/s6-overlay/user/contents.d
# and also create a directory in etc/s6-overlay/s6-rc.d/s6-rc.d with the name of the service, and also create
# a file called "type" in that directory with the contents "oneshot", and also a file called "up" that contains
# the name of the file in etc/s6-overlay/s6-rc/scripts

if [ -d $dir/etc/cont-init.d ]
then
    echo "Found etc/cont-init.d"
    for file in $dir/etc/cont-init.d/*
    do
        echo "Found $file" || exit 1
        service=$(basename $file) || exit 1
        echo "Creating etc/s6-overlay/s6-rc.d/user/contents.d/$service" || exit 1
        touch $dir/etc/s6-overlay/s6-rc.d/user/contents.d/$service || exit 1
        echo "Creating etc/s6-overlay/s6-rc.d/$service" || exit 1
        mkdir -p $dir/etc/s6-overlay/s6-rc.d/$service || exit 1
        echo "Creating etc/s6-overlay/s6-rc.d/$service/type" || exit 1
        echo "oneshot" > $dir/etc/s6-overlay/s6-rc.d/$service/type || exit 1
        echo "Creating etc/s6-overlay/s6-rc.d/$service/up" || exit 1
        echo "#!/bin/sh" > $dir/etc/s6-overlay/s6-rc.d/$service/up || exit 1
        echo "exec /etc/s6-overlay/scripts/$service" >> $dir/etc/s6-overlay/s6-rc.d/$service/up || exit 1
        echo "Moving $file to etc/s6-overlay/scripts/$service" || exit 1
        cp $file $dir/etc/s6-overlay/scripts/$service || exit 1
        # replace #!/command/with-contenv bash with #!/command/with-contenv bash
        sed -i 's/#!\/usr\/bin\/with-contenv bash/#!\/command\/with-contenv bash/g' $dir/etc/s6-overlay/scripts/$service || exit 1
        echo "Making $dir/etc/s6-overlay/scripts/$service executable" || exit 1
        chmod +x $dir/etc/s6-overlay/scripts/$service || exit 1
        # save the file name to an array
        cont_init_files+=($service) || exit 1
    done

    echo "Fixing dependencies and execution order for etc/cont-init.d"
    # (ls sorts by default in alpha order, which is what we want)
    # shellcheck disable=SC2207,SC2011
    list=($(ls "$dir/etc/cont-init.d/"|xargs))
    # iterate through the list of files starting from the second file
    for service in "${list[@]:1}"; do
        mkdir -p "$dir/etc/s6-overlay/s6-rc.d/$service/dependencies.d" || exit 1
        echo -n "dir $service dependencies: "
        # now make dependency files for each of the predecessors:
        for dependency in "${list[@]}"; do
            if [[ "$dependency" == "$service" ]]; then break; fi
            echo -n "$dependency "
            touch "$dir/etc/s6-overlay/s6-rc.d/$service/dependencies.d/$dependency" || exit 1
        done
        echo ""
    done
fi

# check and see if there are etc/services.d files. if so, move them to etc/s6-overlay/s6-rc.d/user/contents.d
# for every file we find, create a file with the name of the service in etc/s6-overlay/user/contents.d
# and also create a directory in etc/s6-overlay/s6-rc.d/s6-rc.d with the name of the service, and also create
# a file called "type" in that directory with the contents "longrun", and also a file called "up" that contains
# the name of the file in etc/s6-overlay/s6-rc/scripts
# we also need to create a dependencies.d directory in the service directory, and create a file called "base" in it

if [ -d $dir/etc/services.d ]
then
    echo "Found etc/services.d"
    for file in $dir/etc/services.d/*
    do
        echo "Found $file" || exit 1
        move_services_d $file || exit 1

        # if $file includes any directories, we need call move_services_d on them
        for subfile in $file/*
        do
            if [ -d $subfile ]
            then
                echo "Found a sub directory, $subfile" || exit 1
                move_services_d $subfile || exit 1
                # we need to add the name of the parent to the dependencies.d directory of the subfile
                service_parent=$(basename $file) || exit 1
                service=$(basename $subfile) || exit 1
                echo "Creating $dir/etc/s6-overlay/s6-rc.d/$service/dependencies.d/$service_parent" || exit 1
                touch $dir/etc/s6-overlay/s6-rc.d/$service/dependencies.d/$service_parent || exit 1

                # now ensure the name is unqiue and refers to the parent
                rm $dir/etc/s6-overlay/s6-rc.d/$service/run
                echo "#!/bin/sh" > $dir/etc/s6-overlay/s6-rc.d/$service/run || exit 1
                echo "exec /etc/s6-overlay/scripts/$service_parent-$service" >> $dir/etc/s6-overlay/s6-rc.d/$service/run || exit 1
                mv $dir/etc/s6-overlay/scripts/$service $dir/etc/s6-overlay/scripts/$service_parent-$service || exit 1
                mv $dir/etc/s6-overlay/s6-rc.d/$service $dir/etc/s6-overlay/s6-rc.d/$service_parent-$service || exit 1
                mv $dir/etc/s6-overlay/s6-rc.d/user/contents.d/$service $dir/etc/s6-overlay/s6-rc.d/user/contents.d/$service_parent-$service || exit 1
            fi
        done
    done
fi

# move all of the cont-init.d and services.d files to $dir/back

# remove $dir/back if it exists
if [ -d $dir/back ]
then
    echo "Removing $dir/back"
    rm -rf $dir/back || exit 1
fi

mkdir -p $dir/back || exit 1

if [ -d $dir/etc/cont-init.d ]
then
    echo "Moving $dir/etc/cont-init.d to $dir/back" || exit 1
    mv -v $dir/etc/cont-init.d $dir/back || exit 1
fi

echo "Moving $dir/etc/services.d to $dir/back" || exit 1
mv -v $dir/etc/services.d $dir/back || exit 1

# we need to fix shebangs, make sure scripts are executable, and fix healthcheck legacy-services

# loop through all of the files

echo "Fixing shebangs, making scripts executable, and fixing healthcheck legacy-services"

for file in $(find $dir -type f)
do
    # if it's a file and the path does include back
    if [ -f $file ] && [[ $file != *"back"* ]]
    then
        echo "Fixing shebang for $file" || exit 1
        sed -i 's/#!\/usr\/bin\/with-contenv/#!\/command\/with-contenv/g' $file || exit 1
        sed -i 's/#!\/usr\/bin\/env/#!\/command\/with-contenv/g' $file || exit 1
        sed -i 's/run\/s6\/legacy-services/run\/service/g' $file || exit 1

        # if the file includes a shebang make it executable
        if grep -q "#!" $file
        then
            echo "Making $file executable" || exit 1
            chmod +x $file || exit 1
        fi
    fi
done
