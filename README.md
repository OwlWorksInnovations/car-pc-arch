# Car PC Arch Linux Setup

Lightweight Arch Linux configuration for a DIY car infotainment and offline navigation system using Openbox and Organic Maps.

## Repository Structure

```text
car-pc-arch/
├── install.sh                 # Post-install dashboard setup script
├── configs/
│   ├── autostart              # Openbox autostart script
│   └── autologin.conf         # Systemd getty@tty1 auto-login override
└── archinstall/
    ├── install-arch.sh        # Interactive disk & password selector for archinstall
    └── config.json            # Base archinstall system configuration template
```

## Quick Start

### 1. Base OS Installation (From Arch Live ISO)
Run the interactive installer script—it will list all available drives (`lsblk`), let you pick the target disk by number, prompt for a root password, and run `archinstall` silently:
```bash
chmod +x archinstall/install-arch.sh
./archinstall/install-arch.sh
```

### 2. Post-Install Dashboard Setup (After Rebooting)
Run `install.sh` (or pipe it via `curl` from your GitHub repo) to configure Flatpak, Organic Maps, auto-login, and Openbox autostart:
```bash
chmod +x install.sh
sudo ./install.sh
```
