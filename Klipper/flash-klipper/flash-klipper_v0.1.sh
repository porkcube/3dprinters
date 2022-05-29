#!/usr/bin/env bash

# script will auto-detect the /dev/serial/by-id/ path to mainboard
# it will also auto-detect the V0.Display device id for dfu-util
# you will need to run make menuconfig per device and then copy the .config 
# generated to .config-(board name) and .config-display to skip make menuconfig
# it will also create ~/firmwares/ dir to archive compiled firmwares

# update to match your main board
mainBoard="btt-skr-mini-e3-v2"
klipperVers=$( cat ~/klipper/out/compile_time_request.c | grep -Fi 'version:' | awk '{print $3}' | cut -c 2- )

flashDisplay() {
    promptText="proceed to compile + flash V0 Display?"
    #prompt
    sudo service klipper stop
    cd ~/klipper/
    cp .config-display .config
    make clean
    make -j4
    promptText="power off display, add DFU jumper, power on"
    prompt
    displayAddress=$( dfu-util -l | tail -1 | awk '{print $3}' | cut -c 2- | cut -c -9 )
    promptText="proceed to flash V0 Display @ [${displayAddress}]?"
    prompt
    make flash FLASH_DEVICE="${displayAddress}"
    dir="display"
    makeDirs
    cp out/klipper.bin "../firmwares/display/${klipperVers}/klipper.bin"
    sudo service klipper start
    echo "remove DFU jumper and power-cycle display"
}

flashHost(){
    promptText="proceed to compile for raspi host?"
    #prompt
    sudo service klipper stop
    cd ~/klipper/
    cp .config-rpi .config
    make clean
    make -j4 flash
    promptText="proceed to update raspi host?"
    #prompt
    sudo service klipper start
}

flashMain(){
    # match the name / revision of your main board
    mainAddress=$( ls /dev/serial/by-id/usb-Klipper_stm32f103xe* | cut -d / -f 5 )
    promptText="proceed to compile + flash ${mainBoard}?"
    #prompt
    sudo service klipper stop
    cd ~/klipper/
    cp .config-"${mainBoard}" .config
    make clean
    make -j4
    promptText="proceed to flash ${mainBoard}"
    #prompt
    scripts/flash-sdcard.sh /dev/serial/by-id/"${mainAddress}" "${mainBoard}"
    dir="${mainBoard}"
    makeDirs
    cp out/klipper.bin "../firmwares/${mainBoard}/${klipperVers}/klipper.bin"
    sudo service klipper start
}

makeDirs() {
    if [[ ! -d "../firmwares/${dir}/${klipperVers}" ]]; then
        mkdir -p "../firmwares/${dir}/${klipperVers}"
    fi
}

prompt(){
   echo "${promptText}"
   read -p "press enter to continue / ctrl-c to quit"
}


if [ "${1}" == "display" ]; then
    flashDisplay
elif [ "${1}" == "main" ]; then
    flashMain
elif [ "${1}" == "host" ]; then
    flashHost
elif [ "${1}" == "all" ]; then
    promptText="flash both main and display boards + host?"
    #prompt
    flashMain
    prompt
    flashDisplay
    flashHost
else
    echo "usage:"
    echo "    flash-klipper.sh display | flash display board via dfu"
    echo "    flash-klipper.sh main    | flash main board via sdcard"
    echo "    flash-klipper.sh host    | flash raspi host"
    echo "    flash-klipper.sh all     | flash all: main and display boards and raspi host"
fi