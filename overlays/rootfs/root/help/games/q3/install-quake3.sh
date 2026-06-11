#!/bin/bash
# Install Quake III Arena (ioquake3) + OpenArena (free game data).
# Run as root. Requires internet.
#
# Rendering: OpenGL via gl4es (GL→GLES2 translation) on PowerVR GPU.
# X11 only — ioquake3 uses GLX, not EGL (no KMSDRM support).
# Requires a desktop environment (XFCE, i3, LXQt, sway, labwc).
# RAM: ~150–250 MB.

set -e
HELPDIR="$(cd "$(dirname "$0")/../.." && pwd)"

echo "=== Installing Quake III Arena ==="
echo "Installs ioquake3 + gl4es + OpenArena (free standalone game)."
echo "Requires X11 desktop (install one from /root/help/wm/ first)."
echo "Press Ctrl+C to cancel, Enter to continue..."
read -r

bash "$HELPDIR/setup-gpu.sh"

apt update
apt install -y --no-install-recommends \
  ioquake3 openarena openarena-data \
  git build-essential cmake libsdl2-dev

# Build gl4es (translates desktop GL calls to GLES2 for PowerVR)
GL4ES=/opt/gl4es
if [ ! -f "$GL4ES/lib/libGL.so.1" ]; then
  echo "Building gl4es..."
  BUILDDIR=/var/tmp/gl4es-build
  rm -rf "$BUILDDIR"
  git clone --depth 1 https://github.com/ptitSeb/gl4es.git "$BUILDDIR"
  mkdir -p "$BUILDDIR/build"
  cd "$BUILDDIR/build"
  cmake .. -DCMAKE_BUILD_TYPE=Release -DODROID=ON 2>&1 | tail -3
  make -j1 2>&1 | tail -3
  mkdir -p "$GL4ES/lib"
  cp /tmp/gl4es-build/lib/libGL.so.1 "$GL4ES/lib/"
  rm -rf "$BUILDDIR"
  echo "gl4es built: $GL4ES/lib/libGL.so.1"
fi

# X11 launcher (gl4es translates GL→GLES2 on PowerVR)
cat > /usr/local/bin/quake3 << 'LAUNCHER'
#!/bin/bash
export LD_PRELOAD=/opt/gl4es/lib/libGL.so.1
export LD_LIBRARY_PATH=/usr/local/lib
export LIBGL_ES=2
exec ioquake3 \
  +set com_hunkMegs 128 +set com_zoneMegs 32 +set com_soundMegs 16 "$@"
LAUNCHER
chmod +x /usr/local/bin/quake3

# OpenArena X11 launcher
cat > /usr/local/bin/openarena-gl << 'LAUNCHER'
#!/bin/bash
export LD_PRELOAD=/opt/gl4es/lib/libGL.so.1
export LD_LIBRARY_PATH=/usr/local/lib
export LIBGL_ES=2
exec openarena \
  +set com_hunkMegs 128 +set com_zoneMegs 32 +set com_soundMegs 16 "$@"
LAUNCHER
chmod +x /usr/local/bin/openarena-gl

# Desktop entries
mkdir -p /usr/share/applications
cat > /usr/share/applications/quake3.desktop << 'DESKTOP'
[Desktop Entry]
Name=Quake III Arena
Comment=ioquake3 via gl4es on PowerVR
Exec=quake3
Terminal=false
Type=Application
Categories=Game;ActionGame;
Icon=applications-games
DESKTOP

cat > /usr/share/applications/openarena.desktop << 'DESKTOP'
[Desktop Entry]
Name=OpenArena
Comment=Free Quake III Arena standalone (gl4es)
Exec=openarena-gl
Terminal=false
Type=Application
Categories=Game;ActionGame;
Icon=applications-games
DESKTOP

echo ""
echo "=== Quake III Arena installed ==="
echo ""
echo "OpenArena (free):  openarena-gl     (X11 desktop required)"
echo "Quake III Arena:   quake3           (needs pak0.pk3)"
echo ""
echo "For retail Q3A, copy pak0.pk3 to ~/.q3a/baseq3/"
echo "OpenArena works out of the box — no purchase needed."
echo ""
echo "NOTE: X11 only. Requires a running desktop (XFCE, i3, sway, etc.)"
echo "      Rendering via gl4es (GL→GLES2 translation on PowerVR GPU)."
