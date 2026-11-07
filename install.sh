#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run this script as root."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[+] Synchronizing package databases and updating system..."
pacman -Syu --noconfirm

echo "[+] Installing Xorg, Openbox, ALSA, fonts, terminal, and media packages..."
pacman -S --noconfirm xorg-server xorg-xinit openbox alsa-utils ttf-dejavu xterm flatpak audacious mpv jack2

echo "[+] Setting up Flathub remote..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo "[+] Installing Organic Maps via Flatpak..."
flatpak install -y flathub app.organicmaps.desktop

echo "[+] Configuring user xinitrc..."
echo "exec openbox-session" > ~/.xinitrc

echo "[+] Configuring systemd auto-login on tty1..."
mkdir -p /etc/systemd/system/getty@tty1.service.d
if [ -f "$SCRIPT_DIR/configs/autologin.conf" ]; then
  cp "$SCRIPT_DIR/configs/autologin.conf" /etc/systemd/system/getty@tty1.service.d/autologin.conf
else
  cat << 'EOF' > /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \u' --noclear --autologin root %I $TERM
EOF
fi
systemctl daemon-reload

echo "[+] Configuring bash profile to auto-start X on login..."
grep -q "startx" ~/.bash_profile || echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> ~/.bash_profile

echo "[+] Configuring Openbox autostart script..."
mkdir -p ~/.config/openbox
if [ -f "$SCRIPT_DIR/configs/autostart" ]; then
  cp "$SCRIPT_DIR/configs/autostart" ~/.config/openbox/autostart
else
  cat << 'EOF' > ~/.config/openbox/autostart
# Disable screen blanking and power saving so the dashboard stays awake
xset s off -dpms &

# Launch offline navigation
flatpak run app.organicmaps.desktop &
EOF
fi

echo "[+] Setup complete! Rebooting system..."
sleep 2
reboot
