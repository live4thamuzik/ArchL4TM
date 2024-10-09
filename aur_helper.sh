#!/bin/bash

# Install AUR Helper
echo -ne "
+--------------------+
| Install AUR Helper |
+--------------------+
"

# Install dependencies for makepkg
pacman -Sy --noconfirm --needed fakeroot debugedit

install_aur_helper() {
    local aur_helper="$1"
    local repo_url="$2"
    local temp_dir="/opt/$aur_helper"
    local temp_user="aur_builder"

    echo "Installing $aur_helper"

    # Create a temporary user
    useradd -m -G wheel -s /bin/bash "$temp_user"

    # Clone the repo
    if ! git clone "$repo_url" "$temp_dir"; then
        echo "Failed to clone $aur_helper repository from $repo_url. Please check your internet connection and try again."
        exit 1
    fi

    # Change ownership of the cloned directory to the temporary user
    chown -R "$temp_user":"$temp_user" "$temp_dir"

    # Switch to the temporary user
    su "$temp_user" -c "
        cd '$temp_dir' &&
        fakeroot makepkg -si --noconfirm
    " || {
        echo "Failed to build and install $aur_helper. Check the installation logs for more details."
        exit 1
    }

    # Clean up
    rm -rf "$temp_dir"
    userdel -r "$temp_user"

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
        pacman -Sy --noconfirm --needed cargo
        install_aur_helper "Paru" "https://aur.archlinux.org/paru.git"
        ;;
    *) echo "Invalid option";;
    esac
done
