#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
   echo "ERROR: Run this script with sudo or as root."
   exit 1
fi

echo "===> Enabling NetworkManager..."
systemctl enable --now NetworkManager

USER_NAME="caruser"
USER_HOME="/home/$USER_NAME"

if ! id "$USER_NAME" >/dev/null 2>&1; then
    echo "===> Creating user '$USER_NAME'..."
    useradd -m -G wheel,video,input -s /bin/bash "$USER_NAME"
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
else
    usermod -aG wheel,video,input "$USER_NAME"
fi

echo "===> Writing clean 1-line .xinitrc (no /etc/X11/xinit/xinitrc fallback)..."
printf "exec openbox-session\n" > "$USER_HOME/.xinitrc"
printf "exec openbox-session\n" > /root/.xinitrc

echo "===> Setting up clean Openbox autostart..."
mkdir -p "$USER_HOME/.config/openbox"
cat << 'EOF' > "$USER_HOME/.config/openbox/autostart"
# Add background apps here, ending with &
# audacious &
EOF

chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.xinitrc" "$USER_HOME/.config"

echo "===> Saving ALSA state..."
alsactl store 2>/dev/null || true

echo "===> Done! Log in directly as '$USER_NAME' on TTY1 and run 'startx'."
