#!/bin/bash
# Thermal sensors
echo "=== Thermal ==="
for tz in /sys/class/thermal/thermal_zone*; do
  [ -e "$tz/type" ] || continue
  type=$(cat "$tz/type")
  temp=$(cat "$tz/temp" 2>/dev/null)
  [ -n "$temp" ] && printf "%-20s %d C\n" "$type" "$((temp/1000))" \
                  || printf "%-20s N/A\n" "$type"
done
