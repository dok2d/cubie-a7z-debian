#!/bin/bash
# GPU test — PowerVR BXM-4-64
echo "=== GPU ==="
lsmod | grep -q pvrsrvkm && echo "OK: pvrsrvkm loaded" || echo "FAIL: pvrsrvkm not loaded"
[ -e /dev/dri/renderD128 ] && echo "OK: /dev/dri/renderD128" || echo "FAIL: renderD128 missing"
if [ -d /sys/kernel/debug/pvr ]; then
  echo "--- PVR debug ---"
  cat /sys/kernel/debug/pvr/status 2>/dev/null | head -5
fi
