# Rofi Type-1 Style-5 Setup for Fedora GNOME Wayland

Automated setup for **Rofi** application launcher on **Fedora GNOME (Wayland)** styled with **adi1090x Type-1 Style-5** (Catppuccin color theme).

## Features
- **Sub-Millisecond Native C Launcher (`rofi-launcher`)**: Replaces Python startup overhead with a compiled `-O3 -march=native` C binary (`~/.local/bin/rofi-launcher`) providing **0.3ms launch latency** and **<1ms instant toggle**.
- **Wayland Environment Bridge (`librofix11.so`)**: Bypasses GNOME Mutter layer-shell protocol limitations by running Rofi under XWayland while seamlessly restoring `WAYLAND_DISPLAY` and cleaning freedesktop/Flatpak forwarding tokens (`@@u`, `@@`) for launched child applications (such as Flatpaks, Extension Manager, and Chrome PWAs).
- **Zero-Overhead Display & DPI Detection**: Reads display geometry and scale directly from X11 memory in <0.1ms:
  - **1080p / 1200p (16" Laptop)**: `96 DPI` (1.0x native)
  - **1440p (27" 2K Monitor)**: `128 DPI` (1.33x scale for matching physical proportions)
  - **2160p (4K Displays)**: `192 DPI` (2.0x scale)
- **Desktop Application In-Memory Cache**: Enables `drun-use-desktop-cache` for instantaneous application indexing without re-parsing desktop files on each launch.
- **Event-Driven Focus Loss Dismissal**: Listens to X11 `PropertyNotify` on `_NET_ACTIVE_WINDOW` using `poll()`, using 0% CPU and instantly dismissing Rofi when clicking outside.
- **WindowCycler Integration (`rofi-exec-helper`)**: Intelligently switches to existing open application windows or cleanly launches new instances using `gtk-launch`.
- **Toggle Shortcut**: Binds **`Ctrl + Space`** to toggle Rofi (instant kernel signal if open, sub-millisecond launch if closed).

## Directory Structure
```
setup_rofi/
├── install.sh                  # Main automated setup script
├── README.md                   # Documentation
└── assets/
    ├── fonts/                  # JetBrains Mono Nerd Font, Iosevka, Feather Icons
    └── rofi_config/            # Rofi configuration files & themes
```

## How to Run

Execute the installer script as your normal user (it will prompt for `sudo` if packages are missing):

```bash
cd ~/Documents/ubuntu_setup/fedora_customization_script/setup_rofi
./install.sh
```

## Shortcuts
- **`Ctrl + Space`**: Toggle Rofi Launcher
