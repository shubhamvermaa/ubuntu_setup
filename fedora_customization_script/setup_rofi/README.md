# Rofi Type-1 Style-5 Setup for Fedora GNOME Wayland

Automated setup for **Rofi** application launcher on **Fedora 44 GNOME (Wayland)** styled with **adi1090x Type-1 Style-5** (Catppuccin color theme, 2x scaled).

## Features
- **Wayland Compatibility**: Bypasses GNOME Mutter layer-shell limitation using Xwayland execution (`env WAYLAND_DISPLAY= rofi`).
- **Focus & Click Support**: Uses `-normal-window` and `-steal-focus` flags so clicking on Rofi focuses its text field immediately.
- **Toggle Shortcut**: Binds **`Ctrl + Space`** to toggle Rofi (open if closed, close if open).
- **2x Scaling**: Enlarged 2x layout (1100px width, 18pt JetBrains Mono Nerd Font, 48px app icons).

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
