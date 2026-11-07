#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
   echo "ERROR: Run this script with sudo or as root."
   exit 1
fi

USER_NAME="caruser"
USER_HOME="/home/$USER_NAME"

echo "===> Enabling NetworkManager..."
systemctl enable --now NetworkManager

if ! id "$USER_NAME" >/dev/null 2>&1; then
    echo "===> Creating user '$USER_NAME'..."
    useradd -m -G wheel,video,input -s /bin/bash "$USER_NAME"
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
else
    usermod -aG wheel,video,input "$USER_NAME"
fi

echo "===> Installing lightweight desktop icon manager (pcmanfm)..."
pacman -S --noconfirm --needed pcmanfm

echo "===> Installing Organic Maps via Flatpak (if online)..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
flatpak install -y flathub app.organicmaps.desktop || echo "WARNING: Could not install Organic Maps (check internet connection)."

echo "===> Configuring automatic login on TTY1 for '$USER_NAME'..."
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat << EOF > /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin $USER_NAME %I \$TERM
EOF

echo "===> Configuring auto-startx on TTY1 login..."
cat << 'EOF' > "$USER_HOME/.bash_profile"
# Auto-start Xorg on TTY1
if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
    exec startx
fi
EOF

echo "===> Writing clean 1-line .xinitrc..."
printf "exec openbox-session\n" > "$USER_HOME/.xinitrc"

echo "===> Configuring Openbox autostart with desktop icons..."
mkdir -p "$USER_HOME/.config/openbox"
cat << 'EOF' > "$USER_HOME/.config/openbox/autostart"
# Render clickable desktop icons and wallpaper
pcmanfm --desktop &
EOF

echo "===> Creating clickable Desktop shortcuts..."
mkdir -p "$USER_HOME/Desktop"

# 1. Music Player Shortcut
cat << 'EOF' > "$USER_HOME/Desktop/Music.desktop"
[Desktop Entry]
Type=Application
Name=Music Player
Comment=Launch Audacious
Exec=audacious
Icon=audacious
Terminal=false
EOF

# 2. Offline Maps Shortcut
cat << 'EOF' > "$USER_HOME/Desktop/Maps.desktop"
[Desktop Entry]
Type=Application
Name=Navigation Maps
Comment=Launch Offline Maps
Exec=flatpak run app.organicmaps.desktop
Icon=app.organicmaps.desktop
Terminal=false
EOF

chmod +x "$USER_HOME/Desktop/"*.desktop
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME"

echo "===> Saving ALSA state..."
alsactl store 2>/dev/null || true

echo "===> All done! Reboot your system ('sudo reboot') to test auto-boot into desktop."
