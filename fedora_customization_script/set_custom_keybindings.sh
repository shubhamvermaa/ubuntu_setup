#!/usr/bin/env bash
# ==============================================================================
# set_custom_keybindings.sh
# Applies custom GNOME keyboard shortcuts and app window switchers on Fedora.
# ==============================================================================

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

# 6. Configure Application Switchers & Rofi Shortcut via Python GSettings helper
python3 - << 'PYEOF'
import os, subprocess, ast

home = os.path.expanduser("~")
switch_script = os.path.join(home, ".local/bin/switch-app-window.sh")
rofi_script = os.path.join(home, ".local/bin/rofi-launcher")

SHORTCUTS = [
    ("Switch to Gemini", f"{switch_script} gemini.desktop", "<Super><Shift>g"),
    ("Switch to Files", f"{switch_script} org.gnome.Nautilus.desktop nautilus", "<Super><Shift>e"),
    ("Switch to Ghostty", f"{switch_script} com.mitchellh.ghostty.desktop", "<Super><Shift>t"),
    ("Switch to Antigravity", f"{switch_script} antigravity-ide.desktop", "<Super><Shift>a"),
    ("Switch to VS Code", f"{switch_script} code.desktop", "<Super><Shift>v"),
    ("Switch to Firefox", f"{switch_script} org.mozilla.firefox.desktop", "<Super><Shift>f"),
    ("Switch to Terminal", f"{switch_script} org.gnome.Ptyxis.desktop ptyxis --new-window", "<Super><Shift>r"),
    ("Switch to ChatGPT", f"{switch_script} chatgpt.desktop", "<Super><Shift>c"),
    ("Switch to Notion", f"{switch_script} notion.desktop", "<Super><Shift>n"),
    ("Rofi Type-1 Style-5 Launcher", rofi_script, "<Control>space"),
]

cmd_get = ['gsettings', 'get', 'org.gnome.settings-daemon.plugins.media-keys', 'custom-keybindings']
out = subprocess.check_output(cmd_get).decode().strip()

try:
    bindings_list = ast.literal_eval(out)
except Exception:
    bindings_list = []

registered_slots = list(bindings_list)
idx = 50

for name, command, binding in SHORTCUTS:
    target_slot = None
    for slot in registered_slots:
        schema = f"org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:{slot}"
        try:
            c = subprocess.check_output(['gsettings', 'get', schema, 'command']).decode().strip().strip("'")
            b = subprocess.check_output(['gsettings', 'get', schema, 'binding']).decode().strip().strip("'")
            if c == command or b == binding:
                target_slot = slot
                break
        except Exception:
            pass

    if not target_slot:
        while True:
            candidate = f"/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom{idx}/"
            if candidate not in registered_slots:
                target_slot = candidate
                registered_slots.append(target_slot)
                break
            idx += 1

    schema = f"org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:{target_slot}"
    subprocess.run(['gsettings', 'set', schema, 'name', name], check=True)
    subprocess.run(['gsettings', 'set', schema, 'command', command], check=True)
    subprocess.run(['gsettings', 'set', schema, 'binding', binding], check=True)
    print(f"  ✓ {binding} -> {name}")

subprocess.run(['gsettings', 'set', 'org.gnome.settings-daemon.plugins.media-keys', 'custom-keybindings', str(registered_slots)], check=True)
PYEOF

echo "Done! Shortcuts applied successfully."
