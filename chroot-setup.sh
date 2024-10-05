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

# Ensure /etc/skel exists and has correct permissions
  if [ ! -d /etc/skel ]; then
    echo 'Warning: /etc/skel does not exist. Creating it...'
    mkdir -p /etc/skel
    chmod 0755 /etc/skel
  fi

# Create user
 useradd -G wheel,power,storage,uucp,network -s /bin/bash $USERNAME 
 echo "$USERNAME:$PASSWORD" | chpasswd

# Explicitly manage /etc/skel and create home directory
  cp -r /etc/skel /home/$USERNAME
  chown -R $USERNAME:$USERNAME /home/$USERNAME
  chmod 0700 /home/$USERNAME
  echo 'Home directory created and populated from /etc/skel'


# Verify /etc/shadow update
  ls -l /etc/shadow  # Check before useradd
   ls -l /etc/shadow  # Check after useradd
  echo 'User added and /etc/shadow updated'


# Validate /etc/default/useradd settings
  echo '--- /etc/default/useradd settings ---'
  echo "SKEL: $(grep ^SKEL= /etc/default/useradd)"
  echo "HOME: $(grep ^HOME= /etc/default/useradd)"
  echo "SHELL: $(grep ^SHELL= /etc/default/useradd)" 


# Set root password
echo "root:$PASSWD" | chpasswd
echo "root password set"

# Set hostname
echo $NAME_OF_MACHINE > /etc/hostname

# Install AUR Helper
echo -ne "
+--------------------+
| Install AUR Helper |
+--------------------+
"

# Create a temporary user for building AUR packages
useradd -m -G wheel -s /bin/bash temp_aur_user

install_aur_helper() {
  local aur_helper="$1"
  local repo_url="$2"
  local temp_dir="/mnt/opt/$aur_helper"

  echo "Installing $aur_helper"

  # Add the temporary user to the wheel group (needed for Yay)
  usermod -aG wheel temp_aur_user

  # Switch to the temporary user and build/install the AUR helper
  su - temp_aur_user -c "
        # Clone the repo
        if ! git clone '$repo_url' '$temp_dir'; then
            echo 'Failed to clone $aur_helper repository from $repo_url. Please check your internet connection and try again.'
            exit 1
        fi

        # Build and install the AUR helper (with --noconfirm)
        chown temp_aur_user -R '$temp_dir' && cd '$temp_dir' && makepkg -si --noconfirm || {
            echo 'Failed to build and install $aur_helper. Check the installation logs for more details.'
            exit 1
        }

        # Clean up
        cd ~ && rm -rf '$temp_dir'
        echo '$aur_helper installed successfully! You can now use $aur_helper to install packages from the AUR.'
    "
}

# Ask the user which AUR helper they want
options=(Yay Paru)
select aur_helper in "${options[@]}"; do
  case $aur_helper in
  "Yay")
    pacman -Sy --noconfirm --needed go
    install_aur_helper "Yay" "https://aur.archlinux.org/yay.git"
    ;;
  "Paru")
    pacman -Sy --noconfirm --needed cargo
    install_aur_helper "Paru" "https://aur.archlinux.org/paru.git"
    ;;
  *) echo "Invalid option";;
  esac
done

# Remove the temporary user
userdel -r temp_aur_user

EOF
