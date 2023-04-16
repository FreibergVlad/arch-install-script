#!/usr/bin/env bash

log_file=$HOME/post_install_log.txt
script_dir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)

source $script_dir/common.sh

packages=(
    "gdm"
    "gnome-shell"
    "gnome-tweaks"
    "gnome-control-center" # Gnome settings manager
    "evince" # Gnome document viewer
    "file-roller" # Gnome archive manager
    "nautilus" # Gnome file manager
)

main() {
    if [[ $(id -u) == 0 ]]; then
      log "Don't run this script as 'root'!"
      exit 1
    fi

    common_setup

    exec_with_log sudo systemctl enable gdm
}

main
