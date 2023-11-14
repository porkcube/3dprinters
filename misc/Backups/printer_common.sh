#!/usr/bin/env bash
#set -ex

hosts=("bluehulk" "dog" "graff" "grapeape" "neopi" "orangepi-zero2" "raspi0w2" "splinter" "vzbot")
repoName=("v2.4r2" "v0.1" "vSW" "v0.2" "nanopi-neo" "orangepi-zero2" "raspi0w2" "v-minion" "vz330")

services=("klipper" "moonraker" "KlipperScreen")

srcPath="/mnt/d/Box Sync/projects/3d printers/backups"
destPath="$HOME/src/3dprinters/config"
