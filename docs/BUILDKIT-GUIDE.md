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

---

## Practical Recipes (On the Board)

These instructions are run **on the board itself** after booting, not during image build.

### Recipe 1: Change Root or User Password

```bash
# Change root password
passwd

# Change cubie user password
passwd cubie

# To bake a different password into the image at build time,
# edit config/debian.env:
#   ROOT_PASSWORD="newpass"
#   DEFAULT_PASSWORD="newpass"
```

### Recipe 2: Add a New User

```bash
# Create user with home directory, bash shell, and sudo access
useradd -m -s /bin/bash -G sudo,audio,video,render,input newuser
passwd newuser

# Verify
su - newuser
whoami
```

### Recipe 3: Delete a User

```bash
# Remove user and their home directory
userdel -r olduser
```

### Recipe 4: Install Packages from Debian Repos

The board has full access to Debian Trixie repositories:

```bash
apt update
apt install <package>

# Examples:
apt install python3 python3-pip   # Python
apt install nginx                  # Web server
apt install mc                     # Midnight Commander file manager
apt install neofetch               # System info
apt install iperf3                 # Network benchmarking
apt install nmap                   # Network scanner
apt install git                    # Version control
```

**Note**: On the 1 GB SKU, large packages may run out of RAM during install.
zram swap (256 MB) helps, but heavy compiles (GCC, Rust) may still OOM.

### Recipe 5: Configure WiFi — Full Walkthrough

```bash
# 1. Check that WiFi chip is powered on
cat /sys/class/misc/sunxi-rfkill/wlan/state
# Should be 1. If 0:
echo 1 > /sys/class/misc/sunxi-rfkill/wlan/state

# 2. Scan for networks
iw dev wlan0 scan | grep SSID

# 3. Configure wpa_supplicant
nano /etc/wpa_supplicant/wpa_supplicant.conf
```

Add your network:
```
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="MyNetwork"
    psk="MyPassword"
}
```

```bash
# 4. Restart networking
systemctl restart networking

# 5. Verify
ip addr show wlan0     # should have an IP
ping 8.8.8.8           # should work
```

#### Connect to a Hidden Network

```
network={
    ssid="HiddenNetwork"
    scan_ssid=1
    psk="password"
}
```

#### Connect to an Enterprise Network (WPA2-EAP)

```
network={
    ssid="CorpWiFi"
    key_mgmt=WPA-EAP
    eap=PEAP
    identity="user@example.com"
    password="secret"
    phase2="auth=MSCHAPV2"
}
```

#### Connect to an Open Network

```
network={
    ssid="OpenCafe"
    key_mgmt=NONE
}
```

#### Multiple Networks with Priority

```
network={
    ssid="HomeWiFi"
    psk="home123"
    priority=10
}
network={
    ssid="WorkWiFi"
    psk="work456"
    priority=5
}
```

The highest priority network that is visible will be used.

### Recipe 6: Set a Static IP Address

```bash
nano /etc/network/interfaces.d/wlan0
```

Replace `dhcp` with static:
```
allow-hotplug wlan0
iface wlan0 inet static
    address 192.168.1.100
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 8.8.8.8 8.8.4.4
    wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
```

```bash
systemctl restart networking
```

### Recipe 7: Configure SSH

#### Change SSH Port

```bash
nano /etc/ssh/sshd_config.d/cubie-a7z.conf
```
```
Port 2222
PermitRootLogin yes
PasswordAuthentication yes
```
```bash
systemctl restart ssh
# Now connect: ssh -p 2222 cubie@<ip>
```

#### Set Up SSH Keys (Passwordless Login)

On your **host** machine:
```bash
# Generate key pair (if you don't have one)
ssh-keygen -t ed25519

# Copy public key to the board
ssh-copy-id cubie@<board-ip>

# Now login without password
ssh cubie@<board-ip>
```

#### Disable Password Login (Keys Only)

After confirming key login works:
```bash
# On the board:
nano /etc/ssh/sshd_config.d/cubie-a7z.conf
```
```
PasswordAuthentication no
PubkeyAuthentication yes
```
```bash
systemctl restart ssh
```

#### Disable Root SSH Login

```bash
nano /etc/ssh/sshd_config.d/cubie-a7z.conf
```
```
PermitRootLogin no
```
```bash
systemctl restart ssh
```

### Recipe 8: Transfer Files To/From the Board

```bash
# Copy file to the board
scp myfile.txt cubie@<ip>:/home/cubie/

# Copy file from the board
scp cubie@<ip>:/home/cubie/results.txt .

# Copy an entire directory
scp -r my-project/ cubie@<ip>:/home/cubie/

# Interactive file transfer
sftp cubie@<ip>

# rsync (better for large/incremental transfers)
rsync -avz my-project/ cubie@<ip>:/home/cubie/my-project/
```

### Recipe 9: Set Timezone and Locale

```bash
# List available timezones
timedatectl list-timezones | grep Moscow

# Set timezone
timedatectl set-timezone Europe/Moscow

# Verify
date
timedatectl status

# Set locale (C.utf8 is the default, no locale-gen needed)
# To add a specific locale:
apt install locales
dpkg-reconfigure locales
```

### Recipe 10: Set Hostname

```bash
hostnamectl set-hostname my-cubie
# Also update /etc/hosts
nano /etc/hosts
# Change: 127.0.1.1  my-cubie
```

### Recipe 11: Mount a USB Drive

```bash
# 1. Connect USB drive to J4 (top USB-C port, with OTG adapter)

# 2. Find the device
lsblk
# Typically: /dev/sda1

# 3. Mount
mkdir -p /mnt/usb
mount /dev/sda1 /mnt/usb

# 4. Use it
ls /mnt/usb

# 5. Unmount before removing
umount /mnt/usb
```

#### Auto-mount USB on Boot

```bash
# Find UUID
blkid /dev/sda1

# Add to fstab
echo 'UUID=xxxx-xxxx  /mnt/usb  vfat  defaults,nofail  0  2' >> /etc/fstab
```

### Recipe 12: Check System Health

```bash
# CPU temperature
cat /sys/class/thermal/thermal_zone3/temp
# Divide by 1000 for degrees C (e.g. 52000 = 52°C)

# GPU temperature
cat /sys/class/thermal/thermal_zone4/temp

# DDR temperature
cat /sys/class/thermal/thermal_zone1/temp

# All temperatures at once
paste <(cat /sys/class/thermal/thermal_zone*/type) \
      <(cat /sys/class/thermal/thermal_zone*/temp) \
  | awk '{printf "%-20s %d°C\n", $1, $2/1000}'

# CPU frequency
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq

# RAM usage
free -h

# Disk usage
df -h

# System uptime and load
uptime

# Systemd failed units
systemctl --failed

# dmesg errors
dmesg | grep -i error | tail -20

# Full hardware test suite
bash /root/tests/test-all.sh
```

### Recipe 13: Manage systemd Services

```bash
# List all running services
systemctl list-units --type=service

# Check a specific service
systemctl status ssh
systemctl status networking

# Start / stop / restart a service
systemctl start nginx
systemctl stop nginx
systemctl restart nginx

# Enable on boot / disable
systemctl enable nginx
systemctl disable nginx

# View service logs
journalctl -u ssh -f          # follow live
journalctl -u ssh --since today
journalctl -u networking -b   # since last boot
```

### Recipe 14: Create a Custom systemd Service

Example: auto-start a Python script on boot.

```bash
cat > /etc/systemd/system/my-app.service << 'EOF'
[Unit]
Description=My Application
After=network.target

[Service]
Type=simple
User=cubie
WorkingDirectory=/home/cubie
ExecStart=/usr/bin/python3 /home/cubie/my-app.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable my-app
systemctl start my-app
systemctl status my-app
```

### Recipe 15: Set Up a Cron Job

```bash
# Edit crontab for root
crontab -e

# Examples:
# Run script every 5 minutes
*/5 * * * * /home/cubie/my-script.sh

# Run at 3 AM daily
0 3 * * * apt update && apt upgrade -y

# Run at reboot
@reboot /home/cubie/startup.sh

# Save and view
crontab -l
```

### Recipe 16: Set Up Bluetooth

```bash
# Start bluetoothctl
bluetoothctl

# Inside bluetoothctl:
power on
agent on
default-agent
scan on
# Wait for devices to appear...
# pair XX:XX:XX:XX:XX:XX
# connect XX:XX:XX:XX:XX:XX
# trust XX:XX:XX:XX:XX:XX
scan off
exit
```

### Recipe 17: HDMI Audio Playback

```bash
# List sound cards
aplay -l
# Should show: sndhdmi

# Play a WAV file
aplay -D hw:sndhdmi test.wav

# Play audio with speaker-test
speaker-test -D hw:sndhdmi -c 2 -t wav

# Adjust volume (if alsa-utils installed)
amixer -c sndhdmi set PCM 80%

# Record from HDMI (capture is not supported, HDMI is output only)
```

### Recipe 18: Run NPU Inference

```bash
# Create inference config
cat > /tmp/resnet50.txt << 'EOF'
[network]
/usr/share/npu/models/resnet50.nb
[input]
/usr/share/npu/input_data/goldfish_224x224.dat
EOF

# Run inference
vpm_run -s /tmp/resnet50.txt -l 1
# Output: inference time ~7.5 ms

# With random input (224x224x3 = 150528 bytes)
dd if=/dev/urandom of=/tmp/random.dat bs=150528 count=1
cat > /tmp/test.txt << 'EOF'
[network]
/usr/share/npu/models/resnet50.nb
[input]
/tmp/random.dat
EOF
vpm_run -s /tmp/test.txt -l 1
```

### Recipe 19: GPIO Access

```bash
# List GPIO chips
gpiodetect

# List all GPIO lines
gpioinfo

# Read a GPIO value (e.g. PB0 = GPIO 32 on gpiochip0)
gpioget gpiochip0 32

# Set a GPIO output high
gpioset gpiochip0 32=1

# Set output low
gpioset gpiochip0 32=0

# Monitor GPIO events (watch for edges)
gpiomon gpiochip0 32
```

GPIO number formula:
```
gpiochip0 (ports A-K): GPIO = port × 32 + pin
  A=0, B=1, C=2, D=3, ..., J=9, K=10

gpiochip1 (ports L-M): GPIO = port × 32 + pin
  L=0, M=1
```

Example: PD16 = 3×32 + 16 = GPIO 112

### Recipe 20: I2C and SPI Access

```bash
# List I2C buses
i2cdetect -l

# Scan for devices on bus 2
i2cdetect -y 2

# Read a register
i2cget -y 2 0x50 0x00

# Write a register
i2cset -y 2 0x50 0x00 0xFF

# SPI loopback test (connect MOSI to MISO on 40-pin header)
# Pins: 19 (MOSI) → 21 (MISO), 23 (CLK), 24 (CS0)
echo -ne '\x01\x02\x03' | spidev_test -D /dev/spidev1.0 -v
```

### Recipe 21: Backup and Restore SD Card

```bash
# On host: backup entire SD card
sudo dd if=/dev/sdX bs=4M status=progress | xz -T0 > cubie-backup.img.xz

# On host: restore from backup
xzcat cubie-backup.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
sync

# On host: backup only rootfs (smaller, no bootloader)
sudo dd if=/dev/sdX2 bs=4M status=progress | xz -T0 > rootfs-backup.img.xz

# On the board: backup important configs
tar czf /tmp/config-backup.tar.gz \
  /etc/wpa_supplicant/wpa_supplicant.conf \
  /etc/network/interfaces.d/ \
  /etc/ssh/sshd_config.d/ \
  /etc/hostname \
  /etc/hosts
scp /tmp/config-backup.tar.gz user@host:/backups/
```

### Recipe 22: Resize Root Filesystem Manually

Normally `first-boot-resize` handles this automatically. If it didn't work:

```bash
# Check current size
df -h /

# Expand partition to fill SD card
echo ", +" | sfdisk -f --no-reread --no-tell-kernel -N 2 /dev/mmcblk0
partx -u /dev/mmcblk0
resize2fs /dev/mmcblk0p2

# Verify
df -h /
```

### Recipe 23: Set Up a Simple Web Server

```bash
# Option 1: Python (already installed, no deps)
cd /var/www && python3 -m http.server 8080 &

# Option 2: nginx (production-grade)
apt install nginx
systemctl start nginx
# Open http://<board-ip>/ in browser

# Option 3: lighttpd (lightweight)
apt install lighttpd
systemctl start lighttpd
```

### Recipe 24: Install and Use Python

```bash
# Python 3 is available from Debian repos
apt install python3 python3-pip python3-venv

# Create a virtual environment (recommended on 1 GB RAM)
python3 -m venv ~/myenv
source ~/myenv/bin/activate

# Install packages
pip install flask requests numpy

# Note: compiling large packages (scipy, pandas, torch) may OOM
# on 1 GB SKU. Use pre-built wheels or cross-compile on host.
```

### Recipe 25: Install and Use Node.js

```bash
apt install nodejs npm

# Verify
node --version
npm --version

# Simple HTTP server
cat > ~/server.js << 'EOF'
const http = require('http');
http.createServer((req, res) => {
  res.writeHead(200);
  res.end('Hello from Cubie A7Z!\n');
}).listen(3000);
console.log('Server running on port 3000');
EOF
node ~/server.js &
```

### Recipe 26: Configure Firewall

```bash
apt install ufw

# Allow SSH (do this first!)
ufw allow 22/tcp

# Allow HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Enable firewall
ufw enable

# Check status
ufw status verbose

# Remove a rule
ufw delete allow 80/tcp
```

### Recipe 27: Set Up Headless Operation (No Monitor)

The board works headless out of the box — SSH is enabled by default.

```bash
# 1. Configure WiFi before going headless:
#    Edit wpa_supplicant.conf (see Recipe 5)

# 2. Find the board on your network:
# From another machine:
nmap -sn 192.168.1.0/24 | grep -A1 cubie
# Or check your router's DHCP table

# 3. Connect via SSH
ssh cubie@<ip>

# 4. If you can't find the IP, connect UART:
#    screen /dev/ttyUSB0 115200
#    Login, run: hostname -I
```

### Recipe 28: Share Internet from Board via USB (Tethering)

```bash
# If the board has WiFi internet and you connect a laptop via USB-C J4:
# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Set up NAT (assuming wlan0 has internet)
apt install iptables
iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
```

### Recipe 29: Monitor Network Traffic

```bash
# Real-time bandwidth
apt install iftop
iftop -i wlan0

# Connection list
ss -tulnp

# Network statistics
ip -s link show wlan0

# DNS test
nslookup google.com
dig google.com
```

### Recipe 30: Update Kernel or DTB Without Full Rebuild

If you have a new kernel Image or DTB and want to update a running SD card:

```bash
# 1. Mount boot partition
mount /dev/mmcblk0p1 /boot

# 2. Copy new kernel
scp user@buildhost:build/kernel/vmlinuz-6.6.98-cubie_a7z /boot/vmlinuz-6.6.98+

# 3. Copy new DTB
scp user@buildhost:build/kernel/sun60i-a733-cubie-a7z.dtb /boot/

# 4. Copy new modules (if changed)
scp -r user@buildhost:build/modules/lib/modules/6.6.98+/ /lib/modules/
depmod 6.6.98+

# 5. Reboot
reboot
```
