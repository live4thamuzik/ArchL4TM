#!/bin/bash

# Exit on any command failure
set -e

# Log all output to a log file
exec > >(tee -a /var/log/arch_install.log) 2>&1

echo -ne "
+--------------------------------+
| Arch Linux Installation Script |
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

# Logging
log_error() {
    local message="$1"
    local err_code="$2"
    echo "Error: $message (exit code: $err_code)" >&2
    # Add more error handling logic if needed (e.g., send an email alert)
}

# Create username and password
newuser () {
    # Loop through user input until the user gives a valid username
    while true
    do 
            read -r -p "Enter a username: " username
            if [[ "${username,,}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]
            then 
                    break
            fi 
            echo "Invalid username."
    done 
    export USERNAME=$username

    while true
    do
        read -rs -p "Set a password: " PASSWORD1
        echo -ne "\n"
        read -rs -p "Confirm password: " PASSWORD2
        echo -ne "\n"
        if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
            break
        else
            echo -ne "ERROR! Passwords do not match. \n"
        fi
    done
    export PASSWORD=$PASSWORD1

     # Loop through user input until the user gives a valid hostname, but allow the user to force save 
    while true
    do 
            read -r -p "Enter a hostname: " name_of_machine
            # hostname regex (!!couldn't find spec for computer name!!)
            if [[ "${name_of_machine,,}" =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]]
            then 
                    break 
            fi 
            # if validation fails allow the user to force saving of the hostname
            read -r -p "Hostname doesn't seem correct. Do you still want to save it? (y/n)" force 
            if [[ "${force,,}" = "y" ]]
            then 
                    break 
            fi 
    done 
    export NAME_OF_MACHINE=$name_of_machine
}

# Set root password
rootpasswd () {
    while true
    do
        read -rs -p "Set root password: " PASSWD1
        echo -ne "\n"
        read -rs -p "confirm password: " PASSWD2
        echo -ne "\n"
        if [[ "$PASSWD1" == "$PASSWD2" ]]; then
            break
        else
            echo -ne "ERROR! Passwords do not match. \n"
        fi
    done
    export PASSWD=$PASSWD1
}


echo -ne "
+-------------------+
| Drive Preparation |
+-------------------+
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
#shred -n 1 -v "$disk"  # Overwrite the disk once with random data
#cryptsetup luksDump "$disk"  # Check for any existing LUKS devices

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

# Create /boot/EFI directory and mount partition 1
mkdir -p /mnt/boot/EFI
mount "${disk}1" /mnt/boot/EFI || { echo "Failed to mount /boot"; exit 1; }

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
+--------------------------+
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

echo -ne "
+------------------+
| Running Pacstrap |
+------------------+
"

# Install base packages 
pacstrap -K /mnt base linux linux-firmware linux-headers --noconfirm --needed || { echo "Failed to install base system"; exit 1; }


echo -ne "
+--------------------------+
| Create user and hostname |
+--------------------------+
"
# Call functions
newuser


echo -ne "
+-------------------+
| Set root password |
+-------------------+
"
rootpasswd


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

   # Set timezone within the chroot
   arch-chroot /mnt /bin/bash -c "ln -sf /usr/share/zoneinfo/$selected_timezone /etc/localtime"

   # Verify timezone setting
   arch-chroot /mnt /bin/bash -c "echo \"Timezone has been set to \$(readlink -f /etc/localtime)\""
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
+----------------+
| Running chroot |
+----------------+
"

# Save the functions and commands in a script file
cat <<EOF > /mnt/chroot-setup.sh
#!/bin/bash

set -e

# Define functions

# Get disk value from the first command-line argument
disk="$1" 

update_sudoers() {
    cp /etc/sudoers /etc/sudoers.backup
    sed -i 's/^# *%wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    echo 'Defaults targetpw' >> /etc/sudoers
    visudo -c || { echo "Syntax error in sudoers. Restoring backup."; cp /etc/sudoers.backup /etc/sudoers; exit 1; }
}

install_grub() {
    grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck || {
        echo "Failed to install GRUB. Exiting."
        exit 1
    }
    grub-mkconfig -o /boot/grub/grub.cfg || {
        echo "Failed to generate GRUB configuration. Exiting."
        exit 1
    }
}


echo -ne "
+--------------------+
| Configuring Pacman |
+--------------------+
"

# Configure pacman
echo "Configuring pacman"
sed -i "/^#Color/c\Color\nILoveCandy" /etc/pacman.conf
sed -i "/^#VerbosePkgLists/c\VerbosePkgLists" /etc/pacman.conf
sed -i "/^#ParallelDownloads/c\ParallelDownloads = 5" /etc/pacman.conf
sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf

echo -ne "
+---------------------+
| Installing Packages |
+---------------------+
"

# Install additional needed packages
echo "Installing Packages"
pacman -Sy --noconfirm --needed archlinux-keyring base-devel networkmanager lvm2 pipewire btop man-db man-pages texinfo tldr bash-completion openssh git parallel neovim grub efibootmgr dosfstools os-prober mtools python kmod debugedit fakeroot shadow || { echo "Failed to install packages"; exit 1; }


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


echo -ne "
+-------------------+
| Enabling Services |
+-------------------+
"

# Enable services
systemctl enable NetworkManager.service || { echo "Failed to enable NetworkManager"; exit 1; }
echo "NetworkManager enabled"
systemctl enable fstrim.timer || { echo "Failed to enable SSD support"; exit 1; }
echo "SSD support enabled"

echo -ne "
+----------------+
| Setting locale |
+----------------+
"

# Uncomment  locale
sed --in-place=.bak 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen

# Generate locales
locale-gen

# Set the locale in /etc/locale.conf within the chroot
echo LANG=en_US.UTF-8 > /etc/locale.conf

# Remove .bak file
rm -rf /etc/locale.gen.bak

echo -ne "
+------------------+
| Update Initramfs |
+------------------+
"

# Update mkinitcpio.conf
sed -i 's/^HOOKS\s*=\s*(.*)/HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf
mkinitcpio -p linux

# Call defined functions
#set_root_password
update_sudoers


echo -ne "
+-----------------+
| Installing GRUB |
+-----------------+
"

install_grub


echo -ne "
+----------------------+
| Updating GRUB Config |
+----------------------+
"

# Update GRUB configuration: /etc/default/grub
sed -i '/^GRUB_DEFAULT=/c\GRUB_DEFAULT=saved' /etc/default/grub || { echo "Failed to update GRUB_DEFAULT"; exit 1; }
sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/c\GRUB_CMDLINE_LINUX_DEFAULT="quiet cryptdevice='"$disk"'3:volgroup0 loglevel=3"' /etc/default/grub || { echo "Failed to update GRUB_CMDLINE_LINUX_DEFAULT"; exit 1; }
sed -i '/^#GRUB_ENABLE_CRYPTODISK=y/c\GRUB_ENABLE_CRYPTODISK=y' /etc/default/grub || { echo "Failed to update GRUB_ENABLE_CRYPTODISK"; exit 1; }
sed -i '/^#GRUB_SAVEDEFAULT=true/c\GRUB_SAVEDEFAULT=true' /etc/default/grub || { echo "Failed to update GRUB_SAVEDEFAULT"; exit 1; }
cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale.en.mo || { echo "Failed to update copy locale for GRUB messages"; exit 1; }
grub-mkconfig -o /boot/grub/grub.cfg || { echo "Failed to regenerate GRUB configuration"; exit 1; }


echo -ne "
+------------------+
| Detecting NVIDIA |
+------------------+
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
+-------------------+
| Installing NVIDIA |
+-------------------+
"

    # Install NVIDIA drivers and related packages
    pacman -S --noconfirm --needed nvidia-dkms libglvnd nvidia-utils opencl-nvidia lib32-libglvnd lib32-nvidia-utils lib32-opencl-nvidia nvidia-settings || { echo "Failed to install NVIDIA packages"; exit 1; }

    # Add NVIDIA modules to initramfs
    sed -i '/^MODULES=()/c\MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)' /etc/mkinitcpio.conf || { echo "Failed to add NVIDIA modules to initramfs"; exit 1; }
    mkinitcpio -p linux || { echo "Failed to regenerate initramfs"; exit 1; }

    # Update GRUB configuration with NVIDIA settings
sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT="quiet cryptdevice=/dev/'\$disk'3:volgroup0 loglevel=3"/c\GRUB_CMDLINE_LINUX_DEFAULT="quiet cryptdevice=/dev/'\$disk'3:volgroup0 nvidia_drm_modeset=1 loglevel=3"' /etc/default/grub || { echo "Failed to update GRUB configuration"; exit 1; }
grub-mkconfig -o /boot/grub/grub.cfg || { echo "Failed to regenerate GRUB configuration"; exit 1; }
else
    echo "No NVIDIA GPUs detected. Skipping NVIDIA-related actions."
fi

echo -ne "
+--------------------------------------------------+
| Adding user, setting passwords, setting hostname |
+--------------------------------------------------+
"

 # Create user home directory
    useradd -m -G wheel,power,storage,uucp,network -s /bin/bash "$USERNAME" 
    if [[ $? -ne 0 ]]; then 
        log_error "Error creating user $USERNAME" $?
        exit $?  # Exit with the useradd exit code
    fi

    # Set user password
    echo "$USERNAME:$PASSWORD" | chpasswd
    if [[ $? -ne 0 ]]; then
        log_error "Error setting password for user $USERNAME" $?
        exit $?  # Exit with the chpasswd exit code
    fi 


# Set hostname
echo $NAME_OF_MACHINE > /etc/hostname

EOF


# Make chroot-setup.sh and common-script.sh executable
chmod +x /mnt/chroot-setup.sh

# Execute the script inside chroot, passing $disk as an argument
arch-chroot /mnt ./chroot-setup.sh "$disk"

# Select GUI (Optional) 
echo -ne "
+-----------------------+
| Select GUI (Optional) |
+-----------------------+
"

install_gui() {
    local gui_choice="$1"

    case $gui_choice in
        "GNOME")
            echo "Installing GNOME desktop environment..."
            arch-chroot /mnt pacman -S --noconfirm --needed gnome gnome-extra gnome-tweaks gnome-shell-extensions gnome-browser-connector firefox || {
                echo "Failed to install GNOME packages. Exiting."
                exit 1
            }

            arch-chroot /mnt systemctl enable gdm.service || {
                echo "Failed to enable gdm service. Exiting."
                exit 1
            }
            echo "GNOME installed and gdm enabled."
            ;;
        "KDE Plasma")
            echo "Installing KDE Plasma desktop environment..."
            arch-chroot /mnt pacman -S --noconfirm --needed xorg plasma-desktop sddm kde-applications dolphin firefox lxappearance || {
                echo "Failed to install KDE Plasma packages. Exiting."
                exit 1
            }

            arch-chroot /mnt systemctl enable sddm.service || {
                echo "Failed to enable sddm service. Exiting."
                exit 1
            }
            echo "KDE Plasma installed and sddm enabled."
            ;;
        *) 
            echo "Server Selected. Skipping GUI installation."
            ;;
    esac
}

# Ask the user if they want to install a GUI
options=("Server (No GUI)" "GNOME" "KDE Plasma")
select gui_choice in "${options[@]}"; do
    install_gui "$gui_choice"
    break
done

echo -ne "

 █████╗ ██████╗  ██████╗██╗  ██╗    ██╗██╗  ██╗████████╗███╗   ███╗
██╔══██╗██╔══██╗██╔════╝██║  ██║    ██║██║  ██║╚══██╔══╝████╗ ████║
███████║██████╔╝██║     ███████║    ██║███████║   ██║   ██╔████╔██║
██╔══██║██╔══██╗██║     ██╔══██║    ██║╚════██║   ██║   ██║╚██╔╝██║
██║  ██║██║  ██║╚██████╗██║  ██║    ███████╗██║   ██║   ██║ ╚═╝ ██║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝    ╚══════╝╚═╝   ╚═╝   ╚═╝     ╚═╝
                                                               
+-----------------------+
| Installation Complete |
+-----------------------+
"

# Remove chroot setup script
rm -rf /mnt/chroot-setup.sh

# Keep log file
cp /var/log/arch_install.log /mnt/var/log/arch_install.log

# Unmount all partitions under /mnt
echo "Unmounting partitions..."
umount -R /mnt

# Reboot the system
echo "Rebooting..."
reboot
