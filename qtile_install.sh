#!/usr/bin/env bash

log_file=$HOME/post_install_log.txt
script_dir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)

source $script_dir/common.sh

packages=(
    "xorg-server" # Xorg X server
    "xorg-xprop" # property displayer for X, useful for troubleshooting
    "xorg-xrandr" # tool to set screen size
    "xorg-xev" # print X events, useful for troubleshooting
    "xorg-drivers" # group of video drivers for Xorg
    "xorg-xinit" # Xorg initialization app
    "xclip" # tool to manage X clipboard
    "qtile" # Qtile window manager
    "xss-lock" # use external locker as X screen saver
    "picom" # window compositor
    "rofi" # application launcher
    "feh" # tool to set wallpaper
    "maim" # tool to take screenshots
    "brightnessctl" # add udev rules to provide access to backlight control
    "dunst" # notification daemon
    "blueman" # bluetooth manager
    "lxappearance-gtk3" # GTK theme picker
    "python-dbus-next" # Python library for D-Bus, required by some of Qtile widgets
    "udiskie" # auto-mount USB disks
    "betterlockscreen" # session lock, i3lock wrapper (AUR)
)

setup_screensaver() {
    sudo systemctl enable betterlockscreen@$USER
}

setup_xorg() {
    echo 'exec qtile start' >> ~/.xinitrc
    echo '[ -z "${DISPLAY}" ] && [ "${XDG_VTNR}" -eq 1 ] && startx' >> ~/.bash_profile
}

main() {
    if [[ $(id -u) == 0 ]]; then
      log "Don't run this script as 'root'!"
      exit 1
    fi

    common_setup

    log "Enabling screensaver (betterlockscreen)..."
    log "Probably you want to set lock screen background after: 'betterlockscreen -u IMAGE'"
    exec_with_log setup_screensaver

    log "Modifying ~/.xinitrc and ~/.bash_profile to start Xorg with Qtile on login"
    exec_with_log setup_xorg

    log "Enabling bluetooth.service..."
    exec_with_log sudo systemctl enable bluetooth

    log "Done. Restart the machine by typing 'reboot' and login to the new system"
    log "You can check the full installation log in $log_file"
}

main
