#!/bin/bash

# Source global functions
source functions.sh

configure_pacman() {
    log_output "Configuring pacman..."

    # Example pacman configuration (replace with your actual settings)
    if ! sed -i "/^#Color/c\Color\nILoveCandy" /etc/pacman.conf || \
       ! sed -i "/^#VerbosePkgLists/c\VerbosePkgLists" /etc/pacman.conf || \
       ! sed -i "/^#ParallelDownloads/c\ParallelDownloads = 5" /etc/pacman.conf || \
       ! sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf; then
        log_error "Failed to configure pacman" $?
        exit 1
    fi
}

install_microcode() {
    log_output "Installing microcode..."
    proc_type=$(lscpu | grep -oP '^Vendor ID:\s+\K\w+')
    if [ "$proc_type" = "GenuineIntel" ]; then
        log_output "Installing Intel microcode"
        if ! pacman -Sy --noconfirm --needed intel-ucode; then
            log_error "Failed to install Intel microcode" $?
            exit 1
        fi
    elif [ "$proc_type" = "AuthenticAMD" ]; then
        log_output "Installing AMD microcode"
        if ! pacman -Sy --noconfirm --needed amd-ucode; then
            log_error "Failed to install AMD microcode" $?
            exit 1
        fi
    fi
}

enable_services() {
    log_output "Enabling services..."
    if ! systemctl enable NetworkManager.service || \
       ! systemctl enable fstrim.timer; then
        log_error "Failed to enable services" $?
        exit 1
    fi
}

set_locale() {
    log_output "Setting locale..."
    if ! sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen || \
       ! locale-gen || \
       ! echo 'LANG=en_US.UTF-8' > /etc/locale.conf; then 
        log_error "Failed to set locale" $?
        exit 1
    fi
}

update_initramfs() {
    log_output "Updating initramfs..."
    if ! sed -i 's/^HOOKS\s*=\s*(.*)/HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf || \
       ! mkinitcpio -p linux; then
        log_error "Failed to update initramfs" $?
        exit 1
    fi
}

create_user() {
    local username="$1"
    log_output "Creating user: $username"
    if ! useradd -m -G wheel,power,storage,uucp,network -s /bin/bash "$username"; then
        log_error "Failed to create user" $?
        exit 1
    fi
}

set_passwords() {
    log_output "Setting passwords..."
    # Make sure USERNAME and PASSWORD are exported before calling this function
    if ! echo "$USERNAME:$PASSWORD" | chpasswd || \
       ! echo "root:$ROOT_PASSWORD" | chpasswd; then  # Assuming ROOT_PASSWORD is exported
        log_error "Failed to set passwords" $?
        exit 1
    fi
}

set_hostname() {
    local hostname="$1"
    log_output "Setting hostname: $hostname"
    if ! echo "$hostname" > /etc/hostname; then 
        log_error "Failed to set hostname" $?
        exit 1
    fi
}

update_sudoers() {
    log_output "Updating sudoers..."
    if ! cp /etc/sudoers /etc/sudoers.backup || \
       ! sed -i 's/^# *%wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers || \
       ! echo 'Defaults targetpw' >> /etc/sudoers || \
       ! visudo -c; then
        log_error "Failed to update sudoers" $?
        # Restore backup if visudo fails
        cp /etc/sudoers.backup /etc/sudoers
        exit 1
    fi
}

install_grub() {
    log_output "Installing GRUB..."
    if ! grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck; then
        log_error "Failed to install GRUB" $?
        exit 1
    fi
}

configure_grub() {
    log_output "Configuring GRUB..."

    # Make sure DISK is exported and available in the environment
    if ! sed -i '/^GRUB_DEFAULT=/c\GRUB_DEFAULT=saved' /etc/default/grub || \
       ! sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/c\GRUB_CMDLINE_LINUX_DEFAULT="quiet cryptdevice='"$DISK"'3:volgroup0 loglevel=3"' /etc/default/grub || \
       ! sed -i '/^#GRUB_ENABLE_CRYPTODISK=y/c\GRUB_ENABLE_CRYPTODISK=y' /etc/default/grub || \
       ! sed -i '/^#GRUB_SAVEDEFAULT=true/c\GRUB_SAVEDEFAULT=true' /etc/default/grub || \
       ! cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale.en.mo || \
       ! grub-mkconfig -o /boot/grub/grub.cfg; then
        log_error "Failed to configure GRUB" $?
        exit 1
    fi
}


install_nvidia_drivers() {
    log_output "Detecting NVIDIA GPUs..."

    # Detect NVIDIA GPUs
    readarray -t dGPU < <(lspci -k | grep -E "(VGA|3D)" | grep -i nvidia)

    # Check if any NVIDIA GPUs were found
    if [ ${#dGPU[@]} -gt 0 ]; then
        log_output "NVIDIA GPU(s) detected:"
        for gpu in "${dGPU[@]}"; do
            log_output "  $gpu"
        done

        log_output "Installing NVIDIA drivers..."

        # Install NVIDIA drivers and related packages
        if ! pacman -Sy --noconfirm --needed nvidia libglvnd nvidia-utils opencl-nvidia lib32-libglvnd lib32-nvidia-utils lib32-opencl-nvidia nvidia-settings; then 
            log_error "Failed to install NVIDIA packages" $?
            exit 1
        fi

        # Add NVIDIA modules to initramfs
        if ! sed -i '/^MODULES=()/c\MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)' /etc/mkinitcpio.conf || \
           ! mkinitcpio -p linux; then
            log_error "Failed to update initramfs with NVIDIA modules" $?
            exit 1
        fi

        # Update GRUB configuration with NVIDIA settings
        # Make sure DISK is exported and available in the environment
        if ! sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT="quiet cryptdevice=\/dev\/'"$DISK"'3:volgroup0 loglevel=3"/c\GRUB_CMDLINE_LINUX_DEFAULT="quiet cryptdevice=\/dev\/'"$DISK"'3:volgroup0 nvidia_drm_modeset=1 loglevel=3"' /etc/default/grub || \
           ! grub-mkconfig -o /boot/grub/grub.cfg; then
            log_error "Failed to update GRUB configuration with NVIDIA settings" $?
            exit 1
        fi
    else
        log_output "No NVIDIA GPUs detected. Skipping NVIDIA driver installation."
    fi
}
