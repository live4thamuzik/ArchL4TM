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
source packages.sh
source config.sh

# --- User Input ---

get_username
get_user_password
get_root_password
get_hostname
get_disk
get_partition_sizes
get_encryption_password

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
        local end=<span class="math-inline">2
local count\=0
echo "Timezones \(</span>((start + 1)) to $end of <span class="math-inline">\{\#timezones\[@\]\}\)\:"
for \(\(i\=start; i<end; i\+\+\)\); do
\# Print timezones in columns with minimized gap
printf "%\-</span>{NUMBER_WIDTH}s%-<span class="math-inline">\{COLUMN\_WIDTH\}s" "</span>{timezones[<span class="math-inline">i\]\}" ""
count\=</span>((count + 1))

            if ((count % COLS == 0)); then
                echo
            fi
        done

        # Add a newline at the end if the last line isn't fully filled
        if ((count % COLS != 0)); then
            echo
        fi
    }

    # Display pages of timezones
    total_timezones=<span class="math-inline">\{\#timezones\[@\]\}
current\_page\=0
while true; do
start\=</span>((current_page * PAGE_SIZE))
        end=$((start + PAGE_SIZE))
        if ((end > total_timezones)); then
            end=$total_timezones
        fi

        display_page $start $end

        # Prompt user for selection or continue
        echo -ne "Enter the number of your timezone choice from this page, or press Enter to see more timezones: "
        read -r choice

        # Check if user made a choice
        if [[ "<span class="math-inline">choice" \=\~ ^\[0\-9\]\+</span> ]]; then
            if [[ "$choice" -ge 1 && "$choice" -le <span class="math-inline">total\_timezones \]\]; then
\# Extract the selected timezone
selected\_timezone\=</span>(echo "<span class="math-inline">\{timezones\[</span>((choice-1))]}" | awk '{print $2}')

                # Set timezone
                ln -sf /usr/share/zoneinfo/"$selected_timezone" /etc/localtime

                # Verify timezone setting
                log_output "Timezone has been set to $(readlink -f /etc/localtime)"
                break
            else
                echo "Invalid selection. Please enter a valid number from the displayed list."
            fi
        elif [[ -z "<span class="math-inline">choice" \]\]; then
\# Continue to the next page
if \(\(end \=\= total\_timezones\)\); then
echo "No more timezones to display\."
break
fi
current\_page\=</span>((current_page + 1))
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

select_gui

# --- AUR Helper Installation ---

install_aur_helper

# --- Installation Steps ---

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
