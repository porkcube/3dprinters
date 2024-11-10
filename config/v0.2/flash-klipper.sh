#!/usr/bin/env bash

mainBoard="btt-skr-pico"
canBoard="SHT36"
canInterface="can0"
canSpeed="1000000"
hostModel="$(grep -m1 Model /proc/cpuinfo | cut -d: -f 2- | sed 's/^ //')"
klipperVers="$( cat ~/klipper/out/compile_time_request.c | grep -Fi 'version:' | awk '{print $3}' | cut -c 2- )"
startKlipper=0

flashCAN() {
    canUUID="41ffd913051f"
    promptText="proceed to compile + flash ${canBoard}?"
    prompt
    cd ~/klipper/
    cp .config-sht36 .config
    make clean
    make -j"$(nproc)"
    python3 ~/Katapult/scripts/flashtool.py \
        -i "${canInterface}" \
        -b "${canSpeed}" \
        -r \
        -u "${canUUID}"
    python3 ~/Katapult/scripts/flashtool.py \
        -i "${canInterface}" \
        -b "${canSpeed}" \
        -f ~/klipper/out/klipper.bin \
        -u "${canUUID}"
}

flashHost(){
    promptText="proceed to compile + flash ${hostModel}?"
    prompt
    cd ~/klipper/
    cp .config-rpi .config
    make clean
    make -j"$(nproc)" flash
}

flashMain(){
    canUUID="2e64f5de5b4f"
    promptText="proceed to compile + flash ${mainBoard}?"
    prompt
    #devPath="$(ls /dev/serial/by-id/usb-katapult_rp2040_*)"
    cd ~/klipper/
    cp .config-"${mainBoard}" .config
    make clean
    make -j"$(nproc)"
    # reset klipper to katapult
    python3 ~/Katapult/scripts/flashtool.py \
        -r \
	-u "${canUUID}"
#    sleep 5

    printf 'Waiting for %s to enter USB DFU mode.' "${mainBoard}"
    i="1"
    while [ "${i}" -le 5 ]; do
        printf '.'
        sleep 1;
        ((i+=1));
    done
    printf '\n'

    # reflash klipper via serial path
    python3 ~/Katapult/scripts/flashtool.py \
        -f ~/klipper/out/klipper.bin \
        -d "$(ls /dev/serial/by-id/usb-katapult_rp2040_*)"
#        -d "${devPath}"
    #make flash FLASH_DEVICE=2e8a:0003
    promptText="go press the reset button on ${mainBoard}"
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
   #read -p "press enter to continue / ctrl-c to quit"
}


if [ "${1}" == "can" ]; then
    klipper stop
    flashCAN
    startKlipper=1
elif [ "${1}" == "host" ]; then
    klipper stop
    flashHost
    startKlipper=1
elif [ "${1}" == "main" ]; then
    klipper stop
    flashMain
    startKlipper=1
elif [ "${1}" == "most" ]; then
    klipper stop
    flashCAN
    flashHost
    startKlipper=1
elif [ "${1}" == "all" ]; then
    klipper stop
    flashCAN
    flashHost
    flashMain
    startKlipper=1
else
    echo "usage:"
    echo "    flash-klipper.sh can      | flash ${canBoard}"
    echo "    flash-klipper.sh host     | flash ${hostModel}"
    echo "    flash-klipper.sh main     | flash ${mainBoard}"
    echo "    flash-klipper.sh most     | flash ${canBoard} + ${hostModel}"
    echo "    flash-klipper.sh all      | flash all: ${canBoard} + ${hostModel} + ${mainBoard}"
    exit 0
fi


if [[ "${startKlipper}" == 1 ]]; then
    klipper start
fi
