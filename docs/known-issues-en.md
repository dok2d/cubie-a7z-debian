# Known Issues — Cubie A7Z Debian

Updated: 2026-06-11

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

### X11 Window Managers and GPU Acceleration: GLVND Conflict

**Summary**: GPU hardware acceleration works, but the path to it differs
between EGL and GLX. X11 desktops use hardware-accelerated glamor compositing,
but `glxinfo` reports software rendering (llvmpipe).

**Architecture — two DRI devices**:

| Card | Driver | KMS | Role |
|------|--------|-----|------|
| card0 | sunxi-drm | Yes | Display controller (HDMI output) |
| card1 | pvrsrvkm | No | 3D GPU (PowerVR BXM-4-64), render-only |

Xorg uses card0 (modesetting driver) for display. GPU acceleration comes from
card1 via EGL → PVR Mesa → pvrsrvkm → renderD128.

**How it works**: Radxa ships a non-GLVND PVR Mesa build in `/usr/local/lib/`
(with `sunxi-drm_dri.so` as an alias for `pvr_dri.so`). The Xorg process loads
these libraries via `LD_LIBRARY_PATH=/usr/local/lib`, bypassing Debian's GLVND
dispatcher. Glamor acceleration uses the EGL path directly.

**The GLVND conflict**:

```
EGL path (works):
  App → /usr/local/lib/libEGL.so.1 (PVR Mesa, non-GLVND)
    → /usr/local/lib/dri/sunxi-drm_dri.so (PVR gallium)
      → pvrsrvkm → GPU hardware ✓

GLX path (software):
  App → /usr/lib/aarch64-linux-gnu/libGL.so.1 (Debian GLVND)
    → libGLX_mesa.so.0 (system Mesa)
      → /usr/lib/aarch64-linux-gnu/dri/ (no sunxi-drm_dri.so here)
        → llvmpipe (CPU software rendering) ✗
```

**What works**:
- `glamor X acceleration enabled on PowerVR B-Series BXM-4-64` — confirmed in Xorg.log
- X11 WMs (XFCE, i3, LXQt) via lightdm/sddm — compositing is hardware-accelerated
- EGL-based apps (GLES games, glmark2-es2, Chromium with `--use-gl=egl`)
- Vulkan apps (via `/usr/lib/libVK_IMG.so`, ICD registered)
- OpenCL (`/usr/lib/libPVROCL.so`)
- KMSDRM gaming (Quake II 60fps, Half-Life 60fps) — bypasses X11 entirely

**What doesn't work**:
- `glxinfo` reports `llvmpipe (LLVM 19.1.7)` — this is the GLX path through GLVND
- Desktop apps that use GLX-only rendering (rare) fall back to software
- Firefox compositing uses software mode (190% CPU, 460 MB RAM) unless forced to EGL
- `glmark2` (non-es2 version) uses GLX → software; use `glmark2-es2` instead

**Wayland WMs** (sway, labwc) avoid this problem entirely — they use EGL natively
with `WLR_DRM_DEVICES=/dev/dri/card0`, and PVR Mesa handles rendering via EGL.

**Workaround for GLX apps**:
```bash
# Force apps to use EGL instead of GLX (where supported)
export __GLX_VENDOR_LIBRARY_NAME=mesa
export MESA_LOADER_DRIVER_OVERRIDE=pvr

# For Firefox specifically
MOZ_X11_EGL=1 firefox
```

**Potential fixes** (see GPU-TODO.md for full analysis):
1. **ld.so.conf.d priority** — add `/usr/local/lib` to global linker path
   (makes PVR Mesa's `libEGL.so.1` take precedence over GLVND)
2. **Replace DRI drivers** — copy `sunxi-drm_dri.so` into system DRI path
   (risk: Mesa ABI mismatch between PVR build and Debian Mesa)
3. **Build PVR Mesa as GLVND vendor** — rebuild with `-Dglvnd=enabled`,
   install as `/etc/glvnd/egl_vendor.d/10_pvr.json` (ideal but complex)

**Impact on WM choice**:

| WM | Protocol | Acceleration | Notes |
|----|----------|-------------|-------|
| XFCE4 | X11 | glamor (EGL) | Recommended. ~300 MB install. GPU compositing works. |
| i3 | X11 | glamor (EGL) | Lightweight tiling. ~200 MB. Same GPU path as XFCE. |
| LXQt | X11 | glamor (EGL) | Qt-based. ~350 MB. Same GPU path. |
| sway | Wayland | EGL native | No GLVND issue. 200 MB. Use `WLR_DRM_DEVICES=/dev/dri/card0`. |
| labwc | Wayland | EGL native | No GLVND issue. 150 MB. Lightest with GPU. |
| KMSDRM | None | EGL native | No WM overhead. Best for games. No desktop. |

**Recommendation**: For desktop use, XFCE4 or i3 are proven stable. Glamor
compositing is hardware-accelerated. The GLX/llvmpipe issue is cosmetic for
most use cases (desktop compositing, web browsing, terminal work). For GPU
benchmarking or gaming, use `glmark2-es2` (EGL) or KMSDRM mode.

### ET7304Y TCPC: probe failed -22 → Resolved

- **ET7304Y TCPC probe -22** → backported upstream patches
  (Yuanshen Cao v3 + Charkov v3 fallback compatible). ET7304 is RT1715-compatible
  with VID 0x6DCF. Driver: `tcpci_rt1711h`. Compatible:
  `"etekmicro,et7304","richtek,rt1715"`. Verified by `test-typec.sh`.
- USB-C PD negotiation and role switching now work through mainline TCPM framework.
- **DP Alt Mode status**: Full DP Alt Mode pipeline implemented:
  - `sunxi-phy-switcher` handles orientation + USB↔DP mode switching via combo PHY
  - `edp0` enabled as DP source (`compatible = "allwinner,drm-dp"`)
  - `tv1` (tcon4) timing controller enabled for DP pipe
  - Signal path: DE → tcon4 → edp0 → combo0_dp → phy_switcher → USB-C
  - **Needs hardware testing**: lane_invert values may need board-specific tuning.
    If DP output doesn't work, try `lane_invert = <1 1 1 1>` in serdes combophy0.

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
