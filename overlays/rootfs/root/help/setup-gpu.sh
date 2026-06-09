#!/bin/bash
# Configure GPU acceleration for PowerVR BXM-4-64
# Called automatically by desktop install scripts.
# Can also be run standalone: bash /root/help/setup-gpu.sh

# PVR Mesa in /usr/local/lib/ needs LD_LIBRARY_PATH
if ! grep -q '/usr/local/lib' /etc/environment 2>/dev/null; then
  echo 'LD_LIBRARY_PATH=/usr/local/lib' >> /etc/environment
  echo "GPU: added LD_LIBRARY_PATH to /etc/environment"
fi

# Vulkan ICD
if [ ! -f /etc/vulkan/icd.d/pvr_icd.json ]; then
  mkdir -p /etc/vulkan/icd.d
  cat > /etc/vulkan/icd.d/pvr_icd.json << 'EOF'
{
    "file_format_version": "1.0.0",
    "ICD": {
        "library_path": "/usr/lib/libVK_IMG.so",
        "api_version": "1.3.0"
    }
}
EOF
  echo "GPU: added Vulkan ICD"
fi

# OpenCL ICD
if [ ! -f /etc/OpenCL/vendors/pvr.icd ]; then
  mkdir -p /etc/OpenCL/vendors
  echo '/usr/lib/libPVROCL.so' > /etc/OpenCL/vendors/pvr.icd
  echo "GPU: added OpenCL ICD"
fi

# Xorg glamor config (for X11 desktops)
if [ ! -f /etc/X11/xorg.conf.d/20-modesetting.conf ] || \
   ! grep -q 'glamor' /etc/X11/xorg.conf.d/20-modesetting.conf 2>/dev/null; then
  mkdir -p /etc/X11/xorg.conf.d
  cat > /etc/X11/xorg.conf.d/20-modesetting.conf << 'EOF'
Section "Device"
    Identifier  "Allwinner Graphics"
    Driver      "modesetting"
    Option      "kmsdev"        "/dev/dri/card0"
    Option      "AccelMethod"   "glamor"
    Option      "DRI"           "3"
EndSection
Section "Screen"
    Identifier  "Default Screen"
    Device      "Allwinner Graphics"
    Monitor     "Default Monitor"
    DefaultDepth 24
    SubSection "Display"
        Depth   24
    EndSubSection
EndSection
Section "Monitor"
    Identifier  "Default Monitor"
EndSection
EOF
  echo "GPU: configured Xorg glamor + DefaultDepth 24"
fi

# libxcb-dri2-0 needed by PVR Mesa EGL
dpkg -l libxcb-dri2-0 2>/dev/null | grep -q '^ii' || \
  apt install -y --no-install-recommends libxcb-dri2-0 2>/dev/null

# Rebuild ldconfig cache
ldconfig

echo "GPU: PowerVR BXM-4-64 acceleration configured."
echo "     OpenGL ES 3.2, Vulkan 1.3, OpenCL 3.0"
