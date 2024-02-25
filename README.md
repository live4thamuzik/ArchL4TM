# ArchL4TM

This is a personal Arch Linux installation script

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
git clone https://github.com/live4thamuzik/ArchL4TM
```

Run script:
```
cd ArchL4TM/
./archl4tm.sh
```
