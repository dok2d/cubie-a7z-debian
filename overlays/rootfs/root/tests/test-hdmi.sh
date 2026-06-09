#!/bin/bash
# HDMI test — video + audio
echo "=== HDMI ==="
for c in /sys/class/drm/card*-HDMI*/status; do
  [ -f "$c" ] || continue
  name=$(dirname "$c" | xargs basename)
  echo "$name: $(cat "$c")"
done
echo "--- Audio ---"
if grep -qi hdmi /proc/asound/cards 2>/dev/null; then
  echo "OK: sndhdmi card present"
  cat /proc/asound/cards | grep -i hdmi
  command -v aplay &>/dev/null && echo "Play test: aplay -D hw:sndhdmi <file.wav>"
else
  echo "WARN: no HDMI audio card"
fi
echo "--- Modes ---"
for m in /sys/class/drm/card*-HDMI*/modes; do
  [ -f "$m" ] && cat "$m" | head -5
done
