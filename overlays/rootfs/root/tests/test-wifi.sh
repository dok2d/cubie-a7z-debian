#!/bin/bash
# WiFi test — AIC8800D80 USB
echo "=== WiFi ==="
lsmod | grep -q aic8800_fdrv && echo "OK: aic8800_fdrv loaded" || echo "FAIL: aic8800_fdrv not loaded"
ip link show wlan0 &>/dev/null && echo "OK: wlan0 exists" || { echo "FAIL: no wlan0"; exit 1; }
echo "State: $(cat /sys/class/net/wlan0/operstate)"
ip addr show wlan0 | grep -oP 'inet \S+'
echo "--- Scan ---"
iw dev wlan0 scan 2>/dev/null | grep -c 'SSID:' | xargs -I{} echo "APs found: {}"
if pgrep -x wpa_supplicant &>/dev/null; then
  echo "wpa_supplicant: running"
  wpa_cli -i wlan0 status 2>/dev/null | grep -E 'ssid=|wpa_state=|ip_address='
fi
ping -c3 -W3 8.8.8.8 2>/dev/null && echo "OK: internet reachable" || echo "WARN: no internet"
