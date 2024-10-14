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
#get_aur_helper

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

        display_page "$start" "$end"

        # Prompt user for selection or continue
        read -p "Enter the number of your timezone choice from this page, or press Enter to see more timezones: " choice

        # Check if user made a choice
        if [[ "$choice" =~ ^[0-9]+$ ]]; then 
            if ((choice >= 1 && choice <= total_timezones)); then 
                # Extract the selected timezone
                selected_timezone=$(echo "${timezones[$((choice-1))]}" | awk '{print $2}')

                # Set timezone
                ln -sf /usr/share/zoneinfo/"$selected_timezone" /etc/localtime

                # Verify timezone setting
                log_output "Timezone has been set to $(readlink -f /etc/localtime)"
                break  # Exit the loop if a valid selection is made
            else
                echo "Invalid selection. Please enter a valid number from the displayed list."
            fi
        elif [[ -z "$choice" ]]; then  # User pressed Enter, go to the next page
            if ((end == total_timezones)); then  # If this is the last page, loop back to the beginning
                current_page=0
            else
                current_page=$((current_page + 1))
            fi
        else
            echo "Invalid input. Please enter a number or press Enter to continue."
        fi
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

#select_gui

# --- Installation Steps ---

log_info "Starting installation process..."

partition_disk "$DISK" "$EFI_SIZE" "$BOOT_SIZE"
setup_lvm "$DISK" "$ENCRYPTION_PASSWORD"

install_prerequisites
configure_mirrors
install_base_packages

genfstab -U -p /mnt >> /mnt/etc/fstab

chroot_and_configure() {
    log_output "Entering chroot and configuring system..."

    # Create a source directory in the chroot
    mkdir -p /mnt/source

    # Copy all scripts and package list to the source directory
    cp *.sh /mnt/source/
    cp pkglst.txt /mnt/source/

    # Make scripts executable
    chmod +x /mnt/source/*.sh 

    if ! arch-chroot /mnt /bin/bash -c "cd /source && ./chroot-setup.sh '$hostname' '$username' '$userpass' '$rootpass' '$encpass'"; then
        log_error "Failed to run chroot configuration" $?
        exit 1
    fi
}

chroot_and_configure

# --- Cleanup ---

cleanup

echo -ne "

 █████╗ ██████╗  ██████╗██╗  ██╗██╗██╗  ██╗████████╗███╗   ███╗
██╔══██╗██╔══██╗██╔════╝██║  ██║██║██║  ██║╚══██╔══╝████╗ ████║
███████║██████╔╝██║     ███████║██║███████║   ██║   ██╔████╔██║
██╔══██║██╔══██╗██║     ██╔══██║██║╚════██║   ██║   ██║╚██╔╝██║
██║  ██║██║  ██║╚██████╗██║  ██║███████╗██║   ██║   ██║ ╚═╝ ██║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝   ╚═╝   ╚═╝     ╚═╝
                                                               
"
