#!/bin/bash

### Chroot Setup ###

# --- Sources ---
source ./global_functions.sh

# --- Pacman Configuration ---
configure_pacman

# --- Install microcode ---
install_microcode 

# --- Install Additional Packages ---
install_additional_packages

# --- Enable services --- 
enable_services

# --- Essential System Setup ---
set_locale
update_initramfs

# --- User and Hostname Configuration ---
create_user "$USERNAME"
set_passwords "$USERNAME" "$USER_PASSWORD" "$ROOT_PASSWORD"
set_hostname "$HOSTNAME"
update_sudoers

# --- Bootloader ---
install_grub
configure_grub "$DISK"

# --- Install NVIDA drivers if GPU found ---
install_nvidia_drivers

# --- GUI Installation ---
install_gui "$GUI_CHOICE"

# --- AUR Installation ---
install_aur_helper "$AUR_HELPER"

# --- Exit Chroot ---
echo "Done"
exit

### END ###
