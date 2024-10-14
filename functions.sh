#!/bin/bash

# --- Logging Functions ---

log_output() {
    local message="$1"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $message"
}

log_error() {
    local message="$1"
    local err_code="$2"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Error: $message (exit code: $err_code)" >&2
}

log_debug() {
    local message="$1"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Debug: $message" >&2
}

log_info() {
    local message="$1"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Info: $message"
}

log_warning() {
    local message="$1"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Warning: $message" >&2
}

# --- Input Validation Functions ---

validate_username() {
    local username="$1"
    if [[ "${username,,}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]; then
        return 0  # True
    else
        log_error "Invalid username: $username" 1  # Log the error here
        return 1  # False
    fi
}

validate_hostname() {
    local hostname="$1"
    if [[ "${hostname,,}" =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]]; then
        return 0  # True
    else
        log_error "Invalid hostname: $hostname" 1  # Log the error here
        return 1  # False
    fi
}

validate_disk() {
    local disk="$1"
    if [ -b "$disk" ]; then 
        return 0  # True
    else
        log_error "Invalid disk path: $disk" 1  # Log the error here
        return 1  # False
    fi
}

# --- Confirmation Function ---

confirm_action() {
    local message="$1"
    read -r -p "$message (Y/n) " confirm
    confirm=${confirm,,}  # Convert to lowercase

    # Check if confirm is "y" or empty
    if [[ "$confirm" == "y" ]] || [[ -z "$confirm" ]]; then  
        return 0  # True
    else
        return 1  # False
    fi
}

# --- User Input Functions ---

get_username() {
    while true; do
        read -r -p "Enter a username: " username

        if ! validate_username "$username"; then
            continue  # No need to log here, validate_username already logs
        fi

        export USERNAME="$username"
        log_output "Username set to: $USERNAME"
        break
    done
}

get_user_password() { # Renamed to avoid conflict with the existing get_password function
    while true; do
        read -rs -p "Set a password for $USERNAME: " USER_PASSWORD1
        echo
        read -rs -p "Confirm password: " USER_PASSWORD2
        echo

        if [[ "$USER_PASSWORD1" != "$USER_PASSWORD2" ]]; then
            log_error "Passwords do not match." 1
            continue
        fi

        export USER_PASSWORD="$USER_PASSWORD1"
        log_output "Password set for $USERNAME successfully."
        break
    done
}

get_root_password() {
    while true; do
        read -rs -p "Set root password: " ROOT_PASSWORD1
        echo
        read -rs -p "Confirm root password: " ROOT_PASSWORD2
        echo

        if [[ "$ROOT_PASSWORD1" != "$ROOT_PASSWORD2" ]]; then
            log_error "Passwords do not match." 1
            continue
        fi

        export ROOT_PASSWORD="$ROOT_PASSWORD1"
        log_output "Root password set successfully."
        break
    done
}

get_hostname() {
    while true; do
        read -r -p "Enter a hostname: " hostname

        if ! validate_hostname "$hostname"; then
            continue
        fi

        export HOSTNAME="$hostname"
        log_output "Hostname set to: $HOSTNAME"
        break
    done
}

# --- AUR Helper Functions ---

get_aur_helper() {
    log_output "Selecting AUR helper..."

    # Ask the user if they want to install an AUR helper
    if ! confirm_action "Do you want to install an AUR helper?"; then
        log_output "Skipping AUR helper installation."
        export AUR_HELPER="none"
        return 0
    fi

    # Ask the user which AUR helper they want
    options=("paru" "yay" "none")
    select aur_helper in "${options[@]}"; do
        case "$aur_helper" in
            paru)
                export AUR_HELPER="paru"
                log_output "paru selected."
                ;;
            yay)
                export AUR_HELPER="yay"
                log_output "yay selected."
                ;;
            none)
                export AUR_HELPER="none"
                log_output "No AUR helper selected."
                ;;    
            *)
                log_output "Invalid option. Skipping AUR helper installation."
                export AUR_HELPER="none" 
                return 1
                ;;
            esac
            break
        done
    }

install_aur_helper() {
    log_output "Installing AUR helper..."

    # Create a temporary user
    if ! useradd -m -G wheel -s /bin/bash tempuser; then
        log_error "Failed to create temporary user" $?
        return 1
    fi

    # Generate and set a random password for the temporary user
    if ! head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '' | passwd tempuser --stdin; then
        log_error "Failed to set password for temporary user" $?
        return 1
    fi

    # Switch to the temporary user
    su tempuser <<EOF

    # Install git if not already installed
    if ! pacman -Qi git &> /dev/null; then
        if ! sudo pacman -S --noconfirm git; then
            log_error "Failed to install git" $?
            exit 1
        fi
    fi

    # Install the chosen AUR helper
    if [[ "$AUR_HELPER" == "yay" ]]; then
        if ! git clone https://aur.archlinux.org/yay.git; then
            log_error "Failed to clone yay repository" $?
            exit 1
        fi
        cd yay
        if ! makepkg -si --noconfirm; then
            log_error "Failed to build and install yay" $?
            exit 1
        fi
        cd ..
        rm -rf yay
    elif [[ "$AUR_HELPER" == "paru" ]]; then
        if ! git clone https://aur.archlinux.org/paru.git; then
            log_error "Failed to clone paru repository" $?
            exit 1
        fi
        cd paru
        if ! makepkg -si --noconfirm; then
            log_error "Failed to build and install paru" $?
            exit 1
        fi
        cd ..
        rm -rf paru
    fi

EOF

    # Switch back to root and remove the temporary user
    if ! userdel -r tempuser; then
        log_error "Failed to remove temporary user" $?
        return 1
    fi

    log_output "AUR helper installed."
}

# --- Cleanup Function ---

cleanup() {
    log_output "Cleaning up..."

    # Remove temporary files and directories created during the installation
    rm -rf /mnt/source
    rm -rf /mnt/chroot-setup.sh

    # Copy log files to the installed system
    cp /var/log/arch_install.log /mnt/var/log/arch_install.log
    cp /var/log/arch_install_error.log /mnt/var/log/arch_install_error.log
}
