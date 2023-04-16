set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

common_packages=(
    "firefox" # web browser
    "chromium" # one more web browser
    "alacritty" # terminal emulator
    "telegram-desktop" # official Telegram client
    "ttf-hack-nerd" # font which will be used in the system
    "xterm" # default X terminal emulator, used as a fallback
    "xdg-user-dirs" # manager of well-known user directories
    "tlp" # power-management and battery life optimizer
    "tlp-rdw" # part of 'tlp', enable / disable Bluetooth, Wi-Fi and WWAN devices by events
    "unzip" # working with .zip archives
    "neofetch" # system info fetcher
    "pacman-contrib" # various tools for pacman
    "reflector" # script which updates mirrorlist
    "pipewire" # multimedia framework
    "pipewire-alsa" # ALSA configuraion
    "pipewire-pulse" # Pulse clients support
    "wireplumber" # Pipewire session manager
    "libreoffice-still" # office programs
    "spotify-launcher" # Spotify
    "bluez" # Bluetooth protocols implementation
)

dev_packages=(
    "docker"
    "docker-compose"
    "go" # Go compiler and tools
    "python-pip" # Python package manager
    "python-setuptools"
    "python-pynvim" # Python library for Neovim
    "ipython" # improved Python shell
    "jupyterlab" # interactive browser-based Python environment
    "flake8" # Python linter
    "npm" # Node package manager
    "ripgrep" # for telescope
    "fd" # for telescope
    "openvpn" # VPN client
    "openconnect" # VPN client
    "jre-openjdk" # Java Runtime Environment, to execute Java applications
    "openvpn-update-resolv-conf-git" # needed to make AWS VPN work with OpenVPN (AUR)
    "golangci-lint" # Golang linter (AUR)
)

# log message to log file and stdout both
log() {
    echo "$1" | tee -a $log_file
}

# execute bash command and log its output:
#   - stdout goes to log file
#   - stderr goes to log file and stdout both
exec_with_log() {
    local cmd=$@
    eval $cmd 2>> >(tee -a $log_file) 1>>$log_file
}

install_packages() {
    yay -Syu \
        --answerdiff None \
        --answerclean None \
        --removemake \
        --noconfirm \
        "${common_packages[@]}" \
        "${dev_packages[@]}" \
        "${packages[@]}"
}

dotfiles() {
    /usr/bin/git --git-dir=$HOME/.dotfiles.git/ --work-tree=$HOME "$@"
}

install_dotfiles() {
    # persist 'dotfiles' function in .bashrc
    echo -e "\n$(declare -f dotfiles)" >> $HOME/.bashrc
    git clone --bare https://github.com/FreibergVlad/dotfiles.git $HOME/.dotfiles.git
    dotfiles config --local status.showUntrackedFiles no
    dotfiles checkout
    # use SSH for all next work with dotfiles
    dotfiles remote set-url origin git@github.com:FreibergVlad/dotfiles.git
    dotfiles config user.name vfreiberg
    dotfiles config user.email ""
}

install_yay() {
    local repo_path=$HOME/repos/yay
    git clone https://aur.archlinux.org/yay.git $repo_path
    (cd $repo_path && makepkg -si --noconfirm)
}

install_pacman_hooks() {
    local hooks_dir=/etc/pacman.d/hooks
    sudo mkdir -p $hooks_dir
    for hook in $script_dir/pacman-hooks/*.hook; do
        [ -e "$hook" ] || continue
        sudo cp $hook $hooks_dir
    done
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

common_setup() {
    log "Installing dotfiles..."
    exec_with_log install_dotfiles
    
    log "Installing Yay (AUR helper)..."
    exec_with_log install_yay

    log "Installing packages..."
    exec_with_log install_packages

    log "Installing Pacman hooks..."
    exec_with_log install_pacman_hooks
    
    log "Creating XDG directories..."
    exec_with_log xdg-user-dirs-update
    
    log "Applying XDG settings"
    exec_with_log xdg-settings set default-web-browser firefox.desktop
    
    log "Enabling fstrim.timer to execute TRIM weekly..."
    exec_with_log sudo systemctl enable fstrim.timer
    
    log "Enabling power manager and battery life optimizer (TLP)..."
    log "Check output of 'tlp-stat -b' later to understand if additional packages should be installed"
    exec_with_log setup_power_manager
    
    log "Enabling docker service..."
    exec_with_log setup_docker
}
