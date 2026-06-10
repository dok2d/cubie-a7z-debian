#!/bin/bash
# Install LXQt desktop — lightweight Qt-based
# Run as root. Requires internet (WiFi must be configured first).
#
# After install, LXQt starts automatically via sddm on HDMI.
# Connect USB keyboard to J4 (top USB-C port).

set -e
echo "=== Installing LXQt desktop ==="
echo "This will download ~350 MB and use ~900 MB disk space."
echo "Press Ctrl+C to cancel, Enter to continue..."
read -r

apt update
apt install -y --no-install-recommends \
  lxqt-core lxqt-config lxqt-session \
  qterminal \
  sddm \
  dbus-x11 x11-xserver-utils \
  xserver-xorg-core xserver-xorg-input-libinput xinit \
  fonts-dejavu-core \
  network-manager-gnome \
  pulseaudio pavucontrol

bash "$(dirname "$0")/../setup-gpu.sh"

# GPU benchmark (optional)
apt install -y --no-install-recommends glmark2-es2 2>/dev/null || true

# Unmask x11-common if masked (Debian Trixie masks it by default)
systemctl unmask x11-common.service 2>/dev/null || true

# Enable sddm — starts X automatically on boot
systemctl enable sddm

echo ""
echo "=== LXQt installed ==="
echo "Reboot to start LXQt via sddm on HDMI."
echo "Or right now: systemctl start sddm"
echo "Connect HDMI and USB keyboard (J4 port) to use."
echo ""
echo "GPU: PowerVR BXM-4-64 hardware acceleration is enabled (glamor)."
echo "     OpenGL ES 3.2, Vulkan 1.3, OpenCL 3.0 available."
echo "     Benchmark: glmark2-es2"
