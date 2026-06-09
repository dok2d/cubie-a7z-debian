#!/bin/bash
# GPU demo — renders on HDMI via PowerVR BXM-4-64
# Requires: glmark2-es2 (OpenGL ES) or vkcube (Vulkan)
echo "=== GPU Demo ==="

export LD_LIBRARY_PATH=/usr/local/lib

# Check GPU is working
if ! grep -q 'glamor.*initialized' /var/log/Xorg.0.log 2>/dev/null; then
  echo "WARN: glamor not initialized — is X running with AccelMethod glamor?"
fi

# GLES2 benchmark (glamor + EGL)
if command -v glmark2-es2 &>/dev/null; then
  echo "--- glmark2-es2 (OpenGL ES 2.0, 10 seconds) ---"
  DISPLAY=:0 glmark2-es2 --run-forever --off-screen -d 10 2>&1 | tail -5
elif command -v glmark2 &>/dev/null; then
  echo "--- glmark2 (10 seconds) ---"
  DISPLAY=:0 glmark2 --run-forever --off-screen -d 10 2>&1 | tail -5
else
  echo "glmark2 not installed. Install:"
  echo "  apt install glmark2-es2"
  echo ""
  echo "Installing now..."
  apt install -y --no-install-recommends glmark2-es2 2>&1 | tail -3
  if command -v glmark2-es2 &>/dev/null; then
    echo ""
    echo "--- glmark2-es2 (OpenGL ES 2.0, on HDMI) ---"
    DISPLAY=:0 glmark2-es2 2>&1 | tail -10
  fi
fi

echo ""

# Vulkan test
if command -v vkcube &>/dev/null; then
  echo "--- vkcube (Vulkan 1.3, 5 seconds on HDMI) ---"
  timeout 5 DISPLAY=:0 vkcube 2>&1 | tail -3
  echo "OK: vkcube ran"
else
  echo "vkcube not installed. Install: apt install vulkan-tools"
fi

echo ""

# Show GPU info summary
echo "--- GPU Summary ---"
eglinfo 2>/dev/null | grep -E 'vendor|version|renderer|client API' | head -5
vulkaninfo --summary 2>/dev/null | grep -E 'deviceName|driverName|apiVersion' | head -3
