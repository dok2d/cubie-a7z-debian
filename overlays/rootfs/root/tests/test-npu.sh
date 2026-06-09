#!/bin/bash
# NPU test — VeriSilicon VIP9000
echo "=== NPU ==="
lsmod | grep -q vipcore && echo "OK: vipcore loaded" || { echo "FAIL: vipcore not loaded"; exit 1; }
[ -e /dev/vipcore ] && echo "OK: /dev/vipcore" || { echo "FAIL: /dev/vipcore missing"; exit 1; }
command -v vpm_run &>/dev/null || { echo "FAIL: vpm_run not installed"; exit 1; }
NB=$(find /usr/share/npu/models -name 'resnet50.nb' 2>/dev/null | head -1)
[ -z "$NB" ] && { echo "WARN: no resnet50.nb model"; exit 0; }
TMP=$(mktemp -d)
dd if=/dev/zero of="$TMP/input.dat" bs=150528 count=1 status=none
cat > "$TMP/sample.txt" << EOF
[network]
$NB
[input]
$TMP/input.dat
EOF
echo "Running ResNet50 inference (zero input)..."
out=$(vpm_run -s "$TMP/sample.txt" -b 1 2>&1)
rc=$?
rm -rf "$TMP"
if [ $rc -eq 0 ]; then
  echo "OK: inference passed (rc=0)"
  echo "$out" | grep -iE 'time|cost|ms' | head -3
else
  echo "FAIL: inference failed (rc=$rc)"
  echo "$out" | tail -5
fi
