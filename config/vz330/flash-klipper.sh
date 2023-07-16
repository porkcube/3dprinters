#!/usr/bin/env bash

#devPath="/dev/ttyACM0"
devPath="/dev/serial/by-id/usb-Klipper_stm32h723xx_15002E001651313338343730-if00"
mainBoard="super8pro"
hostModel="$(grep -m1 Model /proc/cpuinfo | cut -d: -f 2- | sed 's/^ //')"
klipperVers="$( cat ~/klipper/out/compile_time_request.c | grep -Fi 'version:' | awk '{print $3}' | cut -c 2- )"

flashHost(){
    promptText="proceed to compile + flash ${hostModel}?"
    prompt
    cd ~/klipper/
    cp .config-rpi .config
    make clean
    make -j$(nproc) flash
}

flashMain(){
    promptText="proceed to compile + flash ${mainBoard}?"
    prompt
    cd ~/klipper/
    cp .config-"${mainBoard}" .config
    make clean
    make -j$(nproc)
#    scripts/flash-sdcard.sh "${dev/Path}" #  "${mainBoard}"
#    scripts/flash-sdcard.sh /dev/ttyACM0 "${mainBoard}"
    make flash FLASH_DEVICE="${devPath}"
    dir="${mainBoard}"
    makeDirs
    cp out/klipper.bin "../firmwares/${mainBoard}/${klipperVers}/klipper.bin"
}

klipper(){
    sudo service klipper "${1}"
}

makeDirs() {
    if [[ ! -d "../firmwares/${dir}/${klipperVers}" ]]; then
        mkdir -p "../firmwares/${dir}/${klipperVers}"
    fi
}

prompt(){
   echo "=========] ${promptText}"
#   read -p "press enter to continue / ctrl-c to quit"
}


if [ "${1}" == "host" ]; then
    klipper stop
    flashHost
elif [ "${1}" == "main" ]; then
    klipper stop
    flashMain
elif [ "${1}" == "all" ]; then
    klipper stop
    flashHost
    flashMain
else
    echo "usage:"
    echo "    flash-klipper.sh host     | flash ${hostModel}"
    echo "    flash-klipper.sh main     | flash ${mainBoard}"
    echo "    flash-klipper.sh all      | flash all: ${hostModel} + ${mainBoard}"
    exit 0
fi

klipper start

