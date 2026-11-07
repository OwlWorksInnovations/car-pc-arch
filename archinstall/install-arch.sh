#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run this script as root from the Arch Live ISO."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "   Car PC - Unattended Arch Installer     "
echo "=========================================="
echo ""
echo "[+] Scanning available storage devices..."
echo ""

# List physical disks (excluding loop, rom, ram)
mapfile -t DISKS < <(lsblk -dpno NAME,SIZE,MODEL | grep -E '^/dev/(sd|nvme|vd|mmcblk)')

if [ ${#DISKS[@]} -eq 0 ]; then
  echo "[-] No suitable storage devices found!"
  exit 1
fi

for i in "${!DISKS[@]}"; do
  printf "  [%d] %s\n" "$((i+1))" "${DISKS[$i]}"
done

echo ""
while true; do
  read -rp "Select target drive number [1-${#DISKS[@]}]: " CHOICE
  if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#DISKS[@]}" ]; then
    SELECTED_LINE="${DISKS[$((CHOICE-1))]}"
    TARGET_DISK=$(echo "$SELECTED_LINE" | awk '{print $1}')
    break
  else
    echo "[-] Invalid selection. Enter a number between 1 and ${#DISKS[@]}."
  fi
done

echo ""
echo "[!] WARNING: ALL DATA ON $TARGET_DISK ($SELECTED_LINE) WILL BE WIPED!"
read -rp "Type 'yes' to confirm: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "[-] Installation aborted."
  exit 1
fi

echo ""
while true; do
  read -rsp "Enter root password for the new system: " ROOT_PASS
  echo ""
  read -rsp "Confirm root password: " ROOT_PASS_CONFIRM
  echo ""
  if [ -n "$ROOT_PASS" ] && [ "$ROOT_PASS" == "$ROOT_PASS_CONFIRM" ]; then
    break
  else
    echo "[-] Passwords do not match or are empty. Try again."
  fi
done

TMP_CONFIG="/tmp/car-pc-config.json"
TMP_CREDS="/tmp/car-pc-creds.json"

# Inject selected disk into config.json
sed "s|__DISK__|$TARGET_DISK|g" "$SCRIPT_DIR/config.json" > "$TMP_CONFIG"

# Safely serialize root password into JSON via python3
python3 -c '
import json, sys
creds = {"root-enc-password": None, "!root-password": sys.argv[1]}
with open(sys.argv[2], "w") as f:
    json.dump(creds, f, indent=2)
' "$ROOT_PASS" "$TMP_CREDS"

echo ""
echo "[+] Starting archinstall on $TARGET_DISK..."
archinstall --config "$TMP_CONFIG" --creds "$TMP_CREDS" --silent

rm -f "$TMP_CONFIG" "$TMP_CREDS"
echo "[+] Base OS installation complete! You can now reboot into your new system and run install.sh."
