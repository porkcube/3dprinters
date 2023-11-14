#!/usr/bin/env bash
# set -ex

source $(dirname "$0")/printer_common.sh

if [[ ! -z "${1}" ]]; then
    hosts=("${1}")
fi

for host in "${hosts[@]}"; do
    for service in "${services[@]}"; do
        echo "=========] stopping ${service} on ${host}"
        ssh "${host}" -- "sudo service ${service} stop"
    done

    echo "=========] restoring ${host}"

    if [[ -f "${srcPath}/${host}/flash-klipper.sh" ]]; then 
        scp -r "${srcPath}/${host}/flash-klipper.sh" "${host}":
    fi

    if [[ -d "${srcPath}/${host}/boot" ]]; then 
        scp "${srcPath}/${host}/boot/cmdline.txt" "${host}":
        ssh "${host}" -- "sudo cp /boot/cmdline.txt /boot/cmdline.txt- && sudo mv cmdline.txt /boot/cmdline.txt"
        scp "${srcPath}/${host}/boot/config.txt" "${host}":
        ssh "${host}" -- "sudo cp /boot/config.txt /boot/config.txt- && sudo mv config.txt /boot/config.txt"
    fi

    if [[ -d "${srcPath}/${host}/Katapult" ]]; then
        scp -r /mnt/d/Box\ Sync/projects/3d\ printers/backups/"${host}"/Katapult/.config-* "${host}":Katapult/
    fi

    if [[ -d "${srcPath}/${host}/klipper" ]]; then
        scp -r /mnt/d/Box\ Sync/projects/3d\ printers/backups/"${host}"/klipper/.config-* "${host}":klipper/
    fi

    if [[ -d "${srcPath}/${host}/printer_data" ]]; then
        ssh "${host}" -- "if [ -d printer_data ]; then mv printer_data printer_data-$(date +%Y-%m-%d); fi && mkdir printer_data"
        rsync -avhqzLe ssh \
              --exclude '.git' \
              --exclude '*.serial' \
              --exclude '*.sock' \
              --exclude '.thumbs' \
              --exclude 'logs' \
              --delete \
              "${srcPath}/${host}/printer_data" \
              "${host}":
    fi

    ## reload moonraker db to ensure cross arch compatibility
    ssh ${host} -- "sudo apt install -y lmdb-utils && rm -rf ~/printer_data/database/*.mdb; mdb_load -f ~/printer_data/backup/moonraker.txt -s -T ~/printer_data/database"

    for service in "${services[@]}"; do
        echo "=========] starting ${service} on ${host}"
        ssh "${host}" -- "sudo service ${service} start"
    done

    echo "=========] restore completed for ${host}"
done
