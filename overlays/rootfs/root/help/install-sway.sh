#!/bin/bash
# Install Sway — Wayland tiling WM (i3-compatible)
# Run as root. Requires internet (WiFi must be configured first).
#
# After install, Sway starts automatically on tty1 login.
#
# WARNING: Sway needs DRM/KMS with dumb buffer support. On Cubie A7Z,
# card0 (sunxi-drm) supports it but card1 (PowerVR) does not.
# Sway must use card0. If it fails, use install-xfce.sh (X11) instead.

set -e
echo "=== Installing Sway (Wayland) ==="
echo "This will download ~200 MB and use ~500 MB disk space."
echo ""
echo "WARNING: Wayland requires DRM/KMS with dumb buffer support."
echo "PowerVR GPU (card1) does NOT support it. Sway will use sunxi-drm (card0)."
echo "If sway fails to start, use install-xfce.sh or install-i3.sh instead."
echo ""
echo "Press Ctrl+C to cancel, Enter to continue..."
read -r

apt update
apt install -y --no-install-recommends \
  sway swaybg swayidle swaylock \
  foot \
  wmenu \
  xwayland \
  fonts-dejavu-core \
  pulseaudio

SWAY_USER="${1:-cubie}"
SWAY_HOME=$(eval echo "~$SWAY_USER")

# Default sway config
mkdir -p "$SWAY_HOME/.config/sway"
if [ ! -f "$SWAY_HOME/.config/sway/config" ]; then
  cp /etc/sway/config "$SWAY_HOME/.config/sway/config" 2>/dev/null || true
fi
chown -R "$SWAY_USER:" "$SWAY_HOME/.config" 2>/dev/null || true

# Auto-start sway on tty1 login (no display manager needed for Wayland)
PROFILE="$SWAY_HOME/.bash_profile"
if ! grep -q 'exec sway' "$PROFILE" 2>/dev/null; then
  cat >> "$PROFILE" << 'AUTOSWAY'

# Auto-start Sway on tty1 (force card0 for display, card1 has no KMS)
if [ "$(tty)" = "/dev/tty1" ] && [ -z "$WAYLAND_DISPLAY" ]; then
  export WLR_DRM_DEVICES=/dev/dri/card0
  exec sway
fi
AUTOSWAY
  chown "$SWAY_USER:" "$PROFILE" 2>/dev/null || true
fi

# Disable any X11 display manager if present (sway manages its own session)
for dm in lightdm sddm gdm3; do
  systemctl disable "$dm" 2>/dev/null || true
done

# Auto-login on tty1 so sway starts without manual password entry on HDMI
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << AEOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $SWAY_USER --noclear %I \$TERM
AEOF

echo ""
echo "=== Sway installed ==="
echo "Reboot — Sway starts automatically (autologin as $SWAY_USER on tty1)."
echo "If it fails, use install-xfce.sh or install-i3.sh (X11) instead."
echo ""
echo "Key bindings: Mod+Enter=terminal, Mod+d=launcher, Mod+Shift+e=exit"
echo ""
echo "GPU: PowerVR BXM-4-64 — Vulkan 1.3 and OpenGL ES 3.2 available."
echo "     Note: Wayland compositors use EGL directly, not GLX."
