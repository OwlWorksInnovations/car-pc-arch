
#!/bin/bash
set -e

# ==========================================
# CAR INFOTAINMENT INSTALLER
# Arch Linux + Openbox
# ==========================================

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run this script with sudo or as root."
    exit 1
fi

USER_NAME="caruser"
USER_HOME="/home/$USER_NAME"

echo "===> Enabling NetworkManager and Bluetooth..."
systemctl enable --now NetworkManager
systemctl enable --now bluetooth

echo "===> Installing desktop, network and Bluetooth packages..."
pacman -S --noconfirm --needed \
    pcmanfm tint2 xdotool openbox xterm \
    network-manager-applet bluez bluez-utils blueman \
    flatpak audacious alsa-utils

echo "===> Creating user..."
if ! id "$USER_NAME" >/dev/null 2>&1; then
    useradd -m -G wheel,video,input,lp -s /bin/bash "$USER_NAME"
else
    usermod -aG wheel,video,input,lp "$USER_NAME"
fi

mkdir -p /etc/sudoers.d
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

echo "===> Installing Organic Maps..."
flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo || true

flatpak install -y flathub app.organicmaps.desktop || \
    echo "WARNING: Organic Maps installation failed."

echo "===> Removing old GPS configuration..."
systemctl disable --now bt-gps-bridge.service 2>/dev/null || true
systemctl disable --now gpsd.service 2>/dev/null || true

rm -f /etc/systemd/system/bt-gps-bridge.service
rm -f /etc/default/gpsd

systemctl daemon-reload
systemctl reset-failed

echo "===> Configuring automatic login..."
mkdir -p /etc/systemd/system/getty@tty1.service.d

cat << EOF > /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin $USER_NAME %I \$TERM
EOF

echo "===> Configuring automatic X startup..."
cat << 'EOF' > "$USER_HOME/.bash_profile"
if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
    exec startx
fi
EOF

printf "exec openbox-session\n" > "$USER_HOME/.xinitrc"
printf "exec openbox-session\n" > /root/.xinitrc

echo "===> Configuring Openbox..."
mkdir -p "$USER_HOME/.config/openbox"

cp /etc/xdg/openbox/rc.xml \
    "$USER_HOME/.config/openbox/rc.xml"

python3 - << EOF
path = "$USER_HOME/.config/openbox/rc.xml"

with open(path, "r") as f:
    xml = f.read()

rule = """  <application class="*">
    <maximized>true</maximized>
  </application>
</applications>"""

if "</applications>" in xml and '<application class="*">' not in xml:
    xml = xml.replace("</applications>", rule)

with open(path, "w") as f:
    f.write(xml)
EOF

cat << 'EOF' > "$USER_HOME/.config/openbox/autostart"
pcmanfm --desktop &
tint2 &
nm-applet &
blueman-applet &
EOF

echo "===> Configuring Tint2..."
mkdir -p "$USER_HOME/.config/tint2"

cat << 'EOF' > "$USER_HOME/.config/tint2/tint2rc"
panel_items = LTS
panel_size = 100% 48
panel_margin = 0 0
panel_padding = 4 2 4
panel_position = bottom center horizontal
panel_layer = top
strut_policy = follow_size

rounded = 0
border_width = 0
background_color = #181818 100

rounded = 0
border_width = 1
background_color = #2E7D32 100
border_color = #66BB6A 100

rounded = 0
border_width = 1
background_color = #2B2B2B 100
border_color = #444444 100

launcher_padding = 6 4 6
launcher_icon_size = 32
launcher_item_app = /usr/local/share/applications/show-desktop.desktop

taskbar_mode = single_desktop
taskbar_padding = 4 2 6
taskbar_background_id = 0
task_text = 1
task_icon = 1
task_centered = 1
task_font = Sans Bold 12
task_font_color = #EEEEEE 100
task_active_background_id = 1
task_background_id = 2

systray_padding = 4 4 4
systray_background_id = 0
systray_sort = ascending
systray_icon_size = 24
systray_icon_asb = 100 0 0

time1_format = %H:%M
time1_font = Sans Bold 13
clock_font_color = #FFFFFF 100
clock_padding = 10 0
EOF

echo "===> Creating show desktop launcher..."
mkdir -p /usr/local/share/applications

cat << 'EOF' > /usr/local/share/applications/show-desktop.desktop
[Desktop Entry]
Type=Application
Name=Home / Desktop
Exec=xdotool key super+d
Icon=user-desktop
Terminal=false
EOF

echo "===> Configuring PCManFM terminal..."
mkdir -p "$USER_HOME/.config/libfm"

cat << 'EOF' > "$USER_HOME/.config/libfm/libfm.conf"
[config]
terminal=xterm
EOF

echo "===> Creating desktop shortcuts..."
mkdir -p "$USER_HOME/Desktop"

cat << 'EOF' > "$USER_HOME/Desktop/Music.desktop"
[Desktop Entry]
Type=Application
Name=Music Player
Exec=audacious
Icon=audacious
Terminal=false
EOF

cat << 'EOF' > "$USER_HOME/Desktop/Maps.desktop"
[Desktop Entry]
Type=Application
Name=Navigation Maps
Exec=flatpak run app.organicmaps.desktop
Icon=app.organicmaps.desktop
Terminal=false
EOF

cat << 'EOF' > "$USER_HOME/Desktop/Terminal.desktop"
[Desktop Entry]
Type=Application
Name=Terminal
Exec=xterm -fa 'DejaVu Sans Mono' -fs 14
Icon=utilities-terminal
Terminal=false
EOF

cat << 'EOF' > "$USER_HOME/Desktop/Network.desktop"
[Desktop Entry]
Type=Application
Name=Network Settings
Exec=nm-connection-editor
Icon=network-wireless
Terminal=false
EOF

cat << 'EOF' > "$USER_HOME/Desktop/Bluetooth.desktop"
[Desktop Entry]
Type=Application
Name=Bluetooth
Exec=blueman-manager
Icon=bluetooth
Terminal=false
EOF

echo "===> Setting desktop permissions..."
chmod +x "$USER_HOME/Desktop/"*.desktop

echo "===> Saving ALSA state..."
alsactl store 2>/dev/null || true

echo "===> Fixing ownership..."
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME"

echo "===> Reloading systemd..."
systemctl daemon-reload

echo
echo "=========================================="
echo " CAR UI INSTALLATION COMPLETE!"
echo "=========================================="
echo "User: $USER_NAME"
echo "Desktop: Openbox + Tint2"
echo "Network: NetworkManager"
echo "Bluetooth: BlueZ"
echo "Maps: Organic Maps"
echo "GPS bridge: Removed"
echo
echo "Reboot with: reboot"
echo "=========================================="
