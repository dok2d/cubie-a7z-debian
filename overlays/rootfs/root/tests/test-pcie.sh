#!/bin/bash
# PCIe test — Gen3 x1 FPC connector J3
echo "=== PCIe ==="
if [ -d /sys/bus/pci ]; then
  devs=$(lspci 2>/dev/null)
  cnt=$(echo "$devs" | grep -c . || echo 0)
  echo "Devices: $cnt"
  echo "$devs"
  [ "$cnt" -le 1 ] && echo "INFO: only root port visible — plug NVMe via M.2 FPC adapter"
else
  echo "FAIL: no PCIe bus"
fi
