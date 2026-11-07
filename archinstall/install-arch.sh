#!/usr/bin/env bash
set -euo pipefail

# Usage: bash install.sh /dev/vda
DISK="${1:?Usage: bash install.sh /dev/DISK}"

[[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }
[[ -b "$DISK" ]] || { echo "Invalid disk"; exit 1; }
[[ -d /sys/firmware/efi ]] || { echo "UEFI required"; exit 1; }

echo "WARNING: EVERYTHING ON $DISK WILL BE ERASED!"
lsblk "$DISK"
read -rp "Type ERASE to continue: " CONFIRM
[[ "$CONFIRM" == "ERASE" ]] || exit 1

read -rp "Hostname [carpc]: " HOSTNAME
HOSTNAME="${HOSTNAME:-carpc}"

read -rp "Username: " USERNAME
read -rsp "Password: " PASSWORD
echo

# Determine partition naming
if [[ "$DISK" =~ [0-9]$ ]]; then
    EFI="${DISK}p1"
    ROOT="${DISK}p2"
else
    EFI="${DISK}1"
    ROOT="${DISK}2"
fi

# Partition disk
wipefs -af "$DISK"
sgdisk --zap-all "$DISK"

sgdisk \
    -n 1:0:+512M -t 1:ef00 \
    -n 2:0:0     -t 2:8300 \
    "$DISK"

partprobe "$DISK"
udevadm settle
sleep 2

# Format
mkfs.fat -F32 "$EFI"
mkfs.ext4 -F "$ROOT"

# Mount
mount "$ROOT" /mnt
mkdir -p /mnt/boot
mount "$EFI" /mnt/boot

# Install packages
pacstrap -K /mnt \
    base linux linux-firmware intel-ucode \
    sudo networkmanager \
    pipewire pipewire-alsa pipewire-pulse wireplumber

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Basic configuration
arch-chroot /mnt ln -sf \
    /usr/share/zoneinfo/Africa/Johannesburg /etc/localtime

arch-chroot /mnt hwclock --systohc

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' \
    /mnt/etc/locale.gen

arch-chroot /mnt locale-gen

echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "KEYMAP=us" > /mnt/etc/vconsole.conf
echo "$HOSTNAME" > /mnt/etc/hostname

cat > /mnt/etc/hosts <<EOF
127.0.0.1 localhost
::1 localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
EOF

# User and passwords
arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$USERNAME"

sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' \
    /mnt/etc/sudoers

printf 'root:%s\n' "$PASSWORD" | arch-chroot /mnt chpasswd
printf '%s:%s\n' "$USERNAME" "$PASSWORD" | arch-chroot /mnt chpasswd
unset PASSWORD

# Enable networking
arch-chroot /mnt systemctl enable NetworkManager

# Install systemd-boot
arch-chroot /mnt bootctl --esp-path=/boot install

ROOT_UUID=$(blkid -s UUID -o value "$ROOT")

mkdir -p /mnt/boot/loader/entries

cat > /mnt/boot/loader/loader.conf <<EOF
default arch.conf
timeout 3
editor no
EOF

cat > /mnt/boot/loader/entries/arch.conf <<EOF
title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=UUID=$ROOT_UUID rw
EOF

arch-chroot /mnt mkinitcpio -P

echo "Installation complete!"
echo "Remove installation media and reboot."
