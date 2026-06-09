#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

BOARD=cubie_a7z
RELEASE=trixie
ROOTFS_DIR=build/rootfs
ROOTFS_TAR=build/rootfs-${BOARD}-${RELEASE}.tar
IMAGE_FILE=build/${BOARD}-${RELEASE}.img
IMAGE_SIZE=${IMAGE_SIZE:-3800M}

BOOT0=build/bootloader/boot0_stock.bin
[ -f "$BOOT0" ] || { echo "ERROR: no boot0_stock.bin in build/bootloader/"; exit 1; }
BOOT_PACKAGE=build/bootloader/boot_package.fex
KERNEL_RELEASE=6.6.98+
KERNEL_DIR=build/kernel

# Partition layout (512-byte sectors)
# A733 BROM reads boot0 from sector 256 (128 KB), NOT sector 16!
BOOT0_START=256
BOOT_PACKAGE_START=24576
BOOT_PART_START=69632   # 34 MB
ROOT_PART_START=593920  # 290 MB
BOOT_PART_SIZE=524288   # 256 MB

log() { echo "[$(date +%FT%H:%M:%SZ)] ==> $*"; }

rm -f "$IMAGE_FILE" "${IMAGE_FILE}.xz"
log "Creating blank image: $IMAGE_SIZE"
truncate -s "$IMAGE_SIZE" "$IMAGE_FILE"

log "Creating MBR partition table (boot0 at sector 16 conflicts with GPT)"
parted -s "$IMAGE_FILE" mklabel msdos
parted -s "$IMAGE_FILE" unit s mkpart primary fat32 \
  ${BOOT_PART_START} $((BOOT_PART_START + BOOT_PART_SIZE - 1))
parted -s "$IMAGE_FILE" set 1 boot on
parted -s "$IMAGE_FILE" unit s mkpart primary ext4 ${ROOT_PART_START} 100%

log "Writing bootloader"
# boot0 at sector 256 (128 KiB) — A733 BROM reads from this position
dd if="$BOOT0" of="$IMAGE_FILE" bs=512 seek=$BOOT0_START conv=notrunc status=none
# boot_package at sector 24576 (12 MiB) — boot0 loads U-Boot from here
dd if="$BOOT_PACKAGE" of="$IMAGE_FILE" bs=512 seek=$BOOT_PACKAGE_START conv=notrunc status=none

# Verify boot0 magic (should be "eGON.BT0")
BOOT0_MAGIC=$(dd if="$IMAGE_FILE" bs=512 skip=$BOOT0_START count=1 2>/dev/null | strings | head -1)
echo "Boot0: $BOOT0_MAGIC"

# Read partition offsets from the image
log "Reading partition offsets"
BOOT_OFFSET=$(parted -s "$IMAGE_FILE" unit B print | awk '/^ 1 / {print $2}' | tr -d 'B')
BOOT_SIZE=$(parted -s "$IMAGE_FILE" unit B print | awk '/^ 1 / {print $4}' | tr -d 'B')
ROOT_OFFSET=$(parted -s "$IMAGE_FILE" unit B print | awk '/^ 2 / {print $2}' | tr -d 'B')
ROOT_SIZE=$(parted -s "$IMAGE_FILE" unit B print | awk '/^ 2 / {print $4}' | tr -d 'B')
BOOT_SECTORS=$((BOOT_OFFSET / 512))
ROOT_BLOCKS=$((ROOT_SIZE / 4096))

log "Boot: offset=$BOOT_OFFSET size=$BOOT_SIZE"
log "Root: offset=$ROOT_OFFSET size=$ROOT_SIZE (${ROOT_BLOCKS} blocks)"

# Format boot partition (FAT32)
log "Formatting boot partition (FAT32)"
mkfs.vfat -F 32 -n BOOT "$IMAGE_FILE" --offset=$BOOT_SECTORS 2>&1 | cat

# Get boot UUID
BOOT_UUID=$(blkid -p -o value -s UUID --offset $BOOT_OFFSET "$IMAGE_FILE")
log "Boot UUID: $BOOT_UUID"

# Populate root partition by extracting tarball and creating fs from directory
log "Populating rootfs"
rm -rf /tmp/rootfs-populate
mkdir -p /tmp/rootfs-populate
tar xpf "$ROOTFS_TAR" -C /tmp/rootfs-populate 2>&1 | cat

# Create ext4 as standalone file first, then dd into image.
# mke2fs -E offset= corrupts the journal when writing inline.
# Size to rootfs content + 30% overhead. Pre-allocate to avoid sparse file issues
# on nearly full host disks. first-boot-resize expands to full partition on target.
ROOTFS_SIZE_MB=$(( $(du -sm /tmp/rootfs-populate | cut -f1) * 130 / 100 ))
log "Rootfs ext4: ${ROOTFS_SIZE_MB}MB (content + 30%)"
dd if=/dev/zero of=/tmp/rootfs.ext4 bs=1M count=$ROOTFS_SIZE_MB status=none
mke2fs -F -t ext4 -L rootfs -d /tmp/rootfs-populate \
  /tmp/rootfs.ext4 2>&1 | cat

# fstab uses /dev/mmcblk0p* (not UUID) — no need to patch it here.
# UUID-based fstab broke boot when FAT UUID changed after dd.

# Write ext4 into image at root partition offset
log "Writing rootfs to image"
dd if=/tmp/rootfs.ext4 of="$IMAGE_FILE" bs=1M seek=$((ROOT_OFFSET / 1048576)) conv=notrunc status=progress 2>&1 | cat
rm -f /tmp/rootfs.ext4

rm -rf /tmp/rootfs-populate

# Populate boot partition (FAT32) via mtools
log "Populating boot partition"
export MTOOLSRC=/tmp/mtools-$$-rc
cat > "$MTOOLSRC" << EOF
drive x: file="$IMAGE_FILE" offset=$BOOT_OFFSET
EOF

MTOOLSRC="$MTOOLSRC" mcopy "$KERNEL_DIR/vmlinuz-6.6.98-$BOARD" x:/vmlinuz-6.6.98+
MTOOLSRC="$MTOOLSRC" mcopy "$KERNEL_DIR/sun60i-a733-cubie-a7z.dtb" x:/

# Boot scripts (extract from rootfs tarball)
mkdir -p /tmp/boot-files
tar xpf "$ROOTFS_TAR" -C /tmp/boot-files ./boot/boot.cmd ./boot/boot.scr ./boot/extlinux/extlinux.conf 2>/dev/null || true

if [ -f /tmp/boot-files/boot/boot.scr ]; then
  MTOOLSRC="$MTOOLSRC" mcopy /tmp/boot-files/boot/boot.scr x:/
  MTOOLSRC="$MTOOLSRC" mcopy /tmp/boot-files/boot/boot.cmd x:/
  MTOOLSRC="$MTOOLSRC" mmd x:/extlinux 2>/dev/null || true
  MTOOLSRC="$MTOOLSRC" mcopy /tmp/boot-files/boot/extlinux/extlinux.conf x:/extlinux/
fi

rm -rf /tmp/boot-files
rm -f "$MTOOLSRC"

# Compress final image
log "Compressing image (this may take a while)"
xz -T0 -9 "$IMAGE_FILE" 2>&1 | cat

FINAL="${IMAGE_FILE}.xz"
log "Done: $FINAL ($(stat -c%s "$FINAL") bytes)"
log "To flash: xzcat $FINAL | dd of=/dev/sdX bs=4M status=progress"
