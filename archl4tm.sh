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
echo "You have selected $disk. Is this correct? (y/n)"
read confirm
if [ "$confirm" != "y" ]; then
  echo "Exiting."
  exit 1
fi

# List current partitions
echo "Current partitions on $disk:"
fdisk -l "$disk"

# Confirm deletion of existing partitions
echo "This will delete all exisiting partitions on $disk. Proceed? (y/n)"
read proceed
if [ "$proceed" != "y" ]; then
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
echo "1"       # Partition 1
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

# Generate fstab
genfstab -U -p /mnt >> /mnt/etc/fstab || { echo "Failed to generate fstab"; exit 1; }

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
reflector -a 48 -c US -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist || { echo "Failed to setup mirrors"; exit 1; }

# Install base packages 
echo -ne "
+-------------------------------------------------+
| Install base linux linux-firmware linux-headers |
+-------------------------------------------------+
"
pacstrap -K /mnt base linux linux-firmware linux-headers --noconfirm --needed || { echo "Failed to install base system"; exit 1; }

# Change root to /mnt and run further commands
echo "Changing root directory"
cat <<EOF | arch-chroot /mnt
# Configure pacman
echo "Configuring pacman"
sed -i "/^#Color/c\Color\nILoveCandy" /etc/pacman.conf
sed -i "/^#VerbosePkgLists/c\VerbosePkgLists" /etc/pacman.conf
sed -i "/^#ParallelDownloads/c\ParallelDownloads = 5" /etc/pacman.conf
sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf

# Install additional needed packages
echo -ne "
+---------------------+
| Installing packages |
+---------------------+
"
echo "Installing: archlinux-keyring base-devel networkmanager lvm2 pipewire btop man-db man-pages texinfo tldr bash-completion openssh git parallel neovim grub efibootmgr dosfstools os-prober mtools python "
pacman -Sy --noconfirm --needed archlinux-keyring base-devel networkmanager lvm2 pipewire btop man-db man-pages texinfo tldr bash-completion openssh git parallel neovim grub efibootmgr dosfstools os-prober mtools python || { echo "Failed to install packages"; exit 1; }

# Install cpu microcode
echo -ne "
+----------------------+
| Installing Microcode |
+----------------------+
"
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
echo -ne "
+-----------------------------+
| Enabling Essential Services |
+-----------------------------+
"
systemctl enable NetworkManager.service || { echo "Failed to enable NetworkManager"; exit 1; }
echo "  NetworkManager enabled"
systemctl enable fstrim.timer || { echo "Failed to enable SSD support"; exit 1; }
echo "  SSD support enabled"

# Set timezone and locale
echo -ne "
+-------------------------+
| Set Timezone and Locale |
+-------------------------+
"
# Select a timezone from the list, confirm it, and set the timezone
read -p "Select a timezone (e.g., 'America/New_York'): " timezone && \
echo "You have selected: $timezone" && \
read -p "Do you want to set this timezone? (yes/no): " confirm && \
[[ $confirm == "yes" ]] && \
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime && \
echo "Timezone set to: $timezone" || \
echo "Timezone change aborted."

# Read available locales, let the user select one, confirm the selection, and update the locale
locales=$(grep -oP '^\s*\K\w+_\w+\.\w+' /etc/locale.gen) && \
echo "Available locales:" && \
select locale in $locales; do \
    if [[ -n $locale ]]; then \
        break; \
    else \
        echo "Invalid selection. Please try again."; \
    fi \
done && \
echo "You have selected: $locale" && \
read -p "Do you want to set this locale? (yes/no): " confirm && \
[[ $confirm == "yes" ]] && \
sed -i "s/^#\s*$locale/$locale/" /etc/locale.gen && \
locale-gen && \
echo "Locale set to: $locale" || \
echo "Locale change aborted."

# Set hostname
echo -ne "
+--------------+
| Set Hostname |
+--------------+
"
# Set hostname
read -p "Enter hostname: " hostname

if [ -z "$hostname" ]; then
  echo "Hostname cannot be empty, Exiting."
  exit 1
fi

echo "$hostname" > /etc/hostname || { echo "Failed to set hostname"; exit 1; }
echo "Hostname set to: $hostname"

# Add hooks
echo -ne "
+-----------------------+
| Adding hooks initrams |
+-----------------------+
"
# Update mkinitcpio.conf
sed -i "/^HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/c\HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck)" /etc/mkinitcpio.conf
mkinitcpio -p linux

# Set root password
echo -ne"
+-------------------+
| Set Root Password |
+-------------------+
"
while true; do
  read -s -p "Set root password: " root_password
  echo
  read -s -p "Confirm root password: " confirm_root_password
  echo

  if [ "$root_password" == "$confirm_root_password" ]; then
    echo "root_password" | passwd || { echo "Failed to set root password"; exit 1; }
    echo "root password set successfully."
    break
  else
    echo "Passwords do not match. Please try again."
  fi
done

# Add user
echo -ne "
+-------------+
| Create User |
+-------------+
"
read -p "Enter a username: " user

if [ -z "$user" ]; then
  echo "Username cannot be empty. Exiting."
  exit 1
fi

useradd -m -G wheel,power,storage,uucp,network -s /bin/bash "$user" || {echo "Failed to create user; exit 1; }

# Set user password
echo -ne "
+------------------------+
| Set Password for $user |
+------------------------+
"
while true; do
  read -s -p "Set $user password: " user_password
  echo
  read -s -p "Confirm $user password: " confirm_user_password
  echo

  if [ "$user_password" == "$confirm_user_password" ]; then
    echo "user_password" | passwd $user || { echo "Failed to set $user password"; exit 1; }
    echo "$user password set successfully."
    break
  else
    echo "Passwords do not match. Please try again."
  fi
done

# Enable wheel group and enforce root password when sudo is called
echo -ne "
+----------------+
| Update Sudoers |
+----------------+
"
# Backup sudoers file
cp /etc/sudoers /etc/sudoers.backup { echo "Failed to backup sudoers file."; exit 1; }

# Modify sudoers file to uncomment wheel group and add line Defaults targetpw
{
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/c\ %wheel ALL=(ALL:ALL) ALL' /etc/sudoers || { echo "Failed to enable wheel group"; exit 1; }
echo 'Defaults targetpw' >> /etc/sudoers || { echo "Failed to add targetpw": exit 1; }
}

# Check for syntax errors
visudo -c || { echo "Syntax error found. Restoring original file."; cp /etc/sudoers.backup /etc/sudoers; exit 1; }

# Install and configure GRUB
echo -ne "
+--------------+
| Install GRUB |
+--------------+
"
# Make EFI directory
mkdir -p /boot/EFI

# Mount EFI partition
mount /dev/${disk}1 /boot/EFI

# Install GRUB to EFI system partition
grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck || { echo "Failed to install GRUB"; exit 1; }

# Add locale to GRUb for GRUB messages
cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo || { "Failed to copy locale into grub"; exit 1; }

# Update /etc/default/grub
sed -i '/^GRUB_DEFAULT=/c\GRUB_DEFAULT=saved
/^GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/c\^GRUB_CMDLINE_LINUX_DEFAULT="quiet cryptdevice=/dev/${disk}3:volgroup0 loglevel=3"
/^#GRUB_ENABLE_CRYPT_DISK=y/c\GRUB_ENABLE_CRYPT_DISK=y
/^#GRUB_SAVEDEFAULT=true/c\GRUB_SAVEDEFAULT=true' /etc/default/grub

# Make GRUB configuration file
grub-mkconfig -o /boot/grub/grub.cfg || { echo "Failed to install GRUB"; exit 1; }

# Grant User ownership of /boot/grub/themes folder
chown "$user" -R /boot/grub/themes

# Check for NVIDIA GPU
echo -ne "
+--------------+
| NVIDIA Check |
+--------------+
"
# Detect NVIDIA GPUs
readarray -t dGPU < <(lspci -k | grep -E "(VGA|3D)" | grep -i nvidia)

# Check if any NVIDIA GPUs were found
if [ ${#dGPU[@]} -gt 0 ]; then
    echo "NVIDIA GPU(s) detected:"
    for gpu in "${dGPU[@]}"; do
        echo "  $gpu"
    done

    echo -ne "
    +----------------+
    | Install NVIDIA |
    +----------------+
    "
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


# Exiting chroot
exit

EOF

umount -R /mnt

echo -ne "
+---------------------------------------------------------+
| Installation successfull. Remove boot media and reboot. |
+---------------------------------------------------------+
