#!/usr/bin/env bash

flashHost(){
    promptText="proceed to compile for raspi host?"
    cd ~/klipper/
    cp .config-rpi .config
    make clean
    make -j$(nproc) flash
}

flashMain(){
    promptText="proceed to compile for raspi pico?"
    cd ~/klipper
    cp .config-skr-pico .config
    make clean
    make -j$(nproc)
    make flash FLASH_DEVICE=/dev/serial/by-id/usb-Klipper_rp2040_45503571288F3508-if00
    sleep 5;
    make flash FLASH_DEVICE=2e8a:0003 # above seems to enter bootloader mode
#    if [ -e /dev/sda1 ]; then
#        sudo mount /dev/sda1 /mnt
#    fi
#    while [ ! -e /mnt/INDEX.HTM ]; do
#        sleep 1
#    done
#    sudo cp out/klipper.uf2 /mnt/klipper.uf2
#    sync
#    sudo umount /mnt
}


klipper(){
    sudo service klipper "${1}"
}

prompt(){
   echo "=========] ${promptText}"
   read -p "press enter to continue / ctrl-c to quit"
}

if [ "${1}" == "main" ]; then
    klipper "stop"
    flashMain
    klipper "start"
elif [ "${1}" == "host" ]; then
    klipper "stop"
    flashHost
    klipper "start"
elif [ "${1}" == "all" ]; then
    promptText="flash main and host?"
    klipper "stop"
    flashMain
    flashHost
    klipper "start"
else
    echo "usage:"
    echo "    flash-klipper.sh main    | flash main board via sdcard"
    echo "    flash-klipper.sh host    | flash raspi host"
    echo "    flash-klipper.sh all     | flash all: main and raspi host"
fi
