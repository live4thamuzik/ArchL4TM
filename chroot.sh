#!/bin/bash

### Chroot Setup ###

# --- Sources ---
source ./global_functions.sh

# Ensure LOG_FILE is set; if not, set to default
LOG_FILE="${LOG_FILE:-/var/log/archl4tm.log}"

# Redirect all output to the log file
exec > >(tee -a "$LOG_FILE") 2>&1

# --- Pacman Configuration ---
log_info "Starting pacman configuration..."
configure_pacman || { log_error "Exiting due to pacman configuration error."; exit 1; }
log_info "Pacman configuration complete."

# --- Install microcode ---
log_info "Starting microcode installation..."
install_microcode || { log_error "Exiting due to microcode installation error."; exit 1; }
log_info "Microcode installation complete."

# --- Install Additional Packages ---
log_info "Starting additional package installation..."
install_additional_packages || { log_error "Exiting due to additional package installation error."; exit 1; }
log_info "Additional packages installed."

# --- Enable services --- 
log_info "Enabling necessary services..."
enable_services || { log_error "Exiting due to service enabling error."; exit 1; }
log_info "Services enabled."

# --- Essential System Setup ---
log_info "Setting locale..."
set_locale || { log_error "Exiting due to locale setting error."; exit 1; }
log_info "Locale set."

# --- Set Timezone ---
log_info "Setting timezone to $ACTUAL_TIMEZONE..."
set_timezone "$ACTUAL_TIMEZONE" || { log_error "Exiting due to timezone setting error."; exit 1; }
log_info "Timezone set."

# --- Update mkinitcpio.conf ---
log_info "Updating mkinitcpio.conf..."
update_initramfs || { log_error "Exiting due to initramfs update error."; exit 1; }
log_info "Initramfs updated."

# --- User and Hostname Configuration ---
log_info "Creating user $USERNAME..."
create_user "$USERNAME" || { log_error "Exiting due to user creation error."; exit 1; }
log_info "User $USERNAME created."

log_info "Setting passwords..."
set_passwords "$USERNAME" "$USER_PASSWORD" "$ROOT_PASSWORD" || { log_error "Exiting due to password setting error."; exit 1; }
log_info "Passwords set."

log_info "Setting hostname to $HOSTNAME..."
set_hostname "$HOSTNAME" || { log_error "Exiting due to hostname setting error."; exit 1; }
log_info "Hostname set."

log_info "Updating sudoers..."
update_sudoers || { log_error "Exiting due to sudoers update error."; exit 1; }
log_info "Sudoers updated."

# --- Bootloader ---
log_info "Installing GRUB bootloader..."
install_grub || { log_error "Exiting due to GRUB installation error."; exit 1; }
log_info "GRUB installed."

log_info "Installing GRUB theme: $GRUB_THEME..."
install_grub_themes "$GRUB_THEME" || { log_error "Exiting due to GRUB theme installation error."; exit 1; }
log_info "GRUB theme installed."

log_info "Configuring GRUB on $DISK..."
configure_grub "$DISK" || { log_error "Exiting due to GRUB configuration error."; exit 1; }
log_info "GRUB configured."

# --- Install GPU drivers if found ---
log_info "Checking for GPU drivers..."
install_gpu_drivers || { log_error "Exiting due to GPU driver installation error."; exit 1; }
log_info "GPU drivers installed."

# --- Set plymouth splash screen ---
log_info "Setting plymouth splash screen..."
mv ./arch-glow /usr/share/plymouth/themes
plymouth-set-default-theme -R arch-glow || { log_error "Exiting due to plymouth splash screen setup error."; exit 1; }
log_info "Plymouth splash screen set."

# --- AUR Installation ---
log_info "Installing AUR helper: $AUR_HELPER..."
install_aur_helper "$AUR_HELPER" || { log_error "Exiting due to AUR helper installation error."; exit 1; }
log_info "AUR helper installed."

# --- Install AUR Packages ---
log_info "Installing AUR packages..."
install_aur_pkgs || { log_error "Exiting due to AUR package installation error."; exit 1; }
log_info "AUR packages installed."

# --- Enable numlock on boot ---
log_info "Enabling numlock on boot..."
numlock_auto_on || { log_error "Exiting due to numlock auto-on setup error."; exit 1; }
log_info "Numlock enabled."

# --- GUI Installation ---
log_info "Starting GUI installation..."
install_gui "$GUI_CHOICE" || { log_error "Exiting due to GUI installation error."; exit 1; }
log_info "GUI installation complete."

# --- Exit Chroot ---
log_info "Exiting chroot environment..."
exit

### END ###
