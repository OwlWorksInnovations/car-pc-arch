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

echo "===> Installing desktop icon manager (pcmanfm), taskbar (tint2), and xdotool..."
pacman -S --noconfirm --needed pcmanfm tint2 xdotool

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
if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
    exec startx
fi
EOF

echo "===> Writing clean 1-line .xinitrc..."
printf "exec openbox-session\n" > "$USER_HOME/.xinitrc"
printf "exec openbox-session\n" > /root/.xinitrc

echo "===> Configuring Openbox autostart (desktop icons + taskbar)..."
mkdir -p "$USER_HOME/.config/openbox"
cat << 'EOF' > "$USER_HOME/.config/openbox/autostart"
pcmanfm --desktop &
tint2 &
EOF

echo "===> Configuring Openbox to maximize ALL windows by default..."
cp /etc/xdg/openbox/rc.xml "$USER_HOME/.config/openbox/rc.xml"
python3 - << EOF
with open("$USER_HOME/.config/openbox/rc.xml", "r") as f:
    xml = f.read()

rule = """  <application class="*">
    <maximized>true</maximized>
  </application>
</applications>"""

xml = xml.replace("</applications>", rule)
with open("$USER_HOME/.config/openbox/rc.xml", "w") as f:
    f.write(xml)
EOF

echo "===> Configuring crash-free car-friendly tint2 taskbar (rounded = 0)..."
mkdir -p "$USER_HOME/.config/tint2"
cat << 'EOF' > "$USER_HOME/.config/tint2/tint2rc"
# Panel geometry
panel_items = LTSC
panel_size = 100% 48
panel_margin = 0 0
panel_padding = 4 2 4
panel_position = bottom center horizontal
panel_layer = top
strut_policy = follow_size

# Background 0 (Panel)
rounded = 0
border_width = 0
background_color = #181818 100

# Background 1 (Active task)
rounded = 0
border_width = 1
background_color = #2E7D32 100
border_color = #66BB6A 100

# Background 2 (Inactive task)
rounded = 0
border_width = 1
background_color = #2B2B2B 100
border_color = #444444 100

# Launcher (Show Desktop)
launcher_padding = 6 4 6
launcher_icon_size = 32
launcher_item_app = /usr/local/share/applications/show-desktop.desktop

# Taskbar
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

# Clock
time1_format = %H:%M
time1_font = Sans Bold 13
clock_font_color = #FFFFFF 100
clock_padding = 10 0
EOF

# Create "Show Desktop" taskbar button
mkdir -p /usr/local/share/applications
cat << 'EOF' > /usr/local/share/applications/show-desktop.desktop
[Desktop Entry]
Type=Application
Name=Home / Desktop
Exec=xdotool key super+d
Icon=user-desktop
Terminal=false
EOF

echo "===> Setting xterm as PCManFM default terminal..."
mkdir -p "$USER_HOME/.config/libfm"
cat << 'EOF' > "$USER_HOME/.config/libfm/libfm.conf"
[config]
terminal=xterm
EOF

echo "===> Creating clickable Desktop shortcuts (Music, Maps, Terminal)..."
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

chmod +x "$USER_HOME/Desktop/"*.desktop
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME"

echo "===> Saving ALSA state..."
alsactl store 2>/dev/null || true

echo "===> Done! Reboot ('sudo reboot') to boot straight into the maximized car UI."
