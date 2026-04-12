#!/usr/bin/env bash

# This script automatically detects the EasyEffects presets directory and installs the local presets

check_installation() {
    if command -v flatpak &>/dev/null && flatpak list | grep -q "com.github.wwmm.easyeffects"; then
        # Check for new data-based path first, then fallback to config-based path
        if [ -d "$HOME/.var/app/com.github.wwmm.easyeffects/data/easyeffects" ]; then
            PRESETS_DIRECTORY="$HOME/.var/app/com.github.wwmm.easyeffects/data/easyeffects"
        else
            PRESETS_DIRECTORY="$HOME/.var/app/com.github.wwmm.easyeffects/config/easyeffects"
        fi
    elif command -v easyeffects &>/dev/null; then
        PRESETS_DIRECTORY="$HOME/.config/easyeffects"
    else
        # Fallback to default path if command not found but directory might exist
        if [ -d "$HOME/.config/easyeffects" ]; then
            PRESETS_DIRECTORY="$HOME/.config/easyeffects"
        elif [ -d "$HOME/.var/app/com.github.wwmm.easyeffects/data/easyeffects" ]; then
            PRESETS_DIRECTORY="$HOME/.var/app/com.github.wwmm.easyeffects/data/easyeffects"
        elif [ -d "$HOME/.var/app/com.github.wwmm.easyeffects/config/easyeffects" ]; then
            PRESETS_DIRECTORY="$HOME/.var/app/com.github.wwmm.easyeffects/config/easyeffects"
        else
            echo "Error! Couldn't find EasyEffects installation!"
            exit 1
        fi
    fi
    mkdir -p "$PRESETS_DIRECTORY/output"
    mkdir -p "$PRESETS_DIRECTORY/input"
}

install_local_presets() {
    # Get the directory where the script is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "Installing presets from $SCRIPT_DIR..."

    for file in "$SCRIPT_DIR"/*.json; do
        # Check if any .json files exist
        [ -f "$file" ] || continue
        
        filename=$(basename "$file")
        
        # Determine if it's an input or output preset by checking content
        if grep -q '"output":' "$file"; then
            echo "Installing output preset: $filename"
            cp "$file" "$PRESETS_DIRECTORY/output/$filename"
        elif grep -q '"input":' "$file"; then
            echo "Installing input preset: $filename"
            cp "$file" "$PRESETS_DIRECTORY/input/$filename"
        else
            echo "Skipping $filename (could not determine preset type)"
        fi
    done
}

check_installation
install_local_presets

echo ""
echo "Installation complete!"
echo "Presets have been installed to: $PRESETS_DIRECTORY"
echo "You can now select them in EasyEffects."
