#!/bin/bash

# Exit on any command failure
set -e

# Log all output to separate log files with timestamps
exec > >(tee -a /var/log/arch_install.log) 2> >(tee -a /var/log/arch_install_error.log >&2)

# --- Welcome Message ---
echo -ne "
+--------------------------------+
| Arch Linux Installation Script |
+--------------------------------+
"

echo -ne "

 █████╗ ██████╗  ██████╗██╗  ██╗██╗██╗  ██╗████████╗███╗   ███╗
██╔══██╗██╔══██╗██╔════╝██║  ██║██║██║  ██║╚══██╔══╝████╗ ████║
███████║██████╔╝██║     ███████║██║███████║   ██║   ██╔████╔██║
██╔══██║██╔══██╗██║     ██╔══██║██║╚════██║   ██║   ██║╚██╔╝██║
██║  ██║██║  ██║╚██████╗██║  ██║███████╗██║   ██║   ██║ ╚═╝ ██║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝   ╚═╝   ╚═╝     ╚═╝
                                                               
"

# --- Source Functions ---
source functions.sh
source disk_setup.sh
source pkgs.sh
source config.sh

# --- User Input ---

get_username
get_user_password
get_root_password
get_hostname
get_disk
get_partition_sizes
get_encryption_password
get_aur_helper

# --- Timezone Selection ---

setup_timezone() {
    log_output "Setting up timezone..."

    # Function to get a list of timezones
    get_timezones() {
        local count=1
        find /usr/share/zoneinfo -type f | sed 's|/usr/share/zoneinfo/||' | awk -v cnt=$count '{print cnt". "$0; cnt++}'
    }

    # Collect timezones into an array
    mapfile -t timezones < <(get_timezones)

    # Check if timezones were collected
    if [ ${#timezones[@]} -eq 0 ]; then
        log_error "No timezones found. Please check the timezone directory and try again." 1
        exit 1
    fi

    # Constants
    PAGE_SIZE=40
    COLS=1  # Number of columns to display
    NUMBER_WIDTH=4  # Width for number and dot
    COLUMN_WIDTH=2  # Width of each column for timezones

    # Function to display a page of timezones in columns
    display_page() {
    local start=$1
    local end=$2  # Corrected this line
    local count=0

    echo "Timezones ($((start + 1)) to $end of ${#timezones[@]}):"

    for ((i=start; i<end; i++)); do
        # Print timezones in columns with minimized gap
        printf "%-${NUMBER_WIDTH}s%-${COLUMN_WIDTH}s" "${timezones[$i]}" ""
        count=$((count + 1))

        if ((count % COLS == 0)); then
            echo
        fi
    done
    
}

# Display pages of timezones
    total_timezones=${#timezones[@]} 
    current_page=0

    while true; do
        start=$((current_page * PAGE_SIZE))
        end=$((start + PAGE_SIZE))
        if ((end > total_timezones)); then
            end=$total_timezones
        fi

        display_page "$start" "$end"  # Pass arguments with double quotes

        # ... (rest of the while loop remains the same) ...
    done
}

setup_timezone

# --- GUI Selection ---

select_gui() {
    log_output "Selecting GUI..."

    options=("Server (No GUI)" "GNOME" "KDE Plasma")
    select gui_choice in "${options[@]}"; do
        case "$gui_choice" in
            "GNOME")
                export GUI_CHOICE="gnome"
                log_output "GNOME selected."
                ;;
            "KDE Plasma")
                export GUI_CHOICE="kde"
                log_output "KDE Plasma selected."
                ;;
            *)
                export GUI_CHOICE="none"
                log_output "No GUI selected."
                ;;
        esac
        break
    done
}

select_gui

# --- Installation Steps ---

log_info "Starting installation process..."

partition_disk "$DISK" "$EFI_SIZE" "$BOOT_SIZE"
setup_lvm "$DISK" "$ENCRYPTION_PASSWORD"

install_prerequisites
configure_mirrors
install_base_packages
generate_fstab

chroot_and_configure

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

# --- Cleanup and Reboot ---

cleanup

echo -ne "

 █████╗ ██████╗  ██████╗██╗  ██╗██╗██╗  ██╗████████╗███╗   ███╗
██╔══██╗██╔══██╗██╔════╝██║  ██║██║██║  ██║╚══██╔══╝████╗ ████║
███████║██████╔╝██║     ███████║██║███████║   ██║   ██╔████╔██║
██╔══██║██╔══██╗██║     ██╔══██║██║╚════██║   ██║   ██║╚██╔╝██║
██║  ██║██║  ██║╚██████╗██║  ██║███████╗██║   ██║   ██║ ╚═╝ ██║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝   ╚═╝   ╚═╝     ╚═╝
                                                               
"
