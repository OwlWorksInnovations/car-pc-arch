
#!/bin/bash
set -e

# ==========================================
# 0. PRE-FLIGHT CHECKS & DISK SELECTION
# ==========================================

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run this script as root."
    exit 1
fi

if [[ ! -d /sys/firmware/efi/efivars ]]; then
    echo "ERROR: Installer was not booted in UEFI mode!"
    exit 1
fi

if ! ping -c 1 -W 3 archlinux.org >/dev/null 2>&1; then
    echo "ERROR: No internet connection! Please check your network."
    exit 1
fi

# ==========================================
# 1. ROOT PASSWORD SETUP
# ==========================================

echo
echo "=========================================="
echo " ROOT PASSWORD SETUP"
echo "=========================================="

while true; do
    read -rsp "Enter root password: " ROOT_PASSWORD
    echo

    read -rsp "Confirm root password: " ROOT_PASSWORD_CONFIRM
    echo

    if [[ -z "$ROOT_PASSWORD" ]]; then
        echo "ERROR: Password cannot be empty."
    elif [[ "$ROOT_PASSWORD" != "$ROOT_PASSWORD_CONFIRM" ]]; then
        echo "ERROR: Passwords do not match. Try again."
    else
        break
    fi
done

echo "Root password accepted."

# ==========================================
# 2. DISK SELECTION
# ==========================================

echo
echo "Available disks on this system:"
lsblk -dpno NAME,SIZE,MODEL,TYPE | grep disk

read -rp "Enter the target disk to install on (e.g. /dev/sda or /dev/vda): " DISK

if [[ ! -b "$DISK" ]]; then
    echo "ERROR: Disk $DISK does not exist!"
    exit 1
fi

if [[ "$(lsblk -dn -o TYPE "$DISK")" != "disk" ]]; then
    echo "ERROR: Please select an entire disk, not a partition!"
    exit 1
fi

lsblk "$DISK"

read -rp "WARNING: THIS WILL ENTIRELY ERASE $DISK. Continue? (yes/no): " CONFIRM

[[ "$CONFIRM" == "yes" ]] || {
    echo "Installation aborted."
    exit 1
}

# ==========================================
# 3. DISK FORMATTING & PARTITIONING
# ==========================================

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

echo "===> Mounting filesystems with secure permissions..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount -o uid=0,gid=0,fmask=0077,dmask=0077 "$EFI_PART" /mnt/boot

# ==========================================
# 4. SYSTEM INSTALLATION & PACSTRAP
# ==========================================

echo "===> Installing base system and packages..."

pacstrap /mnt \
    base \
    linux \
    linux-firmware \
    base-devel \
    git \
    nano \
    xorg-server \
    xorg-xinit \
    openbox \
    alsa-utils \
    ttf-dejavu \
    xterm \
    flatpak \
    audacious \
    mpv \
    jack2 \
    networkmanager \
    grub \
    efibootmgr

echo "===> Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# ==========================================
# 5. CHROOT CONFIGURATION & GRUB SETUP
# ==========================================

echo "===> Configuring system inside chroot..."

arch-chroot /mnt /bin/bash <<EOF

# Timezone
ln -sf /usr/share/zoneinfo/Africa/Johannesburg /etc/localtime
hwclock --systohc

# Locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Hostname
echo "car-pc" > /etc/hostname

# GRUB installation
grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot \
    --bootloader-id=GRUB \
    --removable \
    --recheck

grub-mkconfig -o /boot/grub/grub.cfg

# NetworkManager
systemctl enable NetworkManager

# Set root password
printf '%s\n' "root:$ROOT_PASSWORD" | chpasswd

EOF

# ==========================================
# 6. CLEANUP & EXIT
# ==========================================

unset ROOT_PASSWORD
unset ROOT_PASSWORD_CONFIRM

echo
echo "=========================================="
echo " INSTALLATION COMPLETE!"
echo "=========================================="

umount -R /mnt

echo "Filesystems unmounted successfully."
echo
echo "You can now safely remove your installation USB and reboot."
echo "Root password is the one you created during installation."
echo "=========================================="
