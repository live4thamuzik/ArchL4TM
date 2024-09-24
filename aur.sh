# Install AUR Helper    
echo -ne "
+--------------------+
| Install AUR Helper |
+--------------------+
"

# Install dependencies for makepkg
pacman -Sy --noconfirm --needed fakeroot debugedit

# Create a temporary user for building AUR packages
useradd -m -G wheel -s /bin/bash temp_aur_user

install_aur_helper() {
    local aur_helper="$1"
    local repo_url="$2"
    local temp_dir="/mnt/tmp/$aur_helper"

    echo "Installing $aur_helper"

    # Add the temporary user to the wheel group (needed for Yay)
    usermod -aG wheel temp_aur_user

    # Switch to the temporary user and build/install the AUR helper
    su - temp_aur_user -c "
        # Clone the repo
        if ! git clone '$repo_url' '$temp_dir'; then 
            echo 'Failed to clone $aur_helper repository. Please check your internet connection and try again.'
            exit 1
        fi 

        # Build and install the AUR helper (with --noconfirm)
        cd '$temp_dir' && makepkg -si --noconfirm || {  
            echo 'Failed to build and install $aur_helper. Check the installation logs for more details.'
            exit 1 
        }

        # Clean up
        cd ~ && rm -rf '$temp_dir'
        echo '$aur_helper installed successfully! You can now use $aur_helper to install packages from the AUR.'
    "
}

# Ask the user which AUR helper they want
options=("Yay" "Paru")
select aur_helper in "${options[@]}"; do
    case $aur_helper in
        "Yay")
            su - temp_aur_user -c "
                # Clone the repo
                if ! git clone 'https://aur.archlinux.org/yay.git' '/mnt/tmp/Yay'; then 
                    echo 'Failed to clone Yay repository. Please check your internet connection and try again.'
                    exit 1
                fi 

                # Build and install Yay (with --noconfirm)
                cd '/mnt/tmp/Yay' && makepkg -si --noconfirm || {  
                    echo 'Failed to build and install Yay. Check the installation logs for more details.'
                    exit 1 
                }

                # Clean up
                cd ~ && rm -rf '/mnt/tmp/Yay'
                echo 'Yay installed successfully! You can now use Yay to install packages from the AUR.'
            "
            ;;
        "Paru")
            su - temp_aur_user -c "
                # Clone the repo
                if ! git clone 'https://aur.archlinux.org/paru.git' '/mnt/tmp/Paru'; then 
                    echo 'Failed to clone Paru repository. Please check your internet connection and try again.'
                    exit 1
                fi 

                # Build and install Paru (with --noconfirm)
                cd '/mnt/tmp/Paru' && makepkg -si --noconfirm || {  
                    echo 'Failed to build and install Paru. Check the installation logs for more details.'
                    exit 1 
                }

                # Clean up
                cd ~ && rm -rf '/mnt/tmp/Paru'
                echo 'Paru installed successfully! You can now use Paru to install packages from the AUR.'
            "
            ;;
        *) echo "Invalid option";;
    esac
done

# Remove the temporary user
userdel -r temp_aur_user
