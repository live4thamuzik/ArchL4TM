# ArchL4TM

This is a personal semi-interactive Arch Linux installation bash script.

The script will install Arch Linux with minimal config and packages using LVM, LUKS and ext4. (no swap)

Drive layout:
Partition 1 - 2GB (EFI)
Partition 2 - 5GB (boot) GRUB is installed here
Partition 3 - 100%Free (LVM) "volgroup0"
lv_root = 100GB
lv_home = 100%FREE

No Desktop Environment
No Window Manager
No Themes 

# Create Arch Installation Media

Before using this script you will need to obtain the [ArchISO](https://archlinux.org/download/) and flash it to a USB drive with a program like Balena [Etcher](https://etcher.balena.io/etcher/) or [Rufus](https://rufus.ie/en/)

# Boot Arch
From the initial prompt do the following

#Connect to WIFI (if wired connection is not available)
```
iwctl
device list
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "NETWORK_NAME"
exit
```

Check IP Address:
```
ip addr show
```

Ping Test:
```
ping -c 4 archlinux.org
```

Install git:
```
pacman -Sy git
```

Clone repo:
```
git clone https://github.com/live4thamuzik/ArchL4TM.git
```

Run script:
```
cd ArchL4TM/
chmod +x archl4tm
sh archl4tm.sh
```
