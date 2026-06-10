#!/bin/bash
# Setup Vulkan — PowerVR BXM-4-64 Vulkan 1.3 support.
# Run as root. Requires internet.
#
# PowerVR Vulkan supports:
#   - VK_KHR_xlib_surface, VK_KHR_xcb_surface (X11)
#   - Does NOT support VK_KHR_display (no Vulkan on KMSDRM)
#
# Used by: games/q2/install-vulkan.sh and any Vulkan X11 app.

set -e
echo "=== Setting up Vulkan ==="

# Ensure GPU is configured (ICD, LD_LIBRARY_PATH, etc.)
bash "$(dirname "$0")/setup-gpu.sh"

apt update
apt install -y --no-install-recommends \
  libvulkan1 \
  vulkan-tools

# Verify ICD
if [ ! -f /etc/vulkan/icd.d/pvr_icd.json ]; then
  mkdir -p /etc/vulkan/icd.d
  cat > /etc/vulkan/icd.d/pvr_icd.json << 'VKEOF'
{"file_format_version":"1.0.0","ICD":{"library_path":"/usr/lib/libVK_IMG.so","api_version":"1.3.0"}}
VKEOF
fi

echo ""
echo "=== Vulkan ready ==="
VK_ICD_FILENAMES=/etc/vulkan/icd.d/pvr_icd.json \
  LD_LIBRARY_PATH=/usr/local/lib vulkaninfo --summary 2>&1 | head -15 || true
echo ""
echo "Limitations:"
echo "  - Vulkan works under X11 only (VK_KHR_xlib_surface)"
echo "  - No Vulkan on KMSDRM (PVR ICD lacks VK_KHR_display)"
echo "  - For KMSDRM, use OpenGL ES 3.2 (gles3 renderer)"
