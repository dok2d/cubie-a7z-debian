#!/bin/bash
# Install Serious Sam: The First Encounter (Vulkan renderer).
# Run as root. Requires internet.
#
# Rendering: native Vulkan 1.3 on PowerVR GPU (SeriousSamClassic-VK).
# X11: primary mode (PVR Vulkan needs VK_KHR_xlib_surface).
# KMSDRM: not possible (PVR lacks VK_KHR_display, engine has no GLES path).
# RAM: ~200–400 MB.
#
# Game data: demo available free from Internet Archive.

set -e
HELPDIR="$(cd "$(dirname "$0")/../.." && pwd)"

INSTALLDIR=/opt/serioussam

if [ -f "$INSTALLDIR/Bin/SeriousSam" ]; then
  echo "Serious Sam already installed."
  echo "Run: serioussam"
  exit 0
fi

echo "=== Installing Serious Sam: The First Encounter ==="
echo "Builds SeriousSamClassic-VK from source (Vulkan renderer)."
echo "Requires X11 desktop (Vulkan needs VK_KHR_xlib_surface)."
echo "Press Ctrl+C to cancel, Enter to continue..."
read -r

bash "$HELPDIR/setup-vulkan.sh"

# Build dependencies
apt update
apt install -y --no-install-recommends \
  git build-essential cmake \
  libsdl2-dev libvorbis-dev libvulkan-dev \
  flex bison zlib1g-dev

BUILDDIR=/var/tmp/serioussam-build
rm -rf "$BUILDDIR"

echo "Cloning SeriousSamClassic-VK..."
git clone --depth 1 --recursive \
  https://github.com/tx00100xt/SeriousSamClassic-VK.git "$BUILDDIR"

cd "$BUILDDIR"
mkdir -p build && cd build
echo "Configuring (ARM64 + Vulkan)..."
cmake .. -DCMAKE_BUILD_TYPE=Release -DRPI4=TRUE 2>&1 | tail -5
echo "Building..."
make -j$(nproc) 2>&1 | tail -5

echo "Installing..."
mkdir -p "$INSTALLDIR"
make install DESTDIR="$INSTALLDIR" 2>&1 | tail -3 || true
# Fallback: copy binaries manually if make install doesn't work
find "$BUILDDIR/build" -name "SeriousSam" -type f -exec cp {} "$INSTALLDIR/" \; 2>/dev/null
find "$BUILDDIR/build" -name "*.so" -exec cp {} "$INSTALLDIR/" \; 2>/dev/null
find "$BUILDDIR/build" -name "ssam*" -type f -exec cp {} "$INSTALLDIR/" \; 2>/dev/null

chmod +x "$INSTALLDIR/SeriousSam" 2>/dev/null || true

rm -rf "$BUILDDIR"

# Game data directory
DATADIR="$HOME/.local/share/Serious-Engine/serioussam"
mkdir -p "$DATADIR"

# Download demo if no game data
if [ ! -f "$DATADIR/1_00c.gro" ]; then
  echo ""
  echo "Downloading Serious Sam TFE demo from Internet Archive..."
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  wget -q --show-progress -O ssdemo.tar.gz \
    "https://archive.org/download/SeriousSamDemo/SeriousSamDemo.tar.gz" 2>&1 || \
  wget -q --show-progress -O ssdemo.tar.gz \
    "https://archive.org/download/serious-sam-the-first-encounter-demo/ssdemo.tar.gz" 2>&1 || true
  if [ -f ssdemo.tar.gz ]; then
    tar xzf ssdemo.tar.gz 2>/dev/null || true
    find . -name "*.gro" -exec cp {} "$DATADIR/" \; 2>/dev/null
    find . -name "*.GRO" -exec cp {} "$DATADIR/" \; 2>/dev/null
    find . -type d -name "Levels" -exec cp -r {} "$DATADIR/" \; 2>/dev/null
    find . -type d -name "Help" -exec cp -r {} "$DATADIR/" \; 2>/dev/null
  fi
  cd /
  rm -rf "$TMPDIR"
fi

# X11 launcher (Vulkan — only supported mode)
cat > /usr/local/bin/serioussam << 'LAUNCHER'
#!/bin/bash
export LD_LIBRARY_PATH=/usr/local/lib:/opt/serioussam
export VK_ICD_FILENAMES=/etc/vulkan/icd.d/pvr_icd.json
cd /opt/serioussam
exec ./SeriousSam "$@"
LAUNCHER
chmod +x /usr/local/bin/serioussam

# Desktop entry
mkdir -p /usr/share/applications
cat > /usr/share/applications/serioussam.desktop << 'DESKTOP'
[Desktop Entry]
Name=Serious Sam TFE
Comment=Serious Sam: The First Encounter (Vulkan on PowerVR)
Exec=serioussam
Terminal=false
Type=Application
Categories=Game;ActionGame;
Icon=applications-games
DESKTOP

echo ""
echo "=== Serious Sam: The First Encounter installed ==="
echo ""
echo "Run: serioussam  (requires X11 desktop)"
echo ""
echo "NOTE: Vulkan only — needs a running desktop (XFCE, i3, sway, etc.)"
echo "      PVR GPU lacks VK_KHR_display, so KMSDRM is not possible."
echo ""
if ls "$DATADIR"/*.gro >/dev/null 2>&1; then
  echo "Game data: $(ls "$DATADIR"/*.gro | wc -l) .gro file(s) in $DATADIR/"
else
  echo "Game data MISSING. Copy .gro files to $DATADIR/"
  echo "Full game: Steam → Serious Sam TFE → Local Files"
fi
