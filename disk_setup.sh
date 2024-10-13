#!/bin/bash

# Source global functions
source functions.sh

get_disk() {
    # List Disks
    log_output "Available disks:"
    fdisk -l | grep "Disk /"  # Only list whole disks

    while true; do
        read -p "Enter the disk to use (e.g., /dev/sda): " disk

        if ! validate_disk "$disk"; then  # Use the validate_disk function from functions.sh
            continue
        fi

        # Confirm Disk Selection using confirm_action from functions.sh
        if confirm_action "You have selected $disk. Is this correct?"; then
            export DISK="$disk"
            log_output "Disk set to: $DISK"
            break
        fi
    done
}

get_partition_sizes() {
    while true; do
        read -p "Enter EFI partition size (e.g., 2G, 512M): " efi_size
        read -p "Enter boot partition size (e.g., 5G, 1G): " boot_size

        # Basic validation (you might want to add more robust checks)
        if [[ "$efi_size" =~ ^[0-9]+(G|M|K)$ ]] && \
           [[ "$boot_size" =~ ^[0-9]+(G|M|K)$ ]]; then
            export EFI_SIZE="$efi_size"
            export BOOT_SIZE="$boot_size"
            log_output "EFI partition size: $EFI_SIZE"
            log_output "Boot partition size: $BOOT_SIZE"
            break
        else
            log_error "Invalid partition size(s). Please use a format like 2G or 512M." 1
        fi
    done
}

get_encryption_password() {
    while true; do
        read -rs -p "Enter encryption password: " password
        echo
        read -rs -p "Confirm encryption password: " confirm_password
        echo

        if [[ "$password" != "$confirm_password" ]]; then
            log_error "Passwords do not match." 1
            continue
        fi

        export ENCRYPTION_PASSWORD="$password"
        log_output "Encryption password set."  # Avoid logging the password itself
        break
    done
}

partition_disk() {
    local disk="$1"
    local efi_size="$2"
    local boot_size="$3"

    log_output "Partitioning disk: $disk"

    # Create new GPT partition table
    if ! sgdisk --zap-all "$disk"; then
        log_error "Failed to clear disk" $?
        exit 1
    fi

    # Create EFI partition
    if ! sgdisk -n 1:0:+"$efi_size" -t 1:EF00 "$disk"; then
        log_error "Failed to create EFI partition" $?
        exit 1
    fi

    # Create boot partition
    if ! sgdisk -n 2:0:+"$boot_size" -t 2:8300 "$disk"; then
        log_error "Failed to create boot partition" $?
        exit 1
    fi

    # Create LVM partition (using remaining space)
    if ! sgdisk -n 3:0:0 -t 3:8E00 "$disk"; then
        log_error "Failed to create LVM partition" $?
        exit 1
    fi

    # Print partition table
    sgdisk -p "$disk"

    # Re-read partition table
    partprobe "$disk"
}

setup_lvm() {
    local disk="$1"
    local password="$2"  # Pass the encryption password as an argument

    log_output "Setting up LVM on disk: $disk"

    # Format partitions 
    if ! mkfs.fat -F32 "${disk}1" || \
       ! mkfs.ext4 "${disk}2"; then
        log_error "Failed to format partitions" $?
        exit 1
    fi

    # Setup encryption on partition 3 using LUKS
    if ! echo "$password" | cryptsetup luksFormat "${disk}3"; then
        log_error "Failed to format LUKS partition" $?
        exit 1
    fi

    # Open LUKS partition
    if ! echo "$password" | cryptsetup open --type luks --batch-mode "${disk}3" lvm; then
        log_error "Failed to open LUKS partition" $?
        exit 1
    fi

    # Create physical volume for LVM on partition 3 with data alignment 1m
    if ! pvcreate /dev/mapper/lvm; then
        log_error "Failed to create physical volume" $?
        exit 1
    fi

    # Create volume group called volgroup0 on partition 3
    if ! vgcreate volgroup0 /dev/mapper/lvm; then
        log_error "Failed to create volume group" $?
        exit 1
    fi

    # Get logical volume sizes from the user
    get_lv_sizes() {
        read -p "Enter root logical volume size (e.g., 50G, 200G): " root_lv_size
        # You might want to add validation here for $root_lv_size
        export ROOT_LV_SIZE="$root_lv_size"
        log_output "Root logical volume size: $ROOT_LV_SIZE"
    }

    get_lv_sizes

    # Create logical volumes (lv_home will use remaining space)
    if ! lvcreate -L "$ROOT_LV_SIZE" volgroup0 -n lv_root || \
       ! lvcreate -l 100%FREE volgroup0 -n lv_home; then
        log_error "Failed to create logical volumes" $?
        exit 1
    fi

    # Load kernel module
    modprobe dm_mod

    # Scan system for volume groups
    vgscan

    # Activate volume group
    if ! vgchange -ay; then
        log_error "Failed to activate volume group" $?
        exit 1
    fi

    # Format root volume
    if ! mkfs.ext4 /dev/volgroup0/lv_root; then
        log_error "Failed to format root volume" $?
        exit 1
    fi

    # Mount root volume
    if ! mount /dev/volgroup0/lv_root /mnt; then
        log_error "Failed to mount root volume" $?
        exit 1
    fi

    # Create /boot directory and mount partition 2
    if ! mkdir -p /mnt/boot; then
        log_error "Failed to create /boot directory" $?
        exit 1
    fi
    if ! mount "${disk}2" /mnt/boot; then
        log_error "Failed to mount /boot" $?
        exit 1
    fi

    # Create /boot/EFI directory and mount partition 1
    if ! mkdir -p /mnt/boot/EFI; then
        log_error "Failed to create /boot/EFI directory" $?
        exit 1
    fi
    if ! mount "${disk}1" /mnt/boot/EFI; then
        log_error "Failed to mount /boot/EFI" $?
        exit 1
    fi

    # Format home volume
    if ! mkfs.ext4 /dev/volgroup0/lv_home; then
        log_error "Failed to format home volume" $?
        exit 1
    fi

    # Create /home directory
    if ! mkdir -p /mnt/home; then
        log_error "Failed to create /home directory" $?
        exit 1
    fi

    # Mount home volume
    if ! mount /dev/volgroup0/lv_home /mnt/home; then
        log_error "Failed to mount /home" $?
        exit 1
    fi

    # Ensure /mnt/etc exists
    if ! mkdir -p /mnt/etc; then
        log_error "Failed to create /mnt/etc directory" $?
        exit 1
    fi

}
