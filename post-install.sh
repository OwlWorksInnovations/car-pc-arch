#!/bin/bash
set -e

# Ensure script is run as root/sudo
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run with sudo or as root." 
   exit 1
fi

echo "===> Enabling and starting NetworkManager..."
systemctl enable --now NetworkManager

USER_NAME="caruser"
USER_HOME="/home/$USER_NAME"

# Create user if it doesn't exist yet
if ! id "$USER_NAME" >/dev/null 2>&1; then
    echo "===> Creating user '$USER_NAME'..."
    useradd -m -G wheel -s /bin/bash "$USER_NAME"
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
    echo "NOTE: Set a password for $USER_NAME later with 'sudo passwd $USER_NAME'"
fi

echo "===> Configuring .xinitrc for Openbox..."
cp /etc/X11/xinit/xinitrc "$USER_HOME/.xinitrc"
# Strip the default twm, xclock, and 3x xterm fallback lines at the bottom
sed -i '/twm &/,$d' "$USER_HOME/.xinitrc"
echo "exec openbox-session" >> "$USER_HOME/.xinitrc"

echo "===> Setting up Openbox autostart configuration..."
mkdir -p "$USER_HOME/.config/openbox"
cat << 'EOF' > "$USER_HOME/.config/openbox/autostart"
# Clean Openbox autostart configuration for Car PC
# Add background apps here, ending with an ampersand (&)

# Example: Launch audacious automatically on startup
# audacious &
EOF

chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.xinitrc" "$USER_HOME/.config"

echo "===> Configuring ALSA audio settings..."
alsactl store 2>/dev/null || echo "ALSA state card not initialized yet; run alsamixer manually later."

echo "===> Post-installation setup complete!"
echo "Switch to $USER_NAME (su - $USER_NAME) and run 'startx' to launch Openbox."
