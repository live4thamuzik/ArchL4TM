# ArchL4TM

This is a semi-interactive Arch Linux minimal installation bash script.

The script will install Arch Linux on EFI systems with minimal config and packages using LVM, LUKS and ext4. (no swap)

# Configuration 
  # Drive layout:
  - Partition 1 - EFI (mounted to /boot/EFI)
  - Partition 2 - boot (GRUB is installed here)
  - Partition 3 - LVM "volgroup0"
  - lv_root 
  - lv_home 

  # Bootloader
  - GRUB

  # Packages:
  - pacman-contrib
  - reflector
  - rsync
  - base
  - linux
  - linux-headers
  - linux-firmware
  - base-devel
  - networkmanager
  - lvm2
  - pipewire
  - btop
  - man-db
  - man-pages
  - texinfo
  - tldr
  - bash-completion
  - openssh
  - git
  - parallel
  - neovim
  - grub
  - efibootmgr
  - dosfstools
  - os-prober
  - mtools
  - python
  - debugedit
 

  # Microcode detection for AMD and Intel processors
  - Script will use lscpu to detect and install the correct microcode needed

  # Locale is set to en_US.UTF-8 UTF-8  (see global_functions.sh to make changes)

  # Timezone can be selected from a list

  # Pacman Configuration (The following settings are enabled in /etc/pacman.conf)
  - ILoveCandy
  - Color
  - VerbosePkgLists
  - ParallelDownloads
  - MultiLib

  # AUR Helper options:
  - Paru
  - Yay

  # Detection for NVIDIA GPU:
  - Script will use lspci to detect and install NVIDIA drivers
  - nvidia-dkms
  - libglnvd
  - nvidia-utils
  - opencl-nvidia
  - lib32-libglvnd
  - lib32-nvidia-utils
  - lib32-opencl-nvidia
  - nvidia-settings

  # Desktop Environment Options:
  - Server = No DE, only installs packages listed above
  - GNOME
  - KDE (Plasma)


# How To:

# Create Arch Installation Media
  Before using this script you will need to obtain the [ArchISO](https://archlinux.org/download/) and flash it to a USB drive with a program like Balena       [Etcher](https://etcher.balena.io/etcher/) or [Rufus](https://rufus.ie/en/)

# Boot Arch
  From the initial prompt do the following

# Connect to WIFI (if wired connection is not available)
```
iwctl
device list
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "NETWORK_NAME"
exit
```

# Check IP Address:
```
ip addr show
```

# Ping Test:
```
ping -c 4 archlinux.org
```

# Install git:
```
pacman -Sy git
```

# Clone repo:
```
git clone https://github.com/live4thamuzik/ArchL4TM.git
```

# Run script:
```
cd ArchL4TM/
chmod +x *.sh
./install.sh
```
