#!/usr/bin/env bash

## mainsail
sudo apt update --allow-releaseinfo-change && sudo apt upgrade
sudo apt install -y git dfu-util unzip

python3 --version	# 3.7 min

sudo apt install -y virtualenv python-dev libffi-dev build-essential libncurses-dev libusb-dev avrdude gcc-avr binutils-avr avr-libc stm32flash dfu-util libnewlib-arm-none-eabi gcc-arm-none-eabi binutils-arm-none-eabi libusb-1.0-0

cd ~
git clone https://github.com/KevinOConnor/klipper

cd ~
virtualenv -p python2 ./klippy-env
./klippy-env/bin/pip install -r ./klipper/scripts/klippy-requirements.txt

sudo tee /etc/systemd/system/klipper.service << KLIPPER
# Systemd Klipper Service

[Unit]
Description=Starts Klipper and provides klippy Unix Domain Socket API
Documentation=https://www.klipper3d.org/
After=network.target
Before=moonraker.service
Wants=udev.target

[Install]
Alias=klippy
WantedBy=multi-user.target

[Service]
Environment=KLIPPER_CONFIG=/home/$USER/klipper_config/printer.cfg
Environment=KLIPPER_LOG=/home/$USER/klipper_logs/klippy.log
Environment=KLIPPER_SOCKET=/tmp/klippy_uds
Type=simple
User=$USER
RemainAfterExit=yes
ExecStart= /home/$USER/klippy-env/bin/python /home/$USER/klipper/klippy/klippy.py \${KLIPPER_CONFIG} -l \${KLIPPER_LOG} -a \${KLIPPER_SOCKET}
Restart=always
RestartSec=10

KLIPPER

sudo systemctl enable klipper.service

mkdir ~/klipper_config
mkdir ~/klipper_logs
mkdir ~/gcode_files
touch ~/klipper_config/printer.cfg

sudo systemctl start klipper

## moonraker
sudo apt install -y python3-virtualenv python3-dev libopenjp2-7 python3-libgpiod curl libcurl4-openssl-dev libssl-dev liblmdb-dev libsodium-dev zlib1g-dev libjpeg-dev

cd ~
git clone https://github.com/Arksine/moonraker.git

cd ~
virtualenv -p python3 ./moonraker-env
./moonraker-env/bin/pip install -r ./moonraker/scripts/moonraker-requirements.txt

tee ~/klipper_config/moonraker.conf << MOONRAKER

[server]
host: 0.0.0.0
port: 7125
enable_debug_logging: False

[file_manager]
config_path: ~/klipper_config
log_path: ~/klipper_logs

[authorization]
cors_domains:
    https://my.mainsail.xyz
    http://my.mainsail.xyz
    http://*.local
    http://*.lan
trusted_clients:
    10.0.0.0/8
    127.0.0.0/8
    169.254.0.0/16
    172.16.0.0/12
    192.168.0.0/16
    FE80::/10
    ::1/128

# enables partial support of Octoprint API
[octoprint_compat]

# enables moonraker to track and store print history.
[history]

# this enables moonraker's update manager
[update_manager]
enable_auto_refresh: True
#refresh interval in hours
refresh_interval: 24

[update_manager mainsail]
type: web
repo: mainsail-crew/mainsail
path: ~/mainsail

MOONRAKER

sudo tee /etc/systemd/system/moonraker.service << MOONRAKER
# Systemd moonraker Service

[Unit]
Description=Moonraker provides Web API for klipper
Documentation=https://moonraker.readthedocs.io/en/latest/
After=network.target klipper.service

[Install]
WantedBy=multi-user.target

[Service]
Environment=MOONRAKER_CONFIG=/home/$USER/klipper_config/moonraker.conf
Environment=MOONRAKER_LOG=/home/$USER/klipper_logs/moonraker.log
Type=simple
User=$USER
RemainAfterExit=yes
ExecStart=/home/$USER/moonraker-env/bin/python /home/$USER/moonraker/moonraker/moonraker.py -c \${MOONRAKER_CONFIG} -l \${MOONRAKER_LOG}
Restart=always
RestartSec=10

MOONRAKER

~/moonraker/scripts/set-policykit-rules.sh
sudo systemctl enable moonraker.service
sudo service moonraker start

curl -s localhost:7125/printer/info | jq

sudo apt install -y nginx

sudo tee /etc/nginx/sites-available/mainsail << NGINX
# /etc/nginx/sites-available/mainsail
server {
    listen 80 default_server;

    access_log /var/log/nginx/mainsail-access.log;
    error_log /var/log/nginx/mainsail-error.log;

    # disable this section on smaller hardware like a pi zero
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_proxied expired no-cache no-store private auth;
    gzip_comp_level 4;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/x-javascript application/json application/xml;

    # web_path from mainsail static files
    root /home/$USER/mainsail;

    index index.html;
    server_name _;

    # disable max upload size checks
    client_max_body_size 0;

    # disable proxy request buffering
    proxy_request_buffering off;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
    location = /index.html {
        add_header Cache-Control "no-store, no-cache, must-revalidate";
    }
    location /websocket {
        proxy_pass http://apiserver/websocket;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;
    }
    location ~ ^/(printer|api|access|machine|server)/ {
        proxy_pass http://apiserver\$request_uri;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Scheme \$scheme;
    }
    location /webcam/ {
        proxy_pass http://mjpgstreamer1/;
    }
    location /webcam2/ {
        proxy_pass http://mjpgstreamer2/;
    }
    location /webcam3/ {
        proxy_pass http://mjpgstreamer3/;
    }
    location /webcam4/ {
        proxy_pass http://mjpgstreamer4/;
    }
}

NGINX

sudo tee /etc/nginx/conf.d/upstreams.conf << UPSTREAMS
# /etc/nginx/conf.d/upstreams.conf
upstream apiserver {
    ip_hash;
    server 127.0.0.1:7125;
}
upstream mjpgstreamer1 {
    ip_hash;
    server 127.0.0.1:8080;
}
upstream mjpgstreamer2 {
    ip_hash;
    server 127.0.0.1:8081;
}
upstream mjpgstreamer3 {
    ip_hash;
    server 127.0.0.1:8082;
}
upstream mjpgstreamer4 {
    ip_hash;
    server 127.0.0.1:8083;
}

UPSTREAMS


sudo tee /etc/nginx/conf.d/common_vars.conf << CORS
# /etc/nginx/conf.d/common_vars.conf

map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}
CORS

mkdir ~/mainsail
sudo rm /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/mainsail /etc/nginx/sites-enabled/
sudo systemctl restart nginx

curl -s localhost/printer/info | jq

cd ~/mainsail
wget -q -O mainsail.zip https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip && unzip mainsail.zip && rm mainsail.zip


sudo apt install -y avahi-daemon

tee ~/klipper_config/mainsail.cfg << MAINSAIL

[virtual_sdcard]
path: ~/gcode_files

[display_status]

[pause_resume]

[gcode_macro PAUSE]
description: Pause the actual running print
rename_existing: PAUSE_BASE
gcode:
  PAUSE_BASE
  _TOOLHEAD_PARK_PAUSE_CANCEL

[gcode_macro RESUME]
description: Resume the actual running print
rename_existing: RESUME_BASE
gcode:
  ##### read extrude from  _TOOLHEAD_PARK_PAUSE_CANCEL  macro #####
  {% set extrude = printer['gcode_macro _TOOLHEAD_PARK_PAUSE_CANCEL'].extrude %}  #### get VELOCITY parameter if specified ####
  {% if 'VELOCITY' in params|upper %}
    {% set get_params = ('VELOCITY=' + params.VELOCITY)  %}
  {%else %}
    {% set get_params = "" %}
  {% endif %}
  ##### end of definitions #####
  {% if printer.extruder.can_extrude|lower == 'true' %}
    M83
    G1 E{extrude} F2100
    {% if printer.gcode_move.absolute_extrude |lower == 'true' %} M82 {% endif %}
  {% else %}
    {action_respond_info("Extruder not hot enough")}
  {% endif %}
  RESUME_BASE {get_params}

[gcode_macro CANCEL_PRINT]
description: Cancel the actual running print
rename_existing: CANCEL_PRINT_BASE
variable_park: True
gcode:
  ## Move head and retract only if not already in the pause state and park set to true
  {% if printer.pause_resume.is_paused|lower == 'false' and park|lower == 'true'%}
    _TOOLHEAD_PARK_PAUSE_CANCEL
  {% endif %}
  TURN_OFF_HEATERS
  CANCEL_PRINT_BASE

[gcode_macro _TOOLHEAD_PARK_PAUSE_CANCEL]
description: Helper: park toolhead used in PAUSE and CANCEL_PRINT
variable_extrude: 1.0
gcode:
  ##### set park positon for x and y #####
  # default is your max posion from your printer.cfg
  {% set x_park = printer.toolhead.axis_maximum.x|float - 5.0 %}
  {% set y_park = printer.toolhead.axis_maximum.y|float - 5.0 %}
  {% set z_park_delta = 2.0 %}
  ##### calculate save lift position #####
  {% set max_z = printer.toolhead.axis_maximum.z|float %}
  {% set act_z = printer.toolhead.position.z|float %}
  {% if act_z < (max_z - z_park_delta) %}
    {% set z_safe = z_park_delta %}
  {% else %}
    {% set z_safe = max_z - act_z %}
  {% endif %}
  ##### end of definitions #####
  {% if printer.extruder.can_extrude|lower == 'true' %}
    M83
    G1 E-{extrude} F2100
    {% if printer.gcode_move.absolute_extrude |lower == 'true' %} M82 {% endif %}
  {% else %}
    {action_respond_info("Extruder not hot enough")}
  {% endif %}
  {% if "xyz" in printer.toolhead.homed_axes %}
    G91
    G1 Z{z_safe} F900
    G90
    G1 X{x_park} Y{y_park} F6000
    {% if printer.gcode_move.absolute_coordinates|lower == 'false' %} G91 {% endif %}
  {% else %}
    {action_respond_info("Printer not homed")}
  {% endif %}

#[gcode_macro BED_MESH_CALIBRATE]
#rename_existing: BASE_BED_MESH_CALIBRATE
#gcode:
    #before the original gcode
#    BED_MESH_CLEAR
#    QUAD_GANTRY_LEVEL
#    G1 X125 Y125 Z5 F6000
    #the original gcode
#    BASE_BED_MESH_CALIBRATE
    #after the original gcode

MAINSAIL

sudo tee /etc/init.d/klipper_mcu << KLIPPER
#!/bin/sh
# System startup script to start the MCU Linux firmware

### BEGIN INIT INFO
# Provides:          klipper_mcu
# Required-Start:    \$local_fs
# Required-Stop:
# Default-Start:     3 4 5
# Default-Stop:      0 1 2 6
# Short-Description: Klipper_MCU daemon
# Description:       Starts the MCU for Klipper.
### END INIT INFO

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
DESC="klipper_mcu startup"
NAME="klipper_mcu"
KLIPPER_HOST_MCU=/usr/local/bin/klipper_mcu
KLIPPER_HOST_ARGS="-r"
PIDFILE=/var/run/klipper_mcu.pid

. /lib/lsb/init-functions

mcu_host_stop()
{
    # Shutdown existing Klipper instance (if applicable). The goal is to        
    # put the GPIO pins in a safe state.
    if [ -c /tmp/klipper_host_mcu ]; then
        log_daemon_msg "Attempting to shutdown host mcu..."
        set -e
        ( echo "FORCE_SHUTDOWN" > /tmp/klipper_host_mcu ) 2> /dev/null || ( log_action_msg "Firmware busy! Please shutdown Klipper and then retry." && exit 1 ) 
        sleep 1
        ( echo "FORCE_SHUTDOWN" > /tmp/klipper_host_mcu ) 2> /dev/null || ( log_action_msg "Firmware busy! Please shutdown Klipper and then retry." && exit 1 ) 
        sleep 1
        set +e
    fi

    log_daemon_msg "Stopping klipper host mcu" \$NAME
    killproc -p \$PIDFILE \$KLIPPER_HOST_MCU
}

mcu_host_start()
{
    [ -x \$KLIPPER_HOST_MCU ] || return

    if [ -c /tmp/klipper_host_mcu ]; then
        mcu_host_stop
    fi

    log_daemon_msg "Starting klipper MCU" \$NAME
    start-stop-daemon --start --quiet --exec \$KLIPPER_HOST_MCU \
                      --background --pidfile \$PIDFILE --make-pidfile \
                      -- \$KLIPPER_HOST_ARGS
    log_end_msg \$?
}

case "\$1" in
start)
    mcu_host_start
    ;;
stop)
    mcu_host_stop
    ;;
restart)
    \$0 stop
    \$0 start
    ;;
reload|force-reload)
    log_daemon_msg "Reloading configuration not supported" \$NAME
    log_end_msg 1
    ;;
status)
    status_of_proc -p \$PIDFILE \$KLIPPER_HOST_MCU \$NAME && exit 0 || exit \$?     
    ;;
*)  log_action_msg "Usage: /etc/init.d/klipper_mcu {start|stop|status|restart|reload|force-reload}"
    exit 2
    ;;
esac
exit 0

KLIPPER

cd ~/klipper
make menuconfig
cp .config .config-host
make -j$(nproc) flash

sudo chmod 755 /etc/init.d/klipper_mcu
sudo systemctl enable klipper_mcu
sudo systemctl start klipper_mcu

# work-around for armbian/nanopi-neo issue
sudo tee -a /etc/network/interfaces << ETH0

auto eth0
iface eth0 inet dhcp
    hwaddress ether DE:AD:BE:EF:04:20

ETH0


sed -i'' 's/nanopineo/neopi/g' /etc/hosts
echo "neopi" | sudo tee /etc/hostname
sudo hostname -s neopi

sudo tee ~/klipper_config/printer.cfg << PRINTER
[include mainsail.cfg]

[mcu]
serial: /tmp/klipper_host_mcu

[temperature_sensor NanoPi_Neo]
sensor_type: temperature_host
gcode_id: NanoPi_Neo

[printer]
kinematics: none
max_velocity: 1
max_accel: 1
square_corner_velocity: 1

PRINTER

echo 'alias htop="htop --sort-key=PERCENT_CPU"' >> ~/.bashrc
