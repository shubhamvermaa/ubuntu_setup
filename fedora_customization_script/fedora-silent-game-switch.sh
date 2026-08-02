#!/usr/bin/env bash
# ==============================================================================
# Fedora Silent Workflow & Gaming Switcher (asusctl / asusd Integration)
# ==============================================================================
# Seamlessly integrates with asusctl / asusd daemon when available.

ACTION="${1:-status}"

set_dbus_profile() {
    local target_profile="$1"
    gdbus call --system \
        --dest net.hadess.PowerProfiles \
        --object-path /net/hadess/PowerProfiles \
        --method org.freedesktop.DBus.Properties.Set \
        net.hadess.PowerProfiles ActiveProfile \
        "<'${target_profile}'>" >/dev/null 2>&1
}

clean_rogue_processes() {
    echo "[+] Checking for rogue high-CPU background processes..."
    
    # 1. Check for stuck udev-worker
    UDEV_PIDS=$(ps aux | awk '$3 > 50.0 && /udev-worker/ {print $2}')
    if [ -n "$UDEV_PIDS" ]; then
        echo "  ! Found stuck udev-worker process(es): $UDEV_PIDS (High CPU)"
        if [ "$EUID" -eq 0 ]; then
            kill -9 $UDEV_PIDS 2>/dev/null
            systemctl restart systemd-udevd 2>/dev/null
            echo "  ✓ Cleaned up stuck udev-worker process."
        elif sudo -n true 2>/dev/null; then
            sudo -n kill -9 $UDEV_PIDS 2>/dev/null
            sudo -n systemctl restart systemd-udevd 2>/dev/null
            echo "  ✓ Cleaned up stuck udev-worker process via sudo."
        else
            echo "  ! Note: Run 'sudo fedora-silent-game-switch clean' to terminate stuck udev process."
        fi
    fi

    # 2. Check for stuck upowerd
    UPOWER_PIDS=$(ps aux | awk '$3 > 30.0 && /upowerd/ {print $2}')
    if [ -n "$UPOWER_PIDS" ]; then
        echo "  ! Found stuck upowerd process(es): $UPOWER_PIDS (High CPU)"
        if [ "$EUID" -eq 0 ]; then
            systemctl restart upower 2>/dev/null
            echo "  ✓ Restarted upower service."
        elif sudo -n true 2>/dev/null; then
            sudo -n systemctl restart upower 2>/dev/null
            echo "  ✓ Restarted upower service via sudo."
        else
            echo "  ! Note: Run 'sudo fedora-silent-game-switch clean' to restart upower service."
        fi
    fi
}

set_silent_mode() {
    echo "[+] Activating Silent Workflow Mode..."
    clean_rogue_processes

    if command -v asusctl >/dev/null 2>&1 && systemctl is-active --quiet asusd 2>/dev/null; then
        echo "  -> Using asusctl profile set Quiet..."
        asusctl profile set Quiet 2>/dev/null || asusctl profile -s Quiet 2>/dev/null
    else
        echo "  -> Using GNOME DBus power-saver profile..."
        set_dbus_profile "power-saver"
        if [ -w /sys/firmware/acpi/platform_profile ]; then
            echo "quiet" > /sys/firmware/acpi/platform_profile 2>/dev/null
        fi
    fi

    # Direct CPU EPP tuning
    for epp in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do
        if [ -w "$epp" ]; then
            echo "balance_power" > "$epp" 2>/dev/null
        fi
    done

    echo "✔ Silent Workflow Profile Active (Fans Quiet/Off, CPU Power Saver)"
}

set_gaming_mode() {
    echo "[+] Activating High-Performance Gaming Mode..."

    if command -v asusctl >/dev/null 2>&1 && systemctl is-active --quiet asusd 2>/dev/null; then
        echo "  -> Using asusctl profile set Performance..."
        asusctl profile set Performance 2>/dev/null || asusctl profile -s Performance 2>/dev/null
    else
        echo "  -> Using GNOME DBus performance profile..."
        set_dbus_profile "performance"
        if [ -w /sys/firmware/acpi/platform_profile ]; then
            echo "performance" > /sys/firmware/acpi/platform_profile 2>/dev/null
        fi
    fi

    # Direct CPU EPP tuning
    for epp in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do
        if [ -w "$epp" ]; then
            echo "performance" > "$epp" 2>/dev/null
        fi
    done

    echo "✔ High-Performance Gaming Mode Active (CPU & GPU fully unthrottled)"
}

show_status() {
    echo "======================================================"
    echo " Fedora Power & Thermal Profile Status"
    echo "======================================================"
    
    if command -v asusctl >/dev/null 2>&1; then
        ASUSD_STATE=$(systemctl is-active asusd 2>/dev/null || echo "inactive")
        echo "  asusd Daemon State    : $ASUSD_STATE"
        if [ "$ASUSD_STATE" = "active" ]; then
            ASUSCTL_PROF=$(asusctl profile get 2>/dev/null || asusctl profile -g 2>/dev/null)
            echo "  asusctl Profile       : ${ASUSCTL_PROF:-Unknown}"
        fi
    fi

    ACTIVE_DBUS=$(gdbus call --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles ActiveProfile 2>/dev/null | grep -oP "'\K[^']+")
    echo "  Power Profile (DBus)  : ${ACTIVE_DBUS:-Unknown}"

    if [ -f /sys/firmware/acpi/platform_profile ]; then
        echo "  ASUS Platform Profile : $(cat /sys/firmware/acpi/platform_profile)"
    fi

    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference ]; then
        echo "  AMD CPU EPP           : $(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference)"
    fi

    echo "------------------------------------------------------"
    echo " Thermal & Fan Status:"
    for hw in /sys/class/hwmon/hwmon*; do
        NAME=$(cat "$hw/name" 2>/dev/null)
        for temp in "$hw"/temp*_input; do
            if [ -f "$temp" ]; then
                VAL=$(cat "$temp" 2>/dev/null)
                C_VAL=$((VAL / 1000))
                [ "$C_VAL" -gt 0 ] && echo "  Temp ($NAME)          : ${C_VAL}°C"
            fi
        done | head -n 2
        for fan in "$hw"/fan*_input; do
            if [ -f "$fan" ]; then
                RPM=$(cat "$fan" 2>/dev/null)
                echo "  Fan Speed ($NAME)      : ${RPM} RPM"
            fi
        done
    done | head -n 6
    echo "======================================================"
}

case "$ACTION" in
    silent|quiet|work|power-saver)
        set_silent_mode
        ;;
    game|gaming|performance)
        set_gaming_mode
        ;;
    clean|kill-rogue)
        clean_rogue_processes
        ;;
    status|info)
        show_status
        ;;
    *)
        echo "Usage: $0 {silent|gaming|clean|status}"
        exit 1
        ;;
esac
