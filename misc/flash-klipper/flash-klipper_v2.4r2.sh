#!/usr/bin/env bash

# script will auto-detect the /dev/serial/by-id/ path to mainboard
# it will also auto-detect the V0.Display device id for dfu-util
# you will need to run make menuconfig per device and then copy the .config 
# generated to .config-(board name) and .config-display to skip make menuconfig
# it will also create ~/firmwares/ dir to archive compiled firmwares

## UUID of CAN device
CANuuid="9f944e51ea3a"
mainAddress="usb-Klipper_stm32f446xx_37003B001950534841313020-if00"
klipperVers=$( cat ~/klipper/out/compile_time_request.c | grep -Fi 'version:' | awk '{print $3}' | cut -c 2- )

flashHost(){
    promptText="proceed to compile for raspi host?"
    cd ~/klipper/
    cp .config-rpi .config
    make clean
    make -j$(nproc) flash
    promptText="proceed to update raspi host?"
}

flashMain(){
    # match the name / revision of your main board
    if [[ -z "$mainAddress" ]]; then
	    mainAddress=$( ls /dev/serial/by-id/usb-Klipper_stm32f446xx* | cut -d / -f 5 )
    fi
    promptText="proceed to compile + flash ${mainAddress}?"
    cd ~/klipper/
    cp .config-octopus_v1.1 .config
    make clean
    promptText="proceed to flash /dev/serial/by-id/${mainAddress}"
    make -j$(nproc) flash FLASH_DEVICE="/dev/serial/by-id/${mainAddress}"
    #make -j$(nproc) flash FLASH_DEVICE=0483:df11
}

flashPico(){
    promptText="proceed to compile for raspi pico?"
    cd ~/klipper
    cp .config-rp2040 .config
    make clean
    make -j$(nproc)
    promptText="connect USB while hoolding BOOT button down"
    prompt
    #sudo make flash FLASH_DEVICE=2e8a:0003
    if [ -e /dev/sda1 ]; then
        sudo mount /dev/sda1 /mnt
    fi
    while [ ! -e /mnt/INDEX.HTM ]; do
        sleep 1
    done
    sudo cp out/klipper.uf2 /mnt/klipper.uf2
    sync
    sudo umount /mnt
}

flashSB2040(){
    promptText="proceed to compile for fly sb2040 and flash via CAN?"
    cd ~/klipper
    cp .config-flysb2040 .config
    make clean
    make -j$(nproc)
    python3 ~/klipper/lib/canboot/flash_can.py -i can0 -f ~/klipper/out/klipper.bin -u "${CANuuid}"
}

klipper(){
    sudo service klipper "${1}"
}

prompt(){
   echo "${promptText}"
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
elif [ "${1}" == "pico" ]; then
    klipper "stop"
    flashPico
    klipper "start"
elif [ "${1}" == "sb2040" ]; then
    klipper "stop"
    flashSB2040
    klipper "start"
elif [ "${1}" == "all" ]; then
    promptText="flash main, sb2040 and host?"
    klipper "stop"
    flashMain
    flashHost
    flashSB2040
    klipper "start"
else
    echo "usage:"
    echo "    flash-klipper.sh main    | flash main board via sdcard"
    echo "    flash-klipper.sh host    | flash raspi host"
    echo "    flash-klipper.sh pico    | flash raspi pico / rp2040"
    echo "    flash-klipper.sh sb2040  | flash fly-sb2040 CAN board"
    echo "    flash-klipper.sh all     | flash all: main, fly-sb2040 and raspi host"
fi
