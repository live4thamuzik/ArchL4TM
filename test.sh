#!/bin/bash

# Exit on any command failure
set -e

# Log all output to a log file
exec > >(tee -a /var/log/arch_install.log) 2>&1

echo -ne "
+--------------------------------+
| Automated Arch Linux Installer |
+--------------------------------+
"

echo -ne "

 █████╗ ██████╗  ██████╗██╗  ██╗    ██╗██╗  ██╗████████╗███╗   ███╗
██╔══██╗██╔══██╗██╔════╝██║  ██║    ██║██║  ██║╚══██╔══╝████╗ ████║
███████║██████╔╝██║     ███████║    ██║███████║   ██║   ██╔████╔██║
██╔══██║██╔══██╗██║     ██╔══██║    ██║╚════██║   ██║   ██║╚██╔╝██║
██║  ██║██║  ██║╚██████╗██║  ██║    ███████╗██║   ██║   ██║ ╚═╝ ██║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝    ╚══════╝╚═╝   ╚═╝   ╚═╝     ╚═╝
                                                                   
"

echo -ne "
+--------------------+
| Drive Preparation  |
+--------------------+
"
# List Disks
fdisk -l

# Select Disk
read -p "Enter the disk (e.g., /dev/sda): " disk

# Validate Disk Path
if [ ! -b "$disk" ]; then
  echo "Invalid disk: $disk. Exiting."
  exit 1
fi

# Confirm Disk Selection
echo "You have selected $disk. Is this correct? (Y/n)"
read confirm

# Convert input to lowercase for easier comparison
confirm=${confirm,,}

# If the input is empty or 'y', proceed; otherwise, exit
if [ "$confirm" != "y" ] && [ -n "$confirm" ]; then
  echo "Exiting."
  exit 1
fi

# List current partitions
echo "Current partitions on $disk:"
fdisk -l "$disk"

# Confirm deletion of existing partitions
echo "This will delete all existing partitions on $disk. Proceed? (Y/n)"
read proceed

# Convert input to lowercase for easier comparison
proceed=${proceed,,}

# If the input is neither 'y' nor empty, exit
if [ "$proceed" != "y" ] && [ -n "$proceed" ]; then
  echo "Exiting."
  exit 1
fi

# Remove existing partitions and clear old signatures
echo -ne "d\nw" | fdisk "$disk" || { echo "Failed to delete partitions"; exit 1; }
dd if=/dev/zero of="$disk" bs=512 count=1 conv=notrunc || { echo "Failed to wipe disk"; exit 1; }

# Create new GPT partition table and partitions with types
echo "Creating new GPT table and partitions on $disk"
(
echo "g"       # Create new GPT table
echo "n"       # Add new partition
echo ""        # Default partition number 1
echo ""        # Default to first sector
echo "+2G"     # Partition 1 size 2GB
echo "t"       # Change partition type
echo "1"       # Set type to EFI System
echo "n"       # Add new partition
echo ""        # Default to partition number 2
echo ""        # Default to first sector
echo "+5G"     # Partition 2 size 5GB
echo "n"       # Add new partition
echo ""        # Default to partition number 3
echo ""        # Default to first sector
echo ""        # Use remaining space
echo "t"       # Change partition type
echo "3"       # Partition 3
echo "44"      # Set type to LVM
echo "w"       # Write changes
) | fdisk "$disk" || { echo "Failed to create partitions"; exit 1; }
partprobe "$disk" || { echo "Failed to re-read partition table"; exit 1; }

echo -ne "
+-------------------+
| Perform LVM setup |
+-------------------+
"
# Format partition 1 as FAT32
mkfs.fat -F32 "${disk}1" || { echo "Failed to format ${disk}1"; exit 1; }

# Format partition 2 as ext4
mkfs.ext4 "${disk}2" || { echo "Failed to format ${disk}2"; exit 1; }

# Ask user to set encryption password
read -s -p "Enter encryption password: " password
echo

# Confirm encryption password
read -s -p "Confirm encryption password: " confirm_password
echo

# Check if passwords match
if [ "$password" != "$confirm_password" ]; then
  echo "Passwords do not match. Exiting."
  exit 1
fi

# Setup encryption on partition 3 using LUKS
echo "$password" | cryptsetup luksFormat "${disk}3" || { echo "Failed to format LUKS partition"; exit 1; }

# Open LUKS partition
echo "$password" | cryptsetup open --type luks --batch-mode "${disk}3" lvm || { echo "Failed to open LUKS partition"; exit 1; }

# Create physical volume for LVM on partition 3 with data alignment 1m
pvcreate /dev/mapper/lvm || { echo "Failed to create physical volume"; exit 1; }

# Create volume group called volgroup0 on partition 3
vgcreate volgroup0 /dev/mapper/lvm || { echo "Failed to create volume group"; exit 1; }

# Create logical volumes
lvcreate -L 100GB volgroup0 -n lv_root || { echo "Failed to create logical volume lv_root"; exit 1; }
lvcreate -l 100%FREE volgroup0 -n lv_home || { echo "Failed to create logical volume lv_home"; exit 1; }

# Load kernel module
modprobe dm_mod

# Scan system for volume groups
vgscan

# Activate volume group
vgchange -ay || { echo "Failed to activate volume group"; exit 1; }

# Format root volume
mkfs.ext4 /dev/volgroup0/lv_root || { echo "Failed to format root volume"; exit 1; }

# Mount root volume
mount /dev/volgroup0/lv_root /mnt || { echo "Failed to mount root volume"; exit 1; }

# Create /boot directory and mount partition 2
mkdir -p /mnt/boot
mount "${disk}2" /mnt/boot || { echo "Failed to mount /boot"; exit 1; }

# Format home volume
mkfs.ext4 /dev/volgroup0/lv_home || { echo "Failed to format home volume"; exit 1; }

# Create /home directory and mount home volume
mkdir -p /mnt/home
mount /dev/volgroup0/lv_home /mnt/home || { echo "Failed to mount /home"; exit 1; }

# Ensure /mnt/etc exists
mkdir -p /mnt/etc

echo "Setup completed successfully."

# Install prereq packages
echo -ne "
+---------------------------
| Installing Prerequisites |
+--------------------------+
"
pacman -S --noconfirm pacman-contrib reflector rsync || { echo "Failed to install prerequisites"; exit 1; }

# Configure pacman for faster downloads
echo -ne "
+-----------------------------------------+
| Setting up mirrors for faster downloads |
+-----------------------------------------+
"
# Backup mirrorlist
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup || { echo "Failed to backup mirrorlist"; exit 1; }
reflector -a 48 -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist || { echo "Failed to setup mirrors"; exit 1; }

# Install base packages 
pacstrap -K /mnt base linux linux-firmware linux-headers --noconfirm --needed || { echo "Failed to install base system"; exit 1; }

# Generate fstab
genfstab -U -p /mnt >> /mnt/etc/fstab || { echo "Failed to generate fstab"; exit 1; }

echo -ne "
+----------------+
| Setting locale |
+----------------+
"
# Function to get a list of locales from /etc/locale.gen
get_locales() {
  awk '{print NR ". " $1}' /mnt/etc/locale.gen
}

# Collect locales into an array
locales=($(get_locales))

# Check if locales were collected
if [ ${#locales[@]} -eq 0 ]; then
  echo "No locales found in /etc/locale.gen. Please add some locales and try again."
  exit 1
fi

# Constants
PAGE_SIZE=80
COLS=2  # Number of columns to display
NUMBER_WIDTH=4  # Width for number and dot
COLUMN_WIDTH=2  # Width of each column for locales

# Function to display a page of locales in columns
display_page() {
  local start=$1
  local end=$2
  local count=0

  echo "Locales ($((start + 1)) to $end of ${#locales[@]}):"

  for ((i=start; i<end; i++)); do
    # Print locales in columns with minimized gap
    printf "%-${NUMBER_WIDTH}s%-${COLUMN_WIDTH}s" "${locales[$i]}" ""
    count=$((count + 1))
    
    if ((count % COLS == 0)); then
      echo
    fi
  done

  # Add a newline at the end if the last line isn't fully filled
  if ((count % COLS != 0)); then
    echo
  fi
}

# Display pages of locales
total_locales=${#locales[@]}
current_page=0

while true; do
  start=$((current_page * PAGE_SIZE))
  end=$((start + PAGE_SIZE))
  if ((end > total_locales)); then
    end=$total_locales
  fi

  display_page $start $end

  # Prompt user for selection or continue
  echo -ne "Enter the number of your locale choice from this page, or press Enter to see more locales: "
  read -r choice

  # Check if user made a choice
  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    if [[ "$choice" -ge 1 && "$choice" -le $total_locales ]]; then
      # Extract the selected locale
      selected_locale=$(echo "${locales[$((choice-1))]}" | awk '{print $2}')

      # Check if the selected locale is commented
      if [[ "$selected_locale" == \#* ]]; then
        # Remove the leading '#' for uncommenting
        uncommented_locale=$(echo "$selected_locale" | sed 's/^# //')
        echo "Uncommenting locale: $uncommented_locale"
        sed -i "/^# $uncommented_locale/s/^# //" /mnt/etc/locale.gen
      else
        echo "Selected locale is already active."
      fi

      # Run locale-gen to apply the changes
      locale-gen

      # Set the locale in /etc/locale.conf
      echo "Setting locale to $selected_locale"
      echo "LANG=$selected_locale" > /mnt/etc/locale.conf

      # Verify locale setting
      echo "Locale has been set to $(cat /mnt/etc/locale.conf)"
      break
    else
      echo "Invalid selection. Please enter a valid number from the displayed list."
    fi
  elif [[ -z "$choice" ]]; then
    # Continue to the next page
    if ((end == total_locales)); then
      echo "No more locales to display."
      break
    fi
    current_page=$((current_page + 1))
  else
    echo "Invalid input. Please enter a number or press Enter to continue."
  fi
done

echo -ne "
+------------------+
| Setting timezone |
+------------------+
"
# Function to get a list of timezones
get_timezones() {
  local count=1
  find /mnt/usr/share/zoneinfo -type f | sed 's|/mnt/usr/share/zoneinfo/||' | awk -v cnt=$count '{print cnt". "$0; cnt++}'
}

# Collect timezones into an array
mapfile -t timezones < <(get_timezones)

# Check if timezones were collected
if [ ${#timezones[@]} -eq 0 ]; then
  echo "No timezones found. Please check the timezone directory and try again."
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

  # Add a newline at the end if the last line isn't fully filled
  if ((count % COLS != 0)); then
    echo
  fi
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

  display_page $start $end

  # Prompt user for selection or continue
  echo -ne "Enter the number of your timezone choice from this page, or press Enter to see more timezones: "
  read -r choice

  # Check if user made a choice
  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    if [[ "$choice" -ge 1 && "$choice" -le $total_timezones ]]; then
      # Extract the selected timezone
      selected_timezone=$(echo "${timezones[$((choice-1))]}" | awk '{print $2}')

      # Set timezone
      echo "Setting timezone to $selected_timezone"
      ln -sf "/mnt/usr/share/zoneinfo/$selected_timezone" /mnt/etc/localtime

      # Verify timezone setting
      echo "Timezone has been set to $(readlink -f /mnt/etc/localtime)"
      break
    else
      echo "Invalid selection. Please enter a valid number from the displayed list."
    fi
  elif [[ -z "$choice" ]]; then
    # Continue to the next page
    if ((end == total_timezones)); then
      echo "No more timezones to display."
      break
    fi
    current_page=$((current_page + 1))
  else
    echo "Invalid input. Please enter a number or press Enter to continue."
  fi
done

echo -ne "
+--------------+
| Set hostname |
+--------------+
"

set_hostname() {
  # Prompt user to enter hostname
  read -p "Enter your desired hostname: " hostname

  # Ensure hostname is not empty
  if [ -z "$hostname" ]; then
    echo "Hostname cannot be empty. Exiting."
    exit 1
  fi

  # Write the hostname to /mnt/etc/hostname
  echo "$hostname" > /mnt/etc/hostname || { echo "Failed to set hostname"; exit 1; }

  echo "Hostname set to $hostname"
}

# Call the function to set hostname
set_hostname

echo -ne "
+----------------+
| Create new user |
+----------------+
"

create_user() {
    # Prompt for username
    read -p "Enter a username: " user

    # Validate username (non-empty, doesn't already exist)
    if [ -z "$user" ]; then
        echo "Username cannot be empty. Please try again."
        return 1  # Indicate failure to the calling script
    elif id "$user" &>/dev/null; then
        echo "User '$user' already exists. Please choose a different username."
        return 1
    fi

    # Create user on the host system
    useradd -m -G wheel,power,storage,uucp,network -s /bin/bash "$user" || {
        echo "Failed to create user '$user' on the host system."
        return 1
    }

    # Prompt for and set password (with confirmation)
    while true; do
        read -s -p "Enter password for '$user': " password
        echo
        read -s -p "Confirm password: " confirm_password
        echo

        if [ "$password" == "$confirm_password" ]; then
            echo "$password" | passwd --stdin "$user" || {
                echo "Failed to set password for '$user'."
                return 1
            }
            break  # Exit the loop if passwords match and are set successfully
        else
            echo "Passwords do not match. Please try again."
        fi
    done

    # Ensure home directory exists within the new system
    mkdir -p /mnt/home/"$user"

    # Set ownership and permissions for the home directory within the new system
    chown -R "$user":"$user" /mnt/home/"$user"
    chmod 700 /mnt/home/"$user"

    echo "User '$user' created successfully with password set."
    return 0  # Indicate success
}

# Call the function to create the user
if ! create_user; then
    echo "User creation failed. Exiting."
    exit 1
fi

# Call the function to create the user
if ! create_user; then
    echo "User creation failed. Exiting."
    exit 1
fi

# Save the functions and commands in a script file
cat <<EOF > /mnt/chroot-setup.sh
#!/bin/bash

set -e

# Define functions

set_root_password() {
    while true; do
        read -s -p "Set root password: " root_password
        echo
        read -s -p "Confirm root password: " confirm_root_password
        echo

        if [ "$root_password" == "$confirm_root_password" ]; then
            # Attempt to set root password non-interactively
            echo "Attempting to set root password..."
            if echo "$root_password" | passwd --stdin root 2>/dev/null; then
                echo "Root password set successfully."
                break
            elif echo "$root_password" | chpasswd 2>/dev/null; then
                echo "Root password set successfully."
                break
            else
                # Fallback to interactive passwd
                echo "Non-interactive methods failed. Please set the root password interactively."
                passwd
                if [ $? -eq 0 ]; then
                    echo "Root password set successfully."
                    break
                else
                    echo "Failed to set root password interactively. Please try again."
                fi
            fi
        else
            echo "Passwords do not match. Please try again."
        fi
    done
}

# Example of calling the functions
set_root_password

update_sudoers() {
    cp /etc/sudoers /etc/sudoers.backup
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/c\ %wheel ALL=(ALL:ALL) ALL' /etc/sudoers
    echo 'Defaults targetpw' >> /etc/sudoers
    visudo -c || { echo "Syntax error in sudoers. Restoring backup."; cp /etc/sudoers.backup /etc/sudoers; exit 1; }
}

install_grub() {
    mkdir -p /boot/EFI
    mount /dev/${disk}1 /boot/EFI
    grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
    grub-mkconfig -o /boot/grub/grub.cfg
}

# Configure pacman
echo "Configuring pacman"
sed -i "/^#Color/c\Color\nILoveCandy" /etc/pacman.conf
sed -i "/^#VerbosePkgLists/c\VerbosePkgLists" /etc/pacman.conf
sed -i "/^#ParallelDownloads/c\ParallelDownloads = 5" /etc/pacman.conf
sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf

# Install additional needed packages
echo "Installing: archlinux-keyring base-devel networkmanager lvm2 pipewire btop man-db man-pages texinfo tldr bash-completion openssh git parallel neovim grub efibootmgr dosfstools os-prober mtools python "
pacman -Sy --noconfirm --needed archlinux-keyring base-devel networkmanager lvm2 pipewire btop man-db man-pages texinfo tldr bash-completion openssh git parallel neovim grub efibootmgr dosfstools os-prober mtools python || { echo "Failed to install packages"; exit 1; }

# Determine processor type and install microcode
proc_type=\$(lscpu | grep -oP '^Vendor ID:\s+\K\w+')
if [ "\$proc_type" = "GenuineIntel" ]; then
    echo "Installing Intel microcode"
    pacman -S --noconfirm --needed intel-ucode || { echo "Failed to install Intel microcode"; exit 1; }
elif [ "\$proc_type" = "AuthenticAMD" ]; then
    echo "Installing AMD microcode"
    pacman -S --noconfirm --needed amd-ucode || { echo "Failed to install AMD microcode"; exit 1; }
fi

# Enable services
systemctl enable NetworkManager.service || { echo "Failed to enable NetworkManager"; exit 1; }
echo "NetworkManager enabled"
systemctl enable fstrim.timer || { echo "Failed to enable SSD support"; exit 1; }
echo "SSD support enabled"

# Update mkinitcpio.conf
sed -i "/^HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/c\HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck)" /etc/mkinitcpio.conf
mkinitcpio -p linux

# Call defined functions
update_sudoers
install_grub

# Detect NVIDIA GPUs
readarray -t dGPU < <(lspci -k | grep -E "(VGA|3D)" | grep -i nvidia)

# Check if any NVIDIA GPUs were found
if [ \${#dGPU[@]} -gt 0 ]; then
    echo "NVIDIA GPU(s) detected:"
    for gpu in "\${dGPU[@]}"; do
        echo "  \$gpu"
    done

    # Install NVIDIA drivers and related packages
    pacman -S --noconfirm --needed nvidia-dkms libglvnd nvidia-utils opencl-nvidia lib32-libglvnd lib32-nvidia-utils lib32-opencl-nvidia nvidia-settings || { echo "Failed to install NVIDIA packages"; exit 1; }

    # Add NVIDIA modules to initramfs
    sed -i '/^MODULES=()/c\MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)' /etc/mkinitcpio.conf || { echo "Failed to add NVIDIA modules to initramfs"; exit 1; }
    mkinitcpio -p linux || { echo "Failed to regenerate initramfs"; exit 1; }

    # Update GRUB configuration
    sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/c\GRUB_CMDLINE_LINUX_DEFAULT="quiet cryptdevice=/dev/'${disk}'3:volgroup0 nvidia_drm_modeset=1 loglevel=3"' /etc/default/grub || { echo "Failed to update GRUB configuration"; exit 1; }
    grub-mkconfig -o /boot/grub/grub.cfg || { echo "Failed to regenerate GRUB configuration"; exit 1; }

else
    echo "No NVIDIA GPUs detected."
fi
EOF

chmod +x /mnt/chroot-setup.sh

# Execute the script inside chroot
arch-chroot /mnt ./chroot-setup.sh
