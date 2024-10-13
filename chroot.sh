#!/bin/bash

# Source required functions
source /sources/functions.sh

chroot_and_configure() {
    local root_mount="$1"
    local username="$2"
    local hostname="$3"
    local root_password="$4"
    local gui_choice="$5"

    # Check if the root mount point is valid
    if [ ! -d "$root_mount" ]; then
        log_error "Root mount point $root_mount does not exist." $?
        exit 1
    fi

    # Create a sources directory in the chroot environment
  #  mkdir -p "$root_mount/sources"

    # Copy necessary configuration scripts to the sources directory
  #  cp /sources/config.sh /sources/pkglist.txt /sources/functions.sh /sources/aur.sh "$root_mount/sources/"
    
    # Chroot into the new system
    log_output "Chrooting into the new system at $root_mount"
    arch-chroot "$root_mount" /bin/bash <<EOF
        # Source the required files
        source /sources/functions.sh
        source /sources/config.sh
        source /sources/chroot.sh
        source /sources/pkgs.sh
        source /sources/pkglst.txt
        source /sources/aur.sh

        # --- System Configuration ---
        configure_pacman
        install_microcode
        enable_services
        set_locale
        update_initramfs
        create_user "$username"
        set_passwords "$root_password"  # Assuming ROOT_PASSWORD is passed in
        set_hostname "$hostname"
        update_sudoers
        install_grub
        configure_grub
        install_nvidia_drivers

        # --- GUI Installation ---
        install_gui() {
            if [[ "$GUI_CHOICE" == "gnome" ]]; then
                log_output "Installing GNOME desktop environment..."
                if ! pacman -S --noconfirm --needed gnome gnome-extra gnome-tweaks gnome-shell-extensions gnome-browser-connector firefox; then
                    log_error "Failed to install GNOME packages" \$?
                    exit 1
                fi
                if ! systemctl enable gdm.service; then
                    log_error "Failed to enable gdm service" \$?
                    exit 1
                fi
                log_output "GNOME installed and gdm enabled."
            elif [[ "$GUI_CHOICE" == "kde" ]]; then
                log_output "Installing KDE Plasma desktop environment..."
                if ! pacman -S --noconfirm --needed xorg plasma-desktop sddm kde-applications dolphin firefox lxappearance; then
                    log_error "Failed to install KDE Plasma packages" \$?
                    exit 1
                fi
                if ! systemctl enable sddm.service; then
                    log_error "Failed to enable sddm service" \$?
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

        # --- Cleanup and Reboot ---
        cleanup

        echo -ne "\n
         █████╗ ██████╗  ██████╗██╗  ██╗██╗██╗  ██╗████████╗███╗   ███╗
        ██╔══██╗██╔══██╗██╔════╝██║  ██║██║██║  ██║╚══██╔══╝████╗ ████║
        ███████║██████╔╝██║     ███████║██║███████║   ██║   ██╔████╔██║
        ██╔══██║██╔══██╗██║     ██╔══██║██║╚════██║   ██║   ██║╚██╔╝██║
        ██║  ██║██║  ██║╚██████╗██║  ██║███████╗██║   ██║   ██║ ╚═╝ ██║
        ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝   ╚═╝   ╚═╝     ╚═╝
                                                               
        "
EOF

    # Exit chroot
    log_output "Configuration complete. Exiting chroot."
}

# Call the function with arguments passed to this script
chroot_and_configure "$@"
