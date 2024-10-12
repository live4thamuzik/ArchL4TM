#!/bin/bash

# Source global functions (if needed)
# source functions.sh  # Uncomment if you need logging functions

aur_helper="$1"

case "$aur_helper" in
    yay)
        log_output "Installing yay..."
        if ! pacman -S --noconfirm --needed base-devel git go || \
           ! git clone https://aur.archlinux.org/yay.git /tmp/yay || \
           ! cd /tmp/yay || \
           ! makepkg -si --noconfirm || \
           ! rm -rf /tmp/yay; then
            log_error "Failed to install yay" $?
            exit 1
        fi
        ;;
    paru)
        log_output "Installing paru..."
        if ! pacman -S --noconfirm --needed base-devel git rust cargo || \
           ! git clone https://aur.archlinux.org/paru.git /tmp/paru || \
           ! cd /tmp/paru || \
           ! makepkg -si --noconfirm || \
           ! rm -rf /tmp/paru; then
            log_error "Failed to install paru" $?
            exit 1
        fi
        ;;
    *)
        log_error "Invalid AUR helper specified" 1
        exit 1
        ;;
esac
