#!/bin/bash
# test-typec.sh — USB-C TCPC + DP Alt Mode check
set -e
PASS=true

check() { if "$@"; then echo "  OK"; else echo "  FAIL"; PASS=false; fi; }

echo "=== [1/6] TCPC probe (dmesg) ==="
if dmesg | grep -iE 'tcpci.*-22|tcpci.*EINVAL|tcpci.*ENODEV' > /dev/null 2>&1; then
    echo "  FAIL: TCPC probe error in dmesg"
    dmesg | grep -iE 'tcpci|rt1711|et7304' | tail -10
    PASS=false
else
    echo "  OK"
fi

echo "=== [2/6] sysfs port presence ==="
check test -d /sys/class/typec/port0
if [ -d /sys/class/typec/port0 ]; then
    echo "  data_role:  $(cat /sys/class/typec/port0/data_role 2>/dev/null)"
    echo "  power_role: $(cat /sys/class/typec/port0/power_role 2>/dev/null)"
fi

echo "=== [3/6] DP altmode driver loaded ==="
check sh -c 'grep -q typec_displayport /proc/modules 2>/dev/null || test -d /sys/bus/typec/drivers/typec_displayport'

echo "=== [4/6] PHY switcher probe ==="
if dmesg | grep -q 'sunxi-phy-switcher'; then
    echo "  OK: sunxi-phy-switcher loaded"
else
    echo "  WARN: sunxi-phy-switcher not found in dmesg (may be built-in)"
fi

echo "=== [5/6] DRM DP connector ==="
DP_CONN=""
for c in /sys/class/drm/card*-DP-*; do
    [ -d "$c" ] && DP_CONN="$c" && break
done
if [ -n "$DP_CONN" ]; then
    echo "  OK: $(basename $DP_CONN)"
    echo "  status:  $(cat $DP_CONN/status 2>/dev/null)"
    echo "  enabled: $(cat $DP_CONN/enabled 2>/dev/null)"
else
    echo "  WARN: no card*-DP-* connector (edp0 may not be enabled)"
fi

echo "=== [6/6] partner detection (if anything plugged) ==="
if [ -d /sys/class/typec/port0/port0-partner ]; then
    echo "  Partner present"
    for f in /sys/class/typec/port0/port0-partner/*/configuration \
             /sys/class/typec/port0/port0-partner/*/pin_assignment; do
        [ -r "$f" ] && echo "    $(basename $(dirname $f))/$(basename $f) = $(cat $f)"
    done
else
    echo "  No partner — OK if nothing plugged in"
fi

$PASS && echo "=== PASS ===" || { echo "=== FAIL ==="; exit 1; }
