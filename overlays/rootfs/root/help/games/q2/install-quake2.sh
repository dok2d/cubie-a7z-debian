#!/bin/bash
# Install Quake II — interactive setup selector.
# Run as root. Requires internet.

set -e

echo "=== Quake II for Cubie A7Z ==="
echo ""
echo "Choose rendering mode:"
echo ""
echo "  1) KMSDRM + SDL2   — GLES3 direct to HDMI, no window manager"
echo "                        Maximum performance, minimum RAM."
echo ""
echo "  2) KMSDRM + SDL3   — Same as (1) but with SDL3 (better frame pacing,"
echo "                        atomic modesetting). Builds from Yamagi master."
echo ""
echo "  3) Vulkan + X11    — Vulkan 1.3 under any desktop (XFCE, i3, sway...)"
echo "                        Requires a desktop environment installed first."
echo ""
read -rp "Enter 1, 2, or 3: " choice

SCRIPTDIR="$(dirname "$0")"

case "$choice" in
  1) exec bash "$SCRIPTDIR/install-kmsdrm.sh" ;;
  2) exec bash "$SCRIPTDIR/install-kmsdrm-sdl3.sh" ;;
  3) exec bash "$SCRIPTDIR/install-vulkan.sh" ;;
  *) echo "Invalid choice."; exit 1 ;;
esac
