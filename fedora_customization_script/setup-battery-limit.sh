#!/bin/bash
# Script to set battery charge threshold on Linux/Fedora (ASUS ROG, ThinkPad, Dell, Framework, etc.)
# Can be run from any directory: sudo ./setup-battery-limit.sh [THRESHOLD_PERCENT]

THRESHOLD="${1:-80}"

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root (e.g. sudo $0 $THRESHOLD)"
  exit 1
fi

# Auto-detect battery sysfs threshold file (BAT0, BAT1, etc.)
BAT_SYSFS=""
for bat in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
    if [ -f "$bat" ]; then
        BAT_SYSFS="$bat"
        BAT_NAME=$(echo "$bat" | cut -d'/' -f5)
        break
    fi
done

if [ -z "$BAT_SYSFS" ]; then
    echo "x Error: No battery charge threshold sysfs file found under /sys/class/power_supply/."
    exit 1
fi

echo "Found battery interface: $BAT_NAME ($BAT_SYSFS)"
echo "Setting battery charge limit to ${THRESHOLD}%..."

# 1. Apply immediately
echo "$THRESHOLD" > "$BAT_SYSFS"
echo "✓ Applied current charge limit: $(cat "$BAT_SYSFS")%"

# 2. Create udev rule for persistent setting across reboots & charger plug-ins
UDEV_RULE="/etc/udev/rules.d/99-battery-charge-limit.rules"
echo 'ACTION=="add|change", KERNEL=="'"$BAT_NAME"'", SUBSYSTEM=="power_supply", ATTR{charge_control_end_threshold}="'"$THRESHOLD"'"' > "$UDEV_RULE"
udevadm control --reload-rules && udevadm trigger
echo "✓ Created udev rule at $UDEV_RULE"

# 3. Create systemd service as backup on boot
SERVICE_FILE="/etc/systemd/system/battery-charge-threshold.service"
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Set Battery Charge Limit to ${THRESHOLD}%
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo ${THRESHOLD} > ${BAT_SYSFS}'

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable battery-charge-threshold.service
systemctl start battery-charge-threshold.service
echo "✓ Created and enabled systemd service at $SERVICE_FILE"

echo ""
echo "Successfully configured battery charge threshold to ${THRESHOLD}% on $BAT_NAME!"

