Cubie A7Z — Help & Setup Scripts
=================================

All scripts require root and working internet.
Configure WiFi first: see wifi.txt

Quick start:
  bash /root/help/wm/install-xfce.sh           # desktop
  bash /root/help/games/q2/install-quake2.sh    # game

Directory layout:

  wifi.txt              WiFi setup guide (do this first)

  setup-gpu.sh          GPU acceleration (auto-called by other scripts)
  setup-vulkan.sh       Vulkan 1.3 (PowerVR, X11 only)
  setup-kmsdrm.sh       KMSDRM environment + kmsdrm-run launcher
  setup-sdl3.sh         SDL3 multimedia library

  wm/                   Window managers / desktops
    install-xfce.sh       XFCE4 (X11, recommended for 1GB RAM)
    install-i3.sh         i3 tiling WM (X11, minimal)
    install-lxqt.sh       LXQt (X11, Qt-based)
    install-sway.sh       Sway tiling WM (Wayland)
    install-labwc.sh      labwc compositor (Wayland)

  games/                Game installers (build from source on board)
    BENCHMARK.md          Performance results for all tested games
    q2/                   Quake II — KMSDRM GLES3 / X11 Vulkan (verified 60fps)
    q3/                   Quake III + OpenArena — X11 gl4es (blocked by GLVND)
    halflife/             Half-Life — KMSDRM native GLES (verified 60fps)
    serioussam/           Serious Sam TFE — X11 Vulkan (untested)

After desktop install, reboot — starts automatically on HDMI:
  X11 (xfce/i3/lxqt):    via lightdm/sddm display manager
  Wayland (sway/labwc):   via autologin on tty1

GPU:
  PowerVR BXM-4-64 — OpenGL ES 3.2, Vulkan 1.3 (X11 only), OpenCL 3.0
  Vulkan on KMSDRM not supported (PVR ICD lacks VK_KHR_display).

HDMI hotplug:
  Handled by hdmi-hotplug-daemon systemd service.
  Console recovers automatically after cable replug (~10s).

Hardware tests:
  bash /root/tests/test-all.sh    Run all tests
  Individual: test-hdmi, test-gpu, test-gpu-demo, test-wifi, test-bt,
              test-npu, test-usbc, test-pcie, test-spi, test-i2c,
              test-gpio, test-thermal
