# Car PC Arch Linux Setup

Fully automated, deployment scripts for an offline DIY car infotainment/navigation system on Arch Linux.

## Usage
1. Boot into the Arch Linux live ISO.
2. Clone or transfer this repository.
3. Make the script executable: `chmod +x install.sh`
4. Run the installer: `./install.sh`
5. Reboot `reboot 0`

## Resource Usage
- RAM: `~500MB`
- Storage: `~4.8GB`

## How to connect to car?
I use aux to my, already installed, car radio which handles the speakers. It is 100% possible to use a Raspberry PI or PI PICO to handle the speakers but this was the easiest solution for me. I haven't tested touch screen yet but I want to order a screen. You might need to make your bluetooth discoverable but in my case it was automatically done; I just go on my phone and connect to bluetooth and play music.

## NOTE
Cars can get **HOT**, and the high temperatures inside a parked vehicle can cause your laptop to overheat. Using a traditional HDD is also highly discouraged, as constant vibrations can accelerate wear and potentially cause data corruption.

An SSD is the recommended option. If you don't have one, a USB flash drive is an alternative, although it comes with its own reliability risks. Fortunately, reinstalling the system is easy with the provided scripts.
