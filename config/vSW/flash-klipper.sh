#!/usr/bin/env bash

canBoard="Fly SB2040"
hostModel="$(grep -m1 Model /proc/cpuinfo | cut -d: -f 2- | sed 's/^ //')"
mainBoard="btt-skr-mini-e3-v2"

flashCAN() {
  canUuid="c8483db605ec"
  cd ~/klipper
  make distclean
  cp .config-flysb2040 .config
  make clean
  make -j$(nproc)
#  python3 ~/CanBoot/scripts/flash_can.py -r -u "${canUuid}"
  python3 ~/CanBoot/scripts/flash_can.py -i can0 -f ~/klipper/out/klipper.bin -u "${canUuid}"
}

flashMain() {
  cd ~/klipper
  make distclean
  cp ".config-${mainBoard}" .config
  make clean
  make -j$(nproc)
#  make flash FLASH_DEVICE=/dev/ttyACM0
  scripts/flash-sdcard.sh /dev/ttyACM0 "${mainBoard}"
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
    flashCAN
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
