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

# Confirm deletion of existing partitions
#echo "This will delete all exisiting partitions on $disk. Proceed? (y/n)"
#read proceed
#if [ "$proceed" != "y" ]; then
#  echo "Exiting."
#  exit 1
#fi

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
reflector -a 48 -c US -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist || { echo "Failed to setup mirrors"; exit 1; }

# Install base packages 
pacstrap -K /mnt base linux linux-firmware linux-headers --noconfirm --needed || { echo "Failed to install base system"; exit 1; }

# Generate fstab
genfstab -U -p /mnt >> /mnt/etc/fstab || { echo "Failed to generate fstab"; exit 1; }

# Save the functions and commands in a script file
cat <<EOF > /mnt/chroot-setup.sh
#!/bin/bash

set -e

# Define functions
set_timezone() {
    ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
    hwclock --systohc
}

set_locale() {
    sed -i "/^#en_US.UTF-8 UTF-8/c\en_US.UTF-8 UTF-8" /etc/locale.gen
    locale-gen
    echo LANG=en_US.UTF-8 > /etc/locale.conf
}

set_hostname() {
    echo archtest > /etc/hostname
}

set_root_password() {
    while true; do
        read -s -p "Set root password: " root_password
        echo
        read -s -p "Confirm root password: " confirm_root_password
        echo

        if [ "$root_password" == "$confirm_root_password" ]; then
            echo "$root_password" | passwd || { echo "Failed to set root password"; exit 1; }
            echo "Root password set successfully."
            break
        else
            echo "Passwords do not match. Please try again."
        fi
    done
}

add_user() {
    read -p "Enter a username: " user
    if [ -z "$user" ]; then
        echo "Username cannot be empty. Exiting."
        exit 1
    fi

    useradd -m -G wheel,power,storage,uucp,network -s /bin/bash "$user" || { echo "Failed to create user"; exit 1; }

    while true; do
        read -s -p "Set $user password: " user_password
        echo
        read -s -p "Confirm $user password: " confirm_user_password
        echo

        if [ "$user_password" == "$confirm_user_password" ]; then
            echo "$user_password" | passwd $user || { echo "Failed to set \$user password"; exit 1; }
            echo "$user password set successfully."
            break
        else
            echo "Passwords do not match. Please try again."
        fi
    done
}

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

# Call defined functions
set_timezone
set_locale
set_hostname

# Update mkinitcpio.conf
sed -i "/^HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/c\HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck)" /etc/mkinitcpio.conf
mkinitcpio -p linux

# Call defined functions
set_root_password
add_user
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

