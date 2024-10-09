#!/bin/bash

# Install AUR Helper
echo -ne "
+--------------------+
| Install AUR Helper |
+--------------------+
"

# Install dependencies for makepkg
pacman -Sy --noconfirm --needed fakeroot debugedit

# Create the build directory
mkdir -p /opt/build

# Set permissions
chgrp nobody /opt/build
chmod g+ws /opt/build
setfacl -m u::rwx,g::rwx /opt/build
setfacl -d --set u::rwx,g::rwx,o::- /opt/build

# Temporarily allow 'nobody' to run sudo without a password
echo "nobody ALL=(ALL) NOPASSWD: /usr/bin/pacman" >> /etc/sudoers

install_aur_helper() {
    local aur_helper="$1"
    local repo_url="$2"
    local temp_dir="/opt/build/$aur_helper" # Use the common build directory

    echo "Installing $aur_helper"

    # Clone the repo
    if ! git clone "$repo_url" "$temp_dir"; then
        echo "Failed to clone $aur_helper repository from $repo_url. Please check your internet connection and try again."
        exit 1
    fi

    # Build the package using makepkg -s (as nobody)
    sudo -u nobody bash -c "
        cd '$temp_dir' &&
        makepkg -s --noconfirm
    " || {
        echo "Failed to build $aur_helper. Check the installation logs for more details."
        exit 1
    }

    # Install the package using pacman -U (as root)
    sudo pacman -U --noconfirm "$temp_dir"/*.pkg.tar.* || {
        echo "Failed to install $aur_helper. Check the installation logs for more details."
        exit 1
    }

    # Clean up
    rm -rf "$temp_dir"

    echo "$aur_helper installed successfully! You can now use $aur_helper to install packages from the AUR."
}

# Ask the user which AUR helper they want
options=("Yay" "Paru")
select aur_helper in "${options[@]}"; do
    case $aur_helper in
    "Yay")
        pacman -Sy --noconfirm --needed go
        install_aur_helper "Yay" "https://aur.archlinux.org/yay.git"
        ;;
    "Paru")
        pacman -Sy --noconfirm --needed rust cargo
        install_aur_helper "Paru" "https://aur.archlinux.org/paru.git"
        ;;
    *) echo "Invalid option";;
    esac
done

# Remove temporary sudo access for 'nobody'
sed -i '$ d' /etc/sudoers
