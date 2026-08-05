# Fedora Customization & Gaming Fixes

This directory contains setup scripts and configuration notes for Fedora Linux on ASUS laptops (AMD Ryzen + NVIDIA dGPU) paired with high-refresh-rate external monitors and Steam gaming controllers.

---

## 🚀 Quick Setup

Run the automated setup script to apply all thermal, udev, NVIDIA, and Steam controller fixes:

```bash
sudo ./setup-silent-gaming-mode.sh
```

---

## 🎮 Key Fixes Included

### 1. Steam Controller & Virtual Gamepad Permission Fix (`/dev/uinput`)
**Issue**: Steam detects Xbox / generic controllers and displays a notification, but Proton games (e.g., *Asphalt Legends*) receive no button inputs.  
**Cause**: Steam Input attempts to create a virtual XInput device via `/dev/uinput`, but returns `Permission denied` (Error 13).  
**Fix**:
1. Add udev rule `/etc/udev/rules.d/99-uinput.rules`:
   ```ini
   KERNEL=="uinput", MODE="0666", OPTIONS+="static_node=uinput"
   ```
2. Reload udev and set permissions:
   ```bash
   sudo udevadm control --reload-rules && sudo udevadm trigger
   sudo chmod 666 /dev/uinput
   sudo usermod -aG input $USER
   ```

---

### 2. High Refresh Rate (240Hz) & NVIDIA Open Driver Setup
**Issue**: External monitor limited to low refresh rates or not recognized on USB-C DisplayPort output.  
**Cause**: Kernel defaults to `nouveau`, which lacks high pixel clock rates and DSC (Display Stream Compression) needed for 2560x1440 @ 240Hz.  
**Fix**:
1. Install NVIDIA Open Kernel driver (required for RTX 50-series Blackwell / Ada / Ampere GPUs on modern kernels):
   ```bash
   sudo dnf install akmod-nvidia-open xorg-x11-drv-nvidia-cuda
   ```
2. Blacklist `nouveau` in `/etc/modprobe.d/blacklist-nouveau.conf`:
   ```ini
   blacklist nouveau
   options nouveau modeset=0
   ```
3. Rebuild boot image:
   ```bash
   sudo dracut --force
   ```
4. Disable Secure Boot in BIOS (or enroll MOK key via `sudo mokutil --import /etc/pki/akmods/certs/public_key.der`).

---

### 3. Launching Games on External 240Hz Display (GNOME Wayland)
- **Primary Display**: Set your external Dell monitor as the **Primary Display** under **Settings → Displays**.
- **Instant Window Move Shortcut**: Press `Super` + `Shift` + `Right/Left Arrow` while the game is focused to move it across monitors.
- **Gamescope Launch Option**: In Steam game properties, set launch options to force 240Hz QHD:
  ```bash
  gamescope -W 2560 -H 1440 -r 240 -f -- %command%
  ```

---

### 4. Function Keys Default to Media Keys Fix (`asus_wmi`)
**Issue**: Top row keys (F1–F12) default to standard F1–F12 functions, requiring `Fn+Esc` or holding `Fn` to use media/brightness controls.  
**Fix**: Set `fnlock_default=0` in `/etc/modprobe.d/asus_wmi.conf` and update kernel boot arguments:
```bash
sudo ./setup-fn-media-keys.sh
```

---

## 📜 Script Reference

- `setup-silent-gaming-mode.sh`: Master script that applies udev rules (`uinput`, ACPI platform profiles), configures NVIDIA D3Cold & nouveau blacklist, and sets up GameMode hooks.
- `fedora-silent-game-switch.sh`: CLI power switcher (`silent`, `gaming`, `clean`, `status`) integrated with `asusctl` and GNOME DBus power profiles.
- `setup-battery-limit.sh`: Sets maximum battery charge threshold (e.g. 80%) for ASUS laptops.
- `setup-fn-media-keys.sh`: Configures `asus_wmi` to make Function keys act as Media keys by default.
- `set_custom_keybindings.sh`: Configures custom GNOME keyboard shortcuts.
- `setup-cpp-precompiled-headers.sh`: Sets up C++20 precompiled headers (`bits/stdc++.h.gch` and PBDS), shell include paths, and `compile_flags.txt` for Codeforces / Competitive Programming.
