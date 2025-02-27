# ArchL4TM

ArchL4TM is a **semi-interactive minimal Arch Linux installation script** designed for advanced users. It automates Arch Linux installation on EFI systems with **LVM**, **LUKS**, and **ext4**, without swap.

**Warning:** This script is not intended for beginners! If you're new to Arch Linux, please consult the [Arch Linux Installation Guide](https://wiki.archlinux.org/title/Installation_guide/) and ensure you understand the installation process before using this script.

## Features

### Drive Layout:
- **Partition 1**: EFI (mounted to `/boot/efi`)
- **Partition 2**: Boot (GRUB installed here)
- **Partition 3**: LVM `volgroup0`
  - `lv_root`
  - `lv_home`

### Bootloader:
- **GRUB** (with optional themes):
  - [Poly Dark](https://github.com/shvchk/poly-dark.git)
  - [CyberESX](https://github.com/HenriqueLopes42/themeGrub.CyberEXS.git)
  - [Cyberpunk](https://gitlab.com/anoopmsivadas/Cyberpunk-GRUB-Theme.git)
  - [HyperFluent](https://github.com/Coopydood/HyperFluent-GRUB-Theme.git)

### Default Packages:
- `pacman-contrib`, `reflector`, `rsync`, `base-devel`, `networkmanager`, `lvm2`, `pipewire`, `btop`, `man-db`, `man-pages`, `texinfo`, `tldr`, `bash-completion`, `openssh`, `git`, `neovim`, `grub`, `efibootmgr`, `python`, `debugedit`, etc.

### Microcode Detection:
- Automatically detects and installs the appropriate **microcode** for **AMD** and **Intel** processors using `lscpu`.

### Locale:
- **en_US.UTF-8** is set as the default locale.

### Timezone:
- Set interactively during installation.

### Pacman Configuration:
The following settings are enabled in `/etc/pacman.conf`:
- `ILoveCandy`
- `Color`
- `VerbosePkgLists`
- `ParallelDownloads`
- `MultiLib`

### AUR Helper Options:
- **Paru** and **Yay** are supported for AUR package management.

### GPU Detection:
- The script detects and installs drivers for **AMD** or **NVIDIA** GPUs using `lspci`.

### Desktop Environments:
- **Server**: No GUI, only core packages.
- **Hyprland**: Includes Hyprland and custom dotfiles from [HyDE](https://github.com/live4thamuzik/L4TM-HyDE).
- **GNOME**: Full GNOME desktop environment.
- **KDE (Plasma)**: Full KDE Plasma desktop environment.

## Installation Guide

### Prerequisites:
1. **Create Arch Installation Media**:
   - Download the [Arch ISO](https://archlinux.org/download/) and flash it to a USB drive using tools like [Balena Etcher](https://etcher.balena.io/etcher/) or [Rufus](https://rufus.ie/en/).

2. **Boot Arch**:
   - Start your system with the Arch ISO.

3. **Connect to Wi-Fi** (if wired connection is not available):
   ```bash
   iwctl
   device list
   station wlan0 scan
   station wlan0 get-networks
   station wlan0 connect "NETWORK_NAME"
   exit

4. **Check IP Address**:
   ```bash
   ip addr show

5. **Ping Test**:
   ```bash
   ping -c 4 archlinux.org

6. **Install Git**:
   ```bash
   pacman -Sy git

7. **Clone the Repository**:
   ```bash
   git clone https://github.com/live4thamuzik/ArchL4TM.git
   
8. **Run the Installation Script**:
   ```bash
   cd ArchL4TM/
   chmod +x *.sh
   ./install.sh
