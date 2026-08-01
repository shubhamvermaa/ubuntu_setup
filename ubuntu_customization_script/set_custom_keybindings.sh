#!/bin/bash
# set_custom_keybindings.sh
# Applies custom GNOME keyboard shortcuts.

echo "Setting custom GNOME keyboard shortcuts..."

# Set Super+M to toggle maximize/unmaximize
gsettings set org.gnome.desktop.wm.keybindings toggle-maximized "['<Super>m']"

# Set Super+V to open the message tray (notification center)
gsettings set org.gnome.shell.keybindings toggle-message-tray "['<Super>v']"
# Unbind Ctrl+Space from GNOME Search
gsettings set org.gnome.settings-daemon.plugins.media-keys search "['<Super>s']"

# Remove Ctrl+Space from IBus (keyboard language switching) to prevent interference
gsettings set org.freedesktop.ibus.general.hotkey trigger "['Zenkaku_Hankaku', 'Alt+Kanji', 'Alt+grave', 'Hangul', 'Alt+Release+Alt_R']"

# Bind Ctrl+Space to toggle the Activities Overview
gsettings set org.gnome.desktop.wm.keybindings panel-main-menu "['<Control>space', '<Super>s', '<Alt>F1']"

echo "Done! Shortcuts applied successfully."
