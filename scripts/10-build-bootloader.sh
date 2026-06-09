#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export PATH="/usr/lib/ccache:/usr/lib/ccache/bin:$PATH"
export KBUILD_BUILD_USER=opencode
export KBUILD_BUILD_HOST=cubie-a7z-builder

BOARD=cubie_a7z
ARCH=arm
CROSS_COMPILE=arm-linux-gnueabi-

UBOOT_SRC=sources/u-boot-vendor
PACK_BIN=sources/orangepi-build/external/packages/pack-uboot/sun60iw2/bin
PACK_TOOLS=sources/orangepi-build/external/packages/pack-uboot/tools
BOARD_CFG=sources/allwinner-device/configs/cubie_a7z
BUILD_DIR=build/bootloader

log() { echo "[$(date -u +%FT%H:%M:%SZ)] ==> $*"; }

# Skip rebuild if bootloader already exists
if [ -f "$BUILD_DIR/boot0_stock.bin" ] && [ -f "$BUILD_DIR/boot_package.fex" ]; then
  log "Bootloader already built, skipping (rm -rf build/bootloader to force)"
  exit 0
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ---- Build U-Boot from source ----
# NOTE: vendor U-Boot DTS tooling uses $PWD-relative paths that break with
# make -C, so we pushd into the source tree instead.
log "Building U-Boot from source"
(
  cd "$UBOOT_SRC"
  make CROSS_COMPILE="$CROSS_COMPILE" distclean 2>&1 | cat
  make CROSS_COMPILE="$CROSS_COMPILE" sun60iw2p1_t736_defconfig 2>&1 | cat
  make CROSS_COMPILE="$CROSS_COMPILE" KCFLAGS="-Wno-error" -j"$(nproc)" 2>&1 | cat
)

U_BOOT_BIN="$UBOOT_SRC/u-boot.bin"
[ -f "$U_BOOT_BIN" ] || { log "ERROR: u-boot.bin not built"; exit 1; }
log "U-Boot built: $(stat -c%s "$U_BOOT_BIN") bytes"

# ---- Copy pack-uboot bin files into U-Boot source tree ----
log "Setting up boot packing environment"
cp -r "$PACK_BIN"/* "$UBOOT_SRC"/

# Use board-specific sys_config.fex (has correct 1800MT/s DRAM config)
cp "$BOARD_CFG/sys_config.fex" "$UBOOT_SRC/sys_config.fex"

# Copy U-Boot binary for packing
cp "$U_BOOT_BIN" "$UBOOT_SRC/u-boot.fex"

# Prepare board DTS
cp "$UBOOT_SRC/dts/u-boot-current.dts" "$UBOOT_SRC/dts/${BOARD}-u-boot.dts"

# ---- Compile board DTB ----
log "Compiling U-Boot DTB"
PACK_PATH=$(readlink -f "$PACK_TOOLS")
MAKE_J=$(nproc)
(
  cd "$UBOOT_SRC"
  "$PACK_PATH/dtc" -p 2048 -W no-unit_address_vs_reg -@ \
    -O dtb -o "${BOARD}-u-boot.dtb" -b 0 "dts/${BOARD}-u-boot.dts" 2>&1 | cat
)

[ -f "$UBOOT_SRC/${BOARD}-u-boot.dtb" ] || { log "ERROR: DTB not generated"; exit 1; }

# ---- Run boot packing tools ----
(
  cd "$UBOOT_SRC"

  log "Running fex script compiler"
  busybox unix2dos sys_config.fex 2>/dev/null
  "$PACK_PATH/script" sys_config.fex 2>&1

  log "Patching DTB into u-boot"
  cp "${BOARD}-u-boot.dtb" sunxi.fex
  "$PACK_PATH/update_dtb" sunxi.fex 4096 2>&1
  "$PACK_PATH/update_uboot" -no_merge u-boot.fex sys_config.bin 2>&1
  "$PACK_PATH/update_uboot" -no_merge u-boot.bin sys_config.bin 2>&1

  log "Packing boot_package.fex"
  busybox unix2dos boot_package.cfg 2>/dev/null
  "$PACK_PATH/dragonsecboot" -pack boot_package.cfg 2>&1
)

# Use stock boot0 extracted from Radxa official image (has correct DRAM init
# for Cubie A7Z LPDDR4X). The generic boot0 from allwinner-device does NOT boot.
# boot0_stock.bin is downloaded and verified by 00-fetch-sources.sh.
BOOT0_FILE="sources/boot0_stock.bin"
[ -f "$BOOT0_FILE" ] || { log "ERROR: boot0_stock.bin not found — run 'make fetch' first"; exit 1; }
BOOT0_FILE=$(readlink -f "$BOOT0_FILE")

log "Using boot0: $BOOT0_FILE"

# ---- Merge final bootloader image ----
(
  cd "$UBOOT_SRC"
  M="u-boot-${BOARD}-merged.bin"

  dd if=/dev/zero of="$M" bs=1M count=20 status=none conv=fsync
  # A733 BROM reads boot0 from sector 256 (128 KB offset)
  dd if="$BOOT0_FILE" of="$M" bs=512 seek=256 conv=fsync,notrunc status=none
  # boot_package at sector 24576 (12 MB offset)
  dd if=boot_package.fex of="$M" bs=512 seek=24576 conv=fsync,notrunc status=none

  log "Merged bootloader: $(stat -c%s "$M") bytes"
)

# ---- Copy artifacts to build directory ----
cp "$UBOOT_SRC/u-boot-${BOARD}-merged.bin" "$BUILD_DIR/"
cp "$UBOOT_SRC/boot_package.fex" "$BUILD_DIR/"
cp "$BOOT0_FILE" "$BUILD_DIR/boot0_stock.bin"
cp "$UBOOT_SRC/sys_config.bin" "$BUILD_DIR/"

log "Bootloader artifacts in $BUILD_DIR"
ls -lh "$BUILD_DIR"/
