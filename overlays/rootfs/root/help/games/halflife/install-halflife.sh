#!/bin/bash
# Install Half-Life via Xash3D FWGS engine.
# Run as root. Requires internet.
#
# Rendering: native GLES3 (gles3compat) on PowerVR GPU — no gl4es needed.
# KMSDRM: direct framebuffer via kmsdrm-run, no WM needed.
# X11: works under any desktop.
# RAM: ~200 MB.
#
# Game data: copy valve/ directory from Steam Half-Life to /opt/halflife/valve/
# Steam HL uses .wad + .bsp files (no .pak needed).

set -e
HELPDIR="$(cd "$(dirname "$0")/../.." && pwd)"

INSTALLDIR=/opt/halflife

if [ -f "$INSTALLDIR/xash3d" ] && [ -d "$INSTALLDIR/valve/maps" ]; then
  echo "Half-Life already installed."
  echo "KMSDRM:  bash $(dirname "$0")/run-kmsdrm.sh"
  echo "X11:     bash $(dirname "$0")/run-x11.sh"
  exit 0
fi

echo "=== Installing Half-Life (Xash3D FWGS) ==="
echo "Builds Xash3D engine + HL SDK from source (~5 min on A733)."
echo "Renderer: gles3compat (native OpenGL ES on PowerVR GPU)."
echo "Press Ctrl+C to cancel, Enter to continue..."
read -r

bash "$HELPDIR/setup-gpu.sh"

# Build dependencies
apt update
apt install -y --no-install-recommends \
  git build-essential python3 \
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
echo "Building engine (bundled gl4es may fail — that's OK)..."
./waf build -j$(nproc) 2>&1 | tail -5 || true

# Verify at least the core engine built
if [ ! -f build/engine/libxash.so ]; then
  echo "ERROR: Engine build failed."
  exit 1
fi

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

# Copy all built .so and binaries
find "$BUILDDIR/engine/build" -name "xash3d" -type f -exec cp {} "$INSTALLDIR/" \;
find "$BUILDDIR/engine/build" -name "*.so" -exec cp {} "$INSTALLDIR/" \; 2>/dev/null

# HL SDK game libraries
find "$BUILDDIR/hlsdk/build" -name "client*.so" -exec cp {} "$INSTALLDIR/valve/cl_dlls/" \;
find "$BUILDDIR/hlsdk/build" -name "hl*.so" -exec cp {} "$INSTALLDIR/valve/dlls/" \;

chmod +x "$INSTALLDIR/xash3d" 2>/dev/null
chown -R 1000:1000 "$INSTALLDIR" 2>/dev/null || true

rm -rf "$BUILDDIR"

# KMSDRM launcher — uses kmsdrm-run wrapper (handles DRM master + fbcon recovery)
cat > /usr/local/bin/halflife-kmsdrm << 'LAUNCHER'
#!/bin/bash
export LD_LIBRARY_PATH=/usr/local/lib:/opt/halflife
cd /opt/halflife
exec ./xash3d -ref gles3compat -fullscreen "$@"
LAUNCHER
chmod +x /usr/local/bin/halflife-kmsdrm

# X11 launcher
cat > /usr/local/bin/halflife-x11 << 'LAUNCHER'
#!/bin/bash
export LD_LIBRARY_PATH=/usr/local/lib:/opt/halflife
cd /opt/halflife
exec ./xash3d -ref gles3compat -fullscreen "$@"
LAUNCHER
chmod +x /usr/local/bin/halflife-x11

# Desktop entry (visible in XFCE, LXQt, i3+dmenu, sway+wmenu)
mkdir -p /usr/share/applications
cat > /usr/share/applications/halflife.desktop << 'DESKTOP'
[Desktop Entry]
Name=Half-Life
Comment=Half-Life via Xash3D FWGS (GLES3 on PowerVR)
Exec=halflife-x11
Terminal=false
Type=Application
Categories=Game;ActionGame;
Icon=applications-games
DESKTOP

echo ""
echo "=== Half-Life engine installed ==="
echo ""
echo "KMSDRM (no WM):  kmsdrm-run halflife-kmsdrm"
echo "X11 (desktop):    halflife-x11"
echo ""
if [ -d "$INSTALLDIR/valve/maps" ] || [ -f "$INSTALLDIR/valve/pak0.pak" ]; then
  echo "Game data found."
else
  echo "Game data MISSING."
  echo ""
  echo "Copy valve/ from Steam Half-Life installation:"
  echo "  scp -r /path/to/Steam/steamapps/common/Half-Life/valve root@<board-ip>:$INSTALLDIR/valve/"
  echo ""
  echo "Then fix permissions:"
  echo "  chown -R 1000:1000 $INSTALLDIR/valve/"
fi
