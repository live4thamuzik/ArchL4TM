#!/bin/bash

# Exit on any command failure
set -e

# Source functions
source /source/config.sh  # Source your config.sh script from /source

# Get disk from argument
DISK="$1"

# --- System Configuration ---

configure_pacman
install_microcode
enable_services
set_locale
update_initramfs
create_user "$USERNAME"  # Make sure USERNAME is exported
set_passwords  # Make sure ROOT_PASSWORD and USER_PASSWORD are exported
set_hostname "$HOSTNAME"  # Make sure HOSTNAME is exported
update_sudoers
install_grub
configure_grub  # Make sure DISK is exported
install_nvidia_drivers  # Make sure DISK is exported

# --- System Configuration ---

configure_pacman
install_microcode
enable_services
set_locale
update_initramfs
create_user "$USERNAME"
set_passwords  # Assuming ROOT_PASSWORD is set in get_password
set_hostname "$HOSTNAME"
update_sudoers
install_grub
configure_grub
install_nvidia_drivers

# --- GUI Installation ---

install_gui() {
    if [[ "$GUI_CHOICE" == "gnome" ]]; then
        log_output "Installing GNOME desktop environment..."
        if ! pacman -S --noconfirm --needed gnome gnome-extra gnome-tweaks gnome-shell-extensions gnome-browser-connector firefox; then
            log_error "Failed to install GNOME packages" $?
            exit 1
        fi
        if ! systemctl enable gdm.service; then
            log_error "Failed to enable gdm service" $?
            exit 1
        fi
        log_output "GNOME installed and gdm enabled."
    elif [[ "$GUI_CHOICE" == "kde" ]]; then
        log_output "Installing KDE Plasma desktop environment..."
        if ! pacman -S --noconfirm --needed xorg plasma-desktop sddm kde-applications dolphin firefox lxappearance; then
            log_error "Failed to install KDE Plasma packages" $?
            exit 1
        fi
        if ! systemctl enable sddm.service; then
            log_error "Failed to enable sddm service" $?
            exit 1
        fi
        log_output "KDE Plasma installed and sddm enabled."
    else
        log_output "No GUI selected. Skipping GUI installation."
    fi
}

install_gui

# --- AUR Installation ---

install_aur_helper