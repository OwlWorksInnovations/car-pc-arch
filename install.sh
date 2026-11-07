#!/bin/bash
set -e

# ==========================================
# 1. DISK FORMATTING & PARTITIONING (DO FIRST)
# ==========================================

DISK="/dev/vda"

echo "===> Unmounting any existing mounts..."
umount -R /mnt 2>/dev/null || true

echo "===> Wiping partition table on $DISK..."
wipefs -a "$DISK"
sgdisk --zap-all "$DISK"

echo "===> Creating new GPT partition table (EFI + Root)..."
sgdisk -n 1:0:+512M -t 1:ef00 "$DISK"
sgdisk -n 2:0:0 -t 2:8300 "$DISK"

if [[ "$DISK" =~ nvme ]]; then
    EFI_PART="${DISK}p1"
    ROOT_PART="${DISK}p2"
else
    EFI_PART="${DISK}1"
    ROOT_PART="${DISK}2"
fi

echo "===> Formatting partitions..."
mkfs.fat -F32 "$EFI_PART"
mkfs.ext4 -F "$ROOT_PART"

echo "===> Mounting filesystems to /mnt with secure umask..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount -o uid=0,gid=0,fmask=0077,dmask=0077 "$EFI_PART" /mnt/boot


# ==========================================
# 2. SYSTEM INSTALLATION (DO AFTER FORMATTING)
# ==========================================

echo "===> Installing base system and packages..."
pacstrap /mnt base linux linux-firmware \
    xorg-server xorg-xinit openbox alsa-utils ttf-dejavu xterm flatpak audacious mpv jack2 \
    networkmanager sudo grub efibootmgr

echo "===> Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab


# ==========================================
# 3. CHROOT CONFIGURATION & GRUB SETUP
# ==========================================

echo "===> Configuring system inside chroot..."
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/Africa/Johannesburg /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "car-pc" > /etc/hostname

# Install GRUB for UEFI
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager

echo "root:changeme" | chpasswd
EOF

echo "===> Installation complete! You can now unmount and reboot."
