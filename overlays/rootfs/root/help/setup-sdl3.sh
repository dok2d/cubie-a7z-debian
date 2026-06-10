#!/bin/bash
# Setup SDL3 — next-gen multimedia library for KMSDRM, Wayland, X11 apps.
# Run as root. Requires internet.
#
# Benefits over SDL2:
#   - Improved KMSDRM backend (atomic modesetting, better VSync)
#   - Nanosecond-precision timers (better frame pacing)
#   - Lazy audio conversion (lower CPU usage)
#   - Stream-based audio API with automatic device migration
#   - Vulkan renderer backend
#
# Used by: install-quake2-kmsdrm.sh and any future SDL3 KMSDRM apps.
# Can coexist with SDL2 — different soname (libSDL3.so.0 vs libSDL2-2.0.so.0).

set -e
echo "=== Setting up SDL3 ==="

if dpkg -s libsdl3-0 >/dev/null 2>&1; then
  echo "SDL3 runtime already installed: $(dpkg-query -W -f '${Version}' libsdl3-0)"
  if dpkg -s libsdl3-dev >/dev/null 2>&1; then
    echo "SDL3 dev headers already installed."
    exit 0
  fi
fi

apt update
apt install -y --no-install-recommends \
  libsdl3-0 \
  libsdl3-dev

echo ""
echo "=== SDL3 installed ==="
echo "Version: $(dpkg-query -W -f '${Version}' libsdl3-0)"
echo ""
echo "For KMSDRM apps, the LD_PRELOAD libudev workaround is still needed:"
echo "  export LD_PRELOAD=/lib/aarch64-linux-gnu/libudev.so.1"
echo ""
echo "This is an upstream SDL bug (issues #2397, #4879) — SDL tries to"
echo "resolve udev symbols before dlopen(libudev.so.1). Affects SDL2 & SDL3."
echo "LD_PRELOAD ensures libudev is loaded globally before SDL init."
echo ""
echo "SDL3 KMSDRM environment variables:"
echo "  SDL_VIDEODRIVER=kmsdrm"
echo "  SDL_KMSDRM_DEVICE_INDEX=0          # sunxi-drm (HDMI)"
echo "  SDL_KMSDRM_REQUIRE_DRM_MASTER=0    # optional: don't require master"
