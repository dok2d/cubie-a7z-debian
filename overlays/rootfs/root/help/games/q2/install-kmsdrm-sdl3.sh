#!/bin/bash
# Install Quake II — KMSDRM + SDL3 + OpenGL ES 3.2.
# Runs directly on HDMI framebuffer, no window manager needed.
# SDL3 benefits: atomic KMSDRM, nanosecond frame pacing, lazy audio conversion.
# Run as root. Requires internet.

set -e
source "$(dirname "$0")/_common.sh"

INSTALLDIR=/opt/quake2-kmsdrm
Q2DIR="$INSTALLDIR/baseq2"

if [ -f "$INSTALLDIR/quake2" ] && [ -f "$Q2DIR/pak0.pak" ]; then
  echo "Quake II KMSDRM (SDL3) already installed."
  echo "KMSDRM: kmsdrm-run quake2-kmsdrm"
  echo "X11:    quake2-yamagi"
  exit 0
fi

echo "=== Installing Quake II (KMSDRM + SDL3) ==="
echo "Builds Yamagi Quake II (SDL3 master) from source."
echo "KMSDRM: OpenGL ES 3.2 direct to framebuffer (no WM)"
echo "X11:    Vulkan 1.3 via PowerVR (under any desktop)"
echo "Press Ctrl+C to cancel, Enter to continue..."
read -r

# Setup SDL3 + KMSDRM + GPU
bash "$HELPDIR/setup-sdl3.sh"
bash "$HELPDIR/setup-kmsdrm.sh"

# Build dependencies (SDL3 dev installed by setup-sdl3.sh)
apt install -y --no-install-recommends \
  git build-essential cmake \
  libvulkan-dev libcurl4-openssl-dev \
  libopenal-dev wget unzip

# Build Yamagi Quake II (master — SDL3)
BUILDDIR=/tmp/yquake2-build
rm -rf "$BUILDDIR"
echo "Cloning Yamagi Quake II (SDL3 master)..."
git clone --depth 1 https://github.com/yquake2/yquake2.git "$BUILDDIR/yquake2"
echo "Building..."
cd "$BUILDDIR/yquake2"
make -j$(nproc) 2>&1 | tail -5

# Build Vulkan renderer (ref_vk)
echo "Cloning ref_vk..."
git clone --depth 1 https://github.com/yquake2/ref_vk.git "$BUILDDIR/ref_vk"
echo "Building ref_vk..."
cd "$BUILDDIR/ref_vk"
make -j$(nproc) 2>&1 | tail -5

# Install
mkdir -p "$INSTALLDIR/baseq2"
for so in quake2 ref_soft.so ref_gl1.so ref_gl3.so ref_gles3.so; do
  find "$BUILDDIR/yquake2/release" -name "$so" -exec cp {} "$INSTALLDIR/" \; 2>/dev/null
done
find "$BUILDDIR/yquake2/release" -name 'game.so' -exec cp {} "$Q2DIR/" \; 2>/dev/null
find "$BUILDDIR/ref_vk" -name 'ref_vk.so' -exec cp {} "$INSTALLDIR/" \; 2>/dev/null
chmod +x "$INSTALLDIR/quake2" 2>/dev/null

# KMSDRM launcher (GLES3 — no Vulkan on KMSDRM, PVR lacks VK_KHR_display)
cat > /usr/local/bin/quake2-kmsdrm << 'LAUNCHER'
#!/bin/bash
# libudev workaround: upstream SDL bug #2397/#4879.
export LD_PRELOAD=/lib/aarch64-linux-gnu/libudev.so.1
export SDL_VIDEODRIVER=kmsdrm
export SDL_KMSDRM_DEVICE_INDEX=0
export LD_LIBRARY_PATH=/usr/local/lib:/opt/quake2-kmsdrm
export VK_ICD_FILENAMES=/etc/vulkan/icd.d/pvr_icd.json
for dm in lightdm sddm; do systemctl stop "$dm" 2>/dev/null; done
pkill -x Xorg 2>/dev/null; pkill -x sway 2>/dev/null
sleep 1
cd /opt/quake2-kmsdrm
exec ./quake2 +set vid_renderer gles3 "$@"
LAUNCHER
chmod +x /usr/local/bin/quake2-kmsdrm

# X11 launcher (Vulkan via VK_KHR_xlib_surface)
cat > /usr/local/bin/quake2-yamagi << 'LAUNCHER'
#!/bin/bash
export LD_LIBRARY_PATH=/usr/local/lib:/opt/quake2-kmsdrm
export VK_ICD_FILENAMES=/etc/vulkan/icd.d/pvr_icd.json
cd /opt/quake2-kmsdrm
exec ./quake2 +set vid_renderer vk "$@"
LAUNCHER
chmod +x /usr/local/bin/quake2-yamagi

# Desktop entries (visible in XFCE, LXQt, i3+dmenu, sway+wmenu)
create_desktop_entry "Quake II (KMSDRM)" "SDL3 GLES3 direct framebuffer" \
  "kmsdrm-run quake2-kmsdrm" "quake2-kmsdrm" "true"
create_desktop_entry "Quake II (Vulkan)" "Vulkan 1.3 on PowerVR" \
  "quake2-yamagi" "quake2-yamagi" "false"

download_shareware "$Q2DIR"
rm -rf "$BUILDDIR"

echo ""
if [ -f "$INSTALLDIR/quake2" ]; then
  echo "=== Quake II installed (SDL3) ==="
  echo ""
  echo "KMSDRM (no WM):  kmsdrm-run quake2-kmsdrm  (GLES3)"
  echo "X11 (any WM):    quake2-yamagi              (Vulkan 1.3)"
  echo "SDL: $(dpkg-query -W -f '${Version}' libsdl3-0 2>/dev/null)"
  echo ""
  print_game_status "$INSTALLDIR"
else
  echo "ERROR: Build failed."
fi
