#!/bin/bash

# Source global functions
source functions.sh

install_prerequisites() {
    log_output "Installing prerequisite packages..."
    if ! pacman -Sy --noconfirm --needed pacman-contrib reflector rsync; then
        log_error "Failed to install prerequisite packages" $?
        exit 1
    fi
}

configure_mirrors() {
    log_output "Configuring pacman mirrors for faster downloads..."
    if ! cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup || \
       ! reflector -a 48 -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist; then
        log_error "Failed to configure pacman mirrors" $?
        exit 1
    fi
}

install_base_packages() {
    log_output "Installing base packages using pacstrap..."
    if ! pacstrap -K /mnt base linux linux-firmware linux-headers --noconfirm --needed; then
        log_error "Failed to install base packages" $?
        exit 1
    fi
}

install_additional_packages() {
    log_output "Installing additional packages..."
    if ! pacman -S --noconfirm --needed - < package-list.txt; then 
        log_error "Failed to install additional packages" $?
        exit 1
    fi
}
