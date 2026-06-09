#!/bin/bash
# Install labwc — lightweight Wayland stacking compositor (openbox-like)
# Run as root. Requires internet (WiFi must be configured first).
#
# After install, labwc starts automatically on tty1 login.
#
# WARNING: labwc needs DRM/KMS with dumb buffer support. On Cubie A7Z,
# card0 (sunxi-drm) supports it but card1 (PowerVR) does not.
# If labwc fails, use install-xfce.sh (X11) instead.

set -e
echo "=== Installing labwc (Wayland) ==="
echo "This will download ~150 MB and use ~400 MB disk space."
echo ""
echo "WARNING: Wayland requires DRM/KMS with dumb buffer support."
echo "PowerVR GPU (card1) does NOT support it."
echo "If labwc fails to start, use install-xfce.sh or install-i3.sh instead."
echo ""
echo "Press Ctrl+C to cancel, Enter to continue..."
read -r

apt update
apt install -y --no-install-recommends \
  labwc \
  foot \
  xwayland \
  fonts-dejavu-core \
  pulseaudio

LABWC_USER="${1:-cubie}"
LABWC_HOME=$(eval echo "~$LABWC_USER")

# Auto-start labwc on tty1 login
PROFILE="$LABWC_HOME/.bash_profile"
if ! grep -q 'exec labwc' "$PROFILE" 2>/dev/null; then
  cat >> "$PROFILE" << 'AUTOLABWC'

# Auto-start labwc on tty1 (force card0 for display, card1 has no KMS)
if [ "$(tty)" = "/dev/tty1" ] && [ -z "$WAYLAND_DISPLAY" ]; then
  export WLR_DRM_DEVICES=/dev/dri/card0
  exec labwc
fi
AUTOLABWC
  chown "$LABWC_USER:" "$PROFILE" 2>/dev/null || true
fi

# Disable any X11 display manager if present
for dm in lightdm sddm gdm3; do
  systemctl disable "$dm" 2>/dev/null || true
done

# Auto-login on tty1 so labwc starts without manual password entry on HDMI
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << AEOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $LABWC_USER --noclear %I \$TERM
AEOF

echo ""
echo "=== labwc installed ==="
echo "Reboot — labwc starts automatically (autologin as $LABWC_USER on tty1)."
echo "If it fails, use install-xfce.sh or install-i3.sh (X11) instead."
echo ""
echo "GPU: PowerVR BXM-4-64 — Vulkan 1.3 and OpenGL ES 3.2 available."
