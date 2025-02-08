#!/bin/bash

# --- Sources ---
source ./global_functions.sh

# --- Log output function ---
log_output() {
    echo "[INFO] $1"
}

# --- Log error function ---
log_error() {
    echo "[ERROR] $1" >&2  # Print to standard error
}

# --- Check for NVIDIA GPU ---
check_nvidia_gpu() {
    lspci | grep -i nvidia > /dev/null 2>&1
}

install_hyprland_dependencies() {
    log_output "Installing Hyprland dependencies..."

    # Check for pacman
    if ! command -v pacman > /dev/null; then
        log_error "pacman is required but not found. Please install pacman and try again."
        exit 1
    fi

    # Install base packages using pacman (with sudo)
    if ! sudo pacman -Syu --noconfirm --needed \
        hyprland wayland swaybg swaylock wofi grim slurp \
        sddm qt5-quickcontrols qt5-quickcontrols2 qt5-graphicaleffects \
        rofi-wayland waybar swww hyprlock hyprpicker satty \
        cliphist hyprsunset polkit-gnome xdg-desktop-portal-hyprland \
        pacman-contrib parallel jq imagemagick \
        qt5-imageformats ffmpegthumbs kde-cli-tools libnotify \
        nwg-look qt5ct qt6ct kvantum kvantum-qt5 qt5-wayland qt6-wayland \
        papirus-icon-theme ttf-font-awesome noto-fonts-emoji \
        firefox kitty dolphin ark unzip code nwg-displays \
        libreoffice-fresh mpv chromium flatpak sl lolcat cmatrix \
        asciiquarium remmina freerdp strawberry dfc udiskie \
        ttf-anonymouspro-nerd ttf-daddytime-mono-nerd ttf-firacode-nerd \
        ttf-meslo-nerd; then
        log_error "Failed to install base dependencies. Check the output above for errors."
        exit 1
    fi

    # Temporarily allow the user to run sudo without a password (within the chroot)
    echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers > /dev/null

    # Build and install AUR packages using the chosen AUR helper (via runuser)
    log_output "Building and installing AUR packages..."
    
    # Switch to the created user and install AUR packages
    if ! runuser -u "$USERNAME" -- /bin/bash -c "
        # Check if the AUR helper is installed
        if ! command -v \"$AUR_HELPER\" &> /dev/null; then
            log_error \"AUR helper '$AUR_HELPER' not found. Make sure it's installed.\"
            exit 1
        fi

        # Install AUR packages using paru
        if ! $AUR_HELPER -Sy --noconfirm --needed \
            wlogout auto-cpufreq hyde-cli-git bazecor appimage-installer \
            hyprshade brave-bin python-pyamdgpuinfo bluemail nordic-darker-theme-git; then
	    log_error \"Failed to install AUR packages\" \$?
            exit 1
        fi
    "; then
        log_error "Failed to install AUR packages as $USERNAME" $?
        # Remove the temporary sudoers entry in case of failure
        sed -i "/$USERNAME ALL=(ALL) NOPASSWD: ALL/d" /etc/sudoers
        exit 1
    fi

    # Remove the temporary sudoers entry
    sed -i "/$USERNAME ALL=(ALL) NOPASSWD: ALL/d" /etc/sudoers

    log_output "Hyprland dependencies installation complete!"
}

    # Install display drivers (NVIDIA only)
    if check_nvidia_gpu; then
        pacman -S --noconfirm --needed nvidia nvidia-utils
    fi
    
# --- Clone and install SDDM themes ---
#install_sddm_themes() {
#    log_output "Cloning and installing SDDM themes..."

    # Clone Candy theme
#    git clone https://github.com/EliverLara/sddm-candy-theme.git ./sddm-candy-theme || {
#        log_error "Failed to clone Candy theme"
#        exit 1
#    }

    # Clone Corners theme
#    git clone https://github.com/XtremeDevX/sddm-corners-theme.git ./sddm-corners-theme || {
#        log_error "Failed to clone Corners theme"
#        exit 1
#    }

    # Copy Candy theme to /usr/share/sddm/themes/
#    cp -r ./sddm-candy-theme/Candy /usr/share/sddm/themes/ || {
#        log_error "Failed to copy Candy theme to /usr/share/sddm/themes/"
#        exit 1
#    }

    # Copy Corners theme to /usr/share/sddm/themes/
#    cp -r ./sddm-corners-theme/Corners /usr/share/sddm/themes/ || {
#        log_error "Failed to copy Corners theme to /usr/share/sddm/themes/"
#        exit 1
#    }

#    # Clean up temporary files
#    rm -rf ./sddm-candy-theme ./sddm-corners-theme
#}

# --- Configure SDDM ---
#configure_sddm() {
#    log_output "Configuring SDDM..."

    # Get user's theme choice
#    options=("Candy" "Corners")
#    select theme_choice in "${options[@]}"; do
#        case "$theme_choice" in
#            "Candy")
#                theme_name="Candy"
#              ;;
#            "Corners")
#                theme_name="Corners"
#              ;;
#            *)
#                log_error "Invalid theme choice. Skipping SDDM configuration."
#                return 1
#              ;;
#        esac
#        break
#    done

    # Apply the chosen theme
#    theme_dir="/usr/share/sddm/themes/$theme_name"
#    if [[ -d "$theme_dir" ]]; then
#        sed -i "s/^Current=.*$/Current=$theme_name/" /etc/sddm.conf
#        log_output "SDDM theme set to $theme_name."
#    else
#        log_error "Theme directory not found: $theme_dir"
#        return 1
#    fi
#}

# --- Configure Hyprland ---
configure_hyprland() {
    log_output "Configuring Hyprland..."

    # Copy .bashrc file, Dygma and oh-my-posh folders
    cp -r /Configs/.bashrc /Configs/Dygma /Configs/oh-my-posh "$HOME" || {
        log_error "Failed to copy files to home directory"
        exit 1
    }

    # Copy .config .icons .local & .themes folders
    cp -r /Configs/.config Configs/.icons Configs/.local Configs/.themes "$HOME" || {
        log_error "Failed to copy.config folder"
        exit 1
    }

    # Copy sddm.conf.d folder
    cp -r /Configs/etc/sddm.conf.d /etc || {
        log_error "Failed to copy .config folder"
        exit 1
    }

    # Copy usr folder
    cp -r /Configs/usr / || {
	log_error "Failed to copy usr folder"
        exit 1
    }

    # Clone oh-my-posh
    git clone https://github.com/JanDeDobbeleer/oh-my-posh.git "$HOME" || {
        log_error "Failed to clone oh-my-posh repo"
        exit 1
    }
}



# --- Install Hyprland themes and customizations ---
install_hyprland_themes() {
    log_output "Installing Hyprland themes and customizations..."

    # Install themes
    hyde-cli install AbyssGreen
    hyde-cli install Abyssal-Wave
    hyde-cli install Another-World
    hyde-cli install Bad-Blood
    hyde-cli install BlueSky
    hyde-cli install Cat-Latte
    hyde-cli install Catppuccin-Latte
    hyde-cli install Catppuccin-Mocha
    hyde-cli install Crimson-Blade
    hyde-cli install Decay-Green
    hyde-cli install Dracula
    hyde-cli install Edge-Runner
    hyde-cli install Eternal-Arctic
    hyde-cli install Ever-Blushing
    hyde-cli install Frosted-Glass
    hyde-cli install Graphite-Mono
    hyde-cli install Green-Lush
    hyde-cli install Greenify
    hyde-cli install Gruvbox-Retro
    hyde-cli install Hack-the-Box
    hyde-cli install Ice-Age
    hyde-cli install Mac-OS
    hyde-cli install Material-Sakura
    hyde-cli install Monokai
    hyde-cli install Monterey-Frost
    hyde-cli install Nordic-Blue
    hyde-cli install One-Dark
    hyde-cli install Oxo-Carbon
    hyde-cli install Paranoid-Sweet
    hyde-cli install Pixel-Dream
    hyde-cli install Rain-Dark
    hyde-cli install Red-Stone
    hyde-cli install Rose-Pine
    hyde-cli install Scarlet-Night
    hyde-cli install Sci-fi
    hyde-cli install Solarized-Dark
    hyde-cli install Synth-Wave
    hyde-cli install Tokyo-Night
    hyde-cli install Vanta-Black
    hyde-cli install Windows-11

    # Apply default theme
    hyde-cli apply Catppuccin-Mocha
}

# --- Enable services ---
enable_services() {
    log_output "Enabling services..."

    # Enable SDDM
    systemctl enable sddm.service
}

# --- Main function ---
main() {
    install_hyprland_dependencies
    install_sddm_themes
    configure_sddm
    configure_hyprland
    install_hyprland_themes
    enable_services

    log_output "Hyprland installation complete!"
}

main
