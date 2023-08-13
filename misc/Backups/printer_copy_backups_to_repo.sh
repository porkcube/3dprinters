#!/usr/bin/env bash
## rsync printer backups to git repo
# set -ex

source $(dirname "$0")/printer_common.sh

i=0
## $((${#hosts[@]} - 1)) is "arraylength - 1" as the array starts at 0
while [ "${i}" -le "$((${#hosts[@]} - 1))" ]; do
    printer=${hosts[$i]}
    repo=${repoName[$i]}
    mkdir -p "${destPath}/${repo}"

    echo "=========] syncing ${printer} -> ${repo}"
    rsync -avihzL \
          --delete \
          "${srcPath}/${printer}/flash-klipper.sh" \
          "${destPath}/${repo}/flash-klipper.sh"
    if [[ ! -d "${srcPath}/${printer}/Katapult" ]]; then
        if [[ -d "${srcPath}/${printer}/CanBoot" ]]; then
            mv "${srcPath}/${printer}/CanBoot" "${srcPath}/${printer}/Katapult"        
        else
            mkdir -p "${srcPath}/${printer}/Katapult"
        fi
    fi
    rsync -avihzL \
          --delete \
          "${srcPath}/${printer}/Katapult/" \
          "${destPath}/${repo}/Katapult"
    rsync -avihzL \
          --delete \
          "${srcPath}/${printer}/klipper/" \
          "${destPath}/${repo}/klipper"
    rsync -avihzL \
          --delete \
          --exclude '*.bkp' \
          --exclude '.git' \
          --exclude 'ratosmess' \
          --exclude 'old-printer-cfgs' \
          --exclude 'firmware' \
          --exclude 'printer-*.cfg' \
          --exclude '*.secrets' \
          "${srcPath}/${printer}/printer_data/config/" \
          "${destPath}/${repo}/printer_configs"
    i=$((${i}+1))
done
