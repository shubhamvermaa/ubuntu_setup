# Rofi Type-1 Style-5 Setup for Fedora GNOME Wayland

Automated setup for **Rofi** application launcher on **Fedora GNOME (Wayland)** styled with **adi1090x Type-1 Style-5** (Catppuccin color theme).

## Features
- **Wayland Environment Bridge (`librofix11.so`)**: Bypasses GNOME Mutter layer-shell protocol limitations by running Rofi under XWayland while seamlessly restoring `WAYLAND_DISPLAY` and cleaning freedesktop/Flatpak forwarding tokens (`@@u`, `@@`) for launched child applications (such as Flatpaks, Extension Manager, and Chrome PWAs).
- **Dynamic Multi-Monitor DPI Scaling**: Automatically detects the active display's resolution and scale factor in under 10ms:
  - **1080p / 1200p (16" Laptop)**: `96 DPI` (1.0x native)
  - **1440p (27" 2K Monitor)**: `128 DPI` (1.33x scale for matching physical proportions)
  - **2160p (4K Displays)**: `192 DPI` (2.0x scale)
- **Focus & Click Support**: Uses `-normal-window` and `-steal-focus` flags with high-speed window ID detection and instant focus-loss dismissal when clicking outside.
- **WindowCycler Integration (`rofi-exec-helper`)**: Intelligently switches to existing open application windows or cleanly launches new instances using `gtk-launch`.
- **Toggle Shortcut**: Binds **`Ctrl + Space`** to toggle Rofi (instant kill if open, instant launch if closed).

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
