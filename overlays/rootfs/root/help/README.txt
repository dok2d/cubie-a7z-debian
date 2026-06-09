Cubie A7Z — Help & Setup Scripts
=================================

Quick references and install scripts for common tasks.
All scripts require root and working internet (configure WiFi first).

Files:
  wifi.txt          WiFi setup guide (do this first)
  install-xfce.sh   XFCE4 desktop (X11, lightweight, recommended for 1GB RAM)
  install-i3.sh     i3 tiling WM (X11, minimal)
  install-lxqt.sh   LXQt desktop (X11, Qt-based)
  install-sway.sh   Sway tiling WM (Wayland, needs DRM — may not work with PowerVR)
  install-labwc.sh  labwc compositor (Wayland, needs DRM — may not work with PowerVR)

Recommended for 1GB RAM: XFCE or i3 (X11).
Wayland compositors (sway/labwc) need DRM with dumb buffer support.
PowerVR GPU (card1) does NOT support it — Wayland will use sunxi-drm (card0)
which is software rendering. X11 options are more reliable.

Usage:
  bash /root/help/install-xfce.sh

After install, reboot — desktop starts automatically on HDMI:
  X11 (xfce/i3/lxqt): via lightdm/sddm display manager
  Wayland (sway/labwc): via autologin on tty1 + .bash_profile
Connect a USB keyboard to the top USB-C port (J4).

Notes:
  - x11-common.service is masked by Debian Trixie — install scripts unmask it
  - Xorg uses modesetting driver on /dev/dri/card0 (sunxi-drm)
  - /dev/dri/card1 (PowerVR) is for 3D acceleration only, not display

Hardware tests:
  bash /root/tests/test-all.sh
