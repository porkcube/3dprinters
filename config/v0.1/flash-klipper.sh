#!/usr/bin/env bash

# script will auto-detect the /dev/serial/by-id/ path to mainboard
# it will also auto-detect the V0.Display device id for dfu-util
# you will need to run make menuconfig per device and then copy the .config
# generated to .config-(board name) and .config-display to skip make menuconfig
# it will also create ~/firmwares/ dir to archive compiled firmwares

# update to match your main board
mainBoard="btt-skr-mini-e3-v2"
klipperVers=$( cat ~/klipper/out/compile_time_request.c | grep -Fi 'version:' | awk '{print $3}' | cut -c 2- )

flashCAN() {
    canuuid="705e06a96060"
    cd ~/klipper/
    cp .config-sht36v2 .config
    make clean
    make -j$(nproc)
    python3 ~/klipper/lib/canboot/flash_can.py -v -u "${canuuid}"
}

flashDisplay() {
    promptText="proceed to compile + flash V0 Display?"
    cd ~/klipper/
    cp .config-display .config
    make clean
    make -j$(nproc)
    promptText="power off display, add DFU jumper, power on"
    prompt
    displayAddress=$( dfu-util -l | tail -1 | awk '{print $3}' | cut -c 2- | cut -c -9 )
    promptText="proceed to flash V0 Display @ [${displayAddress}]?"
    prompt
    make -j$(nproc) flash FLASH_DEVICE="${displayAddress}"
  # sudo dfu-util -p 1-1.2 -R -a 0 -s 0x8000000:leave -D out/klipper.bin
    dir="display"
    makeDirs
    cp out/klipper.bin "../firmwares/display/${klipperVers}/klipper.bin"
    echo "remove DFU jumper and power-cycle display"
}

flashExpander() {
    promptText="proceed to compile + flash Expander board?"
    cd ~/klipper/
    cp .config-expander .config
    make clean
    make -j$(nproc)
    promptText="power off expander, add DFU jumper, power on"
    prompt
    expanderAddress="usb-Klipper_stm32f042x6_2F0002801943303054313620-if00"
    #expanderAddress=$( ls /dev/serial/by-id/usb-Klipper_stm32f103xe* | cut -d / -f 5 )
	promptText="proceed to flash Expander @ [${expanderAddress}]?"
    #displayAddress=$( dfu-util -l | tail -1 | awk '{print $3}' | cut -c 2- | cut -c -9 )
    #promptText="proceed to flash V0 Display @ [${displayAddress}]?"
    prompt
    make flash FLASH_DEVICE="${expanderAddress}"
  # sudo dfu-util -p 1-1.2 -R -a 0 -s 0x8000000:leave -D out/klipper.bin
    dir="expander"
    makeDirs
    cp out/klipper.bin "../firmwares/expander/${klipperVers}/klipper.bin"
    echo "remove DFU jumper and power-cycle expander"
}

flashHost(){
    promptText="proceed to compile for raspi host?"
    cd ~/klipper/
    cp .config-rpi .config
    make clean
    make -j$(nproc) flash
    promptText="proceed to update raspi host?"
    #prompt
}

flashMain(){
    # match the name / revision of your main board
    mainAddress=$( ls /dev/serial/by-id/usb-Klipper_stm32f103xe* | cut -d / -f 5 )
    promptText="proceed to compile + flash ${mainBoard}?"
    cd ~/klipper/
    cp .config-"${mainBoard}" .config
    make clean
    make -j$(nproc)
    promptText="proceed to flash ${mainBoard}"
    scripts/flash-sdcard.sh /dev/serial/by-id/"${mainAddress}" "${mainBoard}"
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
   echo "${promptText}"
   read -p "press enter to continue / ctrl-c to quit"
}

reset_display(){
   echo "Resetting USB Display"
   sudo usbreset stm32f042x6
}

if [ "${1}" == "can" ]; then
    klipper stop
    flashCAN
elif [ "${1}" == "display" ]; then
    klipper stop
    flashDisplay
elif [ "${1}" == "expander" ]; then
    klipper stop
    flashExpander
elif [ "${1}" == "main" ]; then
    klipper stop
    flashMain
elif [ "${1}" == "host" ]; then
    klipper stop
    flashHost
elif [ "${1}" == "most" ]; then
    klipper stop
    flashMain
    flashHost
    flashCAN
elif [ "${1}" == "all" ]; then
    promptText="flash main, CANboard, display + expander and host?"
    prompt
    klipper stop
    flashMain
    flashDisplay
    flashHost
    flashCAN
else
    echo "usage:"
    echo "    flash-klipper.sh can      | flash CANboard via flash_can.py"
    echo "    flash-klipper.sh display  | flash display board via dfu"
    echo "    flash-klipper.sh expander | flash expander board via dfu"
    echo "    flash-klipper.sh main     | flash main board via sdcard"
    echo "    flash-klipper.sh host     | flash raspi host"
    echo "    flash-klipper.sh most     | flash raspi host main CANbus"
    echo "    flash-klipper.sh all      | flash all: main, display + CANbus boards, and raspi host"
    exit 0
fi

reset_display
klipper start
