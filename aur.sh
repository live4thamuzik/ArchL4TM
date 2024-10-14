#!/bin/bash

source ./functions.sh  # Source functions.sh from the current directory

aur_helper="$1"

# Create a temporary directory
temp_dir=$(mktemp -d)

case "$aur_helper" in
    yay)
        log_output "Installing yay..."
        if ! pacman -Sy --noconfirm --needed base-devel git go || \
           ! runuser -u nobody git clone https://aur.archlinux.org/yay.git "$temp_dir/yay" || \
           ! chown nobody:nobody "$temp_dir/yay" || \
           ! cd "$temp_dir/yay" || \
           ! runuser -u nobody makepkg -si --noconfirm || \
           ! rm -rf "$temp_dir"; then
            log_error "Failed to install yay" $?
            exit 1
        fi
        ;;
    paru)
        log_output "Installing paru..."
        if ! pacman -Sy --noconfirm --needed base-devel git rust cargo || \
           ! runuser -u nobody git clone https://aur.archlinux.org/paru.git "$temp_dir/paru" || \
           ! chown nobody:nobody "$temp_dir/paru" || \
           ! cd "$temp_dir/paru" || \
           ! runuser -u nobody makepkg -si --noconfirm || \
           ! rm -rf "$temp_dir"; then
            log_error "Failed to install paru" $?
            exit 1
        fi
        ;;
    *)
        log_error "Invalid AUR helper specified" 1
        exit 1
        ;;
esac
