#!/bin/bash
# Install Quake II for KMSDRM — runs directly on framebuffer, no WM needed.
# Uses Yamagi Quake II (master, SDL3) + ref_vk with SDL3 KMSDRM backend.
# Run as root. Requires internet and ~500 MB disk space.
#
# Maximum performance, minimum RAM usage. Ideal for 1GB SKU.
# SDL3 benefits: atomic KMSDRM, nanosecond frame pacing, lazy audio conversion.

set -e

INSTALLDIR=/opt/quake2-kmsdrm
Q2DIR="$INSTALLDIR/baseq2"

if [ -f "$INSTALLDIR/quake2" ] && [ -f "$Q2DIR/pak0.pak" ]; then
  echo "Quake II KMSDRM already installed."
  echo "Run: kmsdrm-run quake2-kmsdrm"
  exit 0
fi

echo "=== Installing Quake II (SDL3 + KMSDRM) ==="
echo "Builds Yamagi Quake II (SDL3) from source."
echo "Runs directly on HDMI without any window manager."
echo "Press Ctrl+C to cancel, Enter to continue..."
read -r

# Setup SDL3 and KMSDRM environment
bash "$(dirname "$0")/setup-sdl3.sh"
bash "$(dirname "$0")/setup-kmsdrm.sh"

# Build dependencies (SDL3 dev installed by setup-sdl3.sh)
apt install -y --no-install-recommends \
  git build-essential cmake \
  libvulkan-dev libcurl4-openssl-dev \
  libopenal-dev \
  wget unzip

# Build Yamagi Quake II (master — uses SDL3)
BUILDDIR=/tmp/yquake2-build
rm -rf "$BUILDDIR"
echo "Cloning Yamagi Quake II (master, SDL3)..."
git clone --depth 1 https://github.com/yquake2/yquake2.git "$BUILDDIR/yquake2"
echo "Building Yamagi Quake II..."
cd "$BUILDDIR/yquake2"
make -j$(nproc) 2>&1 | tail -5

# Build Vulkan renderer (ref_vk)
echo "Cloning ref_vk (Vulkan renderer)..."
git clone --depth 1 https://github.com/yquake2/ref_vk.git "$BUILDDIR/ref_vk"
echo "Building ref_vk..."
cd "$BUILDDIR/ref_vk"
make -j$(nproc) 2>&1 | tail -5

# Install
mkdir -p "$INSTALLDIR/baseq2"
echo "Installing..."

# Yamagi Makefile builds to release/
find "$BUILDDIR/yquake2/release" -name 'quake2' -type f -exec cp {} "$INSTALLDIR/" \; 2>/dev/null
find "$BUILDDIR/yquake2/release" -name 'ref_soft.so' -exec cp {} "$INSTALLDIR/" \; 2>/dev/null
find "$BUILDDIR/yquake2/release" -name 'ref_gl1.so' -exec cp {} "$INSTALLDIR/" \; 2>/dev/null
find "$BUILDDIR/yquake2/release" -name 'ref_gl3.so' -exec cp {} "$INSTALLDIR/" \; 2>/dev/null
find "$BUILDDIR/yquake2/release" -name 'ref_gles3.so' -exec cp {} "$INSTALLDIR/" \; 2>/dev/null
find "$BUILDDIR/yquake2/release" -name 'game.so' -exec cp {} "$Q2DIR/" \; 2>/dev/null

# ref_vk
find "$BUILDDIR/ref_vk" -name 'ref_vk.so' -exec cp {} "$INSTALLDIR/" \; 2>/dev/null

chmod +x "$INSTALLDIR/quake2" 2>/dev/null

# Create KMSDRM launcher
cat > /usr/local/bin/quake2-kmsdrm << 'LAUNCHER'
#!/bin/bash
# SDL3 KMSDRM launcher for Yamagi Quake II
# libudev workaround: upstream SDL bug #2397/#4879 — SDL tries to resolve
# udev symbols before dlopen(libudev.so.1). Affects both SDL2 and SDL3.
export LD_PRELOAD=/lib/aarch64-linux-gnu/libudev.so.1
export SDL_VIDEODRIVER=kmsdrm
export SDL_KMSDRM_DEVICE_INDEX=0
export LD_LIBRARY_PATH=/usr/local/lib:/opt/quake2-kmsdrm
export VK_ICD_FILENAMES=/etc/vulkan/icd.d/pvr_icd.json
# Stop any DRM masters (Xorg/sway) — KMSDRM needs exclusive access
for dm in lightdm sddm; do systemctl stop "$dm" 2>/dev/null; done
pkill -x Xorg 2>/dev/null; pkill -x sway 2>/dev/null
sleep 1
cd /opt/quake2-kmsdrm
exec ./quake2 +set vid_renderer gles3 "$@"
LAUNCHER
chmod +x /usr/local/bin/quake2-kmsdrm

# Also keep X11/XWayland launcher for use under WM
cat > /usr/local/bin/quake2-yamagi << 'LAUNCHER'
#!/bin/bash
export LD_LIBRARY_PATH=/usr/local/lib:/opt/quake2-kmsdrm
cd /opt/quake2-kmsdrm
exec ./quake2 +set vid_renderer gles3 "$@"
LAUNCHER
chmod +x /usr/local/bin/quake2-yamagi

# Desktop entry
mkdir -p /usr/share/applications
cat > /usr/share/applications/quake2-kmsdrm.desktop << 'DESKTOP'
[Desktop Entry]
Name=Quake II (KMSDRM)
Comment=Quake II SDL3 — direct framebuffer, no WM
Exec=kmsdrm-run quake2-kmsdrm
Terminal=true
Type=Application
Categories=Game;ActionGame;
Icon=applications-games
DESKTOP

# Download shareware demo if no pak files
if [ ! -f "$Q2DIR/pak0.pak" ]; then
  echo "Downloading Quake II shareware demo..."
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  wget -q --show-progress -O q2-demo.zip \
    "https://deponie.yamagi.org/quake2/idstuff/q2-314-demo-x86.exe" 2>&1 || \
  wget -q --show-progress -O q2-demo.zip \
    "https://archive.org/download/quake-2-demo/q2-314-demo-x86.exe" 2>&1 || true
  if [ -f q2-demo.zip ]; then
    mkdir -p extracted
    unzip -o -j q2-demo.zip 'Install/Data/baseq2/*' -d extracted/ 2>/dev/null || \
    unzip -o -j q2-demo.zip '*/baseq2/*' -d extracted/ 2>/dev/null || true
    cp extracted/*.pak "$Q2DIR/" 2>/dev/null || true
  fi
  cd /
  rm -rf "$TMPDIR"
fi

# Cleanup
rm -rf "$BUILDDIR"

echo ""
if [ -f "$INSTALLDIR/quake2" ]; then
  echo "=== Quake II (KMSDRM) installed ==="
  echo ""
  echo "KMSDRM (no WM): kmsdrm-run quake2-kmsdrm"
  echo "Under sway/X11: quake2-yamagi"
  echo ""
  if [ -f "$Q2DIR/pak0.pak" ]; then
    echo "Game data: $(ls "$Q2DIR"/*.pak 2>/dev/null | wc -l) pak file(s)"
  else
    echo "WARNING: No pak files. Copy pak0.pak to $Q2DIR/"
  fi
  echo ""
  echo "Full game: copy baseq2/ from GOG/Steam Quake II to $Q2DIR/"
  echo ""
  echo "GPU: PowerVR BXM-4-64 — OpenGL ES 3.2 direct to framebuffer"
  echo "SDL: SDL3 $(dpkg-query -W -f '${Version}' libsdl3-0 2>/dev/null) — KMSDRM backend"
else
  echo "ERROR: Build failed."
fi
