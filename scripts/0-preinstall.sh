#!/usr/bin/env bash
#
#github-action genshdoc
#
# @file Preinstall
# @brief Contains the steps necessary to configure and pacstrap the install to selected drive. 
echo -ne "
-------------------------------------------------------------------------
                    Automated Arch Linux Installer
-------------------------------------------------------------------------

Setting up mirrors for optimal download
"
source $CONFIGS_DIR/setup.conf
iso=$(curl -4 ifconfig.co/country-iso)
timedatectl set-ntp true
pacman -S --noconfirm archlinux-keyring #update keyrings to latest to prevent packages failing to install
pacman -S --noconfirm --needed pacman-contrib terminus-font
setfont ter-v22b
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
pacman -S --noconfirm --needed reflector rsync grub
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
echo -ne "
-------------------------------------------------------------------------
                    Setting up $iso mirrors for faster downloads
-------------------------------------------------------------------------
"
reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
mkdir /mnt &>/dev/null # Hiding error message if any
echo -ne "
-------------------------------------------------------------------------
                    Installing Prerequisites
-------------------------------------------------------------------------
"
pacman -S --noconfirm --needed gptfdisk btrfs-progs glibc
echo -ne "
-------------------------------------------------------------------------
                    Drive Preperation
-------------------------------------------------------------------------
"
# Function to check for old signatures and remove them
remove_old_signature() {
  dd if=/dev/zero of="$1" bs=512 count=1 conv=notrunc
}

# Function to perform LVM setup
setup_lvm() {
  # Format partition 1 as fat32
  mkfs.fat -F32 "/dev/${disk}1"

  # Format partition 2 as ext4
  mkfs.ext4 "/dev/${disk}2"

  # Create physical volume for LVM on partition 3 with data alignment 1m
  pvcreate --dataalignment 1m "/dev/${disk}3"

  # Create volume group called volgroup0 on partition 3
  vgcreate volgroup0 "/dev/${disk}3"

  # Create logical volumes
  lvcreate -L 30GB volgroup0 -n lv_root
  lvcreate -l +100%FREE volgroup0 -n lv_home

  # Load kernel module
  modprobe dm_mod

  # Scan system for volume groups
  vgscan

  # Activate volume group
  vgchange -ay

  # Format root volume
  mkfs.ext4 /dev/volgroup0/lv_root

  # Mount root volume
  mount /dev/volgroup0/lv_root /mnt

  # Create /boot directory and mount partition 2
  mkdir /mnt/boot
  mount "/dev/${disk}2" /mnt/boot

  # Format home volume
  mkfs.ext4 /dev/volgroup0/lv_home

  # Create /home directory and mount home volume
  mkdir /mnt/home
  mount /dev/volgroup0/lv_home /mnt/home

  # Create /etc directory
  mkdir /mnt/etc

  # Generate fstab
  #genfstab -U -p /mnt >> /mnt/etc/fstab
}

# Function to setup encryption and perform LVM setup
setup_encryption() {
  # Format partition 1 as fat32
  mkfs.fat -F32 "/dev/${disk}1"

  # Format partition 2 as ext4
  mkfs.ext4 "/dev/${disk}2"

  # Setup encryption on partition 3 using luks
  cryptsetup luksFormat "/dev/${disk}3"
  echo "YES" | cryptsetup open --type luks "/dev/${disk}3" lvm

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

  # Use luks to open partition 3 and name it lvm
  cryptsetup luksOpen "/dev/${disk}3" lvm

  # Ask user for encryption password
  read -s -p "Enter encryption password: " entered_password
  echo

  # Check if entered password is correct
  if [ "$entered_password" != "$password" ]; then
    echo "Incorrect encryption password. Exiting."
    exit 1
  fi

  setup_lvm
}

# List disks
fdisk -l

# Select disk
read -p "Enter the disk (e.g., /dev/sda): " disk

# Use fdisk to delete all partitions
echo -e "d\nw" | fdisk "/dev/${disk}"

# Ask user if they want to use encryption
read -p "Do you want to use encryption? (y/n): " encrypt_option

if [ "$encrypt_option" == "y" ]; then
  # Encryption selected
  echo "Encryption selected."
  echo -e "g\nn\n1\n\n+1G\na\n1\nn\n2\n\n+1G\nn\n3\n\n\nt\n1\n1\nt\n3\n31\nw" | fdisk "/dev/${disk}"
  setup_encryption
else
  # No encryption selected
  echo "No encryption selected."
  echo -e "g\nn\n1\n\n+1G\na\n1\nn\n2\n\n\nt\n1\n1\nt\n2\n44\nw" | fdisk "/dev/${disk}"
  setup_lvm
fi

echo "Setup completed successfully."
echo -ne "
-------------------------------------------------------------------------
                    Arch Install on Main Drive
-------------------------------------------------------------------------
"
pacstrap -K /mnt base base-devel linux linux-firmware linux-firmware-marvell sof-firmware linux-headers lvm2 vim nano sudo archlinux-keyring wget libnewt man-db man-pages texinfo --noconfirm --needed
echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf
cp -R ${SCRIPT_DIR} /mnt/root/ArchL4TM
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

genfstab -L /mnt >> /mnt/etc/fstab
echo " 
  Generated /etc/fstab:
"
cat /mnt/etc/fstab
echo -ne "
-------------------------------------------------------------------------
                    GRUB BIOS Bootloader Install & Check
-------------------------------------------------------------------------
"
if [[ ! -d "/sys/firmware/efi" ]]; then
    grub-install --boot-directory=/mnt/boot ${DISK}
else
    pacstrap /mnt efibootmgr --noconfirm --needed
fi
echo -ne "
-------------------------------------------------------------------------
                    Checking for low memory systems <8G
-------------------------------------------------------------------------
"
TOTAL_MEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[  $TOTAL_MEM -lt 8000000 ]]; then
    # Put swap into the actual system, not into RAM disk, otherwise there is no point in it, it'll cache RAM into RAM. So, /mnt/ everything.
    mkdir -p /mnt/opt/swap # make a dir that we can apply NOCOW to to make it btrfs-friendly.
    chattr +C /mnt/opt/swap # apply NOCOW, btrfs needs that.
    dd if=/dev/zero of=/mnt/opt/swap/swapfile bs=1M count=2048 status=progress
    chmod 600 /mnt/opt/swap/swapfile # set permissions.
    chown root /mnt/opt/swap/swapfile
    mkswap /mnt/opt/swap/swapfile
    swapon /mnt/opt/swap/swapfile
    # The line below is written to /mnt/ but doesn't contain /mnt/, since it's just / for the system itself.
    echo "/opt/swap/swapfile	none	swap	sw	0	0" >> /mnt/etc/fstab # Add swap to fstab, so it KEEPS working after installation.
fi
echo -ne "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 1-setup.sh
-------------------------------------------------------------------------
"