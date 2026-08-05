#!/usr/bin/env bash
# ==============================================================================
# Rofi Type-1 Style-5 Automated Setup Script for Fedora (GNOME Wayland)
# ==============================================================================
# Features:
# - Installs Rofi & dependencies (rofi, xprop, fontconfig)
# - Installs required fonts (JetBrains Mono Nerd Font, Feather Icons)
# - Deploys 2x scaled Type-1 Style-5 Catppuccin theme to ~/.config/rofi
# - Deploys launcher wrapper script to ~/.local/bin/rofi-launcher
# - Precise WM_CLASS Focus Auto-Dismiss: Cancels Rofi when clicking another window
# - Configures GNOME Super+D shortcut to toggle Rofi with focus support
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FONT_DIR="$HOME/.local/share/fonts"
ROFI_CONFIG_DIR="$HOME/.config/rofi"
BIN_DIR="$HOME/.local/bin"

if [ "$EUID" -eq 0 ]; then
    echo "Error: Do not run this script with sudo directly."
    echo "Run it as your normal user. It will prompt for sudo when installing packages."
    exit 1
fi

echo "=========================================="
echo " Starting Rofi Setup for Fedora GNOME"
echo "=========================================="

# 1. Check and install system packages
echo "[1/5] Checking required packages..."
MISSING_PKGS=()

if ! command -v rofi &> /dev/null; then
    MISSING_PKGS+=("rofi")
fi
if ! command -v xprop &> /dev/null; then
    MISSING_PKGS+=("xprop")
fi

if [ ${#MISSING_PKGS[@]} -ne 0 ]; then
    echo "Installing missing package(s): ${MISSING_PKGS[*]}..."
    sudo dnf install -y "${MISSING_PKGS[@]}"
else
    echo "All required system packages are already installed."
fi

# 2. Install bundled fonts
echo "[2/5] Installing fonts to $FONT_DIR..."
mkdir -p "$FONT_DIR"
if [ -d "$SCRIPT_DIR/assets/fonts" ]; then
    cp -rf "$SCRIPT_DIR/assets/fonts"/* "$FONT_DIR/"
    fc-cache -f "$FONT_DIR"
    echo "Fonts installed and cache refreshed."
else
    echo "Warning: Font directory not found in assets. Skipping font copy."
fi

# 3. Install Rofi theme configurations
echo "[3/5] Deploying Rofi theme configuration..."
mkdir -p "$ROFI_CONFIG_DIR"
if [ -d "$SCRIPT_DIR/assets/rofi_config" ]; then
    cp -rf "$SCRIPT_DIR/assets/rofi_config"/* "$ROFI_CONFIG_DIR/"
    echo "Theme files successfully copied to $ROFI_CONFIG_DIR."
else
    echo "Error: Rofi config assets not found!"
    exit 1
fi

# 4. Create and install wrapper launcher script with focus auto-dismiss and WindowCycler integration
echo "[4/5] Creating launcher scripts in $BIN_DIR..."
mkdir -p "$BIN_DIR"

cat << 'EOF' > "$BIN_DIR/rofi-exec-helper"
#!/usr/bin/env python3
"""
Rofi Execution Helper with WindowCycler Integration.
Switches to an existing open window if available; otherwise launches a new instance.
"""
import glob
import os
import subprocess
import sys

EXPLICIT_MAP = {
    "firefox": "org.mozilla.firefox.desktop",
    "ghostty": "com.mitchellh.ghostty.desktop",
    "ptyxis": "org.gnome.Ptyxis.desktop",
    "code": "code.desktop",
    "nautilus": "org.gnome.Nautilus.desktop",
    "google-chrome": "google-chrome.desktop",
    "chrome": "google-chrome.desktop",
    "spotify": "spotify.desktop",
    "slack": "slack.desktop",
    "discord": "discord.desktop",
}

def get_wayland_display():
    uid = os.getuid()
    sockets = glob.glob(f"/run/user/{uid}/wayland-*")
    for s in sockets:
        if not s.endswith(".lock"):
            return os.path.basename(s)
    return "wayland-0"

def find_app_id(cmd_str):
    tokens = cmd_str.strip().split()
    if not tokens:
        return None
    
    bin_name = os.path.basename(tokens[0]).lower()
    if bin_name in EXPLICIT_MAP:
        return EXPLICIT_MAP[bin_name]

    search_dirs = [
        os.path.expanduser("~/.local/share/applications"),
        "/usr/share/applications",
        "/var/lib/flatpak/exports/share/applications",
    ]

    for d in search_dirs:
        if not os.path.isdir(d):
            continue
        for filepath in glob.glob(os.path.join(d, "*.desktop")):
            fname = os.path.basename(filepath)
            fname_lower = fname.lower()
            if fname_lower.startswith(bin_name) or f".{bin_name}." in fname_lower or fname_lower == f"{bin_name}.desktop":
                return fname

    for d in search_dirs:
        if not os.path.isdir(d):
            continue
        for filepath in glob.glob(os.path.join(d, "*.desktop")):
            fname_lower = os.path.basename(filepath).lower()
            if bin_name in fname_lower:
                return os.path.basename(filepath)

    return bin_name + ".desktop"

def cycle_or_launch(cmd_str):
    env = os.environ.copy()
    wayland_disp = get_wayland_display()
    env["WAYLAND_DISPLAY"] = wayland_disp

    app_id = find_app_id(cmd_str)
    
    # 1. Try to focus an existing window via WindowCycler
    if app_id:
        try:
            res = subprocess.check_output([
                "gdbus", "call", "--session",
                "--dest", "org.gnome.Shell",
                "--object-path", "/org/gnome/shell/extensions/WindowCycler",
                "--method", "org.gnome.Shell.Extensions.WindowCycler.CycleAppWindows",
                app_id
            ], env=env, stderr=subprocess.DEVNULL).decode().strip()
            
            if "(1,)" in res:
                sys.exit(0)
        except Exception:
            pass

        # 2. Launch using gtk-launch with restored Wayland environment
        try:
            subprocess.Popen(["gtk-launch", app_id], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            sys.exit(0)
        except Exception:
            pass

    # 3. Fallback: Strip freedesktop field codes (%F, %u, etc.) and launch raw command
    clean_cmd = re.sub(r'%\w', '', cmd_str).strip()
    subprocess.Popen(clean_cmd, shell=True, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    sys.exit(0)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        full_cmd = " ".join(sys.argv[1:])
        cycle_or_launch(full_cmd)
EOF

chmod +x "$BIN_DIR/rofi-exec-helper"

cat << 'EOF' > "$BIN_DIR/rofi-launcher"
#!/usr/bin/env python3
import subprocess
import sys
import time

def get_rofi_window_id():
    try:
        out = subprocess.check_output(
            ['xprop', '-display', ':0', '-root', '_NET_CLIENT_LIST'],
            stderr=subprocess.DEVNULL
        ).decode()
        parts = out.strip().split('#')
        if len(parts) > 1:
            win_ids = parts[1].split(',')
            for wid in win_ids:
                wid = wid.strip()
                if not wid:
                    continue
                try:
                    c_out = subprocess.check_output(
                        ['xprop', '-display', ':0', '-id', wid, 'WM_CLASS'],
                        stderr=subprocess.DEVNULL
                    ).decode()
                    if 'rofi' in c_out.lower():
                        return wid
                except Exception:
                    pass
    except Exception:
        pass
    return None

def get_active_window():
    try:
        out = subprocess.check_output(
            ['xprop', '-display', ':0', '-root', '_NET_ACTIVE_WINDOW'],
            stderr=subprocess.DEVNULL
        ).decode()
        parts = out.strip().split('#')
        if len(parts) > 1:
            return parts[1].strip()
    except Exception:
        pass
    return None

def main():
    # 1. Instant Toggle: If rofi is running, kill it immediately (0ms delay)
    res = subprocess.run(['pgrep', '-x', 'rofi'], stdout=subprocess.DEVNULL)
    if res.returncode == 0:
        subprocess.run(['pkill', '-9', '-x', 'rofi'])
        sys.exit(0)

    # 2. Launch Rofi instantly
    theme_path = '/home/shubham/.config/rofi/launchers/type-1/style-5.rasi'
    rofi_proc = subprocess.Popen(
        ['env', 'WAYLAND_DISPLAY=', 'rofi', '-normal-window', '-steal-focus', '-show', 'drun', '-theme', theme_path],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    # 3. High-speed window ID detection (10ms polling)
    rofi_win_id = None
    for _ in range(40):
        time.sleep(0.01)
        if rofi_proc.poll() is not None:
            sys.exit(0)
        wid = get_rofi_window_id()
        if wid:
            rofi_win_id = wid
            break

    if not rofi_win_id:
        rofi_proc.wait()
        sys.exit(0)

    # 4. Fast active window confirmation
    for _ in range(20):
        time.sleep(0.01)
        if get_active_window() == rofi_win_id:
            break

    # 5. Ultra-fast focus-loss monitor loop (20ms polling for instant dismiss)
    while rofi_proc.poll() is None:
        time.sleep(0.02)
        curr_active = get_active_window()
        if curr_active and curr_active != rofi_win_id:
            subprocess.run(['pkill', '-9', '-x', 'rofi'])
            break

    sys.exit(0)

if __name__ == '__main__':
    main()
EOF

chmod +x "$BIN_DIR/rofi-launcher"
echo "Launcher script installed."

# 5. Register GNOME custom keybinding (Ctrl+Space)
echo "[5/5] Configuring GNOME shortcut (Ctrl+Space)..."
python3 - << 'PYEOF'
import subprocess, ast

# Unbind Ctrl+Space from GNOME Overview to avoid conflict
subprocess.run(['gsettings', 'set', 'org.gnome.shell.keybindings', 'toggle-overview', '[]'], check=False)
subprocess.run(['gsettings', 'set', 'org.gnome.desktop.wm.keybindings', 'panel-main-menu', "['<Alt>F1']"], check=False)

target_cmd = '/home/shubham/.local/bin/rofi-launcher'
target_binding = '<Control>space'
target_name = 'Rofi Type-1 Style-5 Launcher'

# Get existing custom keybinding list
cmd_get = ['gsettings', 'get', 'org.gnome.settings-daemon.plugins.media-keys', 'custom-keybindings']
out = subprocess.check_output(cmd_get).decode().strip()

try:
    bindings_list = ast.literal_eval(out)
except Exception:
    bindings_list = []

# Find existing rofi keybinding or allocate next available slot
target_slot = None
for slot in bindings_list:
    schema_path = f"org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:{slot}"
    try:
        c = subprocess.check_output(['gsettings', 'get', schema_path, 'command']).decode().strip().strip("'")
        if c == target_cmd or 'rofi-launcher' in c or 'rofi' in c:
            target_slot = slot
            break
    except Exception:
        pass

if not target_slot:
    idx = 50
    while True:
        candidate = f"/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom{idx}/"
        if candidate not in bindings_list:
            target_slot = candidate
            bindings_list.append(target_slot)
            break
        idx += 1
    
    subprocess.run(['gsettings', 'set', 'org.gnome.settings-daemon.plugins.media-keys', 'custom-keybindings', str(bindings_list)], check=True)

schema_path = f"org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:{target_slot}"
subprocess.run(['gsettings', 'set', schema_path, 'name', target_name], check=True)
subprocess.run(['gsettings', 'set', schema_path, 'command', target_cmd], check=True)
subprocess.run(['gsettings', 'set', schema_path, 'binding', target_binding], check=True)

print(f"Registered shortcut {target_binding} -> {target_cmd} at {target_slot}")
PYEOF

echo "=========================================="
echo " Setup Completed Successfully!"
echo " Press Super+D to test your Rofi launcher."
echo "=========================================="
