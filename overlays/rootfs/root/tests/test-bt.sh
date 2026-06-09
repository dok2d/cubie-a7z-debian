#!/bin/bash
# Bluetooth test — AIC8800 USB btusb
echo "=== Bluetooth ==="
lsmod | grep -q btusb && echo "OK: btusb loaded" || echo "FAIL: btusb not loaded"
hciconfig hci0 &>/dev/null || { hciconfig hci0 up 2>/dev/null; sleep 1; }
hci_state=$(hciconfig hci0 2>/dev/null | grep -oP 'UP|DOWN' | head -1)
echo "HCI0: ${hci_state:-not found}"
[ "$hci_state" = "UP" ] || exit 1
echo "--- LE scan (5s) ---"
timeout 6 hcitool lescan --passive 2>/dev/null | grep -v '^LE' | head -10
