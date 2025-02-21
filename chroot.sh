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
install_grub_themes "$GRUB_THEME"
configure_grub "$DISK"

# --- Install NVIDA drivers if GPU found ---
install_amd_gpu_drivers
install_nvidia_drivers

# --- Set plymouth splash screen ---
mv ./arch-glow /usr/share/plymouth/themes
plymouth-set-default-theme -R arch-glow

# --- AUR Installation ---
install_aur_helper "$AUR_HELPER"

# --- Install AUR Packages ---
install_aur_pkgs

# --- Enable numlock on boot ---
numlock_auto_on

# --- GUI Installation ---
install_gui "$GUI_CHOICE"

# --- Exit Chroot ---
echo "Done"
exit

### END ###
