#!/bin/bash

# Define the log file path
LOG_FILE="/var/log/archl4tm.log"

# Create or clear the log file
: > "$LOG_FILE"

# Redirect all output to the log file
exec > >(tee -a "$LOG_FILE") 2>&1

# Source global functions
source ./global_functions.sh

# Exit on any command failure
set -e

# --- Welcome Message ---
log_info "
+--------------------------------+
| Arch Linux Installation Script |
+--------------------------------+
"

log_info "

 █████╗ ██████╗  ██████╗██╗  ██╗██╗██╗  ██╗████████╗███╗   ███╗
██╔══██╗██╔══██╗██╔════╝██║  ██║██║██║  ██║╚══██╔══╝████╗ ████║
███████║██████╔╝██║     ███████║██║███████║   ██║   ██╔████╔██║
██╔══██║██╔══██╗██║     ██╔══██║██║╚════██║   ██║   ██║╚██╔╝██║
██║  ██║██║  ██║╚██████╗██║  ██║███████╗██║   ██║   ██║ ╚═╝ ██║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝   ╚═╝   ╚═╝     ╚═╝
"

sleep 1

# --- User Input ---
get_username
get_user_password
get_root_password
get_hostname
select_timezone
get_disk
get_partition_sizes
get_encryption_password
select_gui
get_grub_theme
get_aur_helper

# --- Export Variables --- 
export USERNAME
export USER_PASSWORD
export ROOT_PASSWORD
export HOSTNAME
export ACTUAL_TIMEZONE=$(select_timezone)
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
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to disk preperation error."
    exit 1
fi

setup_lvm "$DISK" "$ENCRYPTION_PASSWORD"
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to LVM setup error."
    exit 1
fi

# --- Install pacman-contrib reflector rsync python ---
install_prerequisites
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to prerequisite installation error."
    exit 1
fi

# --- Make /etc/pacman.d/mirrorlist.backup and run reflector on /etc/pacman.d/mirrorlist ---
configure_mirrors
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to mirror configuration error."
    exit 1
fi

# --- run pacstrap ---
install_base_packages
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to base package installation error."
    exit 1
fi

# --- Generate FS Tab ---
genfstab -U -p /mnt >> /mnt/etc/fstab

# --- Copy sources to /mnt and make script executable
cp -r ./global_functions.sh ./chroot.sh ./pkgs.lst ./aur_pkgs.lst ./hypr.sh ./Source/arch-glow /mnt
chmod +x /mnt/*.sh

# --- Chroot Setup ---
arch-chroot /mnt /bin/bash -c "LOG_FILE=$LOG_FILE ./chroot.sh"

# --- Cleanup ---
cleanup

# --- Unmount everything ---
umount -R /mnt

# --- Comment ---
log_info "Installation is complete, please reboot system."

log_info "

 █████╗ ██████╗  ██████╗██╗  ██╗██╗██╗  ██╗████████╗███╗   ███╗
██╔══██╗██╔══██╗██╔════╝██║  ██║██║██║  ██║╚══██╔══╝████╗ ████║
███████║██████╔╝██║     ███████║██║███████║   ██║   ██╔████╔██║
██╔══██║██╔══██╗██║     ██╔══██║██║╚════██║   ██║   ██║╚██╔╝██║
██║  ██║██║  ██║╚██████╗██║  ██║███████╗██║   ██║   ██║ ╚═╝ ██║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝   ╚═╝   ╚═╝     ╚═╝
"
