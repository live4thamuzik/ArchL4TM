#!/bin/bash

source functions.sh

aur_helper="$1"

case "$aur_helper" in
    yay)
        log_output "Installing yay..."
        if ! pacman -Sy --noconfirm --needed base-devel git go || \
           ! runuser -u nobody git clone https://aur.archlinux.org/yay.git /tmp/yay || \
           ! chown nobody:nobody /tmp/yay || \
           ! cd /tmp/yay || \
           ! runuser -u nobody makepkg -si --noconfirm || \
           ! rm -rf /tmp/yay; then
            log_error "Failed to install yay" $?
            exit 1
        fi
        ;;
    paru)
        log_output "Installing paru..."
        if ! pacman -Sy --noconfirm --needed base-devel git rust cargo || \
           ! runuser -u nobody git clone https://aur.archlinux.org/paru.git /tmp/paru || \
           ! chown nobody:nobody /tmp/paru || \
           ! cd /tmp/paru || \
           ! runuser -u nobody makepkg -si --noconfirm || \
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
