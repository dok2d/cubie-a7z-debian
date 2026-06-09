#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
DEFAULT_IMAGE="$SCRIPT_DIR/../build/cubie_a7z-trixie.img.xz"

# Load config for credentials display
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh" 2>/dev/null || true

# Parse arguments
DEVICE=""
IMAGE=""
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    -h|--help) DEVICE="" ; break ;;
    /dev/*) DEVICE="$arg" ;;
    *) IMAGE="$arg" ;;
  esac
done

IMAGE="${IMAGE:-$DEFAULT_IMAGE}"

if [ -z "$DEVICE" ]; then
  echo "Usage: $0 <sd-device> [image-file] [--force]"
  echo ""
  echo "Flash a Cubie A7Z Debian image to an SD card."
  echo ""
  echo "  <sd-device>   Block device, e.g. /dev/sdb or /dev/mmcblk0"
  echo "  [image-file]  Path to .img.xz file (default: build/cubie_a7z-trixie.img.xz)"
  echo "  --force       Override removable device check (DANGEROUS)"
  echo ""
  echo "Example:"
  echo "  $0 /dev/sdb"
  echo "  $0 /dev/sdd path/to/image.img.xz"
  exit 1
fi

# Must run as root (blockdev, dd, partition access)
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: this script must be run as root."
  echo "  sudo $0 $*"
  exit 1
fi

# Validate device exists
if [ ! -b "$DEVICE" ]; then
  echo "Error: $DEVICE is not a block device"
  exit 1
fi

# Safety: refuse to write to non-removable devices (NVMe, SSD, HDD)
DEV_NAME=$(basename "$DEVICE")
REMOVABLE=$(cat "/sys/block/$DEV_NAME/removable" 2>/dev/null || echo "?")
if [ "$REMOVABLE" != "1" ]; then
  if $FORCE; then
    echo "WARNING: $DEVICE is not removable (removable=$REMOVABLE), proceeding with --force"
  else
    echo "Error: $DEVICE is not a removable device (removable=$REMOVABLE)"
    echo "This script only writes to SD cards / USB drives."
    echo "Use --force to override (DANGEROUS)."
    exit 1
  fi
fi

# Check device has media inserted
DEV_SIZE=$(blockdev --getsize64 "$DEVICE" 2>/dev/null || echo 0)
if [ "$DEV_SIZE" -eq 0 ]; then
  echo "Error: $DEVICE has size 0 — no media inserted?"
  exit 1
fi

# Validate image exists
if [ ! -f "$IMAGE" ]; then
  echo "Error: image file not found: $IMAGE"
  echo "Run scripts/40-assemble-image.sh first."
  exit 1
fi

# Check device is large enough for uncompressed image
IMG_SIZE=$(xz --robot --list "$IMAGE" 2>/dev/null | awk '/^totals/{print $5}' || echo 0)
if [ "$IMG_SIZE" -gt 0 ] && [ "$DEV_SIZE" -lt "$IMG_SIZE" ]; then
  echo "Error: $DEVICE ($(numfmt --to=iec "$DEV_SIZE")) is smaller than image ($(numfmt --to=iec "$IMG_SIZE"))"
  exit 1
fi

# Check if device is mounted
MOUNTS=$(grep "$DEVICE" /proc/mounts 2>/dev/null || true)
if [ -n "$MOUNTS" ]; then
  echo "Error: $DEVICE has mounted partitions. Unmount them first."
  echo "$MOUNTS"
  exit 1
fi

# boot0 and boot_package are already inside the image (written by 40-assemble-image.sh).
# No need to write them separately.

# Show block devices for verification
echo "Connected block devices:"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS 2>/dev/null || lsblk
echo ""
echo "Device:  $DEVICE ($(numfmt --to=iec "$DEV_SIZE"))"
echo "Image:   $IMAGE ($(du -h "$IMAGE" | cut -f1))"
echo ""
echo "Commands to execute:"
echo "  1) xzcat $IMAGE | dd of=$DEVICE bs=4M iflag=fullblock status=progress"
echo "  2) sync"
echo "  3) fsck.ext4 -n ${DEVICE}2"
echo ""
echo "WARNING: ALL DATA on $DEVICE will be DESTROYED!"
read -rp "Type 'yes' to continue: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

echo ""
echo "[1/3] Writing image..."
xzcat "$IMAGE" | dd of="$DEVICE" bs=4M status=progress iflag=fullblock conv=fsync

echo "[2/3] sync"
sync
blockdev --rereadpt "$DEVICE" 2>/dev/null || true

echo "[3/3] Checking filesystem..."
fsck.ext4 -n "${DEVICE}2" 2>/dev/null || fsck.ext4 -n "${DEVICE}p2" 2>/dev/null || true

echo ""
echo "SD card is ready. Insert into Cubie A7Z and boot."
echo "Default login: ${DEFAULT_USER:-cubie} / ${DEFAULT_PASSWORD:-cubie} (or root / ${ROOT_PASSWORD:-cubie})"
