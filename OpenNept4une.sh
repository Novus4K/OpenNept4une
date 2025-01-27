#!/bin/bash

# Path to the script and other resources
SCRIPT="${HOME}/OpenNept4une/OpenNept4une.sh"
DISPLAY_SERVICE_INSTALLER="${HOME}/OpenNept4une/display/display-service-installer.sh"
MCU_RPI_INSTALLER="${HOME}/OpenNept4une/img-config/rpi-mcu-install.sh"
USB_STORAGE_AUTOMOUNT="${HOME}/OpenNept4une/img-config/usb-storage-automount.sh"
ANDROID_RULE_INSTALLER="${HOME}/OpenNept4une/img-config/adb-automount.sh"
CROWSNEST_FIX_INSTALLER="${HOME}/OpenNept4une/img-config/crowsnest-lag-fix.sh"
BASE_IMAGE_INSTALLER="${HOME}/OpenNept4une/img-config/base_image_configuration.sh"
DE_ELEGOO_IMAGE_CLEANSER="${HOME}/OpenNept4une/img-config/de_elegoo_cleanser.sh"
FLAG_FILE="/boot/.OpenNept4une.txt"

# Command line arguments
model_key=""
motor_current=""
pcb_version=""
auto_yes=false

# ASCII art for OpenNept4une 
OPENNEPT4UNE_ART=$(cat <<'EOF'

  ____                _  __         __  ____              
 / __ \___  ___ ___  / |/ /__ ___  / /_/ / /__ _____  ___ 
/ /_/ / _ \/ -_) _ \/    / -_) _ \/ __/_  _/ // / _ \/ -_)
\____/ .__/\__/_//_/_/|_/\__/ .__/\__/ /_/ \_,_/_//_/\__/ 
    /_/                    /_/                            


EOF
)

clear_screen() {
    # Clear the screen and move the cursor to the top left
    clear
    tput cup 0 0
}

run_fixes() {
    # Add user 'mks' to 'gpio' and 'spiusers' groups for GPIO and SPI access
    if ! sudo usermod -aG gpio,spiusers mks &>/dev/null; then
        echo "Failed to add user 'mks' to groups 'gpio' and 'spiusers'."
    fi
    # Remove obsolete GPIO script if it exists
    if [ -f "/usr/local/bin/set_gpio.sh" ]; then
        sudo rm -f "/usr/local/bin/set_gpio.sh" || echo "Failed to remove /usr/local/bin/set_gpio.sh"
    fi
    # Ensure the flag file exists to mark completion of fixes
    if ! sudo touch "$FLAG_FILE"; then
        echo "Failed to ensure flag file exists at $FLAG_FILE"
    fi
    # Append system information to the flag file if not already present
    SYSTEM_INFO=$(uname -a)
    if ! sudo grep -qF "$SYSTEM_INFO" "$FLAG_FILE"; then
        echo "$SYSTEM_INFO" | sudo tee -a "$FLAG_FILE" >/dev/null || echo "Failed to append system info to $FLAG_FILE"
    fi
    # Create a symbolic link to the main script if it doesn't exist
    SYMLINK_PATH="/usr/local/bin/opennept4une"
    if [ ! -L "$SYMLINK_PATH" ]; then  # Checking for symbolic link instead of regular file
        sudo ln -s "$SCRIPT" "$SYMLINK_PATH" || echo "Failed to create symlink at $SYMLINK_PATH"
    fi
}

# Function to update the repository
update_repo() {
    clear_screen
    echo -e "\033[0;94m$OPENNEPT4UNE_ART\033[0m"
    echo "======================================"
    echo "Checking for updates..."
    echo "======================================"
    repo_dir="$HOME/OpenNept4une"

    if [ ! -d "$repo_dir" ]; then
        echo "Repository directory not found at $repo_dir!"
        return 1
    fi

    # Fetch updates from the remote repository
    if ! git -C "$repo_dir" fetch origin main --quiet; then
        echo "Failed to fetch updates from the repository."
        return 1
    fi

    LOCAL=$(git -C "$repo_dir" rev-parse '@')
    REMOTE=$(git -C "$repo_dir" rev-parse '@{u}')

    if [ "$LOCAL" != "$REMOTE" ]; then
        echo "Updates are available for the repository."
        if [ "$auto_yes" != "true" ]; then
             read -p "Would you like to update the repository? (y/n): " -r
        fi

        if [[ $REPLY =~ ^[Yy]$ || $auto_yes = "true" ]]; then
            echo "Updating repository..."
            git -C "$repo_dir" reset --hard && \
            git -C "$repo_dir" clean -fd && \
            git -C "$repo_dir" pull origin main --force || {
                echo "Failed to update the repository."
                return 1
            }

            echo "Repository updated successfully."
            exec "$SCRIPT"
            exit 0
        else
            echo "Update skipped."
        fi
    else
        echo "Your repository is already up-to-date."
    fi
    echo "======================================"
}

advanced_more() {
    while true; do
        clear_screen
        echo -e "\033[0;94m$OPENNEPT4UNE_ART\033[0m"
        echo "======================================"
        echo "Welcome to OpenNept4une - Advanced Options"
        echo "======================================"
        echo ""
        echo "1) Install Android ADB rules (klipperscreen)"
        echo ""
        echo "2) Install Crowsnest FPS Fix - Improves FPS & Configs Device Number"
        echo ""
        echo "3) Base ZNP-K1 Compiled Image Config - NOT for OpenNept4une Releases."
        echo ""
        echo "4) Elegoo Image Cleanser Script - NOT for OpenNept4une Releases"
        echo ""
        echo "5) Resize Active Armbian Partition - for eMMC > 8GB."
        echo ""
        echo "6) Return to Main Menu"
        echo "======================================"

        read -p "Enter your choice: " choice

        case $choice in
            1) android_rules;;
            2) crowsnest_fix;;
            3) base_image_config;;
            4) de_elegoo_image_cleanser;;
            5) armbian_resize;;
            6) return;;  # Return to the main menu
            *) echo "Invalid choice, please try again.";;
        esac

        # Optional: prompt before returning to the menu
        read -p "Press enter to continue..."
    done
}

# Generic installation function
install_feature() {
    local feature_name="$1"
    local action="$2"  # This can be a script path or direct commands
    local prompt_message="$3"

    clear_screen
    echo -e "\033[0;94m$OPENNEPT4UNE_ART\033[0m"
    echo "======================================"
    echo "$feature_name Installation"
    echo "======================================"
    # Initialize variable to avoid using potentially undefined variable
    local user_input=""

    # Only prompt the user if auto_yes is not set to true
    if [ "$auto_yes" != "true" ]; then
        read -p "$prompt_message (Y/n): " -r user_input
    fi

    # Proceed if the user agrees or if auto_yes is true
    if [[ $user_input =~ ^[Yy]$ || -z $user_input || $auto_yes = "true" ]]; then
        echo "Running $feature_name Installer..."
        if [[ -f "$action" || -n "$action" ]]; then
            if eval "$action"; then  # Use eval to execute both file paths and direct commands
                echo "$feature_name Installer ran successfully."
            else
                echo "$feature_name Installer encountered an error."
            fi
        else
            echo "Error: Action for $feature_name not found or not specified."
        fi
    else
        echo "Installation skipped."
    fi

    echo "======================================"
}

### ADVANCED PAGE INSTALLERS ###

android_rules() {
    install_feature "Android ADB Rules" "$ANDROID_RULE_INSTALLER" "Do you want to install the android ADB rules? (may fix klipperscreen issues)"
}

crowsnest_fix() {
    install_feature "Crowsnest FPS Fix" "$CROWSNEST_FIX_INSTALLER" "Do you want to install the crowsnest fps fix?"
}

base_image_config() {
    install_feature "Base Ambian Image Confifg" "$BASE_IMAGE_INSTALLER" "Do you want to configure a base/fresh armbian image that you compiled?"
}

de_elegoo_image_cleanser() {
    install_feature "Elegoo Image/eMMC Cleanser" "$DE_ELEGOO_IMAGE_CLEANSER" "DO NOT run this on an OpenNept4une GitHub Image, for Elegoo images only! Do you want to proceed?"
}

armbian_resize() {
    # Commands for resizing are passed directly
    local resize_commands="sudo systemctl enable armbian-resize-filesystem && sudo reboot"
    install_feature "Armbian Resize" "$resize_commands" "Reboot then resize Armbian filesystem?"
}

### MAIN PAGE INSTALLERS ###

wifi_config() {
sudo nmtui
}

usb_auto_mount() {
    install_feature "USB Auto Mount" "$USB_STORAGE_AUTOMOUNT" "Do you want to auto mount USB drives?"
}

update_mcu_rpi_fw() {
    install_feature "MCU Updater" "$MCU_RPI_INSTALLER" "Do you want to update the MCU's?"
}

install_screen_service() {
    install_feature "Touch-Screen Display Service" "$DISPLAY_SERVICE_INSTALLER" "Do you want to install the Touch-Screen Display Service?"
}

select_option() {
    local -n ref=$1
    echo "$2"
    select opt in "${@:3}"; do
        ref=$opt
        break
    done
}


install_printer_cfg() {
    # Headless operation checks
    if [ "$auto_yes" = "true" ]; then
        if { [ "$model_key" = "n4" ] || [ "$model_key" = "n4pro" ]; } && { [ -z "$motor_current" ] || [ -z "$pcb_version" ]; }; then
            echo "Headless mode for n4 and n4pro requires --motor_current and --pcb_version."
            return 1
        elif [ -z "$model_key" ]; then
            echo "Headless mode requires --printer_model."
            return 1
        fi
    else
        # Interactive mode for model selection
        clear_screen
        echo -e "\033[0;94m$OPENNEPT4UNE_ART\033[0m"
        echo "Please select your printer model:"
        select _ in "Neptune4" "Neptune4 Pro" "Neptune4 Plus" "Neptune4 Max"; do
            case $REPLY in
                1) model_key="n4";;
                2) model_key="n4pro";;
                3) model_key="n4plus";;
                4) model_key="n4max";;
                *) echo "Invalid selection. Please try again."; continue;;
            esac
            break
        done

        # Interactive mode for motor current and PCB version if applicable
        if [ "$model_key" = "n4" ] || [ "$model_key" = "n4pro" ]; then
            [ -z "$motor_current" ] && select_option motor_current "Select the stepper motor current:" "0.8" "1.2"
            [ -z "$pcb_version" ] && select_option pcb_version "Select the PCB version:" "1.0" "1.1"
        fi
    fi

    # Define necessary paths
    PRINTER_CFG_DEST="${HOME}/printer_data/config"
    DTB_DEST="/boot/dtb/rockchip/rk3328-roc-cc.dtb"
    DATABASE_DEST="${HOME}/printer_data/database"
    PRINTER_CFG_FILE="$PRINTER_CFG_DEST/printer.cfg"
    BACKUP_PRINTER_CFG_FILE="$PRINTER_CFG_DEST/backup-printer.cfg.bak"

    # Build configuration paths based on selections
    if [[ $model_key == "n4" || $model_key == "n4pro" ]]; then
        PRINTER_CFG_SOURCE="${HOME}/OpenNept4une/printer-confs/${model_key}/${model_key}-${motor_current}-printer.cfg"
        DTB_SOURCE="${HOME}/OpenNept4une/dtb/n4-n4pro-v${pcb_version}/rk3328-roc-cc.dtb"
        FLAG_LINE=$(echo "$model_key" | sed -E 's/^(.)(4)(.?)/\U\1\2\u\3/')-${motor_current}A-v${pcb_version}
    else
        PRINTER_CFG_SOURCE="${HOME}/OpenNept4une/printer-confs/${model_key}/${model_key}-printer.cfg"
        DTB_SOURCE="${HOME}/OpenNept4une/dtb/n4plus-n4max-v1.1-2.0/rk3328-roc-cc.dtb"
        FLAG_LINE=$(echo "$model_key" | sed -E 's/^(.)(4)(.?)/\U\1\2\u\3/')-

    fi

    # Create directories if they don't exist
    mkdir -p "$PRINTER_CFG_DEST" "$DATABASE_DEST"

    update_flag_file() {
    local flag_value=$1
    # Use sudo with awk to read and update the flag file, then use sudo tee to overwrite the original file
    sudo awk -v line="$flag_value" '
    BEGIN { added = 0 }
    /^N4/ { print line; added = 1; next }
    { print }
    END { if (!added) print line }
    ' "$FLAG_FILE" | sudo tee "$FLAG_FILE" > /dev/null
    }

    update_flag_file "$FLAG_LINE"
    apply_configuration
    reboot_system
}


apply_configuration() {

    # Backup existing printer configuration if it exists
    if [[ -f "$PRINTER_CFG_FILE" ]]; then
        cp "$PRINTER_CFG_FILE" "$BACKUP_PRINTER_CFG_FILE" && \
        echo "Backup of 'printer.cfg' created as '$BACKUP_PRINTER_CFG_FILE'." || \
        echo "Error: Failed to create backup of 'printer.cfg'."
    fi

    # Copy new printer configuration
    if [[ -n "$PRINTER_CFG_SOURCE" && -f "$PRINTER_CFG_SOURCE" ]]; then
        cp "$PRINTER_CFG_SOURCE" "$PRINTER_CFG_FILE" && \
        echo "Printer configuration updated from '$PRINTER_CFG_SOURCE'." || \
        echo "Error: Failed to update printer configuration from '$PRINTER_CFG_SOURCE'."
    else
        echo "Error: Invalid printer configuration file '$PRINTER_CFG_SOURCE'."
        sleep 2
        return 1
    fi

    # DTB file update prompt
    if [[ -n "$DTB_SOURCE" && -f "$DTB_SOURCE" ]]; then
        local update_dtb=false
        if [ "$auto_yes" != "true" ]; then
            read -p "Update DTB file? Recommended for first-time setup. (y/N): " -r reply
            [[ $reply =~ ^[Yy]$ ]] && update_dtb=true
        else
            update_dtb=true
        fi

        if $update_dtb && ! grep -q "mks" /boot/.OpenNept4une.txt; then
            sudo cp "$DTB_SOURCE" "$DTB_DEST" && \
            echo "DTB file updated from '$DTB_SOURCE'." || \
            echo "Error: Failed to update DTB file from '$DTB_SOURCE'."
        elif grep -q "mks" /boot/.OpenNept4une.txt; then
            echo -e "\nSkipping DTB update based on system check.\n"
            sleep 2
        fi
    elif [[ -n "$DTB_SOURCE" ]]; then
        echo "Error: DTB file '$DTB_SOURCE' not found."
        sleep 2
        return 1
    fi

    local install_configs="$auto_yes"  # Defaults to the value of auto_yes
    if [ "$auto_yes" != "true" ]; then
        echo "The latest KAMP/moonraker/fluiddGUI configurations include updated settings and features for your printer."
        echo "It's recommended for first-time installs or if you want to reset to the default configurations."
        read -p "Install latest configurations? (y/N): " -r choice
        [[ $choice =~ ^[Yy]$ ]] && install_configs="true"
    fi

    # Install the configurations if confirmed
    if [ "$install_configs" = "true" ]; then
        echo "Installing latest configurations..."
        if cp -r ~/OpenNept4une/img-config/printer-data/* ~/printer_data/config/ && \
           mv ~/printer_data/config/data.mdb ~/printer_data/database/data.mdb; then
            echo "Configurations installed successfully."
        else
            echo "Error: Failed to install latest configurations."
            return 1
        fi
    else
        echo "Installation of latest configurations skipped."
    fi
}


reboot_system() {
    clear_screen
    echo -e "\033[0;94m$OPENNEPT4UNE_ART\033[0m"
    if [ $auto_yes = false ]; then
        echo "The system needs to be rebooted to continue. Reboot now? (y/n)"
        read -p "Enter your choice (highly advised): " REBOOT_CHOICE
    fi
    if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ || $auto_yes = true ]]; then
        echo "System will reboot now."
        sudo reboot
    else
        echo "Reboot canceled."
    fi
}


print_help() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND
OpenNept4une configuration script.

Options:
  -y, --yes                  Automatically confirm all prompts (non-interactive mode).
  --printer_model=MODEL      Specify the printer model (e.g., n4, n4pro, n4plus / n4max).
  --motor_current=VALUE      Specify the stepper motor current (e.g., 0.8, 1.2).
  --pcb_version=VALUE        Specify the PCB version (e.g., 1.0, 1.1).
  -h, --help                 Display this help message and exit.

Commands:
  install_printer_cfg        Install or update the OpenNept4une Printer.cfg and other configurations.
  usb_auto_mount             Enable USB storage auto-mount feature.
  update_mcu_rpi_fw          Update MCU & Virtual MCU RPi firmware.
  install_screen_service     Install or update the Touch-Screen Display Service (BETA).
  update_repo                Update the OpenNept4une repository to the latest version.
  android_rules              Install Android ADB rules (for klipperscreen).
  crowsnest_fix              Install Crowsnest FPS fix.
  base_image_config          Apply base configuration for ZNP-K1 Compiled Image (Not for release images).
  de_elegoo_image_cleanser   Run Elegoo Image/eMMC Cleanser Script (Use with caution).
  armbian_resize             Resize the active Armbian partition (for eMMC > 8GB).

EOF
}

# Function to Print the Main Menu
print_menu() {
    clear_screen
    echo -e "\033[0;94m$OPENNEPT4UNE_ART\033[0m"
    echo "======================================"
    echo "              Main Menu               "
    echo "======================================"
    echo "1) Install/Update OpenNept4une printer configurations"
    echo ""
    echo "2) Configure WiFi"
    echo ""
    echo "3) Enable USB Storage AutoMount"
    echo ""
    echo "4) Update MCU & Virtual MCU Firmware"
    echo ""
    echo "5) Install/Update Touch-Screen Service (BETA)"
    echo ""
    echo "6) Advanced Options"
    echo ""
    echo "7) Update OpenNept4une Repository"
    echo ""
    echo "8) Exit"
    echo "======================================"
    echo "Select an option by entering a number (1-8):"
}

# Parse Command-Line Arguments
TEMP=$(getopt -o yh --long yes,help,printer_model:,motor_current:,pcb_version: -n 'OpenNept4une.sh' -- "$@")
if [ $? != 0 ]; then echo "Failed to parse options." >&2; exit 1; fi
eval set -- "$TEMP"

# Process Options
while true; do
    case "$1" in
        --printer_model) model_key="$2"; shift 2 ;;
        --motor_current) motor_current="$2"; shift 2 ;;
        --pcb_version) pcb_version="$2"; shift 2 ;;
        -y|--yes) auto_yes=true; shift ;;
        -h|--help) print_help; exit 0 ;;
        --) shift; break ;;
        *) echo "Invalid option: $1"; exit 1 ;;
    esac
done

# Main Script Logic
if [ -z "$1" ]; then
    run_fixes
    update_repo

    while true; do
        print_menu
        read -p "Enter your choice: " choice
        case $choice in
            1) install_printer_cfg ;;
            2) wifi_config ;;
            3) usb_auto_mount ;;
            4) update_mcu_rpi_fw ;;
            5) install_screen_service ;;
            6) advanced_more ;;
            7) update_repo ;;
            8) echo "Exiting..."; exit 0 ;;
            *) echo "Invalid choice. Please try again."; ;;
        esac
    done
else
    run_fixes
    # Direct command execution
    COMMAND=$1;
    case $COMMAND in
        install_printer_cfg) install_printer_cfg ;;
        wifi_config) wifi_config ;;
        usb_auto_mount) usb_auto_mount ;;
        update_mcu_rpi_fw) update_mcu_rpi_fw ;;
        install_screen_service) install_screen_service ;;
        update_repo) update_repo ;;
        android_rules) android_rules ;;
        crowsnest_fix) crowsnest_fix ;;
        base_image_config) base_image_config ;;
        de_elegoo_image_cleanser) de_elegoo_image_cleanser ;;
        armbian_resize) armbian_resize ;;
        *) echo "Invalid command. Please try again." ;;
    esac
fi
