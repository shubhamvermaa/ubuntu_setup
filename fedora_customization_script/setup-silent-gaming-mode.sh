#!/bin/bash
# Script to setup Silent Workflow & Auto-Gaming Mode on Fedora Linux (ASUS ROG/TUF, AMD Ryzen + NVIDIA)
# Compatible with asusctl, asusd, and rog-control-center
# Can be run from any directory: sudo ./setup-silent-gaming-mode.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWITCHER_SRC="$SCRIPT_DIR/fedora-silent-game-switch.sh"

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root (e.g. sudo $0)"
  exit 1
fi

echo "================================================================="
echo " Configuring Fedora Silent Workflow & Auto Gaming Mode (asusctl)"
echo "================================================================="

# 1. Enable & Start asusd daemon if asusctl is installed
if command -v asusctl >/dev/null 2>&1; then
    echo "[+] Enabling asusd system daemon..."
    systemctl daemon-reload
    systemctl enable --now asusd.service 2>/dev/null
    echo "✓ asusd service enabled & started."
fi

# 2. Create udev rule for non-root ACPI Platform Profile, CPU EPP, and Steam Controller /dev/uinput access
UDEV_PROFILE_RULE="/etc/udev/rules.d/99-platform-profile.rules"
UDEV_UINPUT_RULE="/etc/udev/rules.d/99-uinput.rules"

echo "[+] Creating udev permission rules for ACPI profiles and Steam /dev/uinput..."
cat << 'EOF' > "$UDEV_PROFILE_RULE"
# Allow non-root users to toggle ASUS ACPI Platform Profile and CPU EPP without sudo
ACTION=="add|change", SUBSYSTEM=="acpi", KERNEL=="platform_profile", RUN+="/bin/chmod 0666 /sys/firmware/acpi/platform_profile"
ACTION=="add|change", SUBSYSTEM=="drivers", KERNEL=="policy*", RUN+="/bin/chmod 0666 /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference"
EOF

cat << 'EOF' > "$UDEV_UINPUT_RULE"
# Allow Steam Input to access /dev/uinput to emulate Xbox / XInput controllers without permission errors
KERNEL=="uinput", MODE="0666", OPTIONS+="static_node=uinput"
EOF

chmod 0666 /dev/uinput 2>/dev/null || true
udevadm control --reload-rules && udevadm trigger
echo "✓ udev rules applied."

# 3. Configure NVIDIA Power Management & Blacklist nouveau for High Refresh Rate (240Hz)
NVIDIA_POWER_CONF="/etc/modprobe.d/nvidia-power-management.conf"
NVIDIA_NOUVEAU_CONF="/etc/modprobe.d/blacklist-nouveau.conf"

echo "[+] Configuring NVIDIA Dynamic Power Management (D3Cold Sleep)..."
cat << 'EOF' > "$NVIDIA_POWER_CONF"
options nvidia NVreg_DynamicPowerManagement=0x02
EOF

echo "[+] Blacklisting nouveau driver to ensure NVIDIA proprietary/open driver loads for high refresh rates (240Hz)..."
cat << 'EOF' > "$NVIDIA_NOUVEAU_CONF"
blacklist nouveau
options nouveau modeset=0
EOF

echo "✓ NVIDIA power management & nouveau blacklist configured."

# 4. Install CLI Switcher to /usr/local/bin/fedora-silent-game-switch
if [ -f "$SWITCHER_SRC" ]; then
    echo "[+] Installing CLI switcher to /usr/local/bin/fedora-silent-game-switch..."
    cp "$SWITCHER_SRC" /usr/local/bin/fedora-silent-game-switch
    chmod +x /usr/local/bin/fedora-silent-game-switch
    echo "✓ Installed /usr/local/bin/fedora-silent-game-switch"
fi

# 5. Configure GameMode hooks & input group access for the active target user
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(eval echo "~$TARGET_USER")

if [ -n "$TARGET_USER" ]; then
    usermod -aG input "$TARGET_USER" 2>/dev/null || true
    echo "✓ Added user $TARGET_USER to input group for Steam controller access."
fi

if [ -d "$TARGET_HOME" ]; then
    GAMEMODE_DIR="$TARGET_HOME/.config"
    GAMEMODE_INI="$GAMEMODE_DIR/gamemode.ini"
    
    echo "[+] Configuring GameMode start/end hooks in $GAMEMODE_INI for user $TARGET_USER..."
    mkdir -p "$GAMEMODE_DIR"
    
    cat << EOF > "$GAMEMODE_INI"
[custom]
# Automatically switch Fedora to high-performance gaming mode when a game starts
start = /usr/local/bin/fedora-silent-game-switch gaming

# Automatically revert Fedora back to silent workflow mode when the game closes
end = /usr/local/bin/fedora-silent-game-switch silent
EOF

    chown -R "$TARGET_USER:$TARGET_USER" "$GAMEMODE_INI"
    echo "✓ GameMode hooks created."
fi

# 6. Clean up rogue udev-worker / upowerd background processes
echo "[+] Cleaning up rogue background processes..."
UDEV_PIDS=$(ps aux | awk '$3 > 50.0 && /udev-worker/ {print $2}')
if [ -n "$UDEV_PIDS" ]; then
    kill -9 $UDEV_PIDS 2>/dev/null
    systemctl restart systemd-udevd
    echo "✓ Terminated stuck udev-worker process(es): $UDEV_PIDS"
fi

# 7. Apply Silent Profile immediately
echo "[+] Applying Silent Workflow Mode..."
/usr/local/bin/fedora-silent-game-switch silent

echo ""
echo "================================================================="
echo " Successfully configured Silent Workflow & Auto Gaming Mode!"
echo " Manual CLI Usage: fedora-silent-game-switch {silent|gaming|clean|status}"
echo "================================================================="
