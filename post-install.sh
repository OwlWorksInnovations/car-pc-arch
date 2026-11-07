#!/bin/bash
set -e

# Ensure script is run as root/sudo
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run with sudo or as root." 
   exit 1
fi

echo "===> Enabling and starting NetworkManager..."
systemctl enable --now NetworkManager

echo "===> Setting up user Openbox configuration for 'caruser'..."
USER_HOME="/home/caruser"

if [[ -d "$USER_HOME" ]]; then
    sudo -u caruser mkdir -p "$USER_HOME/.config/openbox"
    
    # Write a clean autostart file that launches your media player instead of random xterms
    cat << 'EOF' > "$USER_HOME/.config/openbox/autostart"
# Clean Openbox autostart configuration for Car PC
# Add background apps here, ending with an ampersand (&)

# Example: Launch audacious or mpv automatically on startup
# audacious &
EOF

    chown -R caruser:caruser "$USER_HOME/.config"
    echo "===> Openbox autostart configured at $USER_HOME/.config/openbox/autostart"
else
    echo "WARNING: /home/caruser directory not found. Skipping user autostart setup."
fi

echo "===> Configuring ALSA audio settings..."
# Unmute master and PCM channels and store state
alsactl store 2>/dev/null || echo "ALSA state card not fully initialized yet; run alsamixer manually later."

echo "===> Post-installation setup complete!"
echo "You can now log into your user account and run 'startx' to launch Openbox."
