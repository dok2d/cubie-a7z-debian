#!/bin/bash
# Install Quake II — X11 + Vulkan (vkQuake2 by kondrak).
# Requires a running X11 desktop (XFCE, i3, LXQt, etc.).
# Run as root. Requires internet.

set -e
source "$(dirname "$0")/_common.sh"

INSTALLDIR=/opt/quake2
Q2DIR="$INSTALLDIR/baseq2"

if [ -f "$INSTALLDIR/quake2" ] && [ -f "$Q2DIR/pak0.pak" ]; then
  echo "Quake II (Vulkan/X11) already installed."
  echo "Run: quake2-vk"
  exit 0
fi

echo "=== Installing Quake II (Vulkan + X11) ==="
echo "Builds vkQuake2 (kondrak) from source."
echo "Requires a desktop environment (XFCE, i3, LXQt, sway, labwc)."
echo "Press Ctrl+C to cancel, Enter to continue..."
read -r

# Setup Vulkan + GPU
bash "$HELPDIR/setup-vulkan.sh"

# Build dependencies
apt install -y --no-install-recommends \
  git build-essential cmake \
  libvulkan-dev libsdl2-dev libcurl4-openssl-dev \
  libxxf86dga-dev libx11-dev libxext-dev libxxf86vm-dev \
  libglu1-mesa-dev wget unzip

# Build vkQuake2
BUILDDIR=/tmp/vkquake2-build
rm -rf "$BUILDDIR"
echo "Cloning vkQuake2..."
git clone --depth 1 https://github.com/kondrak/vkQuake2.git "$BUILDDIR"
echo "Building..."
cd "$BUILDDIR/linux"
make -j$(nproc) 2>&1 | tail -5

# Install
mkdir -p "$INSTALLDIR/baseq2"
for f in quake2 ref_vk.so ref_gl.so ref_soft.so; do
  find "$BUILDDIR/linux" -name "$f" -exec cp {} "$INSTALLDIR/" \; 2>/dev/null
done
find "$BUILDDIR/linux" -name "game.so" -exec cp {} "$Q2DIR/" \; 2>/dev/null
chmod +x "$INSTALLDIR/quake2" 2>/dev/null

# Launchers
cat > /usr/local/bin/quake2-vk << 'LAUNCHER'
#!/bin/bash
export LD_LIBRARY_PATH=/usr/local/lib:/opt/quake2
export VK_ICD_FILENAMES=/etc/vulkan/icd.d/pvr_icd.json
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

# Desktop entries (visible in XFCE, LXQt, i3+dmenu, sway+wmenu)
create_desktop_entry "Quake II (Vulkan)" "vkQuake2 Vulkan 1.3 on PowerVR" \
  "quake2-vk" "quake2-vk" "false"

download_shareware "$Q2DIR"
rm -rf "$BUILDDIR"

echo ""
if [ -f "$INSTALLDIR/quake2" ]; then
  echo "=== Quake II (Vulkan/X11) installed ==="
  echo ""
  echo "Vulkan:   quake2-vk"
  echo "Software: quake2-soft"
  echo "Desktop:  Quake II in application menu"
  echo ""
  print_game_status "$INSTALLDIR"
  echo ""
  echo "GPU: PowerVR BXM-4-64 — Vulkan 1.3"
else
  echo "ERROR: Build failed."
fi
