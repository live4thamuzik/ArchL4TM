#!/bin/bash

### Chroot Setup ###

# --- Enter Chroot ---
arch-chroot /mnt /bin/bash

# --- Sources ---
source /global_functions.sh

# --- Pacman Configuration ---
echo "Configuring pacman"
configure_pacman

echo "Installing microcode"
install_microcode 

# --- Install Additional Packages ---
echo "Installing packages"
install_additional_packages

# --- Enable services --- 
echo "Enabling services"
enable_services

# --- Essential System Setup ---
echo "Setting locale"
set_locale

echo "Update intiramfs"
update_initramfs

# --- User and Hostname Configuration ---
echo "Creating user"
create_user "$USERNAME"

echo "Setting passwords"
set_passwords "$USERNAME" "$USER_PASSWORD" "$ROOT_PASSWORD"

echo "Setting hostname"
set_hostname "$HOSTNAME"

echo "Updating Sudoers"
update_sudoers

# --- Bootloader ---
echo "Installing GRUB"
install_grub

echo "Configuring GRUB"
configure_grub "$DISK"

echo "Looking for NVIDIA GPU, DKMS drivers will be installed if GPU found."
install_nvidia_drivers

# --- GUI Installation ---
echo "Installing Desktop/Server Environment"
install_gui "$GUI_CHOICE"

# --- AUR Installation ---
echo "Installing AUR"
install_aur_helper "$AUR_HELPER"

# --- Exit Chroot ---
echo "Done"
exit

### END ###
