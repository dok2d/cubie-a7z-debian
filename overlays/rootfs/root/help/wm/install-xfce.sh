#!/bin/bash
# Install XFCE4 desktop — lightweight, good for 1GB RAM
# Run as root. Requires internet (WiFi must be configured first).
#
# After install, XFCE starts automatically via lightdm on HDMI.
# Connect USB keyboard to J4 (top USB-C port).

set -e
echo "=== Installing XFCE4 desktop ==="
echo "This will download ~300 MB and use ~800 MB disk space."
echo "Press Ctrl+C to cancel, Enter to continue..."
read -r

apt update
apt install -y --no-install-recommends \
  xfce4 xfce4-terminal xfce4-notifyd \
  lightdm lightdm-gtk-greeter \
  dbus-x11 x11-xserver-utils \
  xserver-xorg-core xserver-xorg-input-libinput xinit \
  fonts-dejavu-core \
  network-manager-gnome \
  pulseaudio pavucontrol

bash "$(dirname "$0")/../setup-gpu.sh"

# GPU benchmark (optional but useful for verifying acceleration)
apt install -y --no-install-recommends glmark2-es2 2>/dev/null || true

# Unmask x11-common if masked (Debian Trixie masks it by default)
systemctl unmask x11-common.service 2>/dev/null || true

# Enable lightdm — starts X automatically on boot
systemctl enable lightdm

echo ""
echo "=== XFCE4 installed ==="
echo "Reboot to start XFCE via lightdm on HDMI."
echo "Or right now: systemctl start lightdm"
echo "Connect HDMI and USB keyboard (J4 port) to use."
echo ""
echo "GPU: PowerVR BXM-4-64 hardware acceleration is enabled (glamor)."
echo "     OpenGL ES 3.2, Vulkan 1.3, OpenCL 3.0 available."
echo "     Benchmark: glmark2-es2"
