#!/usr/bin/env bash

canBoard="Fly SB2040v2"
#canBoard="Fly SB2040"
hostModel="$(grep -m1 Model /proc/cpuinfo | cut -d: -f 2- | sed 's/^ //')"
mainBoard="btt-skr-mini-e3-v2"
serialPath="/dev/ttyACM0"
#serialPath="/dev/serial/by-id/usb-Klipper_stm32f103xe_31FFD6053031543914611343-if00"

flashCAN() {
  canUuid="284e84c01aa8"
#  canUuid="c8483db605ec"
  cd ~/klipper
  make distclean
  cp .config-flysb2040v2 .config
  make clean
  make -j$(nproc)
#  python3 ~/CanBoot/scripts/flash_can.py -r -u "${canUuid}"
  python3 ~/Katapult/scripts/flashtool.py -i can0 -f ~/klipper/out/klipper.bin -u "${canUuid}"
}

flashMain() {
  cd ~/klipper
  make distclean
  cp ".config-${mainBoard}" .config
  make clean
  make -j$(nproc)
#  make flash FLASH_DEVICE="${serialPath}"
#  make serialflash FLASH_DEVICE="${serialPath}"
#  scripts/flash-sdcard.sh /dev/ttyACM0 "${mainBoard}"
  scripts/flash-sdcard.sh "${serialPath}" "${mainBoard}"
}

flashHost() {
  cd ~/klipper
  make distclean
  cp .config-rpi .config
  make clean
  make -j$(nproc)
  make flash
}

klipper() {
  sudo service klipper "${1}"
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
elif [ "${1}" == "all" ]; then
    klipper stop
#    flashCAN
    flashHost
    flashMain
else
    echo "usage:"
    echo "    flash-klipper.sh can      | flash ${canBoard}"
    echo "    flash-klipper.sh host     | flash ${hostModel}"
    echo "    flash-klipper.sh main     | flash ${mainBoard}"
    echo "    flash-klipper.sh all      | flash all: ${canBoard} + ${hostModel} + ${mainBoard}"
    exit 0
fi

klipper start
