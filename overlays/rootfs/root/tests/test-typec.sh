#!/bin/bash
# test-typec.sh — USB-C TCPC + DP Alt Mode check
set -e
PASS=true

check() { if "$@"; then echo "  OK"; else echo "  FAIL"; PASS=false; fi; }

echo "=== [1/4] TCPC probe (dmesg) ==="
if dmesg | grep -iE 'tcpci.*-22|tcpci.*EINVAL|tcpci.*ENODEV' > /dev/null 2>&1; then
    echo "  FAIL: TCPC probe error in dmesg"
    dmesg | grep -iE 'tcpci|rt1711|et7304' | tail -10
    PASS=false
else
    echo "  OK"
fi

echo "=== [2/4] sysfs port presence ==="
check test -d /sys/class/typec/port0
if [ -d /sys/class/typec/port0 ]; then
    echo "  data_role:  $(cat /sys/class/typec/port0/data_role 2>/dev/null)"
    echo "  power_role: $(cat /sys/class/typec/port0/power_role 2>/dev/null)"
fi

echo "=== [3/4] DP altmode driver loaded ==="
check grep -q typec_displayport /proc/modules || \
  check test -d /sys/bus/typec/drivers/typec_displayport

echo "=== [4/4] partner detection (if anything plugged) ==="
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
