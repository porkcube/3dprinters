#!/usr/bin/env bash

cd ~/klipper
make clean
make -j4
sudo service klipper stop
make flash
sudo service klipper start
