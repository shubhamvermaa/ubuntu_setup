#!/bin/bash
# set_custom_keybindings.sh
# Applies custom GNOME keyboard shortcuts on Fedora.

if [ "$EUID" -eq 0 ]; then
    echo "Warning: Do not run this script with sudo. Run it as your normal user."
    exit 1
fi

echo "Setting custom GNOME keyboard shortcuts..."

# 1. Allow window switcher (Ctrl+Tab / Alt+Tab) to switch windows across all workspaces
gsettings set org.gnome.shell.window-switcher current-workspace-only false

# 2. Unbind Super+M from notification tray so Super+M works for maximize
gsettings set org.gnome.shell.keybindings toggle-message-tray "['<Super>v']"

# 3. Set Super+M to toggle maximize/unmaximize window
gsettings set org.gnome.desktop.wm.keybindings toggle-maximized "['<Super>m']"

# 4. Remove Ctrl+Space from IBus (keyboard language switching) to prevent interference
gsettings set org.freedesktop.ibus.general.hotkey trigger "['Zenkaku_Hankaku', 'Alt+Kanji', 'Alt+grave', 'Hangul', 'Alt+Release+Alt_R']"

# 5. Unbind Ctrl+Space from GNOME overview and bind to Rofi Launcher
gsettings set org.gnome.desktop.wm.keybindings panel-main-menu "['<Alt>F1']"
gsettings set org.gnome.shell.keybindings toggle-overview "[]"
python3 -c "
import subprocess
prefix = 'org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom59/'
subprocess.run(['gsettings', 'set', prefix, 'name', 'Rofi Type-1 Style-5 Launcher'], check=False)
subprocess.run(['gsettings', 'set', prefix, 'command', '/home/shubham/.local/bin/rofi-launcher'], check=False)
subprocess.run(['gsettings', 'set', prefix, 'binding', '<Control>space'], check=False)
"

echo "Done! Shortcuts applied successfully."
