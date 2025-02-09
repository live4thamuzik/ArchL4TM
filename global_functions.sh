#!/bin/bash

## Global Functions ##

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

# --- User Input Functions --- #
# --- Ask for desired username ---
get_username() {
    while true; do
        read -r -p "Enter a username: " username

        if ! validate_username "$username"; then
            continue
        fi

        export USERNAME="$username"
        log_output "Username set to: $USERNAME"
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
            log_error "Passwords do not match." 1
            continue
        fi

        export USER_PASSWORD="$USER_PASSWORD1"
        log_output "Password set for $USERNAME successfully."
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
            log_error "Passwords do not match." 1
            continue
        fi

        export ROOT_PASSWORD="$ROOT_PASSWORD1"
        log_output "Root password set successfully."
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
        log_output "Hostname set to: $HOSTNAME"
        break
    done
}

# --- Ask which disk to use ---
get_disk() {
    # List Disks
    log_output "Available disks:"
    fdisk -l | grep "Disk /"  # Only list whole disks

    while true; do
        read -r -p "Enter the disk to use (e.g. /dev/nvme0n1 , /dev/sda): " disk

        if ! validate_disk "$disk"; then
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
            log_output "EFI partition size: $EFI_SIZE"
            log_output "Boot partition size: $BOOT_SIZE"
            break
        else
            log_error "Invalid partition size(s). Please use a format like 512M or 1G." 1
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
            log_error "Passwords do not match." 1
            continue
        fi

        export ENCRYPTION_PASSWORD="$password"
        log_output "Encryption password set."  # Avoid logging the password itself
        break
    done
}

# --- Timezone Selection ---
setup_timezone() {
  log_output "Setting up timezone..."

  # Function to get a list of timezones
  get_timezones() {
    local count=1
    find /usr/share/zoneinfo -type f | sed 's|/usr/share/zoneinfo/||' | awk '{print NR". "$0}'
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
  COLUMN_WIDTH=2  # Width of each column for timezones (consider increasing)

  # Function to display a page of timezones in columns
  display_page() {
    local start=$1
    local end=$2
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
    read -r -p "Enter the number of your timezone choice from this page, or press Enter to see more timezones: " choice

    # Check if user made a choice
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
      if ((choice >= 1 && choice <= total_timezones)); then
        # Extract the selected timezone (Corrected)
        selected_timezone=$(echo "${timezones[$((choice-1))]}" | awk '{for (i=2;i<=NF;i++) printf $i" "}')

        # Set timezone
        ln -sf /usr/share/zoneinfo/"$selected_timezone" /etc/localtime

        # Verify timezone setting (with added error check)
        if [[ $? -eq 0 ]]; then
          log_output "Timezone has been set to $(readlink -f /etc/localtime)"

          # Update hardware clock
          hwclock --systohc 
          if [[ $? -eq 0 ]]; then
            log_output "Hardware clock updated."
            break  # Exit the loop if successful
          else
            log_error "Failed to update hardware clock." 1
            exit 1
          fi
        else
          log_error "Failed to set timezone." 1
          exit 1
        fi
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


# --- Ask for desired server/desktop ---
select_gui() {
    log_output "Selecting GUI..."

    options=("Server (No GUI)" "Hyprland" "GNOME" "KDE Plasma")
    select gui_choice in "${options[@]}"; do  # "in" moved outside parentheses
        case "$gui_choice" in
            "Hyprland")
                export GUI_CHOICE="hyprland"
                log_output "Hyprland selected."
                ;;
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

# --- Ask for desired GRUB theme ---
get_grub_theme() {
  log_output "Selecting GRUB Theme..."

  # Ask the user if they want to install a GRUB Theme
  if ! confirm_action "Do you want to install a GRUB Theme?"; then
    log_output "Skipping GRUB Theme installation."
    export GRUB_THEME="none" 
    return 0
  fi

  # Ask the user which GRUB Theme they want
  options=("poly-dark" "CyberEXS" "Cyberpunk" "HyperFluent" "none")
  while true; do
    select grub_theme in "${options[@]}"; do
      case "$grub_theme" in
        poly-dark)
          export GRUB_THEME="poly-dark" 
          log_output "poly-dark selected."
          break 
          ;;
        CyberEXS)
          export GRUB_THEME="CyberEXS" 
          log_output "CyberEXS selected."
          break 
          ;;
        Cyberpunk)
          export GRUB_THEME="Cyberpunk"
          log_output "Cyberpunk selected."
          break 
          ;;
        HyperFluent)
          export GRUB_THEME="HyperFluent" 
          log_output "HyperFluent selected."
          break 
          ;;
        none)
          export GRUB_THEME="none" 
          log_output "No GRUB Theme selected."
          break 
          ;;
        *)
          log_output "Invalid option. Please select a valid theme." 
          ;; 
      esac
    done
    break
  done
}

# --- Ask for desired AUR helper ---
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
            exit 1  # Exit the script if the option is invalid
            ;;
    esac
    break
done
}

# --- Disk Setup ---
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

    # Format EFI partition
      if [[ $disk =~ nvme ]]; then
          if ! mkfs.fat -F32 "${disk}p1"; then
          log_error "Failed to format EFI partition" $?
          exit 1
      fi
    else
      if ! mkfs.fat -F32 "${disk}1"; then
          log_error "Failed to format EFI partition" $?
          exit 1
      fi
    fi


    # Format boot partition
     if [[ $disk =~ nvme ]]; then 
      if ! mkfs.ext4 "${disk}p2"; then
          log_error "Failed to format boot partition" $?
          exit 1
      fi
    else
      if ! mkfs.ext4 "${disk}2"; then
          log_error "Failed to format boot partition" $?
          exit 1
      fi
    fi 

    # Setup encryption on partition 3 using LUKS
      if [[ $disk =~ nvme ]]; then
        if ! echo "$password" | cryptsetup luksFormat "${disk}p3"; then
          log_error "Failed to format LUKS partition" $?
          exit 1
        fi

    # Open LUKS partition
      if ! echo "$password" | cryptsetup open --type luks --batch-mode "${disk}p3" lvm; then
        log_error "Failed to open LUKS partition" $?
        exit 1
      fi
    else
      if ! echo "$password" | cryptsetup luksFormat "${disk}3"; then
        log_error "Failed to format LUKS partition" $?
        exit 1
      fi

    # Open LUKS partition
      if ! echo "$password" | cryptsetup open --type luks --batch-mode "${disk}3" lvm; then
        log_error "Failed to open LUKS partition" $?
        exit 1
      fi
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
        read -r -p "Enter root logical volume size (e.g., 50G, 100G): " root_lv_size
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
        log_error "Failed to mount /boot" $?
        exit 1
      fi
    else
      if ! mount "${disk}2" /mnt/boot; then
        log_error "Failed to mount /boot" $?
        exit 1
      fi
    fi

    # Create /boot/EFI directory and mount partition 1
    if ! mkdir -p /mnt/boot/EFI; then
      log_error "Failed to create /boot/EFI directory" $?
      exit 1
    fi

    if [[ $disk =~ nvme ]]; then
      if ! mount "${disk}p1" /mnt/boot/EFI; then
        log_error "Failed to mount /boot/EFI" $?
        exit 1
      fi
    else
      if ! mount "${disk}1" /mnt/boot/EFI; then
        log_error "Failed to mount /boot/EFI" $?
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
    echo -ne "
    #------------------------------#
    # Installing prerequisite pkgs #
    #------------------------------#
    "
    log_output "Installing prerequisite packages..."
    if ! pacman -Sy --noconfirm --needed pacman-contrib reflector rsync; then
        log_error "Failed to install prerequisite packages" $?
        exit 1
    fi
}

# --- Update mirrorlist with reflector ---
configure_mirrors() {
    echo -ne "
    #---------------------#
    # Updating mirrorlist #
    #---------------------#
    "
    log_output "Configuring pacman mirrors for faster downloads..."
    if ! cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup || \
       ! reflector -a 48 -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist; then
        log_error "Failed to configure pacman mirrors" $?
        exit 1
    fi
}

# --- Run pacstrap ---
install_base_packages() {
    echo -ne "
    #------------------#
    # Running pacstrap #
    #------------------#
    "
    log_output "Installing base packages using pacstrap..."
    if ! pacstrap -K /mnt base linux linux-firmware linux-headers --noconfirm --needed; then
        log_error "Failed to install base packages" $?
        exit 1
    fi
}

# --- Configure pacman ---
configure_pacman() {
    echo -ne "
    #--------------------#
    # Configuring Pacman #
    #--------------------#
    "
    log_output "Configuring pacman..."

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
    echo -ne "
    #----------------------#
    # Installing microcode #
    #----------------------#
    "
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

# --- Install all pacman packages defined in pkgs.lst ---
install_additional_packages() {
    echo -ne "
    #----------------------------#
    # Installing additional pkgs #
    #----------------------------#
    "
    log_output "Installing additional packages..."
    if ! pacman -S --noconfirm --needed - < ./pkgs.lst; then
        log_error "Failed to install additional packages" $?
        exit 1
    fi
}

# --- Enable system services ---
enable_services() {
    echo -ne "
    #-------------------#
    # Enabling Services #
    #-------------------#
    "
    log_output "Enabling services..."
    if ! systemctl enable NetworkManager.service || \
       ! systemctl enable ntpd.service || \
       ! systemctl enable fstrim.timer; then
        log_error "Failed to enable services" $?
        exit 1
    fi
}

# --- Set locale to en_US.UTF-8 ---
set_locale() {
    echo -ne "
    #----------------#
    # Setting Locale #
    #----------------#
    "
    log_output "Setting locale..."
    if ! sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen || \
       ! locale-gen || \
       ! echo 'LANG=en_US.UTF-8' > /etc/locale.conf; then 
        log_error "Failed to set locale" $?
        exit 1
    fi
}

# --- Add HOOKS to mkinitcpoio.conf / Update initramfs --- 
update_initramfs() {
    echo -ne "
    #--------------------#
    # Updating Initramfs #
    #--------------------#
    "
    log_output "Updating initramfs..."
    if ! sed -i 's/^HOOKS\s*=\s*(.*)/HOOKS=(base udev plymouth autodetect modconf block encrypt lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf || \
       ! mkinitcpio -p linux; then
        log_error "Failed to update initramfs" $?
        exit 1
    fi
}

# --- Create User Account ---
create_user() {
    echo -ne "
    #---------------#
    # Creating User #
    #---------------#
    "
    local username="$1"
    log_output "Creating user: $username"
    if ! useradd -m -G wheel,power,storage,uucp,network -s /bin/bash "$username"; then
        log_error "Failed to create user" $?
        exit 1
    fi
}

# --- Set user and root passwords ---
set_passwords() {
    echo -ne "
    #-------------------#
    # Setting Passwords #
    #-------------------#
    "
    log_output "Setting passwords..."
    if ! echo "$USERNAME:$USER_PASSWORD" | chpasswd || \
       ! echo "root:$ROOT_PASSWORD" | chpasswd; then
        log_error "Failed to set passwords" $?
        exit 1
    fi
}

# --- Set hostname ---
set_hostname() {
    echo -ne "
    #------------------#
    # Setting hostname #
    #------------------#
    "
    local hostname="$1"
    log_output "Setting hostname: $hostname"
    if ! echo "$hostname" > /etc/hostname; then 
        log_error "Failed to set hostname" $?
        exit 1
    fi
}

# --- Update sudoers file ---
update_sudoers() {
    echo -ne "
    #------------------#
    # Updating sudoers #
    #------------------#
    "
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

# --- Install GRUB ---
install_grub() {
  echo -ne "
  #-----------------#
  # Installing GRUB #
  #-----------------#
  "
  log_output "Installing GRUB..."
  if ! grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck; then
    log_error "Failed to install GRUB" $?
    exit 1
  fi
}

# --- Install selected GRUB theme ---
install_grub_themes() {
  echo -ne "
  #-----------------------#
  # Installing GRUB Theme #
  #-----------------------#
  "
  log_output "Installing GRUB themes..."

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
    log_error "Failed to change ownership of GRUB themes directory"
    exit 1  
  fi
}

# --- Update /etc/default/grub / Run grub-mkconfig ---
configure_grub() {
  echo -ne "
  #------------------#
  # Configuring GRUB #
  #------------------#
  "
  log_output "Configuring GRUB..."

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
    log_error "Failed to retrieve UUID's for cryptdevice or root partition"
    exit 1
  fi

  sed -i '/^GRUB_DEFAULT=/c\GRUB_DEFAULT=saved' /etc/default/grub 
  sed -i '/^GRUB_TIMEOUT=5/c\GRUB_TIMEOUT=3' /etc/default/grub 
  sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/c\GRUB_CMDLINE_LINUX_DEFAULT="quiet splash cryptdevice=UUID='${CRYPT_UUID}':volgroup0 root=UUID='${ROOT_UUID}' loglevel=3"' /etc/default/grub 
  sed -i '/^#GRUB_ENABLE_CRYPTODISK=y/c\GRUB_ENABLE_CRYPTODISK=y' /etc/default/grub 
  sed -i '/^GRUB_GFXMODE=auto/c\GRUB_GFXMODE=1280x1024x32,auto' /etc/default/grub 
  sed -i '/^#GRUB_SAVEDEFAULT=true/c\GRUB_SAVEDEFAULT=true' /etc/default/grub 

  if ! cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale.en.mo || \
     ! grub-mkconfig -o /boot/grub/grub.cfg; then
    log_error "Failed to configure GRUB" $?
    exit 1
  fi
}

# --- Install/Configure NVIDIA ---
install_nvidia_drivers() {
  echo -ne "
  #-----------------------#
  # Detect/Install NVIDIA #
  #-----------------------#
  "
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
    if ! pacman -S --noconfirm --needed nvidia libglvnd nvidia-utils opencl-nvidia lib32-libglvnd lib32-nvidia-utils lib32-opencl-nvidia nvidia-settings; then
      log_error "Failed to install NVIDIA packages" $?
      exit 1
    fi

    log_output "Updating initramfs..."

    # Add NVIDIA modules to initramfs
    if ! sed -i '/^MODULES=()/c\MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)' /etc/mkinitcpio.conf || \
       ! mkinitcpio -p linux; then
      log_error "Failed to update initramfs with NVIDIA modules" $?
      exit 1
    fi

    echo "NVIDIA installed..."
   
    log_output "Updating GRUB configuration..."

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
    log_error "Failed to retrieve UUID's for cryptdevice or root partition"
    exit 1
  fi

    if ! sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT="quiet splash cryptdevice=UUID='"${CRYPT_UUID}"':volgroup0 root=UUID='"${ROOT_UUID}"' loglevel=3"|GRUB_CMDLINE_LINUX_DEFAULT="quiet splash cryptdevice=UUID='"${CRYPT_UUID}"':volgroup0 root=UUID='"${ROOT_UUID}"' nvidia_drm_modeset=1 loglevel=3"|' /etc/default/grub || \
       ! grub-mkconfig -o /boot/grub/grub.cfg; then
      log_error "Failed to update GRUB configuration with NVIDIA settings" $?
      exit 1
    fi

  else
    log_output "No NVIDIA GPUs detected. Skipping NVIDIA driver installation."
  fi
}

install_gui() {
    echo -ne "
    #---------------------------#
    # Installing Server/Desktop #
    #---------------------------#
    "
    if [[ "$GUI_CHOICE" == "hyprland" ]]; then
        # Clone the dotfiles branch
        git clone --progress --verbose https://github.com/live4thamuzik/L4TM-HyDE.git ./L4TM-HyDE || {
            log_error "Failed to L4TM-HyDE"
            exit 1
        }

        # Copy Configs to /
        cd ./L4TM-HyDE/Scripts

     # Temporarily allow the user to run sudo without a password (within the chroot)
    echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers > /dev/null
    
        # Switch to the created user and install HyDE
    if ! runuser -u "$USERNAME" -- /bin/bash -c "
        # Call hypr.sh
        if ! bash ./install.sh
        log_error \"Failed to install HyDE\" \$?
        exit 1
    fi
    "; then
        log_error "Failed to install AUR packages as $USERNAME" $?
        # Remove the temporary sudoers entry in case of failure
        sed -i "/$USERNAME ALL=(ALL) NOPASSWD: ALL/d" /etc/sudoers
        exit 1
    fi

    # Remove the temporary sudoers entry
    sed -i "/$USERNAME ALL=(ALL) NOPASSWD: ALL/d" /etc/sudoers

    log_output "HyDE installation complete!"
    
    elif [[ "$GUI_CHOICE" == "gnome" ]]; then
        log_output "Installing GNOME desktop environment..."

        if ! pacman -S --noconfirm --needed gnome gnome-extra gnome-tweaks gnome-shell-extensions gnome-browser-connector firefox; then
            log_error "Failed to install GNOME packages: $?"
            exit 1
        fi

        if ! systemctl enable gdm.service; then
            log_error "Failed to enable gdm service: $?"
            exit 1
        fi

        log_output "GNOME installed and gdm enabled."

    elif [[ "$GUI_CHOICE" == "kde" ]]; then
        log_output "Installing KDE Plasma desktop environment..."

        if ! pacman -S --noconfirm --needed xorg plasma-desktop sddm kde-applications dolphin firefox lxappearance; then
            log_error "Failed to install KDE Plasma packages: $?"
            exit 1
        fi

        if ! systemctl enable sddm.service; then
            log_error "Failed to enable sddm service: $?"
            exit 1
        fi

        log_output "KDE Plasma installed and sddm enabled."

    else
        log_output "No GUI selected. Skipping GUI installation."
    fi
}

# --- Install selected AUR Helper ---
install_aur_helper() {
    echo -ne "
    #-----------------------#
    # Installing AUR Helper #
    #-----------------------#
    "
    log_output "Installing AUR helper..."

     # Temporarily allow the user to run sudo without a password
     echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

    # Switch to the created user
    if ! runuser -u "$USERNAME" -- /bin/bash -c "
        # Install git if not already installed
        if ! pacman -Qi git &> /dev/null; then
            if ! sudo pacman -S --noconfirm git; then
                log_error \"Failed to install git\" 3
                exit 3
            fi
        fi

        # Install the chosen AUR helper
        case \"$AUR_HELPER\" in
            yay)
                mkdir -p tmp
                cd tmp && git clone https://aur.archlinux.org/yay.git || { log_error \"Failed to clone yay repository\" 4; exit 4; }
                cd yay && makepkg -si --noconfirm -C yay || { log_error \"Failed to build and install yay\" 5; exit 5; }
                ;;
            paru)
                mkdir -p tmp
                cd tmp && git clone https://aur.archlinux.org/paru.git || { log_error \"Failed to clone paru repository\" 6; exit 6; }
                cd paru && makepkg -si --noconfirm -C paru || { log_error \"Failed to build and install paru\" 7; exit 7; }
                ;;
            *)
                log_error \"Invalid AUR helper specified\" 8
                exit 8
                ;;
        esac
    "; then
        log_error "Failed to switch to user" 9
        return 9
    fi

    # Remove the temporary sudoers entry
    sed -i "/$USERNAME ALL=(ALL) NOPASSWD: ALL/d" /etc/sudoers

    log_output "AUR helper installed."
}

install_aur_pkgs() {
    echo -ne "
    #------------------------#
    # Installing AUR Packages #
    #------------------------#
    "
    log_output "Installing AUR packages..."

    # Temporarily allow the user to run sudo without a password
    echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

    # Switch to the created user and install AUR packages
    if ! runuser -u "$USERNAME" -- /bin/bash -c "
        # Check if the AUR helper is installed
        if ! command -v \"$AUR_HELPER\" &> /dev/null; then
            log_error \"AUR helper '$AUR_HELPER' not found. Make sure it's installed.\" 1
            exit 1
        fi

        # Install AUR packages using paru
        if ! paru -S --noconfirm --needed - < ./aur_pkgs.lst; then
            log_error \"Failed to install AUR packages\" \$?
            exit 1
        fi
    "; then
        log_error "Failed to install AUR packages as $USERNAME" $?
        # Remove the temporary sudoers entry in case of failure
        sed -i "/$USERNAME ALL=(ALL) NOPASSWD: ALL/d" /etc/sudoers
        exit 1
    fi

    # Remove the temporary sudoers entry
    sed -i "/$USERNAME ALL=(ALL) NOPASSWD: ALL/d" /etc/sudoers
}

# --- Add HOOKS to mkinitcpoio.conf for numlock on boot / Update initramfs --- 
numlock_auto_on() {
    echo -ne "
    #--------------------#
    # Updating Initramfs #
    #--------------------#
    "
    log_output "Updating initramfs..."
    if ! sed -i 's/^HOOKS\s*=\s*(.*)/HOOKS=(base udev plymouth autodetect modconf numlock block encrypt lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf || \
       ! mkinitcpio -p linux; then
        log_error "Failed to update initramfs" $?
        exit 1
    fi
}

# --- Cleanup Function ---
cleanup() {
    log_output "Cleaning up..."

    # Remove temporary files and directories created during the installation
    rm -rf /mnt/global_functions.sh
    rm -rf /mnt/chroot.sh
    rm -rf /mnt/pkgs.lst
    rm -rf /mnt/aur_pkgs.lst
    rm -rf /mnt/tmp
    rm -rf /mnt/grub-themes
    rm -rf /mnt/Configs
    rm -rf /mnt/hypr.sh

    # Copy log files to the installed system
    cp /var/log/arch_install.log /mnt/var/log/arch_install.log
    cp /var/log/arch_install_error.log /mnt/var/log/arch_install_error.log
}
