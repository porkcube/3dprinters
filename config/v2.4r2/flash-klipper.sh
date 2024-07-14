#!/usr/bin/env bash

# script will auto-detect the /dev/serial/by-id/ path to mainboard
# it will also auto-detect the V0.Display device id for dfu-util
# you will need to run make menuconfig per device and then copy the .config 
# generated to .config-(board name) and .config-display to skip make menuconfig
# it will also create ~/firmwares/ dir to archive compiled firmwares

## UUID of CAN device
octopus_CANuuid="51798926ca0d"
sb2040_CANuuid="9f944e51ea3a"
klipperVers=$( cat ~/klipper/out/compile_time_request.c | grep -Fi 'version:' | awk '{print $3}' | cut -c 2- )
#mainAddress="usb-Klipper_stm32f446xx_37003B001950534841313020-if00"
startKlipper=0

flashHost(){
    promptText="proceed to compile for raspi host?"
    cd ~/klipper/
    cp .config-rpi .config
    make clean
    make -j$(nproc) flash
}

flashMain(){
#    # match the name / revision of your main board
#    if [[ -z "$mainAddress" ]]; then
#	mainAddress=$( ls /dev/serial/by-id/usb-Klipper_stm32f446xx* | cut -d / -f 5 )
#    fi
    promptText="proceed to compile + flash ${octopus_CANuuid}?"
    cd ~/klipper/
    cp .config-octopus_v1.1 .config
    make clean
    ~/Katapult/scripts/flashtool.py \
        -r \
        -u "${octopus_CANuuid}"
    printf 'Waiting for octopus to enter USB DFU mode.'
    i="1"
    while [ "${i}" -le 5 ]; do
        printf '.'
        sleep 1;
        ((i+=1));
    done
    printf '\n'
    #make -j$(nproc) flash FLASH_DEVICE="/dev/serial/by-id/${mainAddress}"
    make -j$(nproc) flash FLASH_DEVICE=0483:df11
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
    cp .config-sb2040 .config
    make clean
    make -j$(nproc)
    python3 ~/Katapult/scripts/flashtool.py \
        -r \
        -u "${sb2040_CANuuid}"
    python3 ~/Katapult/scripts/flashtool.py \
        -i can0 \
        -f ~/klipper/out/klipper.bin \
        -u "${sb2040_CANuuid}"
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
    startKlipper=1
elif [ "${1}" == "host" ]; then
    klipper "stop"
    flashHost
    startKlipper=1
elif [ "${1}" == "pico" ]; then
    klipper "stop"
    flashPico
    startKlipper=1
elif [ "${1}" == "sb2040" ]; then
    klipper "stop"
    flashSB2040
    startKlipper=1
elif [ "${1}" == "most" ]; then
    promptText="flash main and host?"
    klipper "stop"
    flashMain
    flashHost
    startKlipper=1
elif [ "${1}" == "all" ]; then
    promptText="flash main, sb2040 and host?"
    klipper "stop"
    flashMain
    flashHost
    flashSB2040
    startKlipper=1
else
    echo "usage:"
    echo "    flash-klipper.sh main    | flash main octopus via sdcard"
    echo "    flash-klipper.sh host    | flash raspi host"
    echo "    flash-klipper.sh pico    | flash raspi pico / rp2040"
    echo "    flash-klipper.sh sb2040  | flash raspi Fly SB2040"
    echo "    flash-klipper.sh most    | flash all: octopus / host"
    echo "    flash-klipper.sh all     | flash all: main, fly-sb2040 and raspi host"
fi

if [[ "${startKlipper}" == 1 ]]; then
    klipper "start"
fi
