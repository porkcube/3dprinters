#!/usr/bin/env bash

mainBoard="btt-skr-pico"
canBoard="SHT36"
hostModel="$(grep -m1 Model /proc/cpuinfo | cut -d: -f 2- | sed 's/^ //')"
klipperVers="$( cat ~/klipper/out/compile_time_request.c | grep -Fi 'version:' | awk '{print $3}' | cut -c 2- )"

flashCAN() {
    canuuid="41ffd913051f"
    promptText="proceed to compile + flash ${canBoard}?"
    prompt
    cd ~/klipper/
    cp .config-sht36 .config
    make clean
    make -j$(nproc)
    ## python3 ~/CanBoot/scripts/flash_can.py -r -u "${canuuid}"
    python3 ~/CanBoot/scripts/flash_can.py -i can0 -f ~/klipper/out/klipper.bin -u "${canuuid}"
    # python3 ~/klipper/lib/canboot/flash_can.py -v -u "${canuuid}"
}

flashHost(){
    promptText="proceed to compile + flash ${hostModel}?"
    prompt
    cd ~/klipper/
    cp .config-rpi .config
    make clean
    make -j$(nproc) flash
}

flashMain(){
    canuuid="2e64f5de5b4f"
    promptText="proceed to compile + flash ${mainBoard}?"
    prompt
    cd ~/klipper/
    cp .config-"${mainBoard}" .config
    make clean
    make -j$(nproc)
    python3 ~/CanBoot/scripts/flash_can.py -r -u "${canuuid}" -f ~/klipper/out/klipper.uf2
    sleep 5
    make flash FLASH_DEVICE=2e8a:0003
    ## fails cause make flash doesn't reset properly 8/
    #sudo usbreset 2e8a:0003
    promptText="go press the reset button on ${mainBoard}"
    dir="${mainBoard}"
    makeDirs
    cp out/klipper.uf2 "../firmwares/${mainBoard}/${klipperVers}/klipper.bin"
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
   read -p "press enter to continue / ctrl-c to quit"
}


if [ "${1}" == "can" ]; then
    klipper stop
    flashCAN
elif [ "${1}" == "host" ]; then
    klipper stop
    flashHost
elif [ "${1}" == "main" ]; then
    klipper stop
    flashMain
elif [ "${1}" == "most" ]; then
    klipper stop
    flashCAN
    flashHost
elif [ "${1}" == "all" ]; then
    klipper stop
    flashCAN
    flashHost
    flashMain
else
    echo "usage:"
    echo "    flash-klipper.sh can      | flash ${canBoard}"
    echo "    flash-klipper.sh host     | flash ${hostModel}"
    echo "    flash-klipper.sh main     | flash ${mainBoard}"
    echo "    flash-klipper.sh most     | flash ${canBoard} + ${hostModel}"
    echo "    flash-klipper.sh all      | flash all: ${canBoard} + ${hostModel} + ${mainBoard}"
    exit 0
fi

klipper start