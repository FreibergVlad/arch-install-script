#!/usr/bin/env bash

log_file=install_log.txt
script_dir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)

source $script_dir/common.sh

# ensure system is booted in UEFI mode
log "Checking if system is booted in UEFI mode..."
if [ ! -d "/sys/firmware/efi/efivars" ]; then
  log "Error. System is probably booted in BIOS mode while only UEFI is supported"
  exit 1
fi

# detect CPU vendor, it will be used for microcode installation
cpu_vendor=$(lscpu | grep -e '^Vendor ID' | awk '{print $3}')
if [ "$cpu_vendor" == "AuthenticAMD" ]; then
    cpu_vendor="amd"
elif [ "$cpu_vendor" == "GenuineIntel" ]; then
    cpu_vendor="intel"
else
  log "Error. Unsupported vendor $cpu_vendor"
  exit 1
fi

read -p "Enter the timezone: " TIMEZONE
read -p "Enter the hostname: " HOSTNAME
read -p "Enter disk name (ALL DATA WILL BE DESTROYED): " DRIVE
read -p "Enter encryption passphrase: " LUKS_PASSPHRASE
read -p "Enter root password: " ROOT_PASSWD
read -p "Enter username: " USERNAME
read -p "Enter user's password: " USER_PASSWD

# TIMEZONE=Asia/Tbilisi
# HOSTNAME=arch-vbox
# DRIVE=/dev/sda
# LUKS_PASSPHRASE=123
# ROOT_PASSWD=123
# USERNAME=vbox_user
# USER_PASSWD=123

efi_type_code=ef00
efi_part_label=EFI
efi_part_size=300MiB

luks_type_code=8309
luks_part_label=cryptroot
decrypted_luks_part_label=cryptlvm

lvm_vol_group_name=vol-group
lvm_swap_vol_name=swap
lvm_swap_vol_size=8G
lvm_root_vol_name=root

luks_device=/dev/disk/by-partlabel/$luks_part_label
efi_device=/dev/disk/by-partlabel/$efi_part_label

base_packages=(
    "base"
    "base-devel"
    "linux"
    "linux-lts"
    "linux-firmware"
    "${cpu_vendor}-ucode"
    "lvm2"
    "vim"
    "neovim"
    "tmux"
    "openssh"
    "networkmanager"
    "git"
    "man-db"
    "man-pages"
    "polkit"
    "bash-completion"
    "python"
)
hooks=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems resume fsck)
kernel_params=(
    "root=/dev/$lvm_vol_group_name/$lvm_root_vol_name"
    # set 'allow-discards' to enable TRIM support
    "cryptdevice=$luks_device:$decrypted_luks_part_label:allow-discards"
    # required for hibernation
    "resume=/dev/$lvm_vol_group_name/$lvm_swap_vol_name"
    "rw"
    "quiet"
    "loglevel=3"
    "udev.log_level=3"
    # disable this horrible PC speaker sound at all
    "modprobe.blacklist=pcspkr"
)
user_groups=wheel,video,input

# enable network time synchronization
log "Enabling network time synchronization..."
exec_with_log timedatectl set-ntp true

# zero out all MBR and GPT data structures
log "Destroying old MBR and GPT data structures..."
exec_with_log sgdisk --zap-all $DRIVE

# create new GPT partition table with 2 partitions:
#   - EFI partition (300MiB)
#   - Partition which will be encrypted later and where 
#     LVM volumes will be created (all available space left)
log "Creating new partitions..."
exec_with_log sgdisk --clear \
    --new=1:0:$efi_part_size --typecode=1:$efi_type_code --change-name=1:$efi_part_label \
    --new=2:0:0 --typecode=2:$luks_type_code --change-name=2:$luks_part_label \
    $DRIVE

log "Wait for $luks_device and $efi_device files to appear..."
until [ -e $luks_device ] && [ -e $efi_device ]
do
  sleep 1
done

# create encrypted LUKS container
log "Encrypting $luks_device partition..."
echo $LUKS_PASSPHRASE | exec_with_log cryptsetup -q luksFormat $luks_device
# open encrypted container
echo $LUKS_PASSPHRASE | exec_with_log cryptsetup open $luks_device $decrypted_luks_part_label

log "Creating logical volumes..."
exec_with_log pvcreate /dev/mapper/$decrypted_luks_part_label
exec_with_log vgcreate $lvm_vol_group_name /dev/mapper/$decrypted_luks_part_label
exec_with_log lvcreate -L $lvm_swap_vol_size $lvm_vol_group_name -n $lvm_swap_vol_name
exec_with_log lvcreate -l 100%FREE $lvm_vol_group_name -n $lvm_root_vol_name

log "Creating file systems..."
exec_with_log mkfs.ext4 /dev/$lvm_vol_group_name/$lvm_root_vol_name
exec_with_log mkfs.fat -F32 $efi_device
exec_with_log mkswap /dev/$lvm_vol_group_name/$lvm_swap_vol_name

log "Mounting file systems..."
exec_with_log mount /dev/$lvm_vol_group_name/$lvm_root_vol_name /mnt
exec_with_log mount --mkdir $efi_device /mnt/boot
exec_with_log swapon /dev/$lvm_vol_group_name/$lvm_swap_vol_name

log "Installing base packages..."
exec_with_log pacstrap /mnt "${base_packages[@]}"

log "Generating /mnt/etc/fstab file..."
genfstab -t PARTLABEL /mnt >> /mnt/etc/fstab

log "Setting timezone to $TIMEZONE"
exec_with_log arch-chroot /mnt ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
exec_with_log arch-chroot /mnt hwclock --systohc

log "Generating locales..."
sed -i "/en_US.UTF-8 UTF-8/s/^#//g" /mnt/etc/locale.gen
exec_with_log arch-chroot /mnt locale-gen
echo LANG=en_US.UTF-8 > /mnt/etc/locale.conf

log "Setting the hostname and generating /etc/hosts file..."
echo $HOSTNAME > /mnt/etc/hostname
cat << EOF > /mnt/etc/hosts
127.0.0.1 localhost
::1       localhost
127.0.1.1 $HOSTNAME
EOF

log "Generating initial ramdisk..."
sed -ire "s/^\(HOOKS=\).*$/\1(${hooks[*]})/g" /mnt/etc/mkinitcpio.conf
exec_with_log arch-chroot /mnt mkinitcpio -P

log "Setting the root password..."
echo "root:$ROOT_PASSWD" | exec_with_log chpasswd --root /mnt

log "Creating user $USERNAME"
exec_with_log arch-chroot /mnt useradd -mU -G $user_groups $USERNAME
echo "$USERNAME:$USER_PASSWD" | exec_with_log chpasswd --root /mnt

log "Modifying /etc/sudoers ..."
sed -i "/%wheel ALL=(ALL:ALL) ALL/s/^#//g" /mnt/etc/sudoers

# few Pacman improvements:
#   - enable color output
#   - enable verbose output (display old / new package versions)
#   - enable parallel downloads
log "Modifying /etc/pacman.conf ..."
sed -i "/Color/s/^#//g" /mnt/etc/pacman.conf
sed -i "/VerbosePkgLists/s/^#//g" /mnt/etc/pacman.conf
sed -i "/ParallelDownloads/s/^#//g" /mnt/etc/pacman.conf

log "Generating 'man' database..."
exec_with_log arch-chroot /mnt mandb --create

log "Installing bootloader..."
exec_with_log arch-chroot /mnt bootctl install

cat << EOF > /mnt/boot/loader/loader.conf
default arch.conf
console-mode max
editor no
EOF

cat << EOF > /mnt/boot/loader/entries/arch.conf
title    Arch Linux
linux    /vmlinuz-linux
initrd   /${cpu_vendor}-ucode.img
initrd   /initramfs-linux.img
options  ${kernel_params[@]}
EOF

cat << EOF > /mnt/boot/loader/entries/arch-lts.conf
title    Arch Linux
linux    /vmlinuz-linux-lts
initrd   /${cpu_vendor}-ucode.img
initrd   /initramfs-linux-lts.img
options  ${kernel_params[@]}
EOF

log "Done. Restart the machine by typing 'reboot' and login to the new system"
log "You can check the full installation log in $log_file"
