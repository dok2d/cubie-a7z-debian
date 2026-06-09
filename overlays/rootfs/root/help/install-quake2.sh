#!/bin/bash
# Install Quake II with Vulkan renderer (vkQuake2)
# Run as root. Requires internet and ~500 MB disk space.
#
# Game data: copy pak0.pak (+ pak1.pak, pak2.pak for full game)
# from a legal Quake II copy to /usr/share/games/quake2/baseq2/
# Shareware demo is downloaded automatically if no paks found.

set -e
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
  vulkan-validationlayers \
  wget unzip

# Clone and build vkQuake2
BUILDDIR=/tmp/vkquake2-build
rm -rf "$BUILDDIR"
git clone --depth 1 https://github.com/kondrak/vkQuake2.git "$BUILDDIR"
cd "$BUILDDIR/linux"
make -j$(nproc) 2>&1 | tail -10

# Install
INSTALLDIR=/opt/quake2
mkdir -p "$INSTALLDIR/baseq2"
cp -a "$BUILDDIR/linux/quake2" "$INSTALLDIR/" 2>/dev/null || true
cp -a "$BUILDDIR/linux/ref_vk.so" "$INSTALLDIR/" 2>/dev/null || true
cp -a "$BUILDDIR/linux/ref_gl.so" "$INSTALLDIR/" 2>/dev/null || true
cp -a "$BUILDDIR/linux/ref_soft.so" "$INSTALLDIR/" 2>/dev/null || true
cp -a "$BUILDDIR/linux/game.so" "$INSTALLDIR/baseq2/" 2>/dev/null || true

# Create launcher
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

# Download shareware demo if no pak files
Q2DIR="$INSTALLDIR/baseq2"
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
  echo "Run Vulkan:   quake2-vk"
  echo "Run Software: quake2-soft"
  echo ""
  if [ -f "$Q2DIR/pak0.pak" ]; then
    echo "Game data: $(ls "$Q2DIR"/*.pak 2>/dev/null | wc -l) pak file(s) found"
  else
    echo "WARNING: No pak files found!"
    echo "Copy pak0.pak (+ pak1.pak, pak2.pak) from retail Quake II to:"
    echo "  $Q2DIR/"
  fi
  echo ""
  echo "GPU: PowerVR BXM-4-64 — Vulkan 1.3"
else
  echo "ERROR: Build failed. Check output above."
fi
