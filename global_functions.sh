#!/bin/bash

## Global Functions ##
source ./log.sh

validate_username() {
    local username="$1"
    if [[ "${username,,}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]; then
        return 0  # True
    else
        log_error "Invalid username: $username"
        return 1  # False
    fi
}

validate_hostname() {
    local hostname="$1"
    if [[ "${hostname,,}" =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]]; then
        return 0  # True
    else
        log_error "Invalid hostname: $hostname"
        return 1  # False
    fi
}

validate_disk() {
    local disk="$1"
    if [ -b "$disk" ]; then
        return 0  # True
    else
        log_error "Invalid disk path: $disk"
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
        log_info "User confirmed: $message"
        return 0  # True
    else
        log_warn "User declined: $message"
        return 1  # False
    fi
}

# --- User Input Functions --- #
# --- Ask for desired username ---
get_username() {
    while true; do
        read -r -p "Enter a username: " username

        if ! validate_username "$username"; then
            continue
        fi

        export USERNAME="$username"
        log_info "Username set to: $USERNAME"
        break
    done
}

# --- Ask for desired user password ---
get_user_password() {
    while true; do
        read -rs -p "Set a password for $USERNAME: " USER_PASSWORD1
        echo
        read -rs -p "Confirm password: " USER_PASSWORD2
        echo

        if [[ "$USER_PASSWORD1" != "$USER_PASSWORD2" ]]; then
            log_error "Passwords do not match."
            continue
        fi

        export USER_PASSWORD="$USER_PASSWORD1"
        log_info "Password set for $USERNAME successfully."
        break
    done
}

# --- Ask for desired root password ---
get_root_password() {
    while true; do
        read -rs -p "Set root password: " ROOT_PASSWORD1
        echo
        read -rs -p "Confirm root password: " ROOT_PASSWORD2
        echo

        if [[ "$ROOT_PASSWORD1" != "$ROOT_PASSWORD2" ]]; then
            log_error "Passwords do not match."
            continue
        fi

        export ROOT_PASSWORD="$ROOT_PASSWORD1"
        log_info "Root password set successfully."
        break
    done
}

# --- Ask for desired hostname ---
get_hostname() {
    while true; do
        read -r -p "Enter a hostname: " hostname

        if ! validate_hostname "$hostname"; then
            continue
        fi

        export HOSTNAME="$hostname"
        log_info "Hostname set to: $HOSTNAME"
        break
    done
}

# --- Ask which disk to use ---
get_disk() {
    # List Disks
    log_info "Available disks:"
    fdisk -l | grep "Disk /"

    while true; do
        read -r -p "Enter the disk to use (e.g. /dev/nvme0n1 , /dev/sda): " disk

        if ! validate_disk "$disk"; then
            continue
        fi

        # Confirm Disk Selection using confirm_action from functions.sh
        if confirm_action "You have selected $disk. Is this correct?"; then
            export DISK="$disk"
            log_info "Disk set to: $DISK"
            break
        fi
    done
}

# --- Ask for desired partition sizes ---
get_partition_sizes() {
    while true; do
        read -r -p "Enter EFI partition size (e.g., 512M, 1G): " efi_size
        read -r -p "Enter boot partition size (e.g., 512M, 1G): " boot_size

        # Basic validation
        if [[ "$efi_size" =~ ^[0-9]+(G|M|K)$ ]] && \
           [[ "$boot_size" =~ ^[0-9]+(G|M|K)$ ]]; then
            export EFI_SIZE="$efi_size"
            export BOOT_SIZE="$boot_size"
            log_info "EFI partition size: $EFI_SIZE"
            log_info "Boot partition size: $BOOT_SIZE"
            break
        else
            log_error "Invalid partition size(s). Please use a format like 512M or 1G."
        fi
    done
}

# --- Ask for desired encryption password ---
get_encryption_password() {
    while true; do
        read -rs -p "Enter encryption password: " password
        echo
        read -rs -p "Confirm encryption password: " confirm_password
        echo

        if [[ "$password" != "$confirm_password" ]]; then
            log_error "Passwords do not match."
            continue
        fi

        export ENCRYPTION_PASSWORD="$password"
        log_info "Encryption password set."
        break
    done
}

select_timezone() {
    # Install dialog to generate interactive selection
    pacman -Sy --noconfirm --needed dialog
    
    local timezones
    local selected_timezone
    local timezone_list=()
    local index=1  # Numbering for selection
    local search_query=""
    local filtered_timezones=()

    # Set terminal dimensions dynamically
    local HEIGHT=$(tput lines)
    local WIDTH=$(tput cols)
    local MENU_HEIGHT=$(( HEIGHT - 10 > 20 ? 20 : HEIGHT - 10 ))  # Ensure a reasonable menu size

    # Allow user to search for a timezone
    search_query=$(dialog --title "Search Timezone" --backtitle "Timezone Selection" \
        --inputbox "Enter a partial timezone: e.g. 'America' or 'New_York' (leave blank to show all):" 8 50 3>&1 1>&2 2>&3)

    # Get a list of available timezones
    while IFS= read -r line; do
        if [[ -z "$search_query" || "$line" == *"$search_query"* ]]; then
            timezone_list+=("$index" "$line")
            ((index++))
        fi
    done < <(timedatectl list-timezones)

    # Ensure at least one result exists
    if [[ ${#timezone_list[@]} -eq 0 ]]; then
        dialog --msgbox "No timezones found matching '$search_query'." 8 50
        pacman -Rns --noconfirm dialog  # Clean up dialog installation
        return 1
    fi

    # Use dialog for selection with customized colors
    selected_index=$(dialog --title "Select Timezone" --backtitle "Timezone Selection" \
        --colors --menu "Choose your timezone:" $HEIGHT $WIDTH $MENU_HEIGHT "${timezone_list[@]}" \
        --stdout)

    # Check if a timezone was selected
    if [[ -n "$selected_index" ]]; then
        # Extract actual timezone name (accounting for index placement)
        local selected_timezone_name="${timezone_list[((selected_index * 2))]}"
        export ACTUAL_TIME="$selected_timezone_name"
        log_info "Timezone set to $ACTUAL_TIME"
    else
        echo "No timezone selected."
        pacman -Rns --noconfirm dialog  # Clean up dialog installation
        exit 1
    fi

    # Clean up dialog installation after selection
    pacman -Rns --noconfirm dialog
}

set_timezone() {
    log_info "Setting timezone to $ACTUAL_TIME"
    ln -sf "/usr/share/zoneinfo/$ACTUAL_TIME" /etc/localtime
    hwclock --systohc
}

# --- Ask for desired server/desktop ---
select_gui() {
    log_info "Selecting GUI..."

    options=("Server (No GUI)" "Hyprland" "GNOME" "KDE Plasma")
    select gui_choice in "${options[@]}"; do
        case "$gui_choice" in
            "Hyprland")
                export GUI_CHOICE="hyprland"
                log_info "Hyprland selected."
                break
                ;;
            "GNOME")
                export GUI_CHOICE="gnome"
                log_info "GNOME selected."
                break
                ;;
            "KDE Plasma")
                export GUI_CHOICE="kde"
                log_info "KDE Plasma selected."
                break
                ;;
            "Server (No GUI)")
                export GUI_CHOICE="none"
                log_info "No GUI selected."
                break
                ;;
            *)
                log_error "Invalid selection. Please choose a valid GUI option."
                ;;
        esac
    done
}

# --- Ask for desired GRUB theme ---
get_grub_theme() {
  log_info "Selecting GRUB Theme..."

  # Ask the user if they want to install a GRUB Theme
  if ! confirm_action "Do you want to install a GRUB Theme?"; then
    log_info "Skipping GRUB Theme installation."
    export GRUB_THEME="none" 
    return 0
  fi

  # Ask the user which GRUB Theme they want
  options=("poly-dark" "CyberEXS" "Cyberpunk" "HyperFluent" "none")
  select grub_theme in "${options[@]}"; do
    case "$grub_theme" in
        poly-dark)
            export GRUB_THEME="poly-dark" 
            log_info "poly-dark selected."
            break 
            ;;
        CyberEXS)
            export GRUB_THEME="CyberEXS" 
            log_info "CyberEXS selected."
            break 
            ;;
        Cyberpunk)
            export GRUB_THEME="Cyberpunk"
            log_info "Cyberpunk selected."
            break 
            ;;
        HyperFluent)
            export GRUB_THEME="HyperFluent" 
            log_info "HyperFluent selected."
            break 
            ;;
        none)
            export GRUB_THEME="none" 
            log_info "No GRUB Theme selected."
            break 
            ;;
        *)
            log_error "Invalid selection. Please choose a valid GRUB theme." 
            ;;
    esac
  done
}

# --- Ask for desired AUR helper ---
get_aur_helper() {
    log_info "Selecting AUR helper..."

    # Ask the user if they want to install an AUR helper
    if ! confirm_action "Do you want to install an AUR helper?"; then
        log_info "Skipping AUR helper installation."
        export AUR_HELPER="none"
        return 0
    fi

    # Ask the user which AUR helper they want
    options=("paru" "yay" "none")
    select aur_helper in "${options[@]}"; do
        case "$aur_helper" in
            paru)
                export AUR_HELPER="paru"
                log_info "paru selected."
                break
                ;;
            yay)
                export AUR_HELPER="yay"
                log_info "yay selected."
                break
                ;;
            none)
                export AUR_HELPER="none"
                log_info "No AUR helper selected."
                break
                ;;
            *)
                log_error "Invalid selection. Please choose a valid AUR helper."
                ;;
        esac
    done
}

# --- Disk Setup ---
partition_disk() {
    local disk="$1"
    local efi_size="$2"
    local boot_size="$3"

    log_info "Partitioning disk: $disk"

    # Create new GPT partition table
    if ! sgdisk --zap-all "$disk"; then
        log_error "Failed to clear disk $disk" $?
        exit 1
    fi

    # Create EFI partition
    if ! sgdisk -n 1:0:+"$efi_size" -t 1:EF00 "$disk"; then
        log_error "Failed to create EFI partition on $disk" $?
        exit 1
    fi

    # Create boot partition
    if ! sgdisk -n 2:0:+"$boot_size" -t 2:8300 "$disk"; then
        log_error "Failed to create boot partition on $disk" $?
        exit 1
    fi

    # Create LVM partition (using remaining space)
    if ! sgdisk -n 3:0:0 -t 3:8E00 "$disk"; then
        log_error "Failed to create LVM partition on $disk" $?
        exit 1
    fi

    # Print partition table
    log_info "Partition table on $disk:"
    sgdisk -p "$disk"

    # Re-read partition table
    if ! partprobe "$disk"; then
        log_error "Failed to re-read partition table on $disk" $?
        exit 1
    fi
}

setup_lvm() {
    local disk="$1"
    local password="$2"

    log_info "Setting up LVM on disk: $disk"

    # Format EFI partition
    if [[ $disk =~ nvme ]]; then
        if ! mkfs.fat -F32 "${disk}p1"; then
            log_error "Failed to format EFI partition on ${disk}p1" $?
            exit 1
        fi
    else
        if ! mkfs.fat -F32 "${disk}1"; then
            log_error "Failed to format EFI partition on ${disk}1" $?
            exit 1
        fi
    fi

    # Format boot partition
    if [[ $disk =~ nvme ]]; then
        if ! mkfs.ext4 "${disk}p2"; then
            log_error "Failed to format boot partition on ${disk}p2" $?
            exit 1
        fi
    else
        if ! mkfs.ext4 "${disk}2"; then
            log_error "Failed to format boot partition on ${disk}2" $?
            exit 1
        fi
    fi

    # Setup encryption on partition 3 using LUKS
    if [[ $disk =~ nvme ]]; then
        if ! echo "$password" | cryptsetup luksFormat "${disk}p3"; then
            log_error "Failed to format LUKS partition on ${disk}p3" $?
            exit 1
        fi

        # Open LUKS partition
        if ! echo "$password" | cryptsetup open --type luks --batch-mode "${disk}p3" lvm; then
            log_error "Failed to open LUKS partition on ${disk}p3" $?
            exit 1
        fi
    else
        if ! echo "$password" | cryptsetup luksFormat "${disk}3"; then
            log_error "Failed to format LUKS partition on ${disk}3" $?
            exit 1
        fi

        # Open LUKS partition
        if ! echo "$password" | cryptsetup open --type luks --batch-mode "${disk}3" lvm; then
            log_error "Failed to open LUKS partition on ${disk}3" $?
            exit 1
        fi
    fi

    # Create physical volume for LVM on partition 3 with data alignment 1m
    if ! pvcreate /dev/mapper/lvm; then
        log_error "Failed to create physical volume on /dev/mapper/lvm" $?
        exit 1
    fi

    # Create volume group called volgroup0 on partition 3
    if ! vgcreate volgroup0 /dev/mapper/lvm; then
        log_error "Failed to create volume group volgroup0" $?
        exit 1
    fi

    # Get logical volume sizes from the user
    get_lv_sizes() {
        read -r -p "Enter root logical volume size (e.g., 50G, 100G): " root_lv_size
        export ROOT_LV_SIZE="$root_lv_size"
        log_info "Root logical volume size: $ROOT_LV_SIZE"
    }

    get_lv_sizes

    # Create logical volumes (lv_home will use remaining space)
    if ! lvcreate -L "$ROOT_LV_SIZE" volgroup0 -n lv_root || \
       ! lvcreate -l 100%FREE volgroup0 -n lv_home; then
        log_error "Failed to create logical volumes" $?
        exit 1
    fi

    # Load kernel module
    if ! modprobe dm_mod; then
        log_error "Failed to load dm_mod kernel module" $?
        exit 1
    fi

    # Scan system for volume groups
    vgscan

    # Activate volume group
    if ! vgchange -ay; then
        log_error "Failed to activate volume group" $?
        exit 1
    fi

    # Format and mount root volume
    if ! mkfs.ext4 /dev/volgroup0/lv_root; then
        log_error "Failed to format root volume" $?
        exit 1
    fi

    if ! mount /dev/volgroup0/lv_root /mnt; then
        log_error "Failed to mount root volume" $?
        exit 1
    fi

    # Create /boot directory and mount partition 2
    if ! mkdir -p /mnt/boot; then
        log_error "Failed to create /boot directory" $?
        exit 1
    fi

    if [[ $disk =~ nvme ]]; then
        if ! mount "${disk}p2" /mnt/boot; then
            log_error "Failed to mount /boot on ${disk}p2" $?
            exit 1
        fi
    else
        if ! mount "${disk}2" /mnt/boot; then
            log_error "Failed to mount /boot on ${disk}2" $?
            exit 1
        fi
    fi

    # Create /boot/EFI directory and mount partition 1
    if ! mkdir -p /mnt/boot/efi; then
        log_error "Failed to create /boot/efi directory" $?
        exit 1
    fi

    if [[ $disk =~ nvme ]]; then
        if ! mount "${disk}p1" /mnt/boot/efi; then
            log_error "Failed to mount /boot/efi on ${disk}p1" $?
            exit 1
        fi
    else
        if ! mount "${disk}1" /mnt/boot/efi; then
            log_error "Failed to mount /boot/efi on ${disk}1" $?
            exit 1
        fi
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

# --- Install reflector dependencies ---
install_prerequisites() {
    log_info "Installing prerequisite packages..."
    if ! pacman -Sy --noconfirm --needed pacman-contrib reflector rsync; then
        log_error "Failed to install prerequisite packages" $?
        exit 1
    fi
}

# --- Update mirrorlist with reflector ---
configure_mirrors() {
    log_info "Configuring pacman mirrors for faster downloads..."
    if ! cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup || \
       ! reflector --country US -a 72 -f 10 -l 10 --sort rate --save /etc/pacman.d/mirrorlist; then
        log_error "Failed to configure pacman mirrors" $?
        exit 1
    fi
}

# --- Run pacstrap ---
install_base_packages() {
    log_info "Installing base packages using pacstrap..."
    if ! pacstrap -K /mnt base linux linux-firmware linux-headers --noconfirm --needed; then
        log_error "Failed to install base packages" $?
        exit 1
    fi
}

# --- Configure pacman ---
configure_pacman() {
    log_info "Configuring pacman..."
    if ! sed -i "/^#Color/c\Color\nILoveCandy" /etc/pacman.conf || \
       ! sed -i "/^#VerbosePkgLists/c\VerbosePkgLists" /etc/pacman.conf || \
       ! sed -i "/^#ParallelDownloads/c\ParallelDownloads = 5" /etc/pacman.conf || \
       ! sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf; then
        log_error "Failed to configure pacman" $?
        exit 1
    fi
}

# --- Install microcode ---
install_microcode() {
    log_info "Installing microcode..."
    proc_type=$(lscpu | grep -oP '^Vendor ID:\s+\K\w+')
    if [ "$proc_type" = "GenuineIntel" ]; then
        log_info "Installing Intel microcode"
        if ! pacman -Sy --noconfirm --needed intel-ucode; then
            log_error "Failed to install Intel microcode" $?
            exit 1
        fi
    elif [ "$proc_type" = "AuthenticAMD" ]; then
        log_info "Installing AMD microcode"
        if ! pacman -Sy --noconfirm --needed amd-ucode; then
            log_error "Failed to install AMD microcode" $?
            exit 1
        fi
    fi
}

# --- Install all pacman packages defined in pkgs.lst ---
install_additional_packages() {
    log_info "Installing additional packages..."
    if ! pacman -S --noconfirm --needed - < ./pkgs.lst; then
        log_error "Failed to install additional packages" $?
        exit 1
    fi
}

# --- Enable system services ---
enable_services() {
    log_info "Enabling services..."
    if ! systemctl enable NetworkManager.service || \
       ! systemctl enable ntpd.service || \
       ! systemctl enable fstrim.timer; then
        log_error "Failed to enable services" $?
        exit 1
    fi
}

# --- Set locale to en_US.UTF-8 ---
set_locale() {
    log_info "Setting locale..."
    if ! sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen || \
       ! locale-gen || \
       ! echo 'LANG=en_US.UTF-8' > /etc/locale.conf; then 
        log_error "Failed to set locale" $?
        exit 1
    fi
}

# --- Add HOOKS to mkinitcpoio.conf / Update initramfs --- 
update_initramfs() {
    log_info "Updating initramfs..."
    if ! sed -i 's/^HOOKS\s*=\s*(.*)/HOOKS=(base udev plymouth autodetect modconf block encrypt lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf || \
       ! mkinitcpio -p linux; then
        log_error "Failed to update initramfs" $?
        exit 1
    fi
}

# --- Create User Account ---
create_user() {
    local username="$1"
    log_info "Creating user: $username"
    if ! useradd -m -G wheel,power,storage,uucp,network -s /bin/bash "$username"; then
        log_error "Failed to create user" $?
        exit 1
    fi
}

# --- Set user and root passwords ---
set_passwords() {
    log_info "Setting passwords..."
    if ! echo "$USERNAME:$USER_PASSWORD" | chpasswd || \
       ! echo "root:$ROOT_PASSWORD" | chpasswd; then
        log_error "Failed to set passwords" $?
        exit 1
    fi
}

# --- Set hostname ---
set_hostname() {
    local hostname="$1"
    log_info "Setting hostname: $hostname"
    if ! echo "$hostname" > /etc/hostname; then 
        log_error "Failed to set hostname" $?
        exit 1
    fi
}

# --- Update sudoers file ---
update_sudoers() {
    log_info "Updating sudoers..."
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

# --- Install GRUB ---
install_grub() {
  log_info "Installing GRUB..."
  if ! grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck; then
    log_error "Failed to install GRUB" $?
    exit 1
  fi
}

# --- Install GRUB Theme ---
install_grub_themes() {
  log_info "Installing GRUB themes..."

  # Check if a theme was selected before proceeding
  if [[ "$GRUB_THEME" == "none" ]]; then
    log_info "No GRUB theme selected. Skipping installation."
    return 0  # Exit successfully
  fi

  mkdir -p grub-themes

  case "$GRUB_THEME" in
    poly-dark)
      git clone https://github.com/shvchk/poly-dark.git ./grub-themes/poly-dark
      mv ./grub-themes/poly-dark /boot/grub/themes/
      sed -i 's|^#GRUB_THEME="/path/to/gfxtheme"|GRUB_THEME="/boot/grub/themes/poly-dark/theme.txt"|' /etc/default/grub
      ;;
    CyberEXS)
      git clone https://github.com/HenriqueLopes42/themeGrub.CyberEXS.git ./grub-themes/themeGrub.CyberEXS
      mv ./grub-themes/themeGrub.CyberEXS /boot/grub/themes/
      sed -i 's|^#GRUB_THEME="/path/to/gfxtheme"|GRUB_THEME="/boot/grub/themes/themeGrub.CyberEXS/theme.txt"|' /etc/default/grub
      ;;
    Cyberpunk)
      git clone https://gitlab.com/anoopmsivadas/Cyberpunk-GRUB-Theme.git ./grub-themes/Cyberpunk-GRUB-Theme
      mv ./grub-themes/Cyberpunk-GRUB-Theme /boot/grub/themes/
      sed -i 's|^#GRUB_THEME="/path/to/gfxtheme"|GRUB_THEME="/boot/grub/themes/Cyberpunk-GRUB-Theme/Cyberpunk/theme.txt"|' /etc/default/grub
      ;;
    HyperFluent)
      git clone https://github.com/Coopydood/HyperFluent-GRUB-Theme.git ./grub-themes/HyperFluent-GRUB-Theme
      mv ./grub-themes/HyperFluent-GRUB-Theme /boot/grub/themes/
      sed -i 's|^#GRUB_THEME="/path/to/gfxtheme"|GRUB_THEME="/boot/grub/themes/HyperFluent-GRUB-Theme/arch/theme.txt"|' /etc/default/grub
      ;;
    *)
      log_error "Invalid GRUB Theme specified"
      exit 1
      ;;
  esac

  # Give user ownership of the themes directory
  if ! chown -R $USERNAME:$USERNAME /boot/grub/themes; then
    log_error "Failed to change ownership of GRUB themes directory" $?
    exit 1
  fi
}

# --- Update /etc/default/grub / Run grub-mkconfig ---
configure_grub() {
  log_info "Configuring GRUB..."

  # Make sure DISK is exported and available in the environment
  if [[ $DISK == "/dev/nvme"* ]]; then
    PART_PREFIX="p"
  else
    PART_PREFIX=""
  fi

  ENCRYPTED_PARTITION="${DISK}${PART_PREFIX}3"
  CRYPT_UUID=$(blkid -s UUID -o value "${ENCRYPTED_PARTITION}")
  ROOT_UUID=$(blkid -s UUID -o value /dev/volgroup0/lv_root)

  if [[ -z $CRYPT_UUID || -z $ROOT_UUID ]]; then
    log_error "Failed to retrieve UUID's for cryptdevice or root partition" $?
    exit 1
  fi

  # Update /etc/default/grub configurations
  sed -i '/^GRUB_DEFAULT=/c\GRUB_DEFAULT=saved' /etc/default/grub 
  sed -i '/^GRUB_TIMEOUT=5/c\GRUB_TIMEOUT=3' /etc/default/grub 
  sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"/c\GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash cryptdevice=UUID=${CRYPT_UUID}:volgroup0 root=UUID=${ROOT_UUID} loglevel=3\"" /etc/default/grub 
  sed -i '/^#GRUB_ENABLE_CRYPTODISK=y/c\GRUB_ENABLE_CRYPTODISK=y' /etc/default/grub 
  sed -i '/^GRUB_GFXMODE=auto/c\GRUB_GFXMODE=1920x1440x32' /etc/default/grub 
  sed -i '/^#GRUB_SAVEDEFAULT=true/c\GRUB_SAVEDEFAULT=true' /etc/default/grub
 
  # Locale and GRUB configuration
  if ! cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale.en.mo || \
     ! grub-mkconfig -o /boot/grub/grub.cfg; then
    log_error "Failed to configure GRUB" $?
    exit 1
  fi
}

install_gpu_drivers() {
  log_info "Detecting GPUs..."

  # Detect GPUs (both NVIDIA and AMD)
  readarray -t gpus < <(lspci -k | grep -E "(VGA|3D)")

  if [[ ${#gpus[@]} -eq 0 ]]; then
    log_info "No GPUs detected. Skipping driver installation."
    return 0
  fi

  for gpu in "${gpus[@]}"; do
    vendor=$(echo "$gpu" | grep -oE "(NVIDIA|Advanced Micro Devices)" | head -n 1)

    if [[ "$vendor" == "NVIDIA" ]]; then
      log_info "NVIDIA GPU detected:"
      log_info "$gpu"

      log_info "Installing NVIDIA drivers..."
      if ! pacman -S --noconfirm --needed nvidia libglvnd nvidia-utils opencl-nvidia lib32-libglvnd lib32-nvidia-utils lib32-opencl-nvidia nvidia-settings; then
        log_error "Failed to install NVIDIA packages" $?
        return 1
      fi

      log_info "Updating initramfs..."
      if ! sed -i '/^MODULES=()/c\MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)' /etc/mkinitcpio.conf || \
       ! mkinitcpio -p linux; then
        log_error "Failed to update initramfs with NVIDIA modules" $?
        return 1
      fi

      log_info "Updating GRUB configuration..."

      # Ensure DISK variable is available in the environment
      if [[ $DISK == "/dev/nvme"* ]]; then
        PART_PREFIX="p"
      else
        PART_PREFIX=""
      fi

      ENCRYPTED_PARTITION="${DISK}${PART_PREFIX}3"
      CRYPT_UUID=$(blkid -s UUID -o value "${ENCRYPTED_PARTITION}")
      ROOT_UUID=$(blkid -s UUID -o value /dev/volgroup0/lv_root)

      if [[ -z $CRYPT_UUID || -z $ROOT_UUID ]]; then
        log_error "Failed to retrieve UUID's for cryptdevice or root partition" $?
        return 1
      fi

      if ! sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT="quiet splash cryptdevice=UUID='"${CRYPT_UUID}"':volgroup0 root=UUID='"${ROOT_UUID}"' loglevel=3"|GRUB_CMDLINE_LINUX_DEFAULT="quiet splash cryptdevice=UUID='"${CRYPT_UUID}"':volgroup0 root=UUID='"${ROOT_UUID}"' nvidia_drm_modeset=1 loglevel=3"|' /etc/default/grub || \
       ! grub-mkconfig -o /boot/grub/grub.cfg; then
        log_error "Failed to update GRUB configuration with NVIDIA settings" $?
        return 1
      fi

      log_info "NVIDIA drivers installed and configured successfully."
      return 0

    elif [[ "$vendor" == "Advanced Micro Devices" ]]; then
      log_info "AMD Radeon GPU detected:"
      log_info "$gpu"

      log_info "Installing Radeon drivers and related packages..."
      if ! pacman -S --noconfirm --needed vulkan-radeon lib32-vulkan-radeon; then
        log_error "Failed to install Radeon packages" $?
        return 1
      fi

      log_info "Radeon drivers and related packages installed successfully."
      return 0

    else
      log_warn "Unknown GPU vendor detected: $gpu"
    fi
  done
}

install_gui() {
    log_info "Starting GUI installation..."

    if [[ "$GUI_CHOICE" == "hyprland" ]]; then
        log_info "Installing Hyprland with HyDE..."

        # Clone the dotfiles repository
        git clone --progress --verbose https://github.com/live4thamuzik/L4TM-HyDE.git /home/$USERNAME/L4TM-HyDE || {
            log_error "Failed to clone L4TM-HyDE repository"
            exit 1
        }

        # Fix permissions
        chown $USERNAME /home/$USERNAME/L4TM-HyDE
        chmod -R 777 /home/$USERNAME/L4TM-HyDE

        # Switch to the user's directory and install HyDE
        cd /home/$USERNAME/L4TM-HyDE/Scripts

        # Temporarily allow the user to run sudo without a password (within the chroot)
        echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers > /dev/null

        # Switch to the created user and run the install script
        if ! runuser -u "$USERNAME" -- /bin/bash -c '
            log_info "Running HyDE installer..."
            if ! bash ./install.sh; then
                log_error "Failed to install HyDE" "$?"
                exit 1
            fi
        '; then
            log_error "Failed to install AUR packages as $USERNAME"
            # Remove the temporary sudoers entry in case of failure
            sed -i "/$USERNAME ALL=(ALL) NOPASSWD: ALL/d" /etc/sudoers
            exit 1
        fi

        # Clean up the temporary sudoers entry
        sed -i "/$USERNAME ALL=(ALL) NOPASSWD: ALL/d" /etc/sudoers

        log_info "HyDE installation complete!"

    elif [[ "$GUI_CHOICE" == "gnome" ]]; then
        log_info "Installing GNOME desktop environment..."

        # Install GNOME and related packages
        if ! pacman -S --noconfirm --needed gnome gnome-extra gnome-tweaks gnome-shell-extensions gnome-browser-connector firefox; then
            log_error "Failed to install GNOME packages"
            exit 1
        fi

        # Enable GDM service
        if ! systemctl enable gdm.service; then
            log_error "Failed to enable GDM service"
            exit 1
        fi

        log_info "GNOME installed and GDM service enabled."

    elif [[ "$GUI_CHOICE" == "kde" ]]; then
        log_info "Installing KDE Plasma desktop environment..."

        # Install KDE Plasma and related packages
        if ! pacman -S --noconfirm --needed xorg plasma-desktop sddm kde-applications dolphin firefox lxappearance; then
            log_error "Failed to install KDE Plasma packages"
            exit 1
        fi

        # Enable SDDM service
        if ! systemctl enable sddm.service; then
            log_error "Failed to enable SDDM service"
            exit 1
        fi

        log_info "KDE Plasma installed and SDDM service enabled."

    else
        log_info "No GUI selected. Skipping GUI installation."
    fi
}

install_aur_helper() {
    # Check if an AUR helper was actually selected
    if [[ "$AUR_HELPER" == "none" ]]; then
        log_info "No AUR helper installation requested. Skipping."
        return 0
    fi

    log_info "Starting AUR helper installation process..."

    # Temporarily allow the user to run sudo without a password
    log_info "Granting temporary sudo access for $USERNAME"
    echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

    # Switch to the created user
    log_info "Switching to user $USERNAME to install the AUR helper..."
    if ! runuser -u "$USERNAME" -- /bin/bash -c "
        # Install git if not already installed
        log_info \"Checking if git is installed...\"
        if ! pacman -Qi git &> /dev/null; then
            log_info \"Installing git...\"
            if ! sudo pacman -S --noconfirm git; then
                log_error \"Failed to install git\" 3
                exit 3
            fi
        else
            log_info \"git is already installed.\"
        fi

        # Install the chosen AUR helper
        log_info \"Installing the selected AUR helper: $AUR_HELPER...\"
        case \"$AUR_HELPER\" in
            yay)
                log_info \"Cloning yay repository...\"
                mkdir -p tmp
                cd tmp && git clone https://aur.archlinux.org/yay.git || { log_error \"Failed to clone yay repository\" 4; exit 4; }
                cd yay && makepkg -si --noconfirm -C yay || { log_error \"Failed to build and install yay\" 5; exit 5; }
                ;;
            paru)
                log_info \"Cloning paru repository...\"
                mkdir -p tmp
                cd tmp && git clone https://aur.archlinux.org/paru.git || { log_error \"Failed to clone paru repository\" 6; exit 6; }
                cd paru && makepkg -si --noconfirm -C paru || { log_error \"Failed to build and install paru\" 7; exit 7; }
                ;;
            *)  # This should now be unreachable due to the initial check
                log_error \"Invalid AUR helper specified\" 8
                exit 8
                ;;
        esac
    "; then
        log_error "Failed to switch to user $USERNAME for AUR helper installation" 9
        return 9
    fi

    # Remove the temporary sudoers entry
    log_info "Cleaning up sudoers file by removing temporary sudo access for $USERNAME"
    sed -i "/$USERNAME ALL=(ALL) NOPASSWD: ALL/d" /etc/sudoers

    log_info "AUR helper $AUR_HELPER installed successfully."
}

install_aur_pkgs() {
  log_info "Starting AUR package installation process..."

  # Determine AUR helper. Paru preferred, but checks for yay as well
  AUR_HELPER=""

  if command -v paru &> /dev/null; then
    AUR_HELPER="paru"
    log_info "Paru found. Using Paru for AUR package installation."
  elif command -v yay &> /dev/null; then
    AUR_HELPER="yay"
    log_info "Yay found. Using Yay for AUR package installation."
  else
    log_warn "Neither Paru nor Yay found. Skipping AUR package installation."
    return 0 # Exit successfully because AUR packages are optional
  fi

  # Temporarily allow the user to run sudo without a password
  log_info "Granting temporary sudo access for $USERNAME"
  echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

  # Switch to the created user and install AUR packages
  log_info "Switching to user $USERNAME to install AUR packages..."
  if ! runuser -u "$USERNAME" -- /bin/bash -c "
      # Install AUR packages using the selected helper
      log_info \"Installing AUR packages using \$AUR_HELPER...\"
      if [[ \"\$AUR_HELPER\" == \"paru\" ]]; then
        if ! paru -S --noconfirm --needed - < ./aur_pkgs.lst; then
          log_error \"Failed to install AUR packages with \$AUR_HELPER\" \$?
          exit 1
        fi
      elif [[ \"\$AUR_HELPER\" == \"yay\" ]]; then
        if ! yay -S --noconfirm --needed - < ./aur_pkgs.lst; then
          log_error \"Failed to install AUR packages with \$AUR_HELPER\" \$?
          exit 1
        fi
      fi
    "; then
    log_error "Failed to install AUR packages as $USERNAME" $?
    # Remove the temporary sudoers entry in case of failure
    log_info "Removing temporary sudo access for $USERNAME"
    sed -i "/$USERNAME ALL=(ALL) NOPASSWD: ALL/d" /etc/sudoers
    exit 1
  fi

  # Remove the temporary sudoers entry
  log_info "Removing temporary sudo access for $USERNAME"
  sed -i "/$USERNAME ALL=(ALL) NOPASSWD: ALL/d" /etc/sudoers

  log_info "AUR packages installed successfully using $AUR_HELPER."
}

numlock_auto_on() {
  log_info "Starting the initramfs update process..."

  # Check if mkinitcpio-numlock is installed via AUR helper
  if [[ -n "$AUR_HELPER" ]]; then  # Check if AUR_HELPER is set
    log_info "Checking if mkinitcpio-numlock is installed using $AUR_HELPER..."
    if ! runuser -u "$USERNAME" -- /bin/bash -c "command -v $AUR_HELPER &> /dev/null && $AUR_HELPER -Qs mkinitcpio-numlock &> /dev/null"; then
      log_warn "mkinitcpio-numlock not found (or issue with $AUR_HELPER). Skipping numlock configuration."
      return 0
    fi
  else
    log_warn "No AUR helper found. Skipping mkinitcpio-numlock check and numlock configuration."
    return 0
  fi

  log_info "Updating mkinitcpio configuration to include numlock..."
  if ! sed -i 's/^HOOKS\s*=\s*(.*)/HOOKS=(base udev plymouth autodetect modconf numlock block encrypt lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf || \
     ! mkinitcpio -p linux; then
    log_error "Failed to update initramfs with numlock" $?
    exit 1
  fi

  log_info "Initramfs updated successfully with numlock."
}

# --- Cleanup Function ---
cleanup() {
    log_info "Starting cleanup process..."

    # Remove temporary files and directories created during the installation
    log_info "Removing temporary files and directories..."
    rm -rf /mnt/global_functions.sh && log_info "/mnt/global_functions.sh removed."
    rm -rf /mnt/chroot.sh && log_info "/mnt/chroot.sh removed."
    rm -rf /mnt/log.sh && log_info "/mnt/log.sh removed."
    rm -rf /mnt/pkgs.lst && log_info "/mnt/pkgs.lst removed."
    rm -rf /mnt/aur_pkgs.lst && log_info "/mnt/aur_pkgs.lst removed."
    rm -rf /mnt/tmp && log_info "/mnt/tmp removed."
    rm -rf /mnt/grub-themes && log_info "/mnt/grub-themes removed."

    # Copy log files to the installed system
    log_info "Copying log files to the installed system..."
    if ! cp /var/log/archl4tm.log /mnt/var/log/archl4tm.log; then
        log_error "Failed to copy archl4tm.log" $?
    else
        log_info "/var/log/archl4tm.log copied successfully."
    fi

    log_info "Cleanup process completed."
}
