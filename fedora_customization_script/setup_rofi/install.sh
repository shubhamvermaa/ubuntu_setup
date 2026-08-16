#!/usr/bin/env bash
# ==============================================================================
# Rofi Type-1 Style-5 Automated Setup Script for Fedora (GNOME Wayland)
# ==============================================================================
# Features:
# - Installs Rofi & dependencies (rofi, xprop, xwininfo, gcc, fontconfig)
# - Installs required fonts (JetBrains Mono Nerd Font, Feather Icons)
# - Deploys Type-1 Style-5 Catppuccin theme to ~/.config/rofi
# - Compiles & deploys XWayland environment bridge (librofix11.so) to ~/.local/lib
# - Deploys smart launcher wrapper to ~/.local/bin/rofi-launcher with:
#     * Dynamic relative DPI detection for 1080p, 2K, and 4K displays
#     * Instant toggle & ultra-fast focus-loss auto-dismiss
# - Deploys ~/.local/bin/rofi-exec-helper with WindowCycler & Flatpak/PWA support
# - Configures GNOME Ctrl+Space shortcut to toggle Rofi
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FONT_DIR="$HOME/.local/share/fonts"
ROFI_CONFIG_DIR="$HOME/.config/rofi"
BIN_DIR="$HOME/.local/bin"
LIB_DIR="$HOME/.local/lib"

if [ "$EUID" -eq 0 ]; then
    echo "Error: Do not run this script with sudo directly."
    echo "Run it as your normal user. It will prompt for sudo when installing packages."
    exit 1
fi

echo "=========================================="
echo " Starting Rofi Setup for Fedora GNOME"
echo "=========================================="

# 1. Check and install system packages
echo "[1/6] Checking required packages..."
MISSING_PKGS=()

for pkg in rofi xprop xwininfo gcc fontconfig; do
    if ! command -v "$pkg" &> /dev/null; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -ne 0 ]; then
    echo "Installing missing package(s): ${MISSING_PKGS[*]}..."
    sudo dnf install -y "${MISSING_PKGS[@]}"
else
    echo "All required system packages are already installed."
fi

# 2. Install bundled fonts
echo "[2/6] Installing fonts to $FONT_DIR..."
mkdir -p "$FONT_DIR"
if [ -d "$SCRIPT_DIR/assets/fonts" ]; then
    cp -rf "$SCRIPT_DIR/assets/fonts"/* "$FONT_DIR/"
    fc-cache -f "$FONT_DIR"
    echo "Fonts installed and cache refreshed."
else
    echo "Warning: Font directory not found in assets. Skipping font copy."
fi

# 3. Install Rofi theme configurations
echo "[3/6] Deploying Rofi theme configuration..."
mkdir -p "$ROFI_CONFIG_DIR"
if [ -d "$SCRIPT_DIR/assets/rofi_config" ]; then
    cp -rf "$SCRIPT_DIR/assets/rofi_config"/* "$ROFI_CONFIG_DIR/"
    echo "Theme files successfully copied to $ROFI_CONFIG_DIR."
else
    echo "Error: Rofi config assets not found!"
    exit 1
fi

# 4. Compile and install librofix11.so environment bridge
echo "[4/6] Compiling and installing XWayland environment bridge (librofix11.so)..."
mkdir -p "$LIB_DIR"

cat << 'EOF' > "$LIB_DIR/librofix11.c"
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <unistd.h>
#include <spawn.h>

static char *saved_wayland_display = NULL;

__attribute__((constructor))
static void init(void) {
    const char *wd = getenv("WAYLAND_DISPLAY");
    if (wd && wd[0] != '\0') {
        saved_wayland_display = strdup(wd);
    } else {
        saved_wayland_display = strdup("wayland-0");
    }
    // Unset WAYLAND_DISPLAY so rofi initializes with X11 backend
    unsetenv("WAYLAND_DISPLAY");
    unsetenv("LD_PRELOAD");
}

static char **fix_env(char *const envp[]) {
    if (!saved_wayland_display) return (char **)envp;
    
    int count = 0;
    while (envp && envp[count]) count++;
    
    char **new_env = malloc((count + 3) * sizeof(char *));
    if (!new_env) return (char **)envp;

    int j = 0;
    int has_wd = 0;
    for (int i = 0; i < count; i++) {
        if (strncmp(envp[i], "WAYLAND_DISPLAY=", 16) == 0) {
            char buf[256];
            snprintf(buf, sizeof(buf), "WAYLAND_DISPLAY=%s", saved_wayland_display);
            new_env[j++] = strdup(buf);
            has_wd = 1;
        } else if (strncmp(envp[i], "LD_PRELOAD=", 11) == 0) {
            // strip LD_PRELOAD
        } else {
            new_env[j++] = strdup(envp[i]);
        }
    }
    if (!has_wd) {
        char buf[256];
        snprintf(buf, sizeof(buf), "WAYLAND_DISPLAY=%s", saved_wayland_display);
        new_env[j++] = strdup(buf);
    }
    new_env[j] = NULL;
    return new_env;
}

// Clean argv by removing standalone @@u and @@ arguments from Flatpak commands
static char **fix_argv(char *const argv[]) {
    if (!argv) return NULL;
    int count = 0;
    while (argv[count]) count++;
    
    char **new_argv = malloc((count + 1) * sizeof(char *));
    if (!new_argv) return (char **)argv;

    int j = 0;
    for (int i = 0; i < count; i++) {
        if (strcmp(argv[i], "@@u") == 0 || strcmp(argv[i], "@@") == 0) {
            continue; // filter out empty forwarding markers
        }
        new_argv[j++] = argv[i];
    }
    new_argv[j] = NULL;
    return new_argv;
}

int execve(const char *pathname, char *const argv[], char *const envp[]) {
    static int (*real_execve)(const char *, char *const [], char *const []) = NULL;
    if (!real_execve) real_execve = dlsym(RTLD_NEXT, "execve");
    
    if (saved_wayland_display) {
        setenv("WAYLAND_DISPLAY", saved_wayland_display, 1);
    }
    char **new_env = fix_env(envp ? envp : environ);
    char **new_argv = fix_argv(argv);
    return real_execve(pathname, new_argv, new_env);
}

int execvp(const char *file, char *const argv[]) {
    static int (*real_execvp)(const char *, char *const []) = NULL;
    if (!real_execvp) real_execvp = dlsym(RTLD_NEXT, "execvp");
    if (saved_wayland_display) {
        setenv("WAYLAND_DISPLAY", saved_wayland_display, 1);
    }
    char **new_argv = fix_argv(argv);
    return real_execvp(file, new_argv);
}

int posix_spawn(pid_t *pid, const char *path,
                const posix_spawn_file_actions_t *file_actions,
                const posix_spawnattr_t *attrp,
                char *const argv[], char *const envp[]) {
    static int (*real_posix_spawn)(pid_t *, const char *, const posix_spawn_file_actions_t *, const posix_spawnattr_t *, char *const [], char *const []) = NULL;
    if (!real_posix_spawn) real_posix_spawn = dlsym(RTLD_NEXT, "posix_spawn");
    if (saved_wayland_display) {
        setenv("WAYLAND_DISPLAY", saved_wayland_display, 1);
    }
    char **new_env = fix_env(envp ? envp : environ);
    char **new_argv = fix_argv(argv);
    return real_posix_spawn(pid, path, file_actions, attrp, new_argv, new_env);
}

int posix_spawnp(pid_t *pid, const char *file,
                 const posix_spawn_file_actions_t *file_actions,
                 const posix_spawnattr_t *attrp,
                 char *const argv[], char *const envp[]) {
    static int (*real_posix_spawnp)(pid_t *, const char *, const posix_spawn_file_actions_t *, const posix_spawnattr_t *, char *const [], char *const []) = NULL;
    if (!real_posix_spawnp) real_posix_spawnp = dlsym(RTLD_NEXT, "posix_spawnp");
    if (saved_wayland_display) {
        setenv("WAYLAND_DISPLAY", saved_wayland_display, 1);
    }
    char **new_env = fix_env(envp ? envp : environ);
    char **new_argv = fix_argv(argv);
    return real_posix_spawnp(pid, file, file_actions, attrp, new_argv, new_env);
}
EOF

gcc -shared -fPIC -O2 -o "$LIB_DIR/librofix11.so" "$LIB_DIR/librofix11.c" -ldl
echo "Compiled $LIB_DIR/librofix11.so successfully."

# 5. Create launcher helper and wrapper scripts in $BIN_DIR
echo "[5/6] Deploying launcher helper scripts to $BIN_DIR..."
mkdir -p "$BIN_DIR"

cat << 'EOF' > "$BIN_DIR/rofi-exec-helper"
#!/usr/bin/env python3
"""
Rofi Execution Helper with WindowCycler Integration.
Restores Wayland environment and switches to an existing open window if available; otherwise launches a new instance using gtk-launch.
"""
import glob
import os
import re
import subprocess
import sys

EXPLICIT_MAP = {
    "gemini": "gemini.desktop",
    "chatgpt": "chatgpt.desktop",
    "notion": "notion.desktop",
    "extension-manager": "com.mattjakeman.ExtensionManager.desktop",
    "extension manager": "com.mattjakeman.ExtensionManager.desktop",
    "extensions": "com.mattjakeman.ExtensionManager.desktop",
    "com.mattjakeman.extensionmanager": "com.mattjakeman.ExtensionManager.desktop",
    "firefox": "org.mozilla.firefox.desktop",
    "ghostty": "com.mitchellh.ghostty.desktop",
    "ptyxis": "org.gnome.Ptyxis.desktop",
    "terminal": "org.gnome.Ptyxis.desktop",
    "code": "code.desktop",
    "visual studio code": "code.desktop",
    "nautilus": "org.gnome.Nautilus.desktop",
    "files": "org.gnome.Nautilus.desktop",
    "google-chrome": "com.google.Chrome.desktop",
    "chrome": "com.google.Chrome.desktop",
    "spotify": "spotify.desktop",
    "slack": "slack.desktop",
    "discord": "discord.desktop",
    "stremio": "com.stremio.Stremio.desktop",
    "antigravity": "antigravity-ide.desktop",
    "antigravity-ide": "antigravity-ide.desktop",
}

def get_wayland_display():
    uid = os.getuid()
    sockets = glob.glob(f"/run/user/{uid}/wayland-*")
    for s in sockets:
        if not s.endswith(".lock"):
            return os.path.basename(s)
    return "wayland-0"

def find_app_id(cmd_str):
    clean = cmd_str.strip()
    clean_lower = clean.lower()

    # Direct keyword matches
    if "gdfaincndogidkdcdkhapmbffkckdkhn" in clean_lower or "gemini" in clean_lower.split():
        return "gemini.desktop"
    if "cadlkienfkclaiaibeoongdcgmdikeeg" in clean_lower or "chatgpt" in clean_lower.split():
        return "chatgpt.desktop"
    if "dcokohelbbehjlcjjfmhfbpdgfjcoopf" in clean_lower or "notion" in clean_lower.split():
        return "notion.desktop"
    if "extensionmanager" in clean_lower or "extension-manager" in clean_lower:
        return "com.mattjakeman.ExtensionManager.desktop"

    tokens = clean.split()
    if not tokens:
        return None
    
    bin_name = os.path.basename(tokens[0]).lower()
    if bin_name in EXPLICIT_MAP:
        return EXPLICIT_MAP[bin_name]

    # Handle Flatpak commands like: flatpak run com.example.App ...
    if bin_name == "flatpak":
        for tok in tokens[1:]:
            tok_clean = tok.strip("'\"")
            if "." in tok_clean and not tok_clean.startswith("-"):
                flatpak_id = tok_clean
                if flatpak_id.lower() in EXPLICIT_MAP:
                    return EXPLICIT_MAP[flatpak_id.lower()]
                return f"{flatpak_id}.desktop"

    search_dirs = [
        os.path.expanduser("~/.local/share/applications"),
        "/var/lib/flatpak/exports/share/applications",
        os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
        "/usr/share/applications",
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

def clean_command_string(cmd_str):
    cmd = re.sub(r'%\w', '', cmd_str)
    cmd = re.sub(r'\b@@u\b', '', cmd)
    cmd = re.sub(r'\b@@\b', '', cmd)
    return cmd.strip()

def cycle_or_launch(cmd_str):
    env = os.environ.copy()
    wayland_disp = get_wayland_display()
    env["WAYLAND_DISPLAY"] = wayland_disp
    if "LD_PRELOAD" in env:
        del env["LD_PRELOAD"]

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
            ], env=env, stderr=subprocess.DEVNULL, timeout=2).decode().strip()
            
            if "(1,)" in res or "(2,)" in res or "(3,)" in res:
                sys.exit(0)
        except Exception:
            pass

        # 2. Launch using gtk-launch with restored Wayland environment
        try:
            proc = subprocess.run(["gtk-launch", app_id], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)
            if proc.returncode == 0:
                sys.exit(0)
        except Exception:
            pass

    # 3. Fallback: launch cleaned raw command with restored Wayland environment
    clean_cmd = clean_command_string(cmd_str)
    subprocess.Popen(clean_cmd, shell=True, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    sys.exit(0)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        full_cmd = " ".join(sys.argv[1:])
        cycle_or_launch(full_cmd)
EOF

chmod +x "$BIN_DIR/rofi-exec-helper"

cat << 'EOF' > "$BIN_DIR/rofi-launcher"
#!/usr/bin/env python3
import os
import re
import subprocess
import sys
import time

def detect_display_dpi():
    """
    Dynamically detect the active monitor's resolution and scaling,
    and compute the relative DPI so Rofi looks identical in physical proportions
    across 1080p, 2K (1440p), and 4K displays.
    """
    base_dpi = 96
    try:
        out = subprocess.check_output([
            "gdbus", "call", "--session",
            "--dest", "org.gnome.Mutter.DisplayConfig",
            "--object-path", "/org/gnome/Mutter/DisplayConfig",
            "--method", "org.gnome.Mutter.DisplayConfig.GetCurrentState"
        ], stderr=subprocess.DEVNULL, timeout=0.2).decode().strip()

        monitors = {}
        for m in re.finditer(r"\(\x27([^\x27]+)\x27,\s*(\d+),\s*(\d+)[^\)]*?\{\x27is-current\x27:\s*<true>\}", out, re.DOTALL):
            mode_id, w, h = m.group(1), int(m.group(2)), int(m.group(3))
            preceding = out[:m.start()]
            conns = re.findall(r"\(\x27([A-Za-z0-9_-]+)\x27,\s*\x27([A-Za-z0-9_-]+)\x27", preceding)
            if conns:
                conn = conns[-1][0]
                monitors[conn] = (w, h)

        log_monitors = re.findall(r"\((\d+),\s*(\d+),\s*([0-9.]+),\s*uint32\s*\d+,\s*(true|false),\s*\[\(\x27([^\x27]+)\x27", out)
        if not log_monitors:
            return base_dpi

        target_conn = log_monitors[0][4]
        target_scale = float(log_monitors[0][2])

        # If multiple monitors are active, check active window position
        if len(log_monitors) > 1:
            try:
                active_out = subprocess.check_output(["xprop", "-display", ":0", "-root", "_NET_ACTIVE_WINDOW"], stderr=subprocess.DEVNULL, timeout=0.05).decode()
                parts = active_out.strip().split("#")
                if len(parts) > 1 and parts[1].strip() != "0x0":
                    wid = parts[1].strip()
                    geom_out = subprocess.check_output(["xwininfo", "-id", wid], stderr=subprocess.DEVNULL, timeout=0.05).decode()
                    xm = re.search(r"Absolute upper-left X:\s*(-?\d+)", geom_out)
                    ym = re.search(r"Absolute upper-left Y:\s*(-?\d+)", geom_out)
                    if xm and ym:
                        wx, wy = int(xm.group(1)), int(ym.group(1))
                        for lm in log_monitors:
                            mx, my, msc, is_prim, mconn = int(lm[0]), int(lm[1]), float(lm[2]), lm[3], lm[4]
                            mw, mh = monitors.get(mconn, (1920, 1080))
                            if mx <= wx < mx + mw and my <= wy < my + mh:
                                target_conn = mconn
                                target_scale = msc
                                break
            except Exception:
                pass
        else:
            primary = [m for m in log_monitors if m[3] == "true"]
            if primary:
                target_conn = primary[0][4]
                target_scale = float(primary[0][2])

        w, h = monitors.get(target_conn, (1920, 1080))
        # Relative ratio vs standard 1080p base:
        # 1080p -> ratio 1.0 -> 96 DPI
        # 1440p -> ratio 1.333 -> 128 DPI
        # 2160p (4K) -> ratio 2.0 -> 192 DPI
        ratio = max(w / 1920.0, h / 1080.0)
        effective_scale = max(ratio, target_scale)
        dpi = int(round(base_dpi * effective_scale))
        return dpi
    except Exception:
        return base_dpi

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

    # 2. Compute dynamic relative DPI based on the active monitor resolution
    target_dpi = detect_display_dpi()

    # 3. Launch Rofi with environment restoration helper library and relative DPI
    home_dir = os.path.expanduser("~")
    theme_path = os.path.join(home_dir, ".config/rofi/launchers/type-1/style-5.rasi")
    lib_path = os.path.join(home_dir, ".local/lib/librofix11.so")

    env = os.environ.copy()
    if os.path.isfile(lib_path):
        env['LD_PRELOAD'] = lib_path
    if not env.get('WAYLAND_DISPLAY'):
        env['WAYLAND_DISPLAY'] = 'wayland-0'
    if not env.get('DISPLAY'):
        env['DISPLAY'] = ':0'

    rofi_proc = subprocess.Popen(
        [
            'rofi',
            '-normal-window',
            '-steal-focus',
            '-dpi', str(target_dpi),
            '-show', 'drun',
            '-theme', theme_path,
        ],
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    # 4. High-speed window ID detection (10ms polling)
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

    # 5. Fast active window confirmation
    for _ in range(20):
        time.sleep(0.01)
        if get_active_window() == rofi_win_id:
            break

    # 6. Ultra-fast focus-loss monitor loop (20ms polling for instant dismiss)
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
echo "Launcher and helper scripts installed."

# 6. Register GNOME custom keybinding (Ctrl+Space)
echo "[6/6] Configuring GNOME shortcut (Ctrl+Space)..."
python3 - << 'PYEOF'
import os, subprocess, ast

# Unbind Ctrl+Space from GNOME Overview to avoid conflict
subprocess.run(['gsettings', 'set', 'org.gnome.shell.keybindings', 'toggle-overview', '[]'], check=False)
subprocess.run(['gsettings', 'set', 'org.gnome.desktop.wm.keybindings', 'panel-main-menu', "['<Alt>F1']"], check=False)

home_dir = os.path.expanduser("~")
target_cmd = os.path.join(home_dir, '.local/bin/rofi-launcher')
target_binding = '<Control>space'
target_name = 'Rofi Type-1 Style-5 Launcher'

# Get existing custom keybinding list
cmd_get = ['gsettings', 'get', 'org.gnome.settings-daemon.plugins.media-keys', 'custom-keybindings']
out = subprocess.check_output(cmd_get).decode().strip()

try:
    bindings_list = ast.literal_eval(out)
except Exception:
    bindings_list = []

target_slot = None
for slot in bindings_list:
    schema_path = f"org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:{slot}"
    try:
        c = subprocess.check_output(['gsettings', 'get', schema_path, 'command']).decode().strip().strip("'")
        if c == target_cmd or 'rofi-launcher' in c:
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
echo " Press Ctrl+Space to toggle your Rofi launcher."
echo "=========================================="
