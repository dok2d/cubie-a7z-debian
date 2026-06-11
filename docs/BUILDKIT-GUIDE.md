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
- Internet access for downloading source repos (~8 GB on first build)
- x86_64 only — vendor pack tools (dragonsecboot, script, update_dtb) are x86 binaries

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
# Verify: flags must contain "F" (fix-binary)
cat /proc/sys/fs/binfmt_misc/qemu-aarch64

# Docker
docker build -t cubie-builder -f docker/Dockerfile.builder .
docker run --rm -v $(pwd):/work cubie-builder make all

# Podman (rootless)
podman build -t cubie-builder -f docker/Dockerfile.builder .
podman run --rm --privileged --user root -v .:/work:Z cubie-builder make all
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

The default overlay includes `/root/help/` (WiFi guide, desktop install scripts,
game installers, GPU/Vulkan setup) and test scripts in `/root/tests/`.
Run `bash /root/tests/test-all.sh` on the board to verify hardware.

---

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

---

## Configuration

### Vendor Sources

Repositories and commits are pinned in `config/board.cubie-a7z.env`:

| Repository | URL | Purpose |
|------------|-----|---------|
| orangepi-build | [orangepi-xunlong/orangepi-build](https://github.com/orangepi-xunlong/orangepi-build) | defconfig, pack-uboot tools |
| linux-orangepi | [orangepi-xunlong/linux-orangepi](https://github.com/orangepi-xunlong/linux-orangepi) | BSP kernel 6.6.98+ |
| u-boot-orangepi | [orangepi-xunlong/u-boot-orangepi](https://github.com/orangepi-xunlong/u-boot-orangepi) | U-Boot (brandy-2.0) |
| allwinner-bsp | [radxa/allwinner-bsp](https://github.com/radxa/allwinner-bsp) | Boot0, SCP firmware |
| allwinner-target | [radxa/allwinner-target](https://github.com/radxa/allwinner-target) | GPU/WiFi/Xorg overlay |
| allwinner-device | [radxa/allwinner-device](https://github.com/radxa/allwinner-device) | sys_config.fex |
| aic8800 | [radxa-pkg/aic8800](https://github.com/radxa-pkg/aic8800) | WiFi USB driver |
| ai-sdk | [ZIFENG278/ai-sdk](https://github.com/ZIFENG278/ai-sdk) | NPU SDK (VIPLite v2.0) |
| Radxa stock image | [radxa-build/radxa-cubie-a7z](https://github.com/radxa-build/radxa-cubie-a7z/releases) | boot0 extraction |

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
- `MANIFEST.lock` records actual resolved SHAs after fetch

## Known Quirks

- `dpkg-deb -x` does not resolve dependencies — shared libs are added manually
  (see `docs/rootfs-dependency-map.md`)
- GPU module (pvrsrvkm) is built out-of-tree, requires `/gcc` symlink to cross-compiler
- UFS may be absent on some SKUs (dmesg errors are normal)
- First boot: `first-boot-resize` expands rootfs to full SD card size
- GNU Make 4.4+ conflicts with GPU kbuild — `.SECONDARY` patched automatically

---

## Build Guide for Newcomers

### Case 1: First Build from Scratch (Docker/Podman)

This is the recommended path. You don't need to install any cross-compilers on the host.

```bash
# 1. Clone the repository
git clone https://github.com/dok2d/cubie-a7z-debian.git
cd cubie-a7z-debian

# 2. Install the only host dependency
sudo apt install qemu-user-static binfmt-support
sudo systemctl restart binfmt-support

# 3. Verify binfmt_misc is set up correctly
cat /proc/sys/fs/binfmt_misc/qemu-aarch64
# Must show "flags: F" — the "F" (fix-binary) flag is critical.
# Without it, chroot into arm64 rootfs will fail.

# 4. Build the Docker image (one-time, ~5 min)
docker build -t cubie-builder -f docker/Dockerfile.builder .

# 5. Build everything (first run: ~30 min, ~8 GB download)
docker run --rm -v $(pwd):/work cubie-builder make all

# 6. Output: build/cubie_a7z-trixie.img.xz (~800 MB)
ls -lh build/cubie_a7z-trixie.img.xz
```

**Podman users**: replace `docker` with `podman` and add `--privileged --user root` and `:Z` suffix:
```bash
podman run --rm --privileged --user root -v .:/work:Z cubie-builder make all
```

### Case 2: First Build without Docker (native host)

```bash
# 1. Install ALL build dependencies
sudo apt install -y \
  make git wget curl build-essential bc flex bison libssl-dev \
  gcc-arm-linux-gnueabi gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
  swig device-tree-compiler xxd busybox \
  debootstrap qemu-user-static binfmt-support \
  parted dosfstools e2fsprogs mtools xz-utils \
  u-boot-tools kmod cpio binutils

# 2. Verify all tools are found
make deps

# 3. Build (requires root for debootstrap/chroot)
sudo make all

# 4. Output
ls -lh build/cubie_a7z-trixie.img.xz
```

### Case 3: Rebuild After Code Changes

Build scripts are idempotent — they skip stages if output already exists.

```bash
# Rebuild everything from scratch
rm -rf build/
make all

# Rebuild only the rootfs (e.g. after changing overlays/ or packages)
rm -rf build/rootfs build/rootfs-*.tar build/cubie_a7z-trixie.img*
make rootfs image

# Rebuild only the kernel (e.g. after DTS or defconfig change)
rm -rf build/kernel build/modules
make kernel rootfs image

# Rebuild only the bootloader (e.g. after U-Boot patch)
rm -rf build/bootloader
make bootloader image

# Full clean (keeps downloaded sources)
make clean

# Full clean including downloaded sources (~8 GB re-download)
make distclean
```

### Case 4: Changing the Device Tree

The custom DTS is at `config/dts/sun60i-a733-cubie-a7z.dts`.

```bash
# 1. Edit the DTS
nano config/dts/sun60i-a733-cubie-a7z.dts

# 2. Rebuild kernel (DTS is copied into kernel tree automatically)
rm -rf build/kernel build/modules
make kernel

# 3. Rebuild rootfs + image (kernel is embedded in rootfs)
rm -rf build/rootfs build/rootfs-*.tar build/cubie_a7z-trixie.img*
make rootfs image
```

### Case 5: Adding a Package to the Rootfs

Packages are listed in `scripts/30-build-rootfs.sh` as a comma-separated `PACKAGES` variable.

```bash
# 1. Edit the script
nano scripts/30-build-rootfs.sh
# Find the PACKAGES= lines and add your package, e.g.:
# PACKAGES+=",htop,neofetch"

# 2. Check if your package needs shared libraries not yet in PACKAGES
# Run on a Debian arm64 system or chroot:
apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts \
  --no-breaks --no-replaces --no-enhances your-package | grep "Depends:" | sort -u

# 3. Rebuild rootfs + image
rm -rf build/rootfs build/rootfs-*.tar build/cubie_a7z-trixie.img*
make rootfs image
```

**Why manual dependency tracking?** We use `dpkg --unpack` instead of `apt install`
because `apt install` in a foreign-arch chroot requires `--privileged` Docker.
Each new library must be explicitly added to `PACKAGES`. See `docs/rootfs-dependency-map.md`.

### Case 6: Adding Custom Files to the Image

Place files in `overlays/rootfs/` mirroring the target path:

```bash
# Example: add a custom MOTD
echo "Welcome to Cubie A7Z" > overlays/rootfs/etc/motd

# Example: add a startup script
mkdir -p overlays/rootfs/usr/local/bin
cp my-script.sh overlays/rootfs/usr/local/bin/

# Rebuild
rm -rf build/rootfs build/rootfs-*.tar build/cubie_a7z-trixie.img*
make rootfs image
```

### Case 7: Adding a Kernel Patch

```bash
# 1. Clone the kernel source (if not already fetched)
make fetch

# 2. Make your changes in sources/kernel/
cd sources/kernel
# ... edit files ...

# 3. Create a patch
git add -A && git commit -m "my change"
git format-patch -1 -o ../../patches/kernel/

# 4. Rebuild (clean kernel first, patches are applied on fetch)
cd ../..
rm -rf build/kernel build/modules
# Re-fetch to apply patches cleanly (idempotent, no re-download)
make fetch kernel rootfs image
```

### Case 8: Adding a U-Boot Patch

Same workflow as kernel patches but in `patches/u-boot/`:

```bash
cd sources/u-boot-vendor
# ... edit, commit ...
git format-patch -1 -o ../../patches/u-boot/
cd ../..
rm -rf build/bootloader
make fetch bootloader image
```

### Case 9: Updating Vendor Sources

To update a vendor repo to a newer commit:

```bash
# 1. Find the latest commit
git ls-remote https://github.com/orangepi-xunlong/linux-orangepi.git orange-pi-6.6-sun60iw2

# 2. Update the SHA in config/board.cubie-a7z.env
nano config/board.cubie-a7z.env
# Change KERNEL_COMMIT="..."

# 3. Clean old sources and rebuild
rm -rf sources/kernel build/
make all
```

**Warning**: Updating vendor SHAs may introduce regressions. Always test on hardware.

### Case 10: Flashing an SD Card

```bash
# Identify the SD card device
lsblk

# Method 1: safe flash script (with confirmation, safety checks)
sudo make flash DEV=/dev/sdX

# Method 2: manual dd
xzcat build/cubie_a7z-trixie.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
sync

# Method 3: flash to non-removable device (DANGEROUS)
sudo scripts/90-flash-sd.sh /dev/nvme0n1 --force
```

The flash script:
- Refuses to write to non-removable devices (without `--force`)
- Checks device size vs image size
- Verifies no partitions are mounted
- Runs `fsck` after write
- Shows default credentials

### Case 11: Debugging Boot Failures

```bash
# 1. Connect UART adapter to 40-pin header
#    Pin 10 (TX) → adapter RX
#    Pin 12 (RX) → adapter TX
#    Pin 6  (GND) → adapter GND
#    MUST be 3.3V adapter!

# 2. Open serial terminal
screen /dev/ttyUSB0 115200
# or: minicom -D /dev/ttyUSB0 -b 115200

# 3. Insert SD, power on. You should see:
#    - boot0 DRAM init messages
#    - U-Boot banner
#    - Kernel boot log
#    - Login prompt

# Common failures:
# - No output at all → wrong UART pins, or boot0 not at sector 256
# - boot0 hangs → wrong DRAM params (needs stock boot0, not allwinner-device)
# - U-Boot hangs → boot_package at wrong sector offset (must be 24576)
# - Kernel panic → missing rootfs, wrong root= parameter
# - No network → wpa_supplicant.conf not configured
```

### Case 12: Testing on Hardware Without Full Rebuild

If you only need to update a file on an already-flashed SD card:

```bash
# Mount the SD card on the host
sudo mount /dev/sdX2 /mnt          # rootfs (ext4)
sudo mount /dev/sdX1 /mnt/boot    # boot (FAT32)

# Copy updated files
sudo cp overlays/rootfs/root/tests/test-all.sh /mnt/root/tests/
sudo cp build/kernel/sun60i-a733-cubie-a7z.dtb /mnt/boot/

# Unmount
sudo umount /mnt/boot /mnt
```

### Case 13: Building Only a Specific Module

```bash
# WiFi driver only
make fetch
cd sources/kernel
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=$(pwd)/../../sources/aic8800/src/USB/driver_fw/drivers/aic8800 \
  CONFIG_AIC_LOADFW_SUPPORT=m CONFIG_AIC8800_WLAN_SUPPORT=m modules

# GPU driver only (requires kernel to be built first)
make kernel  # if not done
cd sources/kernel/bsp/modules/gpu/img-bxm/linux/rogue_km/build/linux/sunxi_linux
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KERNELDIR=$(pwd)/../../../../../../.. BUILD=release
```

### Case 14: Creating a Custom Image Variant

```bash
# 1. Fork config
cp config/debian.env config/debian-custom.env
# Edit: change hostname, user, password

# 2. Fork rootfs script (or just edit the original)
# Customize PACKAGES, services, overlay contents

# 3. Build
make all
```

### Case 15: Working with the Docker Builder

```bash
# Build the container image
docker build -t cubie-builder -f docker/Dockerfile.builder .

# Run a single build stage
docker run --rm -v $(pwd):/work cubie-builder make fetch
docker run --rm -v $(pwd):/work cubie-builder make kernel

# Interactive shell inside the builder
docker run --rm -it -v $(pwd):/work cubie-builder bash

# Override UID/GID to match host user (avoids permission issues)
docker build --build-arg BUILDER_UID=$(id -u) --build-arg BUILDER_GID=$(id -g) \
  -t cubie-builder -f docker/Dockerfile.builder .

# Note: rootfs stage requires root (debootstrap/chroot)
# Docker runs as root by default. Podman needs --privileged --user root.
```

### Case 16: Understanding the Boot Process

```
Power on
  → BROM (ROM code in SoC)
    → Reads boot0 from SD sector 256 (128 KB offset)
      → boot0 initializes DRAM, loads boot_package from sector 24576
        → boot_package contains U-Boot + DTB + SCP firmware
          → U-Boot reads extlinux.conf or boot.scr from FAT32 partition
            → Loads kernel Image + DTB
              → Kernel boots, mounts ext4 rootfs
                → systemd starts services
```

See [boot-layout.md](boot-layout.md) for sector offsets and partition map.

### Case 17: Resolving "Missing Shared Library" Errors

When a binary fails with "error while loading shared libraries":

```bash
# 1. On the board, find what's missing
ldd /usr/bin/problematic-binary

# 2. Find which Debian package provides it
apt-file search libmissing.so
# or: dpkg -S libmissing.so (if apt-file not available)

# 3. Add the package to PACKAGES in scripts/30-build-rootfs.sh
# 4. Rebuild rootfs + image
```

See `docs/rootfs-dependency-map.md` for the current dependency tree.

### Case 18: Cross-compiling a Program for the Board

```bash
# Using the cross-compiler directly
aarch64-linux-gnu-gcc -o hello hello.c

# Copy to the board
scp hello cubie@<ip>:/home/cubie/

# Or place in the overlay for inclusion in the image
cp hello overlays/rootfs/usr/local/bin/
```

### Case 19: Installing a Desktop Environment on the Board

The image ships minimal (CLI only). Desktop installers are in `/root/help/wm/`:

```bash
# On the board:
bash /root/help/wm/install-xfce.sh     # XFCE4 (recommended, X11)
bash /root/help/wm/install-i3.sh       # i3 tiling WM (X11, lightweight)
bash /root/help/wm/install-lxqt.sh     # LXQt (X11, Qt-based)
bash /root/help/wm/install-sway.sh     # Sway (Wayland)
bash /root/help/wm/install-labwc.sh    # labwc (Wayland, openbox-like)
```

### Case 20: GPU Acceleration Setup

GPU hardware acceleration is pre-configured but requires X11:

```bash
# On the board:
bash /root/help/wm/install-xfce.sh   # Install X11 desktop
# Reboot, login via HDMI

# Verify GPU is active
DISPLAY=:0 glxinfo | grep renderer
# Should show: PowerVR B-Series BXM-4-64

# If it shows llvmpipe, check:
cat /etc/environment     # Must have LD_LIBRARY_PATH=/usr/local/lib
ls /dev/dri/renderD128   # Must exist (pvrsrvkm module loaded)
```

See [GPU-TODO.md](../GPU-TODO.md) for technical details on the GLVND/Mesa stack.
