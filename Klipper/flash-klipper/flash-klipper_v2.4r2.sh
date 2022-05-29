#!/usr/bin/env bash

# script will auto-detect the /dev/serial/by-id/ path to mainboard
# it will also auto-detect the V0.Display device id for dfu-util
# you will need to run make menuconfig per device and then copy the .config 
# generated to .config-(board name) and .config-display to skip make menuconfig
# it will also create ~/firmwares/ dir to archive compiled firmwares

klipperVers=$( cat ~/klipper/out/compile_time_request.c | grep -Fi 'version:' | awk '{print $3}' | cut -c 2- )

flashHost(){
    promptText="proceed to compile for raspi host?"
    #prompt
    sudo service klipper stop
    cd ~/klipper/
    cp .config-rpi .config
    make clean
    make -j$(nproc) flash
    promptText="proceed to update raspi host?"
    #prompt
    sudo service klipper start
}

flashMain(){
    # match the name / revision of your main board
    mainAddress=$( ls /dev/serial/by-id/usb-Klipper_stm32f446xx* | cut -d / -f 5 )
    promptText="proceed to compile + flash ${mainAddress}?"
    #prompt
    sudo service klipper stop
    cd ~/klipper/
    cp .config-octopus_v1.1 .config
    make clean
    make -j$(nproc)
    promptText="proceed to flash /dev/serial/by-id/${mainAddress}?"
    #prompt
    make -j$(nproc) flash FLASH_DEVICE="/dev/serial/by-id/${mainAddress}"
    # make -j4 flash FLASH_DEVICE=0483:df11
    sudo service klipper start
}

flashPico(){
    promptText="proceed to compile for raspi pico?"
    #prompt
    sudo service klipper stop
    cd ~/klipper
    cp .config-rp2040 .config
    make clean
    make -j$(nproc)
    promptText="connect USB while hoolding BOOT button down"
    prompt
    if [ -e /dev/sda1 ]; then
        sudo mount /dev/sda1 /mnt
    fi
    while [ ! -e /mnt/INDEX.HTM ]; do
        sleep 1
    done
    sudo cp out/klipper.uf2 /mnt/klipper.uf2
    sync
    sudo umount /mnt
    sudo service klipper start
}

prompt(){
   echo "${promptText}"
   read -p "press enter to continue / ctrl-c to quit"
}


if [ "${1}" == "main" ]; then
    flashMain
elif [ "${1}" == "host" ]; then
    flashHost
elif [ "${1}" == "pico" ]; then
    flashPico
elif [ "${1}" == "all" ]; then
    promptText="flash both main + host?"
    #prompt
    flashMain
        flashHost
else
    echo "usage:"
    echo "    flash-klipper.sh main    | flash main board via sdcard"
    echo "    flash-klipper.sh host    | flash raspi host"
    echo "    flash-klipper.sh pico    | flash raspi pico / rp2040"
    echo "    flash-klipper.sh all     | flash all: main and raspi host"
fi