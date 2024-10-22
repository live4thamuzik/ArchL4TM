#!/bin/bash

### Chroot Setup ###
set -x

# --- Enter Chroot ---
arch-chroot /mnt /bin/bash

# --- Sources ---
source /global_functions.sh

# --- Pacman Configuration ---
echo -ne "Configuring pacman"
configure_pacman

echo -ne "Installing microcode"
install_microcode 

# --- Install Additional Packages ---
echo -ne "Installing packages"
install_additional_packages

# --- Enable services --- 
echo -ne "Enabling services"
enable_services

# --- Essential System Setup ---
echo -ne "Setting locale"
set_locale

echo -ne "Update intiramfs"
update_initramfs

# --- User and Hostname Configuration ---
echo -ne "Creating user"
create_user "$USERNAME"

echo -ne "Setting passwords"
set_passwords "$USERNAME" "$USER_PASSWORD" "$ROOT_PASSWORD"

echo -ne "Setting hostname"
set_hostname "$HOSTNAME"

echo -ne "Updating Sudoers"
update_sudoers

# --- Bootloader ---
echo -ne "Installing GRUB"
install_grub

echo -ne "Configuring GRUB"
configure_grub "$DISK"

echo -ne "Looking for NVIDIA GPU, DKMS drivers will be installed if GPU found."
install_nvidia_drivers

# --- GUI Installation ---
echo -ne "Installing Desktop/Server Environment"
install_gui "$GUI_CHOICE"

# --- AUR Installation ---
echo -ne "Installing AUR"
install_aur_helper "$AUR_HELPER"

# --- Exit Chroot ---
echo -ne "Done"
exit

### END ###
