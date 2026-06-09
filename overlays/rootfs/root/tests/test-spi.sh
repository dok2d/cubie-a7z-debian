#!/bin/bash
# SPI test — SPI1 on 40-pin header (PD10-PD13)
echo "=== SPI ==="
if ls /dev/spidev* &>/dev/null; then
  echo "OK: $(ls /dev/spidev*)"
  echo "Loopback test: short MOSI (pin 19) to MISO (pin 21), then:"
  echo "  echo -ne '\\x55\\xAA' | spi-pipe -d /dev/spidev1.0 -s 1000000 | xxd"
else
  echo "FAIL: no /dev/spidev*"
fi
