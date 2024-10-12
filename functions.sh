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

# ... (add log_debug, log_info, log_warning if needed) ...


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
    if [[ "$confirm" == "y" ]]; then  # Check for explicit "y"
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

# --- AUR Helper Installation ---

install_aur_helper() {
    log_output "Installing AUR helper..."

    # Ask the user if they want to install an AUR helper
    if ! confirm_action "Do you want to install an AUR helper?"; then
        log_output "Skipping AUR helper installation."
        return 0
    fi

    # Ask the user which AUR helper they want
    options=("yay" "paru")
    select aur_helper in "${options[@]}"; do
        case "$aur_helper" in
            yay)
                AUR_HELPER="yay"
                log_output "yay selected."
                ;;
            paru)
                AUR_HELPER="paru"
                log_output "paru selected."
                ;;
            *)
                log_output "Invalid option. Skipping AUR helper installation."
                return 1
                ;;
        esac
        break
    done

    # Install the selected AUR helper
    if ! arch-chroot /mnt /bin/bash -c "./aur_helper.sh $AUR_HELPER"; then
        log_error "Failed to install AUR helper" $?
        exit 1
    fi
}
