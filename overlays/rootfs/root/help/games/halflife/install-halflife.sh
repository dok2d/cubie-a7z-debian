#!/bin/bash
# Install Half-Life via Xash3D FWGS engine.
# Run as root. Requires internet.
#
# Rendering: native GLES2 on PowerVR GPU (no gl4es needed).
# KMSDRM: direct framebuffer, no WM needed.
# X11: works under any desktop.
# RAM: ~100–200 MB.
#
# Game data: copy valve/ directory from Steam Half-Life to /opt/halflife/valve/

set -e
HELPDIR="$(cd "$(dirname "$0")/../.." && pwd)"

INSTALLDIR=/opt/halflife

if [ -f "$INSTALLDIR/xash3d" ] && [ -f "$INSTALLDIR/valve/pak0.pak" ]; then
  echo "Half-Life already installed."
  echo "KMSDRM: halflife-kmsdrm"
  echo "X11:    halflife-x11"
  exit 0
fi

echo "=== Installing Half-Life (Xash3D FWGS) ==="
echo "Builds Xash3D engine + HL SDK from source."
echo "Native GLES2 renderer — designed for ARM + embedded Linux."
echo "Press Ctrl+C to cancel, Enter to continue..."
read -r

bash "$HELPDIR/setup-gpu.sh"

# Build dependencies
apt update
apt install -y --no-install-recommends \
  git build-essential python3 cmake \
  libsdl2-dev libfreetype6-dev libfontconfig1-dev \
  libopus-dev libbz2-dev libvorbis-dev libopusfile-dev libogg-dev

BUILDDIR=/var/tmp/xash3d-build
rm -rf "$BUILDDIR"
mkdir -p "$BUILDDIR"

# Build Xash3D FWGS engine
echo "Cloning Xash3D FWGS..."
git clone --depth 1 --recursive https://github.com/FWGS/xash3d-fwgs.git "$BUILDDIR/engine"
cd "$BUILDDIR/engine"
echo "Configuring..."
./waf configure --enable-all-renderers --enable-stbtt -T release 2>&1 | tail -5
echo "Building engine..."
./waf build -j$(nproc) 2>&1 | tail -5

# Build Half-Life SDK (ARM64 game libraries)
echo "Cloning HL SDK..."
git clone --depth 1 --recursive https://github.com/FWGS/hlsdk-portable.git "$BUILDDIR/hlsdk"
cd "$BUILDDIR/hlsdk"
echo "Building HL SDK..."
./waf configure -T release 2>&1 | tail -3
./waf build -j$(nproc) 2>&1 | tail -3

# Install
echo "Installing..."
mkdir -p "$INSTALLDIR/valve/dlls" "$INSTALLDIR/valve/cl_dlls"

# Engine files
cp "$BUILDDIR/engine/build/game_launch/xash3d" "$INSTALLDIR/"
cp "$BUILDDIR/engine/build/engine/libxash.so" "$INSTALLDIR/"
cp "$BUILDDIR/engine/build/filesystem/filesystem_stdio.so" "$INSTALLDIR/"
cp "$BUILDDIR/engine/build/3rdparty/mainui/libmenu.so" "$INSTALLDIR/" 2>/dev/null || true
cp "$BUILDDIR/engine/build/ref/gl/libref_gl.so" "$INSTALLDIR/" 2>/dev/null || true
cp "$BUILDDIR/engine/build/ref/gles/libref_gles.so" "$INSTALLDIR/" 2>/dev/null || true
cp "$BUILDDIR/engine/build/ref/soft/libref_soft.so" "$INSTALLDIR/" 2>/dev/null || true
# Copy all .so from build in case paths differ between versions
find "$BUILDDIR/engine/build" -name "*.so" -exec cp {} "$INSTALLDIR/" \; 2>/dev/null

# HL SDK game libraries (ARM64 naming convention)
find "$BUILDDIR/hlsdk/build" -name "client.so" -exec cp {} "$INSTALLDIR/valve/cl_dlls/" \; 2>/dev/null
find "$BUILDDIR/hlsdk/build" -name "hl.so" -exec cp {} "$INSTALLDIR/valve/dlls/" \; 2>/dev/null

chmod +x "$INSTALLDIR/xash3d"

rm -rf "$BUILDDIR"

# KMSDRM launcher (native GLES2 — best path for PowerVR)
cat > /usr/local/bin/halflife-kmsdrm << 'LAUNCHER'
#!/bin/bash
export LD_PRELOAD=/lib/aarch64-linux-gnu/libudev.so.1
export SDL_VIDEODRIVER=kmsdrm
export SDL_KMSDRM_DEVICE_INDEX=0
export LD_LIBRARY_PATH=/usr/local/lib:/opt/halflife
for dm in lightdm sddm; do systemctl stop "$dm" 2>/dev/null; done
pkill -x Xorg 2>/dev/null; pkill -x sway 2>/dev/null
sleep 1
cd /opt/halflife
exec ./xash3d -ref gles2 -width 1920 -height 1080 -fullscreen "$@"
LAUNCHER
chmod +x /usr/local/bin/halflife-kmsdrm

# X11 launcher
cat > /usr/local/bin/halflife-x11 << 'LAUNCHER'
#!/bin/bash
export LD_LIBRARY_PATH=/usr/local/lib:/opt/halflife
cd /opt/halflife
exec ./xash3d -ref gles2 -width 1920 -height 1080 -fullscreen "$@"
LAUNCHER
chmod +x /usr/local/bin/halflife-x11

# Desktop entry
mkdir -p /usr/share/applications
cat > /usr/share/applications/halflife.desktop << 'DESKTOP'
[Desktop Entry]
Name=Half-Life
Comment=Half-Life via Xash3D FWGS (GLES2 on PowerVR)
Exec=halflife-x11
Terminal=false
Type=Application
Categories=Game;ActionGame;
Icon=applications-games
DESKTOP

echo ""
echo "=== Half-Life engine installed ==="
echo ""
echo "KMSDRM (no WM):  halflife-kmsdrm"
echo "X11 (desktop):    halflife-x11"
echo ""
if [ -f "$INSTALLDIR/valve/pak0.pak" ]; then
  echo "Game data found."
else
  echo "Game data MISSING. Copy valve/ from Steam Half-Life to $INSTALLDIR/valve/"
  echo "Required files: valve/pak0.pak, valve/pak1.pak"
  echo ""
  echo "On PC: Steam → Half-Life → Properties → Local Files → Browse"
  echo "Copy the entire valve/ directory to $INSTALLDIR/valve/"
fi
