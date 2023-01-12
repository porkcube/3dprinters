#!/usr/bin/env bash

CANuuid="9f944e51ea3a"

flashCAN() {
    sudo service klipper stop
    cd ~/klipper/
    cp .config-flysb2040 .config
    make clean
    make -j$(nproc)
    python3 ~/klipper/lib/canboot/flash_can.py -v -u "${CANuuid}"
    sudo service klipper start
}

flashCAN
