#!/bin/bash
# Install i3 — X11 tiling window manager, minimal
# Run as root. Requires internet (WiFi must be configured first).
#
# After install, i3 starts automatically via lightdm on HDMI.
# Connect USB keyboard to J4 (top USB-C port).

set -e
echo "=== Installing i3 window manager ==="
echo "This will download ~200 MB and use ~500 MB disk space."
echo "Press Ctrl+C to cancel, Enter to continue..."
read -r

apt update
apt install -y --no-install-recommends \
  i3-wm i3status i3lock dmenu \
  xterm \
  lightdm lightdm-gtk-greeter \
  dbus-x11 x11-xserver-utils \
  xserver-xorg-core xserver-xorg-input-libinput xinit \
  fonts-dejavu-core \
  pulseaudio

# GPU benchmark (optional)
apt install -y --no-install-recommends glmark2-es2 2>/dev/null || true

# Unmask x11-common if it was masked (Debian Trixie masks it by default)
systemctl unmask x11-common.service 2>/dev/null || true

# .xinitrc for startx (manual fallback)
for user in root cubie; do
  home=$(eval echo "~$user")
  [ -d "$home" ] || continue
  if [ ! -f "$home/.xinitrc" ]; then
    echo "exec i3" > "$home/.xinitrc"
    chown "$user:" "$home/.xinitrc" 2>/dev/null || true
  fi
done

# Enable lightdm — this is what starts X automatically on boot
systemctl enable lightdm

echo ""
echo "=== i3 installed ==="
echo "Reboot to start i3 via lightdm on HDMI."
echo "Or right now: systemctl start lightdm"
echo ""
echo "Manual fallback (no display manager): login on tty, run: startx"
echo "Connect HDMI and USB keyboard (J4 port) to use."
echo ""
echo "GPU: PowerVR BXM-4-64 hardware acceleration is enabled (glamor)."
echo "     OpenGL ES 3.2, Vulkan 1.3, OpenCL 3.0 available."
echo "     Benchmark: glmark2-es2"
