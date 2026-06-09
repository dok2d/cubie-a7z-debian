#!/bin/bash
# GPIO test
echo "=== GPIO ==="
command -v gpiodetect &>/dev/null || { echo "WARN: gpiodetect not installed"; exit 0; }
gpiodetect
echo "--- LED heartbeat ---"
led=/sys/class/leds/cubie:green:user
if [ -e "$led/trigger" ]; then
  echo "Current trigger: $(cat "$led/trigger" | grep -oP '\[\K[^\]]+')"
  echo "Toggle:  echo none > $led/trigger && echo 1 > $led/brightness"
  echo "Restore: echo heartbeat > $led/trigger"
fi
