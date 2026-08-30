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
SRC_DIR="$HOME/.local/src"

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
            
            # If WindowCycler handled it (0 = launched, >= 1 = focused/cycled), exit successfully
            m = re.search(r'\((-?\d+),?\)', res)
            if m:
                code = int(m.group(1))
                if code >= 0:
                    sys.exit(0)
        except Exception:
            pass

        # 2. Fallback: Launch using gtk-launch with restored Wayland environment if WindowCycler returned -1
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

mkdir -p "$SRC_DIR"

cat << 'EOF' > "$SRC_DIR/rofi-launcher.c"
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <unistd.h>
#include <poll.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <errno.h>

typedef void* Display;
typedef unsigned long Window;
typedef unsigned long Atom;
typedef struct {
    int type;
    unsigned long serial;
    int send_event;
    Display *display;
    Window window;
    Atom atom;
    long time;
    int state;
} XPropertyEvent;

typedef union {
    int type;
    XPropertyEvent xproperty;
    long pad[24];
} XEvent;

#define PropertyNotify 28
#define PropertyChangeMask (1L<<22)

static pid_t child_rofi_pid = 0;
static char pidfile_path[256];

static void cleanup_pidfile(void) {
    if (pidfile_path[0]) {
        unlink(pidfile_path);
    }
}

static void handle_sig(int sig) {
    (void)sig;
    if (child_rofi_pid > 0) {
        kill(child_rofi_pid, SIGTERM);
    }
    cleanup_pidfile();
    _exit(0);
}

static int is_rofi_window(void *x11_handle, Display *dpy, Window win, Atom wm_class) {
    if (!win) return 0;
    int (*XGetWindowProperty)(Display*, Window, Atom, long, long, int, Atom, Atom*, int*, unsigned long*, unsigned long*, unsigned char**) = dlsym(x11_handle, "XGetWindowProperty");
    int (*XFree)(void*) = dlsym(x11_handle, "XFree");
    
    Atom actual_type;
    int actual_format;
    unsigned long nitems, bytes_after;
    unsigned char *prop = NULL;

    if (XGetWindowProperty && XFree &&
        XGetWindowProperty(dpy, win, wm_class, 0, 256, 0, 31 /* XA_STRING */, &actual_type, &actual_format, &nitems, &bytes_after, &prop) == 0 && prop) {
        int is_rofi = (strcasestr((char*)prop, "rofi") != NULL);
        XFree(prop);
        return is_rofi;
    }
    return 0;
}

int main(int argc, char *argv[]) {
    uid_t uid = getuid();
    snprintf(pidfile_path, sizeof(pidfile_path), "/run/user/%d/rofi-launcher.pid", (int)uid);

    // 1. Instant Toggle Check (< 0.05ms): Direct kernel signal to running rofi PID
    FILE *pf = fopen(pidfile_path, "r");
    if (pf) {
        int old_launcher_pid = 0, old_rofi_pid = 0;
        if (fscanf(pf, "%d %d", &old_launcher_pid, &old_rofi_pid) >= 1) {
            int killed = 0;
            if (old_rofi_pid > 0 && kill(old_rofi_pid, 0) == 0) {
                kill(old_rofi_pid, SIGTERM);
                killed = 1;
            }
            if (old_launcher_pid > 0 && kill(old_launcher_pid, 0) == 0) {
                kill(old_launcher_pid, SIGTERM);
                killed = 1;
            }
            if (killed) {
                fclose(pf);
                unlink(pidfile_path);
                return 0;
            }
        }
        fclose(pf);
        unlink(pidfile_path);
    }

    signal(SIGTERM, handle_sig);
    signal(SIGINT, handle_sig);
    signal(SIGHUP, handle_sig);

    // 2. Load libX11 dynamically for zero-overhead display detection and event loop
    void *x11 = dlopen("libX11.so.6", RTLD_LAZY);
    Display* (*XOpenDisplay)(const char*) = x11 ? dlsym(x11, "XOpenDisplay") : NULL;
    int (*XCloseDisplay)(Display*) = x11 ? dlsym(x11, "XCloseDisplay") : NULL;
    Window (*XDefaultRootWindow)(Display*) = x11 ? dlsym(x11, "XDefaultRootWindow") : NULL;
    int (*XDefaultScreen)(Display*) = x11 ? dlsym(x11, "XDefaultScreen") : NULL;
    int (*XDisplayWidth)(Display*, int) = x11 ? dlsym(x11, "XDisplayWidth") : NULL;
    int (*XDisplayHeight)(Display*, int) = x11 ? dlsym(x11, "XDisplayHeight") : NULL;
    Atom (*XInternAtom)(Display*, const char*, int) = x11 ? dlsym(x11, "XInternAtom") : NULL;
    int (*XGetWindowProperty)(Display*, Window, Atom, long, long, int, Atom, Atom*, int*, unsigned long*, unsigned long*, unsigned char**) = x11 ? dlsym(x11, "XGetWindowProperty") : NULL;
    int (*XSelectInput)(Display*, Window, long) = x11 ? dlsym(x11, "XSelectInput") : NULL;
    int (*XNextEvent)(Display*, XEvent*) = x11 ? dlsym(x11, "XNextEvent") : NULL;
    int (*XPending)(Display*) = x11 ? dlsym(x11, "XPending") : NULL;
    int (*ConnectionNumber)(Display*) = x11 ? dlsym(x11, "ConnectionNumber") : NULL;
    int (*XFree)(void*) = x11 ? dlsym(x11, "XFree") : NULL;

    int target_dpi = 128; // Default 1440p / 2K
    Display *dpy = XOpenDisplay ? XOpenDisplay(":0") : NULL;
    if (dpy && XDefaultScreen && XDisplayWidth && XDisplayHeight) {
        int scr = XDefaultScreen(dpy);
        int sw = XDisplayWidth(dpy, scr);
        int sh = XDisplayHeight(dpy, scr);
        if (sw >= 3840 || sh >= 2160) {
            target_dpi = 192;
        } else if (sw >= 2560 || sh >= 1440) {
            target_dpi = 128;
        } else {
            target_dpi = 96;
        }
    }

    char dpi_str[16];
    snprintf(dpi_str, sizeof(dpi_str), "%d", target_dpi);

    // 3. Instant Fork & Exec Rofi (< 0.5ms)
    pid_t pid = fork();
    if (pid == 0) {
        setenv("LD_PRELOAD", "/home/shubham/.local/lib/librofix11.so", 1);
        setenv("DISPLAY", ":0", 1);
        setenv("WAYLAND_DISPLAY", "wayland-0", 1);

        const char *theme_path = "/home/shubham/.config/rofi/launchers/type-1/style-5.rasi";
        execlp("rofi", "rofi",
               "-normal-window",
               "-steal-focus",
               "-drun-use-desktop-cache",
               "-dpi", dpi_str,
               "-show", "drun",
               "-theme", theme_path,
               (char*)NULL);
        _exit(1);
    } else if (pid < 0) {
        cleanup_pidfile();
        return 1;
    }

    child_rofi_pid = pid;

    // Write launcher PID and child Rofi PID
    pf = fopen(pidfile_path, "w");
    if (pf) {
        fprintf(pf, "%d %d\n", getpid(), child_rofi_pid);
        fclose(pf);
    }

    // 4. Ultra-low latency event-driven focus loss monitor
    if (dpy && x11 && XDefaultRootWindow && XInternAtom && XSelectInput && XNextEvent && XPending && ConnectionNumber) {
        Window root = XDefaultRootWindow(dpy);
        Atom net_active = XInternAtom(dpy, "_NET_ACTIVE_WINDOW", 0);
        Atom wm_class = XInternAtom(dpy, "WM_CLASS", 0);

        XSelectInput(dpy, root, PropertyChangeMask);

        int x11_fd = ConnectionNumber(dpy);
        struct pollfd pfd;
        pfd.fd = x11_fd;
        pfd.events = POLLIN;

        int rofi_ever_focused = 0;
        int status;

        while (1) {
            pid_t w = waitpid(child_rofi_pid, &status, WNOHANG);
            if (w != 0) {
                break;
            }

            while (XPending(dpy) > 0) {
                XEvent ev;
                XNextEvent(dpy, &ev);
                if (ev.type == PropertyNotify && ev.xproperty.atom == net_active) {
                    Atom actual_type;
                    int actual_format;
                    unsigned long nitems, bytes_after;
                    unsigned char *prop = NULL;
                    if (XGetWindowProperty(dpy, root, net_active, 0, 1, 0, 33 /* XA_WINDOW */,
                                           &actual_type, &actual_format, &nitems, &bytes_after, &prop) == 0 && prop) {
                        Window active = *(Window*)prop;
                        XFree(prop);

                        if (active != 0) {
                            if (is_rofi_window(x11, dpy, active, wm_class)) {
                                rofi_ever_focused = 1;
                            } else if (rofi_ever_focused) {
                                kill(child_rofi_pid, SIGTERM);
                                goto done;
                            }
                        } else if (rofi_ever_focused) {
                            kill(child_rofi_pid, SIGTERM);
                            goto done;
                        }
                    }
                }
            }

            int ret = poll(&pfd, 1, 40);
            if (ret < 0 && errno != EINTR) {
                break;
            }
        }

done:
        if (XCloseDisplay) XCloseDisplay(dpy);
    } else {
        int status;
        waitpid(child_rofi_pid, &status, 0);
    }

    cleanup_pidfile();
    return 0;
}
EOF

gcc -O3 -march=native -pipe "$SRC_DIR/rofi-launcher.c" -o "$BIN_DIR/rofi-launcher" -ldl
chmod +x "$BIN_DIR/rofi-launcher"
echo "Native Rofi launcher compiled and installed to $BIN_DIR/rofi-launcher."
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
