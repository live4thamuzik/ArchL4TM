#!/bin/bash

# Source global functions
source functions.sh

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

    # Format logical volumes
    if ! mkfs.ext4 /dev/volgroup0/lv_root || \
       ! mkfs.ext4 /dev/volgroup0/lv_home; then
        log_error "Failed to format logical volumes" $?
        exit 1
    fi

    # Create mount points
    if ! mkdir -p /mnt/boot /mnt/boot/EFI /mnt/home; then
        log_error "Failed to create mount points" $?
        exit 1
    fi

    # Mount partitions and logical volumes
    if ! mount /dev/volgroup0/lv_root /mnt || \
       ! mount "${disk}2" /mnt/boot || \
       ! mount "${disk}1" /mnt/boot/EFI || \
       ! mount /dev/volgroup0/lv_home /mnt/home; then
        log_error "Failed to mount partitions/volumes" $?
        exit 1
    fi
}
