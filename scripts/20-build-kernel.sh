#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export PATH="/usr/lib/ccache:/usr/lib/ccache/bin:$PATH"
export KBUILD_BUILD_USER=opencode
export KBUILD_BUILD_HOST=cubie-a7z-builder

BOARD=cubie_a7z
ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-
KERNEL_SRC=sources/kernel
KERNEL_CONFIG=sources/orangepi-build/external/config/kernel/linux-sun60iw2-current-a733.config
# Use our customized DTS (committed), not vendor original (gitignored)
BOARD_DTS=config/dts/sun60i-a733-cubie-a7z.dts
BUILD_KERNEL=build/kernel
BUILD_MODULES=build/modules

KERNEL_IMAGE=vmlinuz-6.6.98-$BOARD
INITRD_IMAGE=initrd.img-6.6.98-$BOARD

log() { echo "[$(date -u +%FT%H:%M:%SZ)] ==> $*"; }

KERNEL_RELEASE=6.6.98+
DTS_NAME="sun60i-a733-cubie-a7z"

# Skip rebuild if kernel Image already exists (use make clean to force)
if [ -f "$BUILD_KERNEL/vmlinuz-6.6.98-cubie_a7z" ] && \
   [ -f "$BUILD_KERNEL/${DTS_NAME}.dtb" ] && \
   [ -d "$BUILD_MODULES/lib/modules/$KERNEL_RELEASE" ]; then
  log "Kernel already built, skipping (rm -rf build/kernel to force rebuild)"
  exit 0
fi

rm -rf "$BUILD_KERNEL" "$BUILD_MODULES"
mkdir -p "$BUILD_KERNEL" "$BUILD_MODULES"

log "Preparing kernel source"
# Use mrproper instead of distclean — distclean hangs on vendor BSP wireless
# drivers (atbm6023is). mrproper cleans config + generated files without
# recursing into bsp/drivers/net/wireless/.
make -C "$KERNEL_SRC" CROSS_COMPILE="$CROSS_COMPILE" ARCH="$ARCH" mrproper 2>&1 | tail -5

# Copy board DTS into kernel tree
cp "$BOARD_DTS" "$KERNEL_SRC/arch/arm64/boot/dts/allwinner/${DTS_NAME}.dts"

# Register DTS in kernel Makefile (insert before the last entry)
sed -i "/${DTS_NAME}/d" "$KERNEL_SRC/arch/arm64/boot/dts/allwinner/Makefile"
sed -i "/^dtb-.*CONFIG_ARCH_SUNXI.*orangepi-zero3w/a dtb-\$(CONFIG_ARCH_SUNXI) += ${DTS_NAME}.dtb" \
  "$KERNEL_SRC/arch/arm64/boot/dts/allwinner/Makefile"

# Build kernel config
log "Configuring kernel"
cp "$KERNEL_CONFIG" "$KERNEL_SRC/.config"

# Enable USB-C TCPC (ET7304) and DP Alt Mode — not in orangepi defconfig
cat >> "$KERNEL_SRC/.config" <<'TYPEC_FRAGMENT'
# USB-C PD / DP Alt Mode via ET7304 TCPC (rt1711h driver)
CONFIG_TYPEC=y
CONFIG_TYPEC_TCPM=y
CONFIG_TYPEC_TCPCI=y
CONFIG_TYPEC_RT1711H=y
CONFIG_TYPEC_DP_ALTMODE=y
CONFIG_USB_ROLE_SWITCH=y
TYPEC_FRAGMENT

( yes "" || true ) | make -C "$KERNEL_SRC" CROSS_COMPILE="$CROSS_COMPILE" ARCH="$ARCH" olddefconfig 2>&1 | tail -5

log "Building kernel Image and DTBs"
make -C "$KERNEL_SRC" CROSS_COMPILE="$CROSS_COMPILE" ARCH="$ARCH" \
  -j"$(nproc)" Image dtbs 2>&1 | cat

# Verify outputs
[ -f "$KERNEL_SRC/arch/arm64/boot/Image" ] || { log "ERROR: kernel Image not built"; exit 1; }
[ -f "$KERNEL_SRC/arch/arm64/boot/dts/allwinner/${DTS_NAME}.dtb" ] || {
  log "ERROR: ${DTS_NAME}.dtb not built"; exit 1; }

log "Building kernel modules"
make -C "$KERNEL_SRC" CROSS_COMPILE="$CROSS_COMPILE" ARCH="$ARCH" \
  -j"$(nproc)" modules 2>&1 | cat

log "Installing kernel modules"
make -C "$KERNEL_SRC" CROSS_COMPILE="$CROSS_COMPILE" ARCH="$ARCH" \
  INSTALL_MOD_PATH="$(realpath "$BUILD_MODULES")" modules_install 2>&1 | cat

# Copy kernel artifacts to build directory
cp "$KERNEL_SRC/arch/arm64/boot/Image" "$BUILD_KERNEL/$KERNEL_IMAGE"
cp "$KERNEL_SRC/arch/arm64/boot/dts/allwinner/${DTS_NAME}.dtb" "$BUILD_KERNEL/"
cp "$KERNEL_SRC/.config" "$BUILD_KERNEL/config-6.6.98-$BOARD"
cp "$KERNEL_SRC/System.map" "$BUILD_KERNEL/System.map-6.6.98-$BOARD"

# Create kernel release string
KERNEL_RELEASE=$(make -C "$KERNEL_SRC" CROSS_COMPILE="$CROSS_COMPILE" ARCH="$ARCH" \
  -s kernelrelease 2>/dev/null)
echo "$KERNEL_RELEASE" > "$BUILD_KERNEL/kernelrelease"

# ---- Build out-of-tree WiFi driver (radxa-pkg/aic8800, USB variant) ----
AIC8800_DRV="$(pwd)/sources/aic8800/src/USB/driver_fw/drivers/aic8800"
if [ -d "$AIC8800_DRV" ]; then
  log "Building AIC8800 WiFi driver (radxa USB)"
  make -C "$KERNEL_SRC" M="$AIC8800_DRV" \
    ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
    CONFIG_AIC_LOADFW_SUPPORT=m CONFIG_AIC8800_WLAN_SUPPORT=m \
    modules 2>&1 | cat
  AIC_MODDIR="$BUILD_MODULES/lib/modules/$KERNEL_RELEASE/extra"
  mkdir -p "$AIC_MODDIR"
  ${CROSS_COMPILE}strip --strip-debug \
    "$AIC8800_DRV/aic_load_fw/aic_load_fw.ko" -o "$AIC_MODDIR/aic_load_fw.ko"
  ${CROSS_COMPILE}strip --strip-debug \
    "$AIC8800_DRV/aic8800_fdrv/aic8800_fdrv.ko" -o "$AIC_MODDIR/aic8800_fdrv.ko"
  log "  WiFi: aic_load_fw.ko + aic8800_fdrv.ko"
else
  log "WARN: AIC8800 source not found at $AIC8800_DRV"
fi

# ---- Build out-of-tree GPU driver (PowerVR pvrsrvkm) ----
GPU_BUILD="$KERNEL_SRC/bsp/modules/gpu/img-bxm/linux/rogue_km/build/linux/sunxi_linux"
GPU_KO="$KERNEL_SRC/bsp/modules/gpu/img-bxm/linux/rogue_km/binary_sunxi_linux_nulldrmws_release/target_aarch64/kbuild/pvrsrvkm.ko"
if [ -d "$GPU_BUILD" ]; then
  log "Building GPU module (pvrsrvkm)"
  # GPU Makefile constructs CC as $(LICHEE_TOOLCHAIN_PATH)/$(LICHEE_CROSS_COMPILER)gcc.
  # Both are empty by default → CC=/gcc → not found.
  # LICHEE_TOOLCHAIN_PATH = directory containing the toolchain binaries
  # LICHEE_CROSS_COMPILER = prefix before "gcc" (e.g. "aarch64-linux-gnu-")
  export LICHEE_TOOLCHAIN_PATH="$(dirname "$(which ${CROSS_COMPILE}gcc)")/"
  export LICHEE_CROSS_COMPILER="$CROSS_COMPILE"

  # GNU Make 4.4+ rejects .SECONDARY when kernel uses .NOTINTERMEDIATE.
  # Patch it out of the GPU kbuild template (vendor code, not upstreamable).
  sed -i 's/^\.SECONDARY.*//g' \
    "$KERNEL_SRC/bsp/modules/gpu/img-bxm/linux/rogue_km/build/linux/kbuild/Makefile.template" \
    "$KERNEL_SRC/bsp/modules/gpu/img-bxm/linux/rogue_km/build/linux/toplevel.mk" \
    "$KERNEL_SRC/bsp/modules/gpu/img-bxm/linux/rogue_km/build/linux/defs.mk" \
    2>/dev/null || true

  make -C "$GPU_BUILD" \
    ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
    KERNELDIR="$(pwd)/$KERNEL_SRC" BUILD=release \
    -j"$(nproc)" 2>&1 | tail -20
  if [ -f "$GPU_KO" ]; then
    GPU_MODDIR="$BUILD_MODULES/lib/modules/$KERNEL_RELEASE/extra"
    mkdir -p "$GPU_MODDIR"
    ${CROSS_COMPILE}strip --strip-debug "$GPU_KO" -o "$GPU_MODDIR/pvrsrvkm.ko"
    log "  GPU: pvrsrvkm.ko"
  else
    log "WARN: pvrsrvkm.ko not built"
  fi
else
  log "WARN: GPU build dir not found at $GPU_BUILD"
fi

# ---- Build NPU inference tool (vpm_run from ai-sdk) ----
AI_SDK="$(pwd)/sources/ai-sdk"
if [ -d "$AI_SDK/examples/vpm_run" ]; then
  log "Building vpm_run (NPU inference tool)"
  make -C "$AI_SDK/examples/vpm_run" CC=${CROSS_COMPILE}gcc AI_SDK_PLATFORM=a733 2>&1 | cat
  if [ -f "$AI_SDK/examples/vpm_run/vpm_run" ]; then
    mkdir -p "$BUILD_KERNEL/npu"
    cp "$AI_SDK/examples/vpm_run/vpm_run" "$BUILD_KERNEL/npu/"
    log "  NPU: vpm_run"
  fi
else
  log "WARN: ai-sdk not found at $AI_SDK"
fi

log "Kernel build complete: $KERNEL_RELEASE"
log "  Image: $BUILD_KERNEL/$KERNEL_IMAGE ($(stat -c%s "$BUILD_KERNEL/$KERNEL_IMAGE") bytes)"
log "  DTB:   $BUILD_KERNEL/${DTS_NAME}.dtb ($(stat -c%s "$BUILD_KERNEL/${DTS_NAME}.dtb") bytes)"
log "  Modules: $BUILD_MODULES/lib/modules/$KERNEL_RELEASE/"
