#!/bin/bash
# Install Quake II with Vulkan renderer (vkQuake2)
# Run as root. Requires internet and ~500 MB disk space.
#
# Game data: copy pak0.pak (+ pak1.pak, pak2.pak for full game)
# from a legal Quake II copy to /opt/quake2/baseq2/
# Shareware demo is downloaded automatically if no paks found.

set -e

INSTALLDIR=/opt/quake2
Q2DIR="$INSTALLDIR/baseq2"

# Check if already installed
if [ -f "$INSTALLDIR/quake2" ] && [ -f "$Q2DIR/pak0.pak" ]; then
  echo "Quake II already installed at $INSTALLDIR"
  echo "Run: quake2-vk"
  exit 0
fi

echo "=== Installing Quake II (Vulkan) ==="
echo "This will compile vkQuake2 from source (~5-10 min on A733)."
echo "Press Ctrl+C to cancel, Enter to continue..."
read -r

# Ensure GPU is configured
bash "$(dirname "$0")/setup-gpu.sh"

# Build dependencies
apt update
apt install -y --no-install-recommends \
  git build-essential cmake \
  libvulkan-dev libsdl2-dev libcurl4-openssl-dev \
  libxxf86dga-dev libx11-dev libxext-dev libxxf86vm-dev \
  libglu1-mesa-dev \
  wget unzip

# Clone and build vkQuake2
BUILDDIR=/tmp/vkquake2-build
rm -rf "$BUILDDIR"
echo "Cloning vkQuake2..."
git clone --depth 1 https://github.com/kondrak/vkQuake2.git "$BUILDDIR"
echo "Building (this takes a few minutes)..."
cd "$BUILDDIR/linux"
make -j$(nproc) 2>&1 | tail -5

# Install
mkdir -p "$INSTALLDIR/baseq2"
for f in quake2 ref_vk.so ref_gl.so ref_soft.so; do
  [ -f "$BUILDDIR/linux/$f" ] && cp "$BUILDDIR/linux/$f" "$INSTALLDIR/"
done
# Check debug directory too (vkQuake2 builds to debugaarch64/)
for f in quake2 ref_vk.so ref_gl.so ref_soft.so; do
  find "$BUILDDIR/linux" -name "$f" -exec cp {} "$INSTALLDIR/" \; 2>/dev/null
done
[ -f "$BUILDDIR/linux/baseq2/game.so" ] && cp "$BUILDDIR/linux/baseq2/game.so" "$Q2DIR/"
find "$BUILDDIR/linux" -name "game.so" -exec cp {} "$Q2DIR/" \; 2>/dev/null

# Create launchers
cat > /usr/local/bin/quake2-vk << 'LAUNCHER'
#!/bin/bash
export LD_LIBRARY_PATH=/usr/local/lib:/opt/quake2
cd /opt/quake2
exec ./quake2 +set vid_renderer vk "$@"
LAUNCHER
chmod +x /usr/local/bin/quake2-vk

cat > /usr/local/bin/quake2-soft << 'LAUNCHER'
#!/bin/bash
export LD_LIBRARY_PATH=/usr/local/lib:/opt/quake2
cd /opt/quake2
exec ./quake2 +set vid_renderer soft "$@"
LAUNCHER
chmod +x /usr/local/bin/quake2-soft

# Desktop entry (for XFCE, LXQt, and other freedesktop WMs)
mkdir -p /usr/share/applications
cat > /usr/share/applications/quake2.desktop << 'DESKTOP'
[Desktop Entry]
Name=Quake II (Vulkan)
Comment=Quake II with Vulkan renderer on PowerVR GPU
Exec=quake2-vk
Terminal=false
Type=Application
Categories=Game;ActionGame;
Icon=applications-games
DESKTOP

# Sway/i3: add to launcher if wmenu/dmenu is used (they read $PATH, already works)

# Download shareware demo if no pak files
if [ ! -f "$Q2DIR/pak0.pak" ]; then
  echo ""
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

# Cleanup build
rm -rf "$BUILDDIR"

echo ""
if [ -f "$INSTALLDIR/quake2" ]; then
  echo "=== Quake II (Vulkan) installed ==="
  echo ""
  echo "Run:          quake2-vk"
  echo "Software:     quake2-soft"
  echo "Desktop:      Quake II appears in application menu"
  echo ""
  if [ -f "$Q2DIR/pak0.pak" ]; then
    echo "Game data: $(ls "$Q2DIR"/*.pak 2>/dev/null | wc -l) pak file(s) in $Q2DIR/"
  else
    echo "WARNING: No pak files found!"
    echo "Copy pak0.pak from retail Quake II to: $Q2DIR/"
  fi
  echo ""
  echo "Full game: copy baseq2/ contents from GOG/Steam Quake II to $Q2DIR/"
  echo "Extract GOG installer: innoextract setup_quake2*.exe"
  echo ""
  echo "GPU: PowerVR BXM-4-64 — Vulkan 1.3"
else
  echo "ERROR: Build failed. Try manually:"
  echo "  git clone https://github.com/kondrak/vkQuake2.git /tmp/vkquake2-build"
  echo "  cd /tmp/vkquake2-build/linux && make -j\$(nproc)"
fi
