#!/bin/bash

# Install AUR Helper
echo -ne "
+--------------------+
| Install AUR Helper |
+--------------------+
"

# Install dependencies for makepkg
pacman -Sy --noconfirm --needed fakeroot debugedit

# Create home directory for nobody if it doesn't exist
if [ ! -d "/home/nobody" ]; then
    usermod -d /home/nobody nobody
    mkdir /home/nobody
    chown nobody:nobody /home/nobody
    chmod 700 /home/nobody
fi

# Create the build directory
mkdir -p /home/nobody/build

# Set permissions
chgrp nobody /home/nobody/build
chmod g+ws /home/nobody/build
setfacl -m u::rwx,g::rwx /home/nobody/build
setfacl -d --set u::rwx,g::rwx,o::- /home/nobody/build

# Temporarily allow 'nobody' to run sudo without a password
echo "nobody ALL=(ALL) NOPASSWD: /usr/bin/makepkg" >> /etc/sudoers

install_aur_helper() {
    local aur_helper="$1"
    local repo_url="$2"
    local temp_dir="/home/nobody/build/$aur_helper"

    echo "Installing $aur_helper"

    # Create the build directory if it doesn't exist
    if [ ! -d "$temp_dir" ]; then
        mkdir -p "$temp_dir"
        chown nobody:nobody "$temp_dir"
        chmod 700 "$temp_dir"
    fi

    # Clone the repo
    if ! git clone "$repo_url" "$temp_dir"; then
        echo "Failed to clone $aur_helper repository from $repo_url. Please check your internet connection and try again."
        exit 1
    fi

    # Build and install the package using makepkg -si (as nobody)
    if su nobody bash -c "
        cd '$temp_dir' &&
        makepkg -si --noconfirm 
    "; then
        # Clean up (only if makepkg -si was successful)
        rm -rf "$temp_dir"

        echo "$aur_helper installed successfully! You can now use $aur_helper to install packages from the AUR."
    else
        echo "Failed to build and install $aur_helper. Check the installation logs for more details. The temporary build directory '$temp_dir' has been preserved for debugging."
        exit 1
    fi

    # Remove the sudoers entry for nobody
    sed -i '$ d' /etc/sudoers
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
