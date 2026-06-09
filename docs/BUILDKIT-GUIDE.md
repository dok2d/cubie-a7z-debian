# Build Guide — Cubie A7Z Debian

## Overview

This repository contains scripts for building a bootable Debian arm64 image
for the Radxa Cubie A7Z single-board computer (Allwinner A733).

All third-party sources (kernel, U-Boot, drivers, firmware) are downloaded
automatically during the build from public repositories. Only our scripts,
configs, and DTS are stored in git.

## Host Requirements

- Debian 12+ or Ubuntu 22.04+ (x86_64)
- ~20 GB free disk space
- Internet access for downloading source repos (~8 GB)

### Installing Dependencies

```bash
sudo apt install -y \
  make git wget curl build-essential bc flex bison libssl-dev \
  gcc-arm-linux-gnueabi gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
  swig device-tree-compiler xxd busybox \
  debootstrap qemu-user-static binfmt-support \
  parted dosfstools e2fsprogs mtools xz-utils \
  u-boot-tools kmod cpio binutils
```

Or use Docker/Podman (recommended):

```bash
# Host prerequisite: qemu-user-static with binfmt_misc (needed for arm64 chroot)
sudo apt install qemu-user-static binfmt-support
sudo systemctl restart binfmt-support
# Verify: flags must contain "F"
cat /proc/sys/fs/binfmt_misc/qemu-aarch64

# Docker
docker build -t cubie-builder -f docker/Dockerfile.builder .
docker run --rm -v $(pwd):/work cubie-builder make all

# Podman (rootless)
podman build -t cubie-builder -f docker/Dockerfile.builder .
podman run --rm --user root -v .:/work:Z,exec cubie-builder make all
```

### Verify Dependencies

```bash
make deps
```

## Project Structure

```
├── config/
│   ├── board.cubie-a7z.env    # Repositories and pinned SHAs
│   ├── debian.env             # Debian rootfs configuration
│   └── dts/                   # Device Tree Source (ours, not vendor)
├── scripts/
│   ├── 00-fetch-sources.sh    # Download vendor sources
│   ├── 10-build-bootloader.sh # Build U-Boot + boot_package
│   ├── 20-build-kernel.sh     # Build kernel + WiFi + GPU + NPU
│   ├── 30-build-rootfs.sh     # Build root filesystem
│   ├── 40-assemble-image.sh   # Assemble final .img.xz
│   ├── 90-flash-sd.sh         # Write image to SD card
│   └── lib/common.sh          # Shared functions
├── patches/
│   ├── kernel/                # Kernel patches (git am)
│   └── u-boot/                # U-Boot patches (git am)
├── overlays/rootfs/           # Custom files copied into rootfs (tests, guides)
├── sources/                   # Downloaded vendor sources (gitignored)
├── build/                     # Build artifacts (gitignored)
└── docs/                      # Documentation
```

## Customization

Files in `overlays/rootfs/` are copied verbatim into the rootfs as the last
step before packaging. The directory structure mirrors the target filesystem:

```
overlays/rootfs/etc/motd              → /etc/motd
overlays/rootfs/root/my-script.sh     → /root/my-script.sh
```

The default overlay includes `/root/help/` (WiFi guide, desktop install scripts) and test scripts
in `/root/tests/`. Run `bash /root/tests/test-all.sh` on the board to verify.

## Full Build

```bash
make all
```

Or step by step:

```bash
make fetch         # Download vendor sources (~8 GB, ~5 min)
make bootloader    # Build U-Boot (~1 min)
make kernel        # Build kernel + WiFi + GPU + NPU (~15 min)
make rootfs        # Build root filesystem (~5 min)
make image         # Assemble final .img.xz (~5 min)
```

## Flashing to SD Card

```bash
sudo make flash DEV=/dev/sdX
```

Or manually:

```bash
xzcat build/cubie_a7z-trixie.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
sync
# boot0 and boot_package are written inside the image by assemble-image
```

**Important**: A733 BROM reads boot0 from sector 256 (128 KB), not sector 16!

## Configuration

### Vendor Sources

Repositories and commits are pinned in `config/board.cubie-a7z.env`:

| Repository | Purpose |
|------------|---------|
| orangepi-build | defconfig, pack-uboot tools |
| linux-orangepi | Vendor BSP kernel 6.6.98+ |
| u-boot-orangepi | U-Boot (brandy-2.0) |
| allwinner-bsp | Boot0, SCP, configs |
| allwinner-target | Firmware overlay (GPU, WiFi, Xorg) |
| allwinner-device | Board configs (sys_config.fex) |
| aic8800 | WiFi USB driver (radxa-pkg) |
| ai-sdk | NPU SDK (VIPLite v2.0) |

### Patches

Kernel and U-Boot patches go into `patches/kernel/` and `patches/u-boot/`.
Format: `git format-patch`. Applied automatically via `git am`
in lexical order after fetch.

### Device Tree

DTS is stored in `config/dts/sun60i-a733-cubie-a7z.dts` and copied
into the kernel tree during build. This is **our** DTS, not vendor.

## Reproducibility

- All vendor sources are pinned to specific commit SHAs
- Patches are applied deterministically
- Debian packages are downloaded from a stable mirror
- Docker/Podman ensures a consistent build environment

## Known Quirks

- `dpkg-deb -x` does not resolve dependencies — shared libs are added manually
  (see `docs/rootfs-dependency-map.md`)
- GPU module (pvrsrvkm) is built out-of-tree, requires `/gcc` symlink to cross-compiler
- UFS may be absent on some SKUs (dmesg errors are normal)
- First boot: `first-boot-resize` expands rootfs to full SD card size
