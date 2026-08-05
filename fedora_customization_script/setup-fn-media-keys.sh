#!/usr/bin/env bash
# ==============================================================================
# Setup Fn Keys as Media Keys by Default (ASUS Laptops / asus_wmi)
# ==============================================================================
# By default on ASUS laptops, F1-F12 act as standard Function keys.
# Setting fnlock_default=0 in asus_wmi makes F1-F12 act as Media/Hotkeys
# (volume, brightness, mute, etc.) by default without requiring Fn+Esc or Fn key.
# ==============================================================================

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo." >&2
    exit 1
fi

echo "==> Setting fnlock_default=0 for asus_wmi module in /etc/modprobe.d/asus_wmi.conf..."
cat << 'EOF' > /etc/modprobe.d/asus_wmi.conf
# Configure asus_wmi module to default Fn keys to Media/Hotkeys
options asus_wmi fnlock_default=0
EOF

if command -v grubby &> /dev/null; then
    echo "==> Updating kernel boot parameters via grubby..."
    grubby --update-kernel=ALL --args="asus_wmi.fnlock_default=0"
fi

if command -v dracut &> /dev/null; then
    echo "==> Regenerating initramfs with dracut..."
    dracut -f
elif command -v update-initramfs &> /dev/null; then
    echo "==> Updating initramfs..."
    update-initramfs -u
fi

echo ""
echo "=============================================================================="
echo " Success! Fn keys configured to default to Media Keys (fnlock_default=0)."
echo " Please reboot your computer for changes to take full effect."
echo "=============================================================================="
