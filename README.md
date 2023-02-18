These are simple `bash` scripts I use to install Arch Linux and quickly replicate my
daily-use desktop environment without need of manual intervention (almost).

Repo consists of 2 scripts: `arch_install.sh` and `arch_post_install.sh`. First one is
used to install Arch Linux with minimal set of packages required for booting into the
working system. Second one installs Xorg, window manager, my personal dotfiles, various
daily-use applications and activates necessary `systemd` services. 

I use these scripts on my ThinkPad E15 Gen4 AMD, so if you want to re-use them,
you probably should change some stuff to fit your machine.

## Notes & Assumptions

- You're booted in UEFI mode. BIOS mode is not supported by script.
- You're using SSD with TRIM support.
- You don't use dual-boot as script will destroy any data on installation target drive.
- Script installs my personal [dotfiles](https://github.com/FreibergVlad/dotfiles).
- Script uses hard-coded values for partitions size, labels and list of packages to install,
  so maybe you want to edit them before running the script.
- You read the scripts source code carefully and understand what's going on there.

## Installation & Usage

Install `git`:
```sh
pacman -Sy git
```
Clone repository from GitHub:
```sh
git clone https://github.com/FreibergVlad/arch-install-script.git
```
Execute script. You will be prompted to enter your timezone, hostname,
target drive name, LUKS encryption passphrase, root password, your user name
and password. You can also edit and uncomment section with default values and
comment out prompt section in source code.
```sh
bash arch-install-script/arch_install.sh
```
Wait for an installation to complete. You can check installation log in `install_log.txt` file.

Reboot to the new system and login with your newly created user:
```sh
reboot
```
Activate network connection:
```sh
sudo systemctl enable --now NetworkManager
```
Clone repository from GitHub again:
```sh
git clone https://github.com/FreibergVlad/arch-install-script.git
```
Execute script:
```sh
bash arch-install-script/arch_post_install.sh
```
Wait for an installation to complete. Script uses a lot of `sudo` and may ask you for a password few times, so don't go AFK for a long time.
Once it's done, you can check installation log in `$HOME/post_install_log.txt` file. Then reboot to the new system:
```sh
reboot
```

## Post-installation Steps

- Set lock screen background image: `betterlockscreen -u IMAGE`.
- Review output of `sudo tlp-stat -b` to understand if additional actions should be done
  on battery optimization.

## Inspired by

- https://wiki.archlinux.org/title/User:Altercation/Bullet_Proof_Arch_Install
- https://disconnected.systems/blog/archlinux-installer/
