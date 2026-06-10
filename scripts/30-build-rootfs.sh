#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck disable=SC1091
source "$(dirname "$0")/../config/debian.env"

BOARD=cubie_a7z
ARCH=arm64
RELEASE=trixie
MIRROR="${DEBIAN_MIRROR:-http://deb.debian.org/debian}"
REPO_ROOT=$(pwd)
ROOTFS_DIR="$REPO_ROOT/build/rootfs"
ROOTFS_TAR="$REPO_ROOT/build/rootfs-${BOARD}-${RELEASE}.tar"

KERNEL_RELEASE=6.6.98+
KERNEL_DIR="$REPO_ROOT/build/kernel"
MODULES_DIR="$REPO_ROOT/build/modules/lib/modules/$KERNEL_RELEASE"

log() { echo "[$(date -u +%FT%H:%M:%SZ)] ==> $*"; }

# Chroot helper: runs a command in the arm64 rootfs.
# Requires: running as root + binfmt_misc with qemu-aarch64-static (F flag)
# or qemu-aarch64-static copied into rootfs.
do_chroot() {
  chroot "$ROOTFS_DIR" "$@"
}

# Mount/unmount virtual filesystems for chroot
mount_chroot() {
  mount --bind /proc "$ROOTFS_DIR/proc" 2>/dev/null || true
  mount --bind /sys "$ROOTFS_DIR/sys" 2>/dev/null || true
  mount --bind /dev "$ROOTFS_DIR/dev" 2>/dev/null || true
  mount --bind /dev/pts "$ROOTFS_DIR/dev/pts" 2>/dev/null || true
  cp /etc/resolv.conf "$ROOTFS_DIR/etc/resolv.conf" 2>/dev/null || true
}

umount_chroot() {
  umount "$ROOTFS_DIR/dev/pts" 2>/dev/null || true
  umount "$ROOTFS_DIR/dev" 2>/dev/null || true
  umount "$ROOTFS_DIR/sys" 2>/dev/null || true
  umount "$ROOTFS_DIR/proc" 2>/dev/null || true
}

trap umount_chroot EXIT

rm -rf "$ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR"

log "Stage 1: debootstrap --foreign"
debootstrap --arch=$ARCH --foreign --variant=minbase \
  $RELEASE "$ROOTFS_DIR" "$MIRROR" 2>&1 | tail -5

log "Stage 2: debootstrap --second-stage (via chroot+qemu)"
cp /usr/bin/qemu-aarch64-static "$ROOTFS_DIR/usr/bin/"
mount_chroot
chroot "$ROOTFS_DIR" /debootstrap/debootstrap --second-stage 2>&1 | tail -20

log "Downloading and installing packages"

# Full sources.list (debootstrap only writes main)
cat > "$ROOTFS_DIR/etc/apt/sources.list" << 'SRCEOF'
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
SRCEOF

do_chroot /usr/bin/apt-get update 2>&1 | cat

# Download all needed debs
PACKAGES="systemd,systemd-sysv,udev,dbus,dbus-daemon,dbus-system-bus-common,kmod,initramfs-tools,linux-base,u-boot-tools"
PACKAGES+=",e2fsprogs,fdisk,dosfstools,ifupdown,iproute2,netbase,isc-dhcp-client"
PACKAGES+=",util-linux,util-linux-extra"
PACKAGES+=",procps,less,vim-tiny,openssh-server,openssh-client,firmware-linux-free,ca-certificates"
PACKAGES+=",curl,wget,locales,console-setup,sudo,parted,wpasupplicant,iw,alsa-utils,wireless-regdb"
PACKAGES+=",iputils-ping,tzdata,tree,gawk,fake-hwclock,bash-completion"
PACKAGES+=",systemd-timesyncd,gnupg,psmisc,lsof,bzip2,xz-utils,unzip,rsync,screen,tmux,net-tools,man-db,bluez,libpam-systemd"
# Deps for new utilities
PACKAGES+=",libedit2,libevent-core-2.1-7t64,libgdbm6t64,libjemalloc2,libpipeline1,libpopt0"
# bluez (bluetoothctl) deps
PACKAGES+=",libglib2.0-0t64,libdw1t64,libatomic1"
PACKAGES+=",libdrm2,libexpat1,libstdc++6,libxcb-dri2-0,libxcb-dri3-0,libxcb-present0,libxcb-sync1,libxcb-xfixes0"
# systemd private libs
PACKAGES+=",libsystemd-shared,libapparmor1"
# kmod (systemd-modules-load needs libkmod), iproute2 needs libbpf
PACKAGES+=",libkmod2,libbpf1"
# Diagnostic tools
PACKAGES+=",nano,usbutils,pciutils,i2c-tools,gpiod,rfkill,ethtool,htop,strace,file"
# Shared libs for diagnostic tools (dpkg-deb -x doesn't resolve deps)
PACKAGES+=",libncursesw6,libpci3,libusb-1.0-0,libmnl0,libi2c0"
PACKAGES+=",libelf1t64,libmagic-mgc,libmagic1t64"
# e2fsprogs/fdisk runtime deps (first-boot-resize)
PACKAGES+=",libcom-err2,libext2fs2t64,libfdisk1,libsmartcols1,libreadline8t64"
# Missing shared libs (full dependency tree scan, 4 levels deep)
# L1: direct deps of binaries in rootfs
PACKAGES+=",libidn2-0,libparted2t64,libproc2-0,libasound2t64,libasound2-data,libdbus-1-3"
PACKAGES+=",libunistring5,libnl-3-200,libnl-genl-3-200,libnl-route-3-200,libpcsclite1"
PACKAGES+=",libcurl4t64,libfftw3-single3,libsamplerate0,libsigsegv2,libgpiod3"
PACKAGES+=",libgnutls30t64,libtirpc3t64,libss2,libxtables12,libmpfr6,libpsl5t64"
# L2: deps of L1
PACKAGES+=",libbrotli1,libgomp1,libgssapi-krb5-2,libldap2,libnghttp2-14,libnghttp3-9"
PACKAGES+=",libp11-kit0,librtmp1,libssh2-1t64,libtasn1-6"
# L3: deps of L2
PACKAGES+=",libffi8,libk5crypto3,libkrb5-3,libkrb5support0,libsasl2-2"
# L4: deps of L3
PACKAGES+=",libkeyutils1,libwrap0,libwtmpdb0"
# GPU/Xorg runtime deps
PACKAGES+=",libpixman-1-0,libpciaccess0,libxfont2,libxau6,libxshmfence1,libxdmcp6"

# Download arm64 debs directly from the host using apt-get
# (chroot-based apt download can have working dir issues)
DEB_CACHE="$REPO_ROOT/build/deb-cache"
mkdir -p "$DEB_CACHE"
(
  cd "$DEB_CACHE"
  apt-get download -o APT::Architecture=arm64 \
    -o Dir::Etc::SourceList="$ROOTFS_DIR/etc/apt/sources.list" \
    -o Dir::Etc::SourceParts="" \
    -o Dir::State="$ROOTFS_DIR/var/lib/apt" \
    -o Dir::Cache="$ROOTFS_DIR/var/cache/apt" \
    $(echo "$PACKAGES" | tr ',' ' ') 2>&1 | cat
)

# Install debs via dpkg --unpack through chroot (registers in dpkg database).
log "Unpacking additional packages"
cp "$DEB_CACHE"/*.deb "$ROOTFS_DIR/tmp/" 2>/dev/null || true
do_chroot /bin/sh -c 'dpkg --unpack --force-depends --force-overwrite /tmp/*.deb' 2>&1 | tail -5 || true
rm -f "$ROOTFS_DIR/tmp/"*.deb

# Fix critical symlinks that dpkg-deb -x doesn't create (postinst scripts)
log "Creating essential symlinks"
mkdir -p "$ROOTFS_DIR/sbin"
ln -sf /usr/lib/systemd/systemd "$ROOTFS_DIR/sbin/init" 2>/dev/null || \
  ln -sf /lib/systemd/systemd "$ROOTFS_DIR/sbin/init" 2>/dev/null || true
ln -sf /usr/bin/bash "$ROOTFS_DIR/bin/sh" 2>/dev/null || \
  ln -sf /bin/bash "$ROOTFS_DIR/bin/sh" 2>/dev/null || true
# machine-id: empty file triggers first-boot generation by systemd
touch "$ROOTFS_DIR/etc/machine-id"

# nsswitch.conf (dpkg-deb -x doesn't run libc postinst)
cat > "$ROOTFS_DIR/etc/nsswitch.conf" << 'NSEOF'
passwd:         files
group:          files
shadow:         files
hosts:          files dns
networks:       files
protocols:      db files
services:       db files
ethers:         db files
rpc:            db files
netgroup:       nis
NSEOF

# Configure all unpacked packages (some may fail — that's OK)
log "Configuring packages"
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
  do_chroot /usr/bin/dpkg --configure --force-all -a 2>&1 | tail -10 || true
# Fix any broken dependencies left by dpkg --unpack
DEBIAN_FRONTEND=noninteractive do_chroot /usr/bin/apt-get -f install -y 2>&1 | tail -5 || true

log "Configuring rootfs"
echo "${TARGET_HOSTNAME:-cubie-a7z}" > "$ROOTFS_DIR/etc/hostname"

# Enable bash-completion (Debian ships it commented out in bash.bashrc)
if [ -f "$ROOTFS_DIR/etc/bash.bashrc" ]; then
  sed -i '/# *if.*bash_completion/,/# *fi/s/^#  *//' "$ROOTFS_DIR/etc/bash.bashrc"
fi

cat > "$ROOTFS_DIR/etc/hosts" << 'EOF'
127.0.0.1	localhost
127.0.1.1	cubie-a7z
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

cat > "$ROOTFS_DIR/etc/fstab" << 'EOF'
/dev/mmcblk0p1	/boot	vfat	defaults		0	2
/dev/mmcblk0p2	/	ext4	defaults,noatime	0	1
EOF

mkdir -p "$ROOTFS_DIR/etc/systemd/system/getty.target.wants"
ln -sf /lib/systemd/system/getty@.service \
  "$ROOTFS_DIR/etc/systemd/system/getty.target.wants/getty@ttyS0.service"
ln -sf /lib/systemd/system/getty@.service \
  "$ROOTFS_DIR/etc/systemd/system/getty.target.wants/getty@tty1.service"

# Enable SSH
mkdir -p "$ROOTFS_DIR/etc/systemd/system/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/ssh.service \
  "$ROOTFS_DIR/etc/systemd/system/multi-user.target.wants/ssh.service"
ln -sf /usr/lib/systemd/system/networking.service \
  "$ROOTFS_DIR/etc/systemd/system/multi-user.target.wants/networking.service"
ln -sf /usr/lib/systemd/system/systemd-timesyncd.service \
  "$ROOTFS_DIR/etc/systemd/system/multi-user.target.wants/systemd-timesyncd.service"

# dbus: do NOT create /etc/dbus-1/system.conf — dbus reads /usr/share/dbus-1/system.conf
# by default, and that file includes /etc/dbus-1/system.conf causing circular inclusion.
# Just ensure the drop-in directory exists.
mkdir -p "$ROOTFS_DIR/etc/dbus-1/system.d"

# SSH: generate host keys and ensure password login works
mkdir -p "$ROOTFS_DIR/etc/ssh/sshd_config.d"
ssh-keygen -A -f "$ROOTFS_DIR" 2>/dev/null || true
# dpkg-deb -x doesn't run postinst → sshd_config may be missing.
# Copy from package defaults if not present.
if [ ! -f "$ROOTFS_DIR/etc/ssh/sshd_config" ]; then
  cp "$ROOTFS_DIR/usr/share/openssh/sshd_config" "$ROOTFS_DIR/etc/ssh/sshd_config" 2>/dev/null || true
fi
# Drop-in overrides guarantee our settings take effect regardless of defaults.
cat > "$ROOTFS_DIR/etc/ssh/sshd_config.d/cubie-a7z.conf" << 'SSHEOF'
PermitRootLogin yes
PasswordAuthentication yes
SSHEOF

mkdir -p "$ROOTFS_DIR/etc/network/interfaces.d"
cat > "$ROOTFS_DIR/etc/network/interfaces" << 'EOF'
# /etc/network/interfaces — managed by ifupdown
auto lo
iface lo inet loopback

source /etc/network/interfaces.d/*
EOF
# No eth0 — board has no Ethernet; networking is WiFi-only via AIC8800 USB

# Force traditional interface names (wlan0 instead of wlxMAC).
# Mask the default policy that renames USB WiFi to wlxMAC.
mkdir -p "$ROOTFS_DIR/etc/systemd/network"
ln -sf /dev/null "$ROOTFS_DIR/etc/systemd/network/99-default.link"

cat > "$ROOTFS_DIR/etc/network/interfaces.d/wlan0" << 'EOF'
allow-hotplug wlan0
iface wlan0 inet dhcp
    wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
EOF

mkdir -p "$ROOTFS_DIR/etc/wpa_supplicant"
cat > "$ROOTFS_DIR/etc/wpa_supplicant/wpa_supplicant.conf" << 'EOF'
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

# Uncomment and edit:
# network={
#     ssid="YourSSID"
#     psk="YourPassphrase"
# }
EOF
chmod 600 "$ROOTFS_DIR/etc/wpa_supplicant/wpa_supplicant.conf"

# ALSA config: default audio output to HDMI (only audio output on SBC)
log "Configuring HDMI audio"
cat > "$ROOTFS_DIR/etc/asound.conf" << 'EOF'
pcm.!default {
    type hw
    card "sndhdmi"
}
ctl.!default {
    type hw
    card "sndhdmi"
}
EOF

# Create groups needed by packages/udev rules
grep -q "^netdev:" "$ROOTFS_DIR/etc/group" || echo "netdev:x:109:" >> "$ROOTFS_DIR/etc/group"
grep -q "^i2c:" "$ROOTFS_DIR/etc/group" || echo "i2c:x:110:" >> "$ROOTFS_DIR/etc/group"

echo "root:${ROOT_PASSWORD:-cubie}" | do_chroot /usr/sbin/chpasswd 2>&1 || true
do_chroot /usr/sbin/useradd -m -s /bin/bash -G sudo,adm,netdev,audio,video,render,input "${DEFAULT_USER:-cubie}" 2>/dev/null || true
echo "${DEFAULT_USER:-cubie}:${DEFAULT_PASSWORD:-cubie}" | do_chroot /usr/sbin/chpasswd 2>&1 || true

# XDG dirs for all users (apps like Yamagi Quake II need ~/.local/share)
mkdir -p "$ROOTFS_DIR/etc/skel/.local/share"
mkdir -p "$ROOTFS_DIR/home/${DEFAULT_USER:-cubie}/.local/share"
chown -R 1000:1000 "$ROOTFS_DIR/home/${DEFAULT_USER:-cubie}/.local" 2>/dev/null || true

# C.utf8 is always available, no locale-gen needed
# systemd replaces /etc/default/locale with symlink to /etc/locale.conf
echo "LANG=C.utf8" > "$ROOTFS_DIR/etc/locale.conf"

# Seed fake-hwclock with build host time (board has no RTC battery)
date -u '+%Y-%m-%d %H:%M:%S' > "$ROOTFS_DIR/etc/fake-hwclock.data"
# Enable fake-hwclock services (dpkg-deb -x doesn't run postinst)
rm -f "$ROOTFS_DIR/etc/systemd/system/fake-hwclock.service"  # remove mask if present
mkdir -p "$ROOTFS_DIR/etc/systemd/system/sysinit.target.wants"
mkdir -p "$ROOTFS_DIR/etc/systemd/system/shutdown.target.wants"
ln -sf /usr/lib/systemd/system/fake-hwclock-load.service \
  "$ROOTFS_DIR/etc/systemd/system/sysinit.target.wants/fake-hwclock-load.service"
ln -sf /usr/lib/systemd/system/fake-hwclock-save.service \
  "$ROOTFS_DIR/etc/systemd/system/shutdown.target.wants/fake-hwclock-save.service"

echo "UTC" > "$ROOTFS_DIR/etc/timezone"
ln -sf /usr/share/zoneinfo/UTC "$ROOTFS_DIR/etc/localtime"

# Install vendor overlay: firmware, GPU userland, configs
OVERLAY="$REPO_ROOT/sources/allwinner-target/debian/cubie_a7z/overlay"

mkdir -p "$ROOTFS_DIR/lib/firmware/aic8800D80"
ln -sf aic8800D80 "$ROOTFS_DIR/lib/firmware/aic8800d80"  # driver uses lowercase

log "Installing AIC8800D80 WiFi/BT firmware"
AIC8800_FW="$REPO_ROOT/sources/aic8800/src/USB/driver_fw/fw/aic8800D80"
if [ -d "$AIC8800_FW" ]; then
  cp -a "$AIC8800_FW/"* "$ROOTFS_DIR/lib/firmware/aic8800D80/"
else
  cp -a "$OVERLAY/lib/firmware/aic8800D80/"* "$ROOTFS_DIR/lib/firmware/aic8800D80/"
fi
cp -a "$OVERLAY/lib/firmware/aic_"*        "$ROOTFS_DIR/lib/firmware/" 2>/dev/null || true

# wireless-regdb: dpkg-deb -x doesn't run postinst to create symlinks
if [ -f "$ROOTFS_DIR/usr/lib/firmware/regulatory.db-upstream" ]; then
  ln -sf /usr/lib/firmware/regulatory.db-upstream "$ROOTFS_DIR/lib/firmware/regulatory.db"
  ln -sf /usr/lib/firmware/regulatory.db.p7s-upstream "$ROOTFS_DIR/lib/firmware/regulatory.db.p7s"
fi

log "Installing GPU firmware (PowerVR RGX)"
cp -a "$OVERLAY/lib/firmware/rgx."*        "$ROOTFS_DIR/lib/firmware/"

log "Installing GPU userland (Mesa + PVR)"
# PVR service libraries
cp -a "$OVERLAY/usr/lib/lib"*.so*          "$ROOTFS_DIR/usr/lib/"
# Mesa EGL/GLES/Vulkan/GBM
mkdir -p "$ROOTFS_DIR/usr/local/lib/dri"
cp -a "$OVERLAY/usr/local/lib/"*.so*       "$ROOTFS_DIR/usr/local/lib/"
cp -a "$OVERLAY/usr/local/lib/dri/"*.so    "$ROOTFS_DIR/usr/local/lib/dri/"
# pkg-config files
mkdir -p "$ROOTFS_DIR/usr/local/lib/pkgconfig"
cp -a "$OVERLAY/usr/local/lib/pkgconfig/"* "$ROOTFS_DIR/usr/local/lib/pkgconfig/"
# Ensure linker finds /usr/local/lib
echo "/usr/local/lib" > "$ROOTFS_DIR/etc/ld.so.conf.d/usr-local.conf"

log "Installing Xorg server and drivers"
cp -a "$OVERLAY/usr/bin/Xorg"              "$ROOTFS_DIR/usr/bin/"
mkdir -p "$ROOTFS_DIR/usr/lib/xorg/modules/drivers"
cp -a "$OVERLAY/usr/lib/xorg/modules/"*    "$ROOTFS_DIR/usr/lib/xorg/modules/"
mkdir -p "$ROOTFS_DIR/etc/X11/xorg.conf.d"
cp -a "$OVERLAY/etc/X11/xorg.conf.d/"*     "$ROOTFS_DIR/etc/X11/xorg.conf.d/"

# GPU acceleration: PVR Mesa in /usr/local/lib/ needs LD_LIBRARY_PATH and glamor
echo 'LD_LIBRARY_PATH=/usr/local/lib' > "$ROOTFS_DIR/etc/environment"
# Vulkan ICD for PowerVR (libVK_IMG.so)
mkdir -p "$ROOTFS_DIR/etc/vulkan/icd.d"
cat > "$ROOTFS_DIR/etc/vulkan/icd.d/pvr_icd.json" << 'VKEOF'
{
    "file_format_version": "1.0.0",
    "ICD": {
        "library_path": "/usr/lib/libVK_IMG.so",
        "api_version": "1.3.0"
    }
}
VKEOF
# OpenCL ICD for PowerVR
mkdir -p "$ROOTFS_DIR/etc/OpenCL/vendors"
echo '/usr/lib/libPVROCL.so' > "$ROOTFS_DIR/etc/OpenCL/vendors/pvr.icd"

cat > "$ROOTFS_DIR/etc/X11/xorg.conf.d/20-modesetting.conf" << 'XORGEOF'
Section "Device"
    Identifier  "Allwinner Graphics"
    Driver      "modesetting"
    Option      "kmsdev"        "/dev/dri/card0"
    Option      "AccelMethod"   "glamor"
    Option      "DRI"           "3"
EndSection
Section "Screen"
    Identifier  "Default Screen"
    Device      "Allwinner Graphics"
    Monitor     "Default Monitor"
    DefaultDepth 24
    SubSection "Display"
        Depth   24
    EndSubSection
EndSection
Section "Monitor"
    Identifier  "Default Monitor"
    Option      "Rotate" "normal"
EndSection
XORGEOF

# Install NPU userland (VIPLite runtime + vpm_run + test models)
AI_SDK="$REPO_ROOT/sources/ai-sdk"
AI_SDK_LIBS="$AI_SDK/viplite-tina/lib/aarch64-none-linux-gnu/v2.0"
if [ -d "$AI_SDK_LIBS" ]; then
  log "Installing NPU runtime (VIPLite v2.0)"
  cp -a "$AI_SDK_LIBS/libNBGlinker.so" "$AI_SDK_LIBS/libVIPhal.so" "$ROOTFS_DIR/usr/lib/"
  # vpm_run binary (built by 20-build-kernel.sh)
  if [ -f "$KERNEL_DIR/npu/vpm_run" ]; then
    cp "$KERNEL_DIR/npu/vpm_run" "$ROOTFS_DIR/usr/local/bin/"
    chmod 755 "$ROOTFS_DIR/usr/local/bin/vpm_run"
  fi
  # Test models (ResNet50 + YOLOv5)
  mkdir -p "$ROOTFS_DIR/usr/share/npu/models"
  for model in resnet50 yolov5; do
    if [ -f "$AI_SDK/examples/$model/model/v3/$model.nb" ]; then
      cp "$AI_SDK/examples/$model/model/v3/$model.nb" "$ROOTFS_DIR/usr/share/npu/models/"
    fi
  done
  # Test input data
  if [ -d "$AI_SDK/examples/resnet50/input_data" ]; then
    cp -a "$AI_SDK/examples/resnet50/input_data" "$ROOTFS_DIR/usr/share/npu/"
  fi
fi

# Install kernel modules and Image
log "Installing kernel"
KERNEL_MODDIR="$ROOTFS_DIR/lib/modules/$KERNEL_RELEASE"
mkdir -p "$KERNEL_MODDIR" "$ROOTFS_DIR/boot"
cp -a "$MODULES_DIR"/* "$KERNEL_MODDIR/"
# Remove vendor BSP WiFi modules (replaced by radxa-pkg/aic8800 in extra/)
rm -rf "$KERNEL_MODDIR/kernel/bsp/drivers/net/wireless/aic8800"
cp "$KERNEL_DIR/vmlinuz-6.6.98-$BOARD" "$ROOTFS_DIR/boot/vmlinuz-$KERNEL_RELEASE"
cp "$KERNEL_DIR/sun60i-a733-cubie-a7z.dtb" "$ROOTFS_DIR/boot/"
cp "$KERNEL_DIR/config-6.6.98-$BOARD" "$ROOTFS_DIR/boot/config-$KERNEL_RELEASE"
cp "$KERNEL_DIR/System.map-6.6.98-$BOARD" "$ROOTFS_DIR/boot/System.map-$KERNEL_RELEASE"

# GPU + WiFi modules are built by 20-build-kernel.sh and already in $MODULES_DIR/extra/

# depmod (host tool with --root)
depmod -b "$ROOTFS_DIR" "$KERNEL_RELEASE" 2>&1

# Auto-load hardware modules
log "Configuring module autoload"
mkdir -p "$ROOTFS_DIR/etc/modules-load.d"
cat > "$ROOTFS_DIR/etc/modules-load.d/cubie-a7z.conf" << 'EOF'
# WiFi/BT (AIC8800D80 USB, radxa-pkg/aic8800 driver)
aic_load_fw
aic8800_fdrv
# 2D hardware accelerator
g2d_sunxi
# Video Engine (Cedar)
sunxi-ve
# GPU (PowerVR BXM-4-64)
pvrsrvkm
# NPU (VeriSilicon VIP9000)
vipcore
EOF

# zram swap — critical for 1GB SKU, prevents OOM lockups under desktop use
# zram is built-in (CONFIG_ZRAM=y), no module load needed. Default comp: zstd.
cat > "$ROOTFS_DIR/etc/systemd/system/zram-swap.service" << 'ZRAMSVC'
[Unit]
Description=Configure zram0 as compressed swap
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo 256M > /sys/block/zram0/disksize && /sbin/mkswap /dev/zram0 && /sbin/swapon -p 100 /dev/zram0'
RemainAfterExit=yes
ExecStop=/sbin/swapoff /dev/zram0

[Install]
WantedBy=multi-user.target
ZRAMSVC
ln -sf /etc/systemd/system/zram-swap.service \
  "$ROOTFS_DIR/etc/systemd/system/multi-user.target.wants/zram-swap.service"

# WiFi power: radxa aic_load_fw doesn't call sunxi_wlan_set_power(),
# so we need to enable WiFi via sunxi-rfkill sysfs before the chip appears on USB.
cat > "$ROOTFS_DIR/etc/systemd/system/wifi-power.service" << 'WIFISVC'
[Unit]
Description=Enable WiFi chip power via sunxi-rfkill
Before=network-pre.target
Wants=network-pre.target
After=sys-class-misc-sunxi\x2drfkill.device

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo 1 > /sys/class/misc/sunxi-rfkill/wlan/state'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
WIFISVC
ln -sf /etc/systemd/system/wifi-power.service \
  "$ROOTFS_DIR/etc/systemd/system/multi-user.target.wants/wifi-power.service"

# Build initramfs
log "Building initramfs"
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
  do_chroot /usr/bin/env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  /usr/sbin/mkinitramfs -o "/boot/initrd.img-$KERNEL_RELEASE" "$KERNEL_RELEASE" 2>&1 | cat || true

# Boot script (U-Boot + extlinux)
log "Setting up boot scripts"
cat > "$ROOTFS_DIR/boot/boot.cmd" << 'EOF'
setenv bootargs console=ttyS0,115200 console=tty1 root=/dev/mmcblk0p2 rootwait rw cma=64M panic=10 net.ifnames=0
load mmc 0:1 $kernel_addr_r /vmlinuz-6.6.98+
load mmc 0:1 $fdt_addr_r /sun60i-a733-cubie-a7z.dtb
booti $kernel_addr_r - $fdt_addr_r
EOF
mkimage -A arm64 -O linux -T script -C none -n "Boot Script" \
  -d "$ROOTFS_DIR/boot/boot.cmd" "$ROOTFS_DIR/boot/boot.scr" 2>&1

mkdir -p "$ROOTFS_DIR/boot/extlinux"
cat > "$ROOTFS_DIR/boot/extlinux/extlinux.conf" << 'EOF'
LABEL cubie-a7z
    KERNEL /vmlinuz-6.6.98+
    FDT /sun60i-a733-cubie-a7z.dtb
    APPEND console=ttyS0,115200 console=tty1 root=/dev/mmcblk0p2 rootwait rw cma=64M panic=10 net.ifnames=0
EOF

# First-boot: expand root partition to fill SD card
mkdir -p "$ROOTFS_DIR/usr/local/sbin"
cat > "$ROOTFS_DIR/usr/local/sbin/first-boot-resize" << 'RESIZE'
#!/bin/bash
set -e
ROOT_DEV=$(findmnt -no SOURCE /)
DISK=${ROOT_DEV%p*}
PARTNUM=${ROOT_DEV##*p}
echo ", +" | sfdisk -f --no-reread --no-tell-kernel -N "$PARTNUM" "$DISK"
partx -u "$DISK"
resize2fs "$ROOT_DEV"
systemctl disable first-boot-resize.service
rm -f /etc/systemd/system/first-boot-resize.service /usr/local/sbin/first-boot-resize
RESIZE
chmod 755 "$ROOTFS_DIR/usr/local/sbin/first-boot-resize"

cat > "$ROOTFS_DIR/etc/systemd/system/first-boot-resize.service" << 'UNIT'
[Unit]
Description=Expand root partition on first boot
After=local-fs.target
ConditionPathExists=/usr/local/sbin/first-boot-resize

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/first-boot-resize

[Install]
WantedBy=multi-user.target
UNIT
mkdir -p "$ROOTFS_DIR/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/first-boot-resize.service \
  "$ROOTFS_DIR/etc/systemd/system/multi-user.target.wants/first-boot-resize.service"

# Unmount virtual filesystems before packaging
umount_chroot
rm -f "$ROOTFS_DIR/usr/bin/qemu-aarch64-static"

# Apply user overlay (custom files copied verbatim into rootfs)
USER_OVERLAY="$REPO_ROOT/overlays/rootfs"
if [ -d "$USER_OVERLAY" ] && [ "$(ls -A "$USER_OVERLAY" 2>/dev/null | grep -v .gitkeep)" ]; then
  log "Applying user overlay from overlays/rootfs/"
  cp -a "$USER_OVERLAY"/. "$ROOTFS_DIR"/
fi

log "Rootfs built at $ROOTFS_DIR ($(du -sh "$ROOTFS_DIR" | cut -f1))"
log "Creating rootfs tarball: $ROOTFS_TAR"
tar --one-file-system -cpf "$ROOTFS_TAR" -C "$ROOTFS_DIR" . 2>&1 | cat
log "Rootfs tarball: $(stat -c%s "$ROOTFS_TAR") bytes"
