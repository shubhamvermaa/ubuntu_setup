#!/bin/bash

# Exit on any error
set -e

echo "================================================="
echo "   GNOME Wayland OCR Setup Script                "
echo "================================================="

echo -e "\n[1/4] Installing dependencies..."
# wl-clipboard handles copying to wayland clipboard
# tesseract-ocr handles the optical character recognition
# libnotify-bin provides notify-send
sudo apt update
sudo apt install -y tesseract-ocr tesseract-ocr-eng wl-clipboard libnotify-bin

echo -e "\n[2/4] Creating script directory (~/.local/bin)..."
mkdir -p "$HOME/.local/bin"

echo -e "\n[3/4] Copying the OCR script to ~/.local/bin/ocr-to-clipboard.sh..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$SCRIPT_DIR/ocr-to-clipboard.sh" ]; then
    echo "Error: ocr-to-clipboard.sh not found in the installation directory."
    exit 1
fi

cp "$SCRIPT_DIR/ocr-to-clipboard.sh" "$HOME/.local/bin/ocr-to-clipboard.sh"
chmod +x "$HOME/.local/bin/ocr-to-clipboard.sh"

echo -e "\n[4/4] Configuring GNOME keyboard shortcut (Win + Shift + O)..."
# Get the current custom keybindings array
CURRENT_BINDINGS=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)
BINDING_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ocr-clipboard/"

if [[ $CURRENT_BINDINGS != *"'/"* ]]; then
    # It's an empty array like `@as []`
    NEW_BINDINGS="['$BINDING_PATH']"
elif [[ $CURRENT_BINDINGS != *"$BINDING_PATH"* ]]; then
    # Append to existing array
    NEW_BINDINGS=$(echo "$CURRENT_BINDINGS" | sed "s#]#, '$BINDING_PATH']#")
else
    # Already exists
    NEW_BINDINGS="$CURRENT_BINDINGS"
fi

gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$NEW_BINDINGS"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$BINDING_PATH" name 'OCR to Clipboard'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$BINDING_PATH" command "$HOME/.local/bin/ocr-to-clipboard.sh"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$BINDING_PATH" binding '<Super><Shift>O'

echo -e "\n================================================="
echo "Setup Complete!"
echo "You can now use Win + Shift + O to extract text!"
echo "================================================="
