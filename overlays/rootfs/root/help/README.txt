Cubie A7Z — Help & Setup Scripts
=================================

Quick references and install scripts for common tasks.
All scripts require root and working internet (configure WiFi first).

Files:
  wifi.txt          WiFi setup guide (do this first)
  install-xfce.sh   XFCE4 desktop (X11, lightweight, recommended for 1GB RAM)
  install-i3.sh     i3 tiling WM (X11, minimal)
  install-lxqt.sh   LXQt desktop (X11, Qt-based)
  install-sway.sh   Sway tiling WM (Wayland)
  install-labwc.sh  labwc compositor (Wayland)

Recommended for 1GB RAM: XFCE or i3 (X11).

Usage:
  bash /root/help/install-xfce.sh

After install, reboot — desktop starts automatically on HDMI:
  X11 (xfce/i3/lxqt): via lightdm/sddm display manager
  Wayland (sway/labwc): via autologin on tty1 + .bash_profile
Connect a USB keyboard to the top USB-C port (J4).

GPU acceleration:
  PowerVR BXM-4-64 hardware acceleration is enabled out of the box:
  - OpenGL ES 3.2 (via glamor EGL on Xorg, PVR Mesa in /usr/local/lib/)
  - Vulkan 1.3 (libVK_IMG.so, ICD in /etc/vulkan/icd.d/)
  - OpenCL 3.0 (libPVROCL.so, ICD in /etc/OpenCL/vendors/)
  Xorg uses modesetting + glamor on /dev/dri/card0 (sunxi-drm display).
  /dev/dri/card1 (PowerVR) provides 3D rendering via render node.

Hardware tests:
  bash /root/tests/test-all.sh

GPU demo (renders on HDMI):
  bash /root/tests/test-gpu-demo.sh
