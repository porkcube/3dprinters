#!/usr/bin/env bash

# script will auto-detect the /dev/serial/by-id/ path to mainboard
# it will also auto-detect the V0.Display device id for dfu-util
# you will need to run make menuconfig per device and then copy the .config
# generated to .config-(board name) and .config-display to skip make menuconfig
# it will also create ~/firmwares/ dir to archive compiled firmwares

klipperVers=$( cat ~/klipper/out/compile_time_request.c | grep -Fi 'version:' | awk '{print $3}' | cut -c 2- )

flashHost(){
    promptText="proceed to compile for raspi host?"
    cd ~/klipper/
    cp .config-opi .config
    make clean
    make -j$(nproc) flash
}

klipper(){
    sudo service klipper "${1}"
}

prompt(){
   echo "${promptText}"
   read -p "press enter to continue / ctrl-c to quit"
}


if [ "${1}" == "host" ]; then
    klipper stop
    flashHost
elif [ "${1}" == "all" ]; then
    klipper stop
    promptText="flash both host + pico?"
    flashHost
else
    echo "usage:"
    echo "    flash-klipper.sh host    | flash raspi host"
    echo "    flash-klipper.sh all     | flash all: raspi host and rp2040"
    exit 0
fi

klipper start