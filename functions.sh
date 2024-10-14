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
    options=("yay" "paru")
    select aur_helper in "${options[@]}"; do
        case "$aur_helper" in
            yay)
                export AUR_HELPER="yay"
                log_output "yay selected."
                ;;
            paru)
                export AUR_HELPER="paru"
                log_output "paru selected."
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
    useradd -m -G wheel -s /bin/bash tempuser

    # Generate and set a random password for the temporary user
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '' | passwd tempuser --stdin

    # Switch to the temporary user
    su tempuser <<EOF

    # Install git if not already installed
    if ! pacman -Qi git &> /dev/null; then
        sudo pacman -S --noconfirm git
    fi

    # Install the chosen AUR helper (example with yay)
    if [[ "$AUR_HELPER" == "yay" ]]; then
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ..
        rm -rf yay
    elif [[ "$AUR_HELPER" == "paru" ]]; then
        git clone https://aur.archlinux.org/paru.git
        cd paru
        makepkg -si --noconfirm
        cd ..
        rm -rf paru
    # Add more AUR helper options here if needed
    fi

EOF

    # Switch back to root and remove the temporary user
    userdel -r tempuser

    log_output "AUR helper installed."
}

# --- Cleanup Function ---

cleanup() {
    log_output "Cleaning up..."
    if ! rm -rf /mnt/source || \
       ! rm -rf /mnt/chroot-setup.sh; then
        log_error "Failed to remove chroot-setup.sh" $?
    fi

    if ! cp /var/log/arch_install.log /mnt/var/log/arch_install.log || \
       ! cp /var/log/arch_install_error.log /mnt/var/log/arch_install_error.log; then
        log_warning "Failed to copy log files to the installed system" $?
        # Do not exit here, as this is not a critical step
    fi
}
