#!/usr/bin/env bash
#set -ex

source $(dirname "$0")/printer_common.sh

if [[ ! -z "${1}" ]]; then
    hosts=("${1}")
fi

for host in "${hosts[@]}"; do
    for service in "${services[@]}"; do
        if [[ -f "/etc/systemd/system/${service}.service" ]]; then
            echo "=========] stopping ${service} on ${host}"
            ssh "${host}" -- "sudo service ${service} stop"
        fi
    done

    echo "=========] backing up ${host}"

    mkdir -p "${srcPath}/${host}"
    scp -r "${host}":flash-klipper.sh "${srcPath}/${host}"

    mkdir -p "${srcPath}/${host}/Katapult"
    scp -r "${host}":Katapult/.config-* "${srcPath}/${host}/Katapult"

    mkdir -p "${srcPath}/${host}/klipper"
    scp -r "${host}":klipper/.config-* "${srcPath}/${host}/klipper"

    # backup moonraker db to ensure cross arch compatibility
    ssh ${host} -- 'sudo apt install -y lmdb-utils && echo "=========] dumping moonraker db" && mdb_dump -f ~/printer_data/backup/moonraker.txt -a ~/printer_data/database'

    mkdir -p "${srcPath}/${host}/printer_data"
    rsync -avhqzLe ssh \
          --exclude '.git' \
          --exclude '*.serial' \
          --exclude '*.sock' \
          --exclude '.thumbs' \
          --exclude 'logs' \
          --delete \
          "${host}":printer_data/ \
          "${srcPath}/${host}/printer_data"

    for service in "${services[@]}"; do
        if [[ -f "/etc/systemd/system/${service}.service" ]]; then
            echo "=========] starting ${service} on ${host}"
            ssh "${host}" -- "sudo service ${service} start"
        fi
    done

    echo "=========] backup completed for ${host}"
done
