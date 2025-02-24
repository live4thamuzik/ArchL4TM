#!/bin/bash

### Chroot Setup ###

# --- Sources ---
source ./global_functions.sh

# Check if LOG_FILE is set; if not, set a default
LOG_FILE="${LOG_FILE:-/var/log/arch_install.log}"

# Redirect all output to the log file
exec > >(tee -a "$LOG_FILE") 2>&1

# --- Pacman Configuration ---
configure_pacman
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to pacman configuration error."
    exit 1
fi

# --- Install microcode ---
install_microcode 
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to microcode installation error."
    exit 1
fi

# --- Install Additional Packages ---
install_additional_packages
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to additional package installation error."
    exit 1
fi

# --- Enable services --- 
enable_services
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to service enabling error."
    exit 1
fi

# --- Essential System Setup ---
set_locale
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to locale setting error."
    exit 1
fi

# --- Set Timezone ---
set_timezone "$ACTUAL_TIMEZONE"
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to timezone setting error."
    exit 1
fi

update_initramfs
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to initramfs update error."
    exit 1
fi

# --- User and Hostname Configuration ---
create_user "$USERNAME"
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to user creation error."
    exit 1
fi

set_passwords "$USERNAME" "$USER_PASSWORD" "$ROOT_PASSWORD"
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to password setting error."
    exit 1
fi

set_hostname "$HOSTNAME"
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to hostname setting error."
    exit 1
fi

update_sudoers
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to sudoers update error."
    exit 1
fi

# --- Bootloader ---
install_grub
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to GRUB installation error."
    exit 1
fi

install_grub_themes "$GRUB_THEME"
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to GRUB theme installation error."
    exit 1
fi

configure_grub "$DISK"
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to GRUB configuration error."
    exit 1
fi

# --- Install AMD or NVIDIA GPU drivers if found ---
install_gpu_drivers

# --- Set plymouth splash screen ---
mv ./arch-glow /usr/share/plymouth/themes
plymouth-set-default-theme -R arch-glow

# --- AUR Installation ---
install_aur_helper "$AUR_HELPER"
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to AUR helper installation error."
    exit 1
fi

# --- Install AUR Packages ---
install_aur_pkgs
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to AUR package installation error."
    exit 1
fi

# --- Enable numlock on boot ---
numlock_auto_on
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to numlock auto-on setup error."
    exit 1
fi

# --- GUI Installation ---
install_gui "$GUI_CHOICE"
if [[ $? -ne 0 ]]; then
    log_error "Exiting due to GUI installation error."
    exit 1
fi

# --- Exit Chroot ---
log_info "Done"
exit

### END ###
