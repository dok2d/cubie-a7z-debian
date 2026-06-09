#!/bin/bash
# USB-C test — host port J4 + TCPC ET7304Y
echo "=== USB-C ==="
echo "--- Controllers ---"
ls -d /sys/bus/usb/devices/usb* 2>/dev/null | wc -l | xargs -I{} echo "USB host controllers: {}"
echo "--- Devices ---"
lsusb 2>/dev/null | grep -v 'root hub'
echo "--- TCPC ---"
if [ -d /sys/class/typec ]; then
  for p in /sys/class/typec/port*; do
    [ -e "$p/data_role" ] || continue
    echo "$(basename "$p"): data=$(cat "$p/data_role") power=$(cat "$p/power_role")"
  done
else
  echo "WARN: no /sys/class/typec"
fi
echo "--- VBUS (PL2 GPIO) ---"
echo "Control: gpioset <chip> <line>=1 to enable VBUS"
