#!/bin/bash
# Install Quake II (Yamagi Quake II — OpenGL ES / Vulkan)
# Run as root. Requires internet and ~200 MB disk space.
#
# Game data: you need the original Quake II pak files (pak0.pak, etc.)
# from a legal copy. The shareware demo pak0.pak is included automatically.

set -e
echo "=== Installing Quake II ==="
echo "Press Ctrl+C to cancel, Enter to continue..."
read -r

# Ensure GPU is configured
bash "$(dirname "$0")/setup-gpu.sh"

apt update
apt install -y --no-install-recommends \
  yamagi-quake2 \
  quake2-server \
  game-data-packager \
  wget unzip

# Download shareware demo data if no full game data present
Q2DIR="/usr/share/games/quake2/baseq2"
if [ ! -f "$Q2DIR/pak0.pak" ]; then
  echo "Downloading Quake II shareware demo..."
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  wget -q --show-progress -O q2-demo.zip \
    "https://deponie.yamagi.org/quake2/idstuff/q2-314-demo-x86.exe" 2>&1 || \
  wget -q --show-progress -O q2-demo.zip \
    "https://archive.org/download/quake-2-demo/q2-314-demo-x86.exe" 2>&1
  if [ -f q2-demo.zip ]; then
    unzip -o -j q2-demo.zip 'Install/Data/baseq2/*' -d extracted/ 2>/dev/null || \
    unzip -o -j q2-demo.zip '*/baseq2/*' -d extracted/ 2>/dev/null || true
    mkdir -p "$Q2DIR"
    cp extracted/pak0.pak "$Q2DIR/" 2>/dev/null || true
    cp extracted/*.pak "$Q2DIR/" 2>/dev/null || true
  fi
  cd /
  rm -rf "$TMPDIR"
fi

if [ -f "$Q2DIR/pak0.pak" ]; then
  echo "OK: pak0.pak found"
else
  echo "WARN: pak0.pak not found. Copy your Quake II game data to:"
  echo "  $Q2DIR/"
fi

echo ""
echo "=== Quake II installed ==="
echo ""
echo "Run (X11):     DISPLAY=:0 quake2"
echo "Run (Wayland): quake2  (from sway terminal)"
echo ""
echo "For full game: copy pak0.pak from retail Quake II to $Q2DIR/"
echo ""
echo "GPU: PowerVR BXM-4-64 — OpenGL ES 3.2, Vulkan 1.3"
