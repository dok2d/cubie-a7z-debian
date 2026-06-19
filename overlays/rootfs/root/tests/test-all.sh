#!/bin/bash
# Run all hardware tests
DIR=$(dirname "$0")
for t in wifi bt gpu npu hdmi usbc typec pcie spi i2c gpio thermal; do
  script="$DIR/test-$t.sh"
  [ -x "$script" ] || continue
  bash "$script"
  echo
done
