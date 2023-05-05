#!/usr/bin/env bash

## (Re)compiles Klipper for RP2040 boards and copies to device when mounted
## create ~/klipper/.config-rp2040 by running:
## cd ~/klipper
## make menuconfig
## [ ] Enable extra low-level configuration options
##    Micro-controller Architecture (Raspberry Pi RP2040)  --->
##    Communication interface (USB)  --->
## cp .config .config-rp2040

flashPico(){
    "compiling for rp2040..."
    sudo service klipper stop
    cd ~/klipper
    cp .config-rp2040 .config
    make clean
    make -j$(nproc)
    echo "connect USB while hoolding BOOT button down"
    read -p "press enter to continue / ctrl-c to quit"
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

flashPico
