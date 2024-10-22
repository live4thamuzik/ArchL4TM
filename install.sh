#!/bin/bash

# Exit on any command failure
set -e

# Log all output to separate log files with timestamps
exec > >(tee -a /var/log/arch_install.log) 2> >(tee -a /var/log/arch_install_error.log >&2)

# --- Welcome Message ---
echo -ne "
+--------------------------------+
| Arch Linux Installation Script |
+--------------------------------+
"

echo -ne "

 █████╗ ██████╗  ██████╗██╗  ██╗██╗██╗  ██╗████████╗███╗   ███╗
██╔══██╗██╔══██╗██╔════╝██║  ██║██║██║  ██║╚══██╔══╝████╗ ████║
███████║██████╔╝██║     ███████║██║███████║   ██║   ██╔████╔██║
██╔══██║██╔══██╗██║     ██╔══██║██║╚════██║   ██║   ██║╚██╔╝██║
██║  ██║██║  ██║╚██████╗██║  ██║███████╗██║   ██║   ██║ ╚═╝ ██║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝   ╚═╝   ╚═╝     ╚═╝
                                                               
"

# --- Source Functions ---
source ./global_functions.sh


# --- User Input ---
echo "Please enter a username."
get_username
echo "Please set your password."
get_user_password
echo "Please set the root password."
get_root_password
echo "Please name your system."
get_hostname
echo "Please select a disk to use for installation"
get_disk
echo "Please set partition sizes"
get_partition_sizes
echo "The disk is encrypted with LUKS. Please set a password to unlock the disk"
get_encryption_password
echo "Please choose your timezone."
setup_timezone
echo "Would you like a Desktop Enviornment?"
select_gui
echo "Please choose an AUR helper"
get_aur_helper

# --- Export Variables --- 
export HOSTNAME
export USERNAME
export USER_PASSWORD
export ROOT_PASSWORD
export GUI_CHOICE
export AUR_HELPER 
export DISK
export EFI_SIZE
export BOOT_SIZE
export ENCRYPTION_PASSWORD

### Installation Steps ###
log_info "Starting installation process..."

# --- Disk Preperation ---
echo "Running disk prep"
partition_disk "$DISK" "$EFI_SIZE" "$BOOT_SIZE"
setup_lvm "$DISK" "$ENCRYPTION_PASSWORD"

# --- Install pacman-contrib reflector rsync python ---
echo "Installing dependancies for reflector"
install_prerequisites

# --- Make /etc/pacman.d/mirrorlist.backup and run reflector on /etc/pacman.d/mirrorlist ---
echo "Configuring mirrors for faster downlaods"
configure_mirrors

# --- run pacstrap ---
echo "Installing base packages"
install_base_packages

# --- Generate FS Tab ---
echo "Running genfstab"
genfstab -U -p /mnt >> /mnt/etc/fstab

# --- Copy sources to /mnt and make script executable
cp ./global_functions.sh pkgs.lst /mnt
chmod +x /mnt/global_functions.sh

# --- Chroot Setup ---
echo "Entering chroot"
./chroot.sh

# --- Cleanup ---
echo "cleaning up"
cleanup

# --- Unmount everything ---
umount -R /mnt

# --- Comment ---
echo "Installation is complete, please reboot system."

echo -ne "

 █████╗ ██████╗  ██████╗██╗  ██╗██╗██╗  ██╗████████╗███╗   ███╗
██╔══██╗██╔══██╗██╔════╝██║  ██║██║██║  ██║╚══██╔══╝████╗ ████║
███████║██████╔╝██║     ███████║██║███████║   ██║   ██╔████╔██║
██╔══██║██╔══██╗██║     ██╔══██║██║╚════██║   ██║   ██║╚██╔╝██║
██║  ██║██║  ██║╚██████╗██║  ██║███████╗██║   ██║   ██║ ╚═╝ ██║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝   ╚═╝   ╚═╝     ╚═╝
                                                               
"
