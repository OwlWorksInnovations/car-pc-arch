# Car PC Arch Linux Setup

Lightweight Arch Linux configuration for a DIY car infotainment and offline navigation system using Openbox and Organic Maps.

## Repository Structure

```text
car-pc-arch/
├── install.sh              # Automated post-install setup script
├── configs/
│   ├── autostart           # Openbox autostart script
│   └── autologin.conf      # Systemd getty@tty1 auto-login override
└── archinstall/
    ├── config.json         # Unattended archinstall system configuration
    └── creds.json          # Unattended archinstall root credentials template
```

## Quick Start

### 1. Base OS Installation (Optional)
Update `/dev/vda` in `archinstall/config.json` to match your target drive (e.g., `/dev/sda` or `/dev/nvme0n1`) and set your password in `archinstall/creds.json`, then run:
```bash
archinstall --config archinstall/config.json --creds archinstall/creds.json --silent
```

### 2. Post-Install Dashboard Setup
Run directly from your cloned repository or via `curl`:
```bash
chmod +x install.sh
sudo ./install.sh
```
