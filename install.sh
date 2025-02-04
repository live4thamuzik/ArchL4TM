#!/bin/bash

# Exit on any command failure
set -e

# Log all output to separate log files with timestamps
exec > >(tee -a /var/log/arch_install.log) 2> >(tee -a /var/log/arch_install_error.log >&2)

# --- Welcome Message ---
echo "
+--------------------------------+
| Arch Linux Installation Script |
+--------------------------------+
"

echo "

 █████╗ ██████╗  ██████╗██╗  ██╗██╗██╗  ██╗████████╗███╗   ███╗
██╔══██╗██╔══██╗██╔════╝██║  ██║██║██║  ██║╚══██╔══╝████╗ ████║
███████║██████╔╝██║     ███████║██║███████║   ██║   ██╔████╔██║
██╔══██║██╔══██╗██║     ██╔══██║██║╚════██║   ██║   ██║╚██╔╝██║
██║  ██║██║  ██║╚██████╗██║  ██║███████╗██║   ██║   ██║ ╚═╝ ██║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝   ╚═╝   ╚═╝     ╚═╝
"

# --- Source Functions ---
source ./global_functions.sh

sleep 1

# --- User Input ---
get_username
get_user_password
get_root_password
get_hostname
get_disk
get_partition_sizes
get_encryption_password
setup_timezone
select_gui
get_grub_theme
get_aur_helper

# --- Export Variables --- 
export HOSTNAME
export USERNAME
export USER_PASSWORD
export ROOT_PASSWORD
export GUI_CHOICE
export GRUB_THEME
export AUR_HELPER 
export DISK
export EFI_SIZE
export BOOT_SIZE
export ENCRYPTION_PASSWORD

### Installation Steps ###
log_info "Starting installation process..."

# --- Disk Preperation ---
partition_disk "$DISK" "$EFI_SIZE" "$BOOT_SIZE"
setup_lvm "$DISK" "$ENCRYPTION_PASSWORD"

# --- Install pacman-contrib reflector rsync python ---
install_prerequisites

# --- Make /etc/pacman.d/mirrorlist.backup and run reflector on /etc/pacman.d/mirrorlist ---
configure_mirrors

# --- run pacstrap ---
install_base_packages

# --- Generate FS Tab ---
genfstab -U -p /mnt >> /mnt/etc/fstab

# --- Copy sources to /mnt and make script executable
cp -r ./global_functions.sh ./chroot.sh ./pkgs.lst ./aur_pkgs.lst ./Source/arch-glow /mnt
chmod +x /mnt/*.sh

# --- Chroot Setup ---
arch-chroot /mnt /bin/bash -c "./chroot.sh"

# --- Cleanup ---
cleanup

# --- Unmount everything ---
umount -R /mnt

# --- Comment ---
echo "Installation is complete, please reboot system."


echo "

 █████╗ ██████╗  ██████╗██╗  ██╗██╗██╗  ██╗████████╗███╗   ███╗
██╔══██╗██╔══██╗██╔════╝██║  ██║██║██║  ██║╚══██╔══╝████╗ ████║
███████║██████╔╝██║     ███████║██║███████║   ██║   ██╔████╔██║
██╔══██║██╔══██╗██║     ██╔══██║██║╚════██║   ██║   ██║╚██╔╝██║
██║  ██║██║  ██║╚██████╗██║  ██║███████╗██║   ██║   ██║ ╚═╝ ██║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝   ╚═╝   ╚═╝     ╚═╝
"
