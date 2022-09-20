#!/usr/bin/env bash

log_file=$HOME/post_install_log.txt
script_dir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)

source $script_dir/common.sh

packages=(
    # CORE PACKAGES
    "xorg-server" # Xorg X server
    "xorg-xprop" # property displayer for X, useful for troubleshooting
    "xorg-xrandr" # tool to set screen size
    "xorg-xev" # print X events, useful for troubleshooting
    "xorg-drivers" # group of video drivers for Xorg # TODO specify only necessary drivers
    "xorg-xinit" # Xorg initialization app
    "xterm" # default X terminal emulator, used as a fallback
    "xdg-user-dirs" # manager of well-known user directories
    "xclip" # tool to manage X clipboard
    "qtile" # Qtile window manager
    "xss-lock" # use external locker as X screen saver
    "firefox" # web browser
    "alacritty" # terminal emulator
    "telegram-desktop" # official Telegram client
    "ttf-hack-nerd" # font which will be used in the system
    "pipewire" # multimedia framework
    "pipewire-alsa" # ALSA configuraion
    "pipewire-pulse" # Pulse clients support
    "wireplumber" # Pipewire session manager
    "picom" # window compositor
    "rofi" # application launcher
    "feh" # tool to set wallpaper
    "maim" # tool to take screenshots
    "brightnessctl" # add udev rules to provide access to backlight control
    "tlp" # power-management and battery life optimizer
    "tlp-rdw" # part of 'tlp', enable / disable Bluetooth, Wi-Fi and WWAN devices by events
    "dunst" # notification daemon
    "unzip" # working with .zip archives

    # DEVELOPMENT PACKAGES
    "docker"
    "docker-compose"
    "go"
    "pyright"
    "python-pip"
    "python-setuptools"
    "python-pynvim"
    "ipython"
    "ripgrep" # for telescope
    "fd" # for telescope
    "openvpn"
    "openconnect"

    # AUR PACKAGES
    "teams-for-linux" # unofficial Teams client (AUR)
    "betterlockscreen" # session lock, i3lock wrapper (AUR)
    "spotify" # official Spotify client (AUR)
)

dotfiles() {
    /usr/bin/git --git-dir=$HOME/.dotfiles.git/ --work-tree=$HOME "$@"
}

install_dotfiles() {
    # persist 'dotfiles' function in .bashrc
    echo -e "\n$(declare -f dotfiles)" >> $HOME/.bashrc
    git clone --bare https://github.com/FreibergVlad/dotfiles.git $HOME/.dotfiles.git
    dotfiles config --local status.showUntrackedFiles no
    dotfiles checkout
}

install_yay() {
    cd $HOME
    git clone https://aur.archlinux.org/yay-git.git
    cd yay-git
    makepkg -si --noconfirm
    cd ..
    rm -rf yay-git
}

install_packages() {
    yay -Syu \
        --answerdiff None \
        --answerclean None \
        --removemake \
        --noconfirm \
        "${packages[@]}"
}

setup_screensaver() {
    sudo systemctl enable betterlockscreen@$USER
}

setup_power_manager() {
    sudo systemctl enable tlp
    sudo systemctl enable NetworkManager-dispatcher.service
    sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket
}

setup_docker() {
    sudo usermod -aG docker $USER
    sudo systemctl enable docker
}

setup_xorg() {
    echo 'exec qtile start' >> ~/.xinitrc
    echo '[ -z "${DISPLAY}" ] && [ "${XDG_VTNR}" -eq 1 ] && exec startx' >> ~/.bash_profile
}

main() {
    if [[ $(id -u) == 0 ]]; then
      log "Don't run this script as 'root'!"
      exit 1
    fi

    log "Installing dotfiles..."
    exec_with_log install_dotfiles

    log "Installing Yay (AUR helper)..."
    exec_with_log install_yay

    log "Installing packages..."
    exec_with_log install_packages

    log "Enabling screensaver (betterlockscreen)..."
    log "Probably you want to set lock screen background after: 'betterlockscreen -u IMAGE'"
    exec_with_log setup_screensaver

    log "Creating XDG directories..."
    exec_with_log xdg-user-dirs-update

    log "Enabling power manager and battery life optimizer (TLP)..."
    log "Check output of 'tlp-stat -b' later to understand if additional packages should be installed"
    exec_with_log setup_power_manager

    log "Enabling fstrim.timer to execute TRIM weekly..."
    exec_with_log sudo systemctl enable fstrim.timer

    log "Enabling docker service..."
    exec_with_log setup_docker

    log "Modifying ~/.xinitrc and ~/.bash_profile to start Xorg with Qtile on login"
    exec_with_log setup_xorg

    log "Done. Restart the machine by typing 'reboot' and login to the new system"
    log "You can check the full installation log in $log_file"
}

main