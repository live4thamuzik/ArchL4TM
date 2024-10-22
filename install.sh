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
echo -ne "Please enter a username."
get_username

echo -ne "Please set your password."
get_user_password

echo -ne "Please set the root password."
get_root_password

echo -ne "Please name your system."
get_hostname

echo -ne "Please select a disk to use for installation"
get_disk

echo -ne "Please set partition sizes"
get_partition_sizes

echo -ne "The disk is encrypted with LUKS. Please set a password to unlock the disk"
get_encryption_password

echo -ne "Please choose your timezone."
setup_timezone

echo -ne "Would you like a Desktop Enviornment?"
select_gui

echo -ne "Please choose an AUR helper"
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
echo -ne  "Running disk prep"
partition_disk "$DISK" "$EFI_SIZE" "$BOOT_SIZE"
setup_lvm "$DISK" "$ENCRYPTION_PASSWORD"

# --- Install pacman-contrib reflector rsync python ---
echo -ne "Installing dependancies for reflector"
install_prerequisites

# --- Make /etc/pacman.d/mirrorlist.backup and run reflector on /etc/pacman.d/mirrorlist ---
echo -ne "Configuring mirrors for faster downlaods"
configure_mirrors

# --- run pacstrap ---
echo -ne "Installing base packages"
install_base_packages

# --- Generate FS Tab ---
echo -ne "Running genfstab"
genfstab -U -p /mnt >> /mnt/etc/fstab

# --- Copy sources to /mnt and make script executable
cp ./global_functions.sh ./pkgs.lst /mnt
chmod +x /mnt/global_functions.sh

# --- Chroot Setup ---
echo -ne "Entering chroot"
./chroot.sh

# --- Cleanup ---
echo -ne "Cleaning up"
cleanup

# --- Unmount everything ---
umount -R /mnt

# --- Comment ---
echo -ne "Installation is complete, please reboot system."

echo -ne "

 █████╗ ██████╗  ██████╗██╗  ██╗██╗██╗  ██╗████████╗███╗   ███╗
██╔══██╗██╔══██╗██╔════╝██║  ██║██║██║  ██║╚══██╔══╝████╗ ████║
███████║██████╔╝██║     ███████║██║███████║   ██║   ██╔████╔██║
██╔══██║██╔══██╗██║     ██╔══██║██║╚════██║   ██║   ██║╚██╔╝██║
██║  ██║██║  ██║╚██████╗██║  ██║███████╗██║   ██║   ██║ ╚═╝ ██║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝   ╚═╝   ╚═╝     ╚═╝
                                                               
"
