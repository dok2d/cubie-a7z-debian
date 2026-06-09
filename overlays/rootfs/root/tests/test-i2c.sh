#!/bin/bash
# I2C test — bus 0 (TWI0), bus 13 (S_TWI0/PMIC), bus 14 (S_TWI1/TCPC)
echo "=== I2C ==="
buses=$(ls -d /sys/bus/i2c/devices/i2c-* 2>/dev/null | wc -l)
echo "Buses: $buses"
command -v i2cdetect &>/dev/null || { echo "WARN: i2cdetect not installed"; exit 0; }
for bus in 0 13; do
  [ -e "/dev/i2c-$bus" ] || continue
  echo "--- i2c-$bus ---"
  i2cdetect -y "$bus" 2>/dev/null
done
echo "--- i2c-14: skipped (ET7304Y TCPC — scan causes TWI errors) ---"
