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
confirm=${confirm,,}
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
proceed=${proceed,,}
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
read -s -p "Confirm encryption password: " confirm_password
echo
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

# Enter chroot environment to execute the setup script
arch-chroot /mnt /bin/bash <<EOF
#!/bin/bash

set -e

# Function to get a list of timezones
get_timezones() {
  local count=1
  find /usr/share/zoneinfo -type f | sed 's|/usr/share/zoneinfo/||' | awk -v cnt=\$count '{print cnt". "$0; cnt++}'
}

# Function to display a page of timezones in columns
display_timezones() {
  local start=\$1
  local end=\$2
  local count=0

  echo "Timezones (\$((start + 1)) to \$end of \${#timezones[@]}):"

  for ((i=start; i<end; i++)); do
    printf "%-${NUMBER_WIDTH}s%-${COLUMN_WIDTH}s" "\${timezones[\$i]}" ""
    count=\$((count + 1))
    
    if ((count % COLS == 0)); then
      echo
    fi
  done

  if ((count % COLS != 0)); then
    echo
  fi
}

# Collect timezones into an array
mapfile -t timezones < <(get_timezones)

# Check if timezones were collected
if [ \${#timezones[@]} -eq 0 ]; then
  echo "No timezones found. Please check the timezone directory and try again."
  exit 1
fi

# Constants
PAGE_SIZE=80
COLS=2  # Number of columns to display
NUMBER_WIDTH=4  # Width for number and dot
COLUMN_WIDTH=2  # Width of each column for timezones

# Display pages of timezones
total_timezones=\${#timezones[@]}
current_page=0

while true; do
  start=\$((current_page * PAGE_SIZE))
  end=\$((start + PAGE_SIZE))
  if ((end > total_timezones)); then
    end=\$total_timezones
  fi

  display_timezones \$start \$end

  echo -ne "Enter the number of your timezone choice from this page, or press Enter to see more timezones: "
  read -r choice

  if [[ "\$choice" =~ ^[0-9]+$ ]]; then
    if [[ "\$choice" -ge 1 && "\$choice" -le \$total_timezones ]]; then
      selected_timezone=\$(echo "\${timezones[\$((choice-1))]}" | awk '{print \$2}')

      echo "Setting timezone to \$selected_timezone"
      ln -sf "/usr/share/zoneinfo/\$selected_timezone" /etc/localtime

      echo "Timezone has been set to \$(readlink -f /etc/localtime)"
      break
    else
      echo "Invalid selection. Please enter a valid number from the displayed list."
    fi
  elif [[ -z "\$choice" ]]; then
    if ((end == total_timezones)); then
      echo "No more timezones to display."
      break
    fi
    current_page=\$((current_page + 1))
  else
    echo "Invalid input. Please enter a number or press Enter to continue."
  fi
done

# Function to get a list of locales from /etc/locale.gen
get_locales() {
  awk '{print NR ". " \$1}' /etc/locale.gen
}

# Function to display a page of locales in columns
display_locales() {
  local start=\$1
  local end=\$2
  local count=0

  echo "Locales (\$((start + 1)) to \$end of \${#locales[@]}):"

  for ((i=start; i<end; i++)); do
    printf "%-${NUMBER_WIDTH}s%-${COLUMN_WIDTH}s" "\${locales[\$i]}" ""
    count=\$((count + 1))
    
    if ((count % COLS == 0)); then
      echo
    fi
  done

  if ((count % COLS != 0)); then
    echo
  fi
}

# Collect locales into an array
locales=($(get_locales))

# Check if locales were collected
if [ \${#locales[@]} -eq 0 ]; then
  echo "No locales found in /etc/locale.gen. Please add some locales and try again."
  exit 1
fi

# Constants
PAGE_SIZE=80
COLS=2  # Number of columns to display
NUMBER_WIDTH=4  # Width for number and dot
COLUMN_WIDTH=2  # Width of each column for locales

# Display pages of locales
total_locales=\${#locales[@]}
current_page=0

while true; do
  start=\$((current_page * PAGE_SIZE))
  end=\$((start + PAGE_SIZE))
  if ((end > total_locales)); then
    end=\$total_locales
  fi

  display_locales \$start \$end

  echo -ne "Enter the number of your locale choice from this page, or press Enter to see more locales: "
  read -r choice

  if [[ "\$choice" =~ ^[0-9]+$ ]]; then
    if [[ "\$choice" -ge 1 && "\$choice" -le \$total_locales ]]; then
      selected_locale=\$(echo "\${locales[\$((choice-1))]}" | awk '{print \$2}')

      if [[ "\$selected_locale" == \#* ]]; then
        uncommented_locale=\$(echo "\$selected_locale" | sed 's/^# //')
        echo "Uncommenting locale: \$uncommented_locale"
        sed -i "/^# \$uncommented_locale/s/^# //" /etc/locale.gen
      else
        echo "Selected locale is already active."
      fi

      locale-gen

      echo "Setting locale to \$selected_locale"
      echo "LANG=\$selected_locale" > /etc/locale.conf

      echo "Locale has been set to \$(cat /etc/locale.conf)"
      break
    else
      echo "Invalid selection. Please enter a valid number from the displayed list."
    fi
  elif [[ -z "\$choice" ]]; then
    if ((end == total_locales)); then
      echo "No more locales to display."
      break
    fi
    current_page=\$((current_page + 1))
  else
    echo "Invalid input. Please enter a number or press Enter to continue."
  fi
done

# Configure hostname
read -p "Enter your hostname: " hostname
echo "\$hostname" > /etc/hostname

# Set root password
while true; do
    read -s -p "Enter root password: " root_password
    echo
    read -s -p "Confirm root password: " confirm_password
    echo
    if [ "\$root_password" != "\$confirm_password" ]; then
        echo "Passwords do not match. Try again."
    else
        echo "Setting root password..."
        echo "root:\$root_password" | chpasswd
        break
    fi
done

EOF

chmod +x /mnt/chroot-setup.sh || { echo "Failed to make chroot setup script executable"; exit 1; }

# Enter chroot environment to execute the setup script
arch-chroot /mnt /chroot-setup.sh || { echo "Failed to chroot and run setup script"; exit 1; }

echo -ne "
+-------------------+
| Installation Done |
+-------------------+
"

# Finish up
umount -R /mnt || { echo "Failed to unmount partitions"; exit 1; }
reboot
