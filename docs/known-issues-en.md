# Known Issues — Cubie A7Z Debian

Updated: 2026-06-08

## Resolved

- **WiFi probe fail** → switched to radxa-pkg/aic8800 driver (USB, D80 native)
- **HDMI alloc failed** → cma=64M, works
- **GPU pvrsrvkm** → gpu-supply + power-domains, works
- **USB-C xhci2** → u2phy + serdes + combo PHY, HID works
- **AXP515 probe -22** → chip does not exist on board (AXP318), disabled in DTS
- **USB-C VBUS** → PL2 GPIO → SGM2576 load switch (per schematic)
- **dbus circular inclusion** → removed /etc/dbus-1/system.conf
- **Boot delay 15s** → GPU power domains (pd_gpu_top/core) uncommented
- **ext4 corruption** → CONFIG_ENV_IS_NOWHERE in U-Boot
- **Boot0 won't boot** → allwinner-device boot0 has wrong DRAM init params; using stock boot0 from Radxa rsdk-b1 image (auto-downloaded by 00-fetch-sources.sh)
- **WiFi down after boot** → /etc/network/interfaces was missing + networking.service was not enabled
- **NPU not loaded** → vipcore was missing from modules-load.d
- **rfkill errors in dmesg** → removed empty power_en/pinctrl/clocks properties from DTS
- **SSH Permission denied** → sshd_config did not enable PasswordAuthentication; added drop-in to sshd_config.d/
- **SSH libwrap/libwtmpdb** → added libwrap0, libwtmpdb0 to rootfs packages
- **Hostname = container ID** → $HOSTNAME clashed with bash builtin; renamed to TARGET_HOSTNAME
- **GPU build /gcc not found** → LICHEE_TOOLCHAIN_PATH/LICHEE_CROSS_COMPILER were unset; fixed
- **GPU .SECONDARY/.NOTINTERMEDIATE** → GNU Make 4.4+ conflict; .SECONDARY patched at build time
- **CPU freq scaling** → schedutil works: A55 up to 1794 MHz, A76 up to 2002 MHz (previously thought broken)
- **GPU software rendering** → PVR Mesa from allwinner-target overlay was in rootfs but not activated. Fix: `LD_LIBRARY_PATH=/usr/local/lib` in `/etc/environment`, `AccelMethod "glamor"` in Xorg config, `libxcb-dri2-0` package. Result: `glamor X acceleration enabled on PowerVR B-Series BXM-4-64`

## Open

### UFS: link_startup_fail
- **Chip is not soldered** on this board SKU. DTS node kept for compatibility.
- Does not affect operation — dmesg errors at boot are expected.

### GLX still reports llvmpipe
- Xorg glamor uses EGL+PVR hardware (confirmed working)
- But `glxinfo` shows llvmpipe because Debian GLVND dispatches GLX to system Mesa
- Does not affect actual rendering — glamor bypasses GLX
- Firefox/apps using EGL get hardware acceleration; GLX-only apps fall back to software

### ET7304Y TCPC: probe failed -22
- Chip found on I2C bus 14 addr 0x4E
- Generic `tcpci` driver returns -EINVAL
- USB-C host works without PD negotiation (via usbc2 DTS node)
- **What fixing it unlocks**: USB-C PD charging, DP Alt Mode via typec framework
- Needs vendor-specific driver or proper port/connector nodes

### Rootfs: dpkg-deb -x does not resolve dependencies
- Shared libs (libwrap0, libwtmpdb0, etc.) are added manually to PACKAGES
- Each new utility may require new libs
- **What fixing it unlocks**: mmdebstrap auto-resolves all dependencies
- Blocker: mmdebstrap requires binfmt_misc, unavailable in container without --privileged

### TWI2: SCL stuck low
- Disabled in DTS. No devices connected on 40-pin I2C2.

### regulatory.db
- `cfg80211: failed to load regulatory.db` — wireless-regdb firmware not installed
- WiFi works in permissive mode
- **What fixing it unlocks**: correct TX power limits per country, clean dmesg
