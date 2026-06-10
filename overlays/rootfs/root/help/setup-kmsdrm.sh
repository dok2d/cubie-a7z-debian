#!/bin/bash
# Setup KMSDRM environment — run games/apps directly on framebuffer
# without any window manager (no Xorg, no sway, no Wayland).
# Run as root.
#
# This gives maximum performance and minimum RAM usage on 1GB SKU.

set -e
echo "=== Setting up KMSDRM (no WM) environment ==="

# Ensure GPU is configured
bash "$(dirname "$0")/setup-gpu.sh"

# Disable any display manager / WM autostart
for dm in lightdm sddm gdm3; do
  systemctl disable "$dm" 2>/dev/null || true
done
# Remove sway autologin if present
rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
if [ -f /home/cubie/.bash_profile ]; then
  sed -i '/exec sway/d; /exec labwc/d; /WLR_DRM_DEVICES/d; /WAYLAND_DISPLAY/d' \
    /home/cubie/.bash_profile 2>/dev/null || true
fi
systemctl daemon-reload

# Install minimal deps for KMSDRM gaming
apt update
apt install -y --no-install-recommends \
  libsdl2-2.0-0 \
  libvulkan1 \
  pulseaudio \
  libxcb-dri2-0

# Ensure user can access DRM and input
for grp in video render input audio; do
  usermod -aG "$grp" "${1:-cubie}" 2>/dev/null || true
done

# KMSDRM launcher helper
cat > /usr/local/bin/kmsdrm-run << 'LAUNCHER'
#!/bin/bash
# Launch an app directly on KMSDRM (no WM needed)
# Usage: kmsdrm-run <command> [args...]
#
# Requires: user in video+render+input groups, no other DRM master
# libudev workaround: upstream SDL bug #2397/#4879 — SDL tries to resolve
# udev symbols before dlopen(libudev.so.1). Affects SDL2 and SDL3.
export LD_PRELOAD=/lib/aarch64-linux-gnu/libudev.so.1
export SDL_VIDEODRIVER=kmsdrm
export SDL_KMSDRM_DEVICE_INDEX=0
export LD_LIBRARY_PATH=/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export VK_ICD_FILENAMES=/etc/vulkan/icd.d/pvr_icd.json

# Stop display managers that hold DRM master
for dm in lightdm sddm gdm3; do
  systemctl stop "$dm" 2>/dev/null || true
done

# Kill any existing DRM clients (Xorg, sway)
pkill -x Xorg 2>/dev/null || true
pkill -x sway 2>/dev/null || true
sleep 1

exec "$@"
LAUNCHER
chmod +x /usr/local/bin/kmsdrm-run

# Thermal stats script — lightweight, writes to tty2
cat > /usr/local/bin/kmsdrm-stats << 'STATSEOF'
#!/bin/bash
# Lightweight thermal stats for KMSDRM sessions.
# Writes one line to tty2 every 2 seconds. ~0% CPU overhead.
# View: Ctrl+Alt+F2 | Back to game: Ctrl+Alt+F1
TTY=/dev/tty2
while true; do
  CPU=$(awk '{printf "%.0f", $1/1000}' /sys/class/thermal/thermal_zone3/temp 2>/dev/null)
  GPU=$(awk '{printf "%.0f", $1/1000}' /sys/class/thermal/thermal_zone4/temp 2>/dev/null)
  DDR=$(awk '{printf "%.0f", $1/1000}' /sys/class/thermal/thermal_zone1/temp 2>/dev/null)
  printf "\r CPU:%s°C  GPU:%s°C  DDR:%s°C  " "$CPU" "$GPU" "$DDR" > "$TTY"
  sleep 2
done
STATSEOF
chmod +x /usr/local/bin/kmsdrm-stats

echo ""
echo "=== KMSDRM environment ready ==="
echo ""
echo "Usage: kmsdrm-run <app>"
echo "Example: kmsdrm-run quake2-kmsdrm"
echo ""
echo "This stops any WM/Xorg and runs the app directly on HDMI."
echo "No compositor overhead. Maximum GPU performance."
echo "Press Ctrl+Alt+F2 to switch to tty2 if you need a shell."
