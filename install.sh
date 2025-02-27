#!/bin/bash

# Define the log file path
LOG_FILE="/var/log/archl4tm.log"

# Create or clear the log file
: > "$LOG_FILE"

# Source global functions
source ./global_functions.sh
source ./log.sh

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
export ACTUAL_TIMEZONE
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
log_info "Disk preparation started for $DISK..."
partition_disk "$DISK" "$EFI_SIZE" "$BOOT_SIZE" || log_error "Exiting due to disk preperation error."
log_info "Disk partitioning on $DISK complete."

log_info "Starting LVM setup on $DISK..."
setup_lvm "$DISK" "$ENCRYPTION_PASSWORD" || log_error "Exiting due to LVM setup error."
log_info "LVM setup on $DISK complete."

# --- Install pacman-contrib reflector rsync python ---
log_info "Installing prerequisite packages."
install_prerequisites || log_error "Exiting due to prerequisite installation error."
log_info "Packages installed."

# --- Make /etc/pacman.d/mirrorlist.backup and run reflector on /etc/pacman.d/mirrorlist ---
log_info "Configuring mirrorlist..."
configure_mirrors || log_error "Exiting due to mirror configuration error."
log_info "Mirrorlist configuration successful."

# --- run pacstrap ---
log_info "Starting base system installation..."
install_base_packages || log_error "Exiting due to base package installation error."
log_info "Base system installation successful."

# --- Generate FS Tab ---
log_info "Generating fstab for system mount..."
genfstab -U -p /mnt >> /mnt/etc/fstab

# --- Copy sources to /mnt and make script executable
log_info "Copying resources for chroot..."
cp -r ./log.sh ./global_functions.sh ./chroot.sh ./pkgs.lst ./aur_pkgs.lst ./Source/arch-glow /mnt
chmod +x /mnt/*.sh

# --- Chroot Setup ---
log_info "Entering chroot environment..."
arch-chroot /mnt /bin/bash -c "LOG_FILE=$LOG_FILE ./chroot.sh"
log_info "Chroot setup complete."

# --- Cleanup ---
log_info "Cleaning up..."
cleanup

# --- Unmount everything ---
log_info "Umounting everything..."
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
