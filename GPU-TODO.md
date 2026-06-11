# GPU Acceleration TODO — Cubie A7Z (PowerVR BXM-4-64)

## IMPORTANT: GPU works in Radxa OS!

Radxa's official image has **working GPU acceleration** with the same DDK 24.2.6603887:

```
GL_VENDOR: Imagination Technologies
GL_RENDERER: PowerVR B-Series BXM-4-64
GL_VERSION: OpenGL ES 3.2 build 24.2@6603887
glmark2: 450-565 FPS
```

Source: [geerlingguy/sbc-reviews#100](https://github.com/geerlingguy/sbc-reviews/issues/100),
[smarthomecircle.com review](https://smarthomecircle.com/radxa-cubie-a7z-my-experience)

The vendor PVR libraries in `/usr/lib/` are the same DDK version. Radxa ships a
**custom Mesa + Xorg** in their overlay (allwinner-target), already copied to our rootfs.

**What Radxa ships** (from allwinner-target overlay):
- Custom Mesa with pvr gallium in `/usr/local/lib/` + `/usr/local/lib/dri/pvr_dri.so`
- `sunxi-drm_dri.so` + `swrast_dri.so` in `/usr/local/lib/dri/`
- Custom `Xorg` binary, `modesetting_drv.so`, `libglamoregl.so` in `/usr/lib/xorg/`
- `LD_LIBRARY_PATH=/usr/local/lib` in `/etc/environment`
- `libpvr_mesa_wsi.so` (PVR Window System Interface)
- All these files ARE already in our rootfs after build

**What we tried and what happened**:
1. Set `AccelMethod "glamor"` + `DRI "3"` in Xorg config → **Xorg SIGABRT** at glamor EGL init
2. `/usr/local/lib/` added to ldconfig → EGL/GLES resolve there, but GLX still dispatches to Debian Mesa
3. `LD_LIBRARY_PATH=/usr/local/lib` in `/etc/environment` → doesn't help GLX (GLVND ignores it)
4. Without these changes, falls back to llvmpipe (CPU software rendering)

**Root cause**: Debian GLVND (`libGL.so.1` → `libGLX_mesa.so.0`) hardcodes DRI search
path to `/usr/lib/aarch64-linux-gnu/dri/`. Custom Mesa in `/usr/local/lib/` is ignored.
Radxa's custom Xorg binary may be linked directly against `/usr/local/lib/libEGL.so`
bypassing GLVND, but when Debian's GLVND intercepts, glamor crashes.

**Next steps**:
1. Download Radxa OS rsdk-r6 image and compare the running state (`ldd /usr/lib/xorg/Xorg`,
   `strace -e openat Xorg` to see which libs it actually loads)
2. Check if Debian GLVND libs need to be replaced/removed so `/usr/local/lib/` takes over
3. Try `__EGL_VENDOR_LIBRARY_DIRS=/usr/local/lib` environment for Xorg
4. Try removing `/usr/lib/aarch64-linux-gnu/libEGL*` so only PVR Mesa remains
5. Check if Radxa runs Xorg via wrapper that sets `LD_PRELOAD` or `LD_LIBRARY_PATH`

## GLVND Research Results (2026-06-10)

### How Radxa Actually Solves It

Inspected `radxa/allwinner-target` branch `target-a733-v1.4.6`. The approach is:

1. **Non-GLVND Mesa build** -- Radxa's PVR Mesa in `/usr/local/lib/` is built
   **without** `-Dglvnd=enabled`. The libraries have classic SONAMEs:
   - `libEGL.so.1` (NOT `libEGL_mesa.so.0`)
   - `libGLESv2.so.2` (NOT `libGLESv2_mesa.so.2`)
   - `libgbm.so.1`, `libglapi.so.0`

2. **DRI megadriver with sunxi-drm alias** -- All three DRI drivers are
   identical files (same md5):
   - `pvr_dri.so` = `sunxi-drm_dri.so` = `swrast_dri.so` (15MB each)
   - Built with `-Dgallium-pvr-alias=sunxi-drm` (TI equivalent: `tidss`)
   - When Mesa DRI loader queries card0 (`sunxi-drm`), it finds `sunxi-drm_dri.so`
     which IS the PVR gallium driver

3. **Custom Xorg + glamor** -- Radxa ships a custom-built Xorg binary (2.4MB)
   and `libglamoregl.so` + `modesetting_drv.so` in `/usr/lib/xorg/modules/`.
   The Xorg binary has NO hardcoded RPATH to `/usr/local/lib`.

4. **LD_LIBRARY_PATH in lightdm.service** -- The critical piece:
   ```ini
   [Service]
   #IMG GPU LIB PATH
   Environment="LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH"
   ```
   This makes lightdm (and its child Xorg) resolve `libEGL.so.1` from
   `/usr/local/lib/` BEFORE the system path, bypassing Debian's GLVND stack.

5. **DRI search path** -- With `LD_LIBRARY_PATH=/usr/local/lib`, Mesa's DRI
   loader finds drivers in `/usr/local/lib/dri/` (relative to the libEGL.so
   location), where `sunxi-drm_dri.so` lives.

6. **Xorg config** -- `AccelMethod "none"`, `DRI "2"` (NOT glamor, NOT DRI3).
   GPU acceleration comes from Mesa DRI, not Xorg glamor compositing.

### Why Our Current Setup Fails

The problem is that Debian Trixie's GLVND intercepts library loading:

```
App calls eglGetDisplay()
  -> resolves to /usr/lib/aarch64-linux-gnu/libEGL.so.1 (GLVND dispatcher)
     -> reads /usr/share/glvnd/egl_vendor.d/50_mesa.json
        -> loads libEGL_mesa.so.0 (Debian system Mesa)
           -> DRI loader searches /usr/lib/aarch64-linux-gnu/dri/
              -> no sunxi-drm_dri.so found -> falls back to llvmpipe
```

Even with `LD_LIBRARY_PATH=/usr/local/lib`, GLVND's `libEGL.so.1` (from
`/usr/lib/aarch64-linux-gnu/`) has the same SONAME as PVR Mesa's `libEGL.so.1`.
The dynamic linker loads whichever it finds first based on the search order.
But Xorg is typically started by lightdm which inherits from systemd, where
`/usr/lib/aarch64-linux-gnu/` is baked into the linker cache.

### GLVND Architecture (Reference)

GLVND vendor dispatch works via JSON manifests:

- **Default search paths**: `/etc/glvnd/egl_vendor.d/` then `/usr/share/glvnd/egl_vendor.d/`
- **Override**: `__EGL_VENDOR_LIBRARY_DIRS` (colon-separated dirs)
- **Override**: `__EGL_VENDOR_LIBRARY_FILENAMES` (colon-separated JSON files)
- **Priority**: lower-numbered files = higher priority (`10_nvidia.json` > `50_mesa.json`)
- **Ignored for setuid**: all env vars ignored for setuid binaries (Xorg!)

JSON format:
```json
{
    "file_format_version": "1.0.0",
    "ICD": {
        "library_path": "libEGL_mesa.so.0"
    }
}
```

**GLX dispatch** (separate from EGL): `libGLX.so.0` dispatches to `libGLX_mesa.so.0`.
There is NO `__GLX_VENDOR_LIBRARY_*` equivalent -- GLX vendor is selected per-screen
by the X server's GLX extension.

### Solution Options (Ranked by Practicality)

#### Option A: ld.so.conf.d Priority Override (RECOMMENDED, simplest)

Make `/usr/local/lib` take priority over system paths globally:

```bash
echo "/usr/local/lib" > /etc/ld.so.conf.d/00-pvr-mesa.conf
ldconfig
```

**How it works**: The dynamic linker resolves `libEGL.so.1` to
`/usr/local/lib/libEGL.so.1` (PVR Mesa) instead of
`/usr/lib/aarch64-linux-gnu/libEGL.so.1` (GLVND dispatcher).
Since PVR Mesa is non-GLVND, it handles EGL directly and loads
`sunxi-drm_dri.so` from `/usr/local/lib/dri/`.

**Also needed**: lightdm.service `Environment` line (already present from Radxa overlay).

**Risks**:
- Replaces GLVND dispatch globally -- no multi-vendor GPU support
- `apt upgrade` of `libegl1` may overwrite the symlink (ldconfig re-runs)
- Any package depending on `libEGL_mesa.so.0` won't find it via /usr/local/lib
- Need to also put `/usr/local/lib` in lightdm.service Environment (systemd
  services don't use ld.so.conf for their own PATH, but child processes do)

**Mitigation**: Pin/hold mesa packages: `apt-mark hold libegl1 libgles2 libgl1-mesa-dri`

#### Option B: Replace Debian Mesa DRI Drivers (Surgical)

Keep GLVND, but replace the DRI drivers that GLVND's Mesa backend loads:

```bash
# Copy PVR megadriver into system DRI path
cp /usr/local/lib/dri/pvr_dri.so /usr/lib/aarch64-linux-gnu/dri/
cp /usr/local/lib/dri/sunxi-drm_dri.so /usr/lib/aarch64-linux-gnu/dri/
cp /usr/local/lib/dri/swrast_dri.so /usr/lib/aarch64-linux-gnu/dri/

# Also need PVR support libs in system path
cp /usr/lib/libpvr_dri_support.so* /usr/lib/aarch64-linux-gnu/
cp /usr/lib/libsrv_um.so* /usr/lib/aarch64-linux-gnu/
cp /usr/lib/libpvr_mesa_wsi.so /usr/lib/aarch64-linux-gnu/
# ... and other PVR vendor libs that pvr_dri.so depends on
```

**How it works**: GLVND -> `libEGL_mesa.so.0` -> DRI loader -> finds
`sunxi-drm_dri.so` in standard path -> PVR gallium renders on GPU.

**Risks**:
- `apt upgrade` of `libgl1-mesa-dri` will overwrite `sunxi-drm_dri.so` etc.
- Version mismatch: PVR Mesa DRI driver may not be ABI-compatible with
  Debian's `libEGL_mesa.so.0` (different Mesa builds)
- **LIKELY TO FAIL**: PVR DRI drivers are linked against PVR Mesa's `libglapi.so`,
  not Debian Mesa's. The internal Mesa ABI must match exactly.

**Mitigation**: Use `dpkg-divert` to protect files:
```bash
dpkg-divert --local --rename --add /usr/lib/aarch64-linux-gnu/dri/sunxi-drm_dri.so
```

#### Option C: Build PVR Mesa as GLVND Vendor (Ideal but Complex)

Rebuild PVR Mesa with `-Dglvnd=enabled` so it produces:
- `libEGL_pvr.so.0` (GLVND EGL vendor library)
- `libGLX_pvr.so.0` (GLVND GLX vendor library)

Install vendor JSON: `/etc/glvnd/egl_vendor.d/10_pvr.json`:
```json
{
    "file_format_version": "1.0.0",
    "ICD": {
        "library_path": "/usr/local/lib/libEGL_pvr.so.0"
    }
}
```

**How it works**: GLVND dispatcher loads PVR vendor first (priority 10 < 50),
PVR Mesa handles EGL for the PowerVR device, system Mesa handles llvmpipe
fallback.

**Risks**:
- Requires cross-compiling Mesa from Allwinner BSP source with modifications
- GLX vendor selection is per-X-screen, not per-device -- may not work for
  the card0 (sunxi-drm) + card1 (pvr) split
- No known working example of this for PowerVR

#### Option D: Remove Debian GLVND, Go Full PVR Mesa (Nuclear)

```bash
apt remove --purge libegl1 libgles2 libglx0 libgl1 libglvnd0
# Now only /usr/local/lib has EGL/GLES/GL
ldconfig
```

**How it works**: With GLVND gone, `libEGL.so.1` resolves only to PVR Mesa.

**Risks**:
- Breaks many Debian packages that depend on libegl1, libgles2, etc.
- `apt` will want to remove desktop packages (xfce4, firefox, etc.)
- Very hard to recover from

**Not recommended.**

#### Option E: Xorg Wrapper Script

Instead of modifying system libraries, wrap the Xorg binary:

```bash
mv /usr/bin/Xorg /usr/bin/Xorg.real
cat > /usr/bin/Xorg << 'EOF'
#!/bin/sh
export LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH}
exec /usr/bin/Xorg.real "$@"
EOF
chmod +x /usr/bin/Xorg
```

**Problem**: Xorg is typically setuid root. `LD_LIBRARY_PATH` is **ignored**
for setuid binaries by the dynamic linker (security measure). Radxa's Xorg
is NOT setuid (runs as root via lightdm), so this works for them but may
not work on all Debian setups.

### Recommended Implementation Plan

**Phase 1 -- Match Radxa's Approach (Quick Fix)**:

1. Add `LD_LIBRARY_PATH=/usr/local/lib` to lightdm.service
   (already done via Radxa overlay)
2. Create `/etc/ld.so.conf.d/00-pvr-mesa.conf` with `/usr/local/lib`
3. Run `ldconfig`
4. Ensure Xorg is NOT setuid: `chmod 0755 /usr/bin/Xorg`
   (lightdm runs Xorg as root anyway)
5. Verify with `DISPLAY=:0 glxinfo | grep renderer`

**Phase 2 -- Proper Integration (Build from Source)**:

1. Cross-compile Mesa with PVR gallium + sunxi-drm alias:
   ```
   meson setup build-pvr \
     -Dgallium-drivers=pvr,swrast \
     -Dgallium-pvr-alias=sunxi-drm \
     -Dvulkan-drivers=imagination-experimental \
     -Dglvnd=disabled \
     -Degl=enabled -Dgles1=enabled -Dgles2=enabled \
     -Dplatforms=x11 -Dglx=dri -Ddri3=enabled \
     -Dprefix=/usr --libdir=/usr/lib/aarch64-linux-gnu
   ```
2. Install to system paths, replacing Debian Mesa
3. Use `dpkg-divert` + `apt-mark hold` to prevent overwrites

**Phase 3 -- GLVND-Clean (Future)**:

1. Build PVR Mesa with `-Dglvnd=enabled`
2. Install as GLVND vendor alongside system Mesa
3. Create proper EGL vendor JSON

### Key Reference: TI AM62/AM67 Build Guide

TI's Processor SDK for AM67 (same BXM-4-64 GPU) uses:
- `-Dgallium-drivers=pvr` with `-Dgallium-pvr-alias=tidss`
- The alias creates `tidss_dri.so` -> `pvr_dri.so` megadriver
- For Allwinner: use `-Dgallium-pvr-alias=sunxi-drm` instead

## Current State

Board has **two DRI devices**:

| Card | Driver | Device | Role | KMS dumb buffer |
|------|--------|--------|------|-----------------|
| card0 | sunxi-drm | `/dev/dri/card0` | Display controller (HDMI) | Yes |
| card1 | pvrsrvkm | `/dev/dri/card1`, `/dev/dri/renderD128` | 3D GPU | No |

- **Xorg** uses card0 (modesetting) with `AccelMethod "none"`, `glamor disabled`
- **Rendering** = llvmpipe (CPU software), `glxinfo` → `llvmpipe (LLVM 19.1.7)`
- **Firefox** uses ~190% CPU + 460MB RAM due to software compositing
- **pvrsrvkm** kernel module loaded, PVR DDK v24.2 (vendor BSP)
- **Vendor PVR libraries** installed in `/usr/lib/` (from allwinner-target overlay)

## Vendor Libraries Present

```
/usr/lib/libsrv_um.so                   # PVR services usermode
/usr/lib/libpvr_dri_support.so          # DRI support shim
/usr/lib/libGLESv2_PVR_MESA.so          # GLES2 via Mesa GLVND
/usr/lib/libGLESv1_CM_PVR_MESA.so       # GLES1 via Mesa GLVND
/usr/lib/libVK_IMG.so                   # Vulkan ICD
/usr/lib/libPVROCL.so                   # OpenCL
/usr/lib/libPVRScopeServices.so         # GPU profiling
/usr/lib/libglslcompiler.so             # GLSL compiler
/usr/lib/libusc.so                      # Unified Shading Cluster
/usr/lib/libufwriter.so                 # Firmware writer
/usr/lib/libsutu_display.so             # Display support
```

All are proprietary, version 24.2.6603887.

## Why It Doesn't Work

1. **Debian Mesa 25.0.7** is NOT compiled with `-Dgallium-drivers=pvr`
2. No `pvr_dri.so` in `/usr/lib/aarch64-linux-gnu/dri/` (Mesa DRI search path)
3. Mesa DRI loader selects driver by device name: card0 = `sunxi-drm` → looks for `sunxi-drm_dri.so` → not found → llvmpipe
4. card1 (PVR) has no KMS → cannot be primary display → Xorg won't use it
5. EGL vendor JSON (`/usr/share/glvnd/egl_vendor.d/`) points only to Mesa, not PVR
6. PRIME GPU offload (`DRI_PRIME=1`) fails because Mesa has no pvr backend

## What Was Tried (and failed)

- Symlink `/usr/lib/aarch64-linux-gnu/dri/pvr_dri.so` → `/usr/lib/libpvr_dri_support.so` — Mesa DRI loader ignores it (wrong API)
- PVR EGL vendor JSON — no effect on GLX path
- `DRI_PRIME=1`, `MESA_LOADER_DRIVER_OVERRIDE=pvr` — Mesa has no pvr driver compiled in

## Solution: Build Mesa with PVR Gallium Driver

### Upstream Support

Mesa 25.3+ has `pvr` gallium driver. From [Mesa docs](https://docs.mesa3d.org/drivers/powervr.html):

> BXM-4-64 (B-Series, 36.56.104.183) — Vulkan 1.2 (actively developed)

This is exactly our GPU (`BVNC 36.56.104.183` per Xorg config).

### Build Plan

#### Step 1: Cross-compile Mesa with PVR

```bash
# Meson cross-compile for aarch64
meson setup build-pvr \
  --cross-file aarch64-cross.txt \
  -Dgallium-drivers=pvr,swrast \
  -Dvulkan-drivers=imagination-experimental \
  -Dglx=dri \
  -Degl=enabled \
  -Dgles1=enabled \
  -Dgles2=enabled \
  -Dplatforms=x11 \
  -Ddri3=enabled \
  -Dllvm=enabled \
  -Dprefix=/usr

ninja -C build-pvr
DESTDIR=/tmp/mesa-pvr ninja -C build-pvr install
```

Key outputs needed:
- `/usr/lib/aarch64-linux-gnu/dri/pvr_dri.so` — gallium DRI driver
- `/usr/lib/aarch64-linux-gnu/libvulkan_powervr.so` — Vulkan ICD

#### Step 2: Install on Board

```bash
# Replace system Mesa DRI modules (backup first!)
cp /tmp/mesa-pvr/usr/lib/aarch64-linux-gnu/dri/pvr_dri.so /usr/lib/aarch64-linux-gnu/dri/
# Or for sunxi-drm display card:
ln -sf pvr_dri.so /usr/lib/aarch64-linux-gnu/dri/sunxi-drm_dri.so
```

#### Step 3: Configure Xorg

Update `/etc/X11/xorg.conf.d/` — remove `AccelMethod "none"`, enable glamor:

```
Section "Device"
    Identifier  "Allwinner Graphics"
    Driver      "modesetting"
    Option      "kmsdev"        "/dev/dri/card0"
    Option      "AccelMethod"   "glamor"
    Option      "DRI"           "3"
EndSection
```

#### Step 4: Configure GLVND for PVR EGL

Create `/usr/share/glvnd/egl_vendor.d/10_pvr.json`:
```json
{
    "file_format_version": "1.0.0",
    "ICD": {
        "library_path": "libEGL_pvr.so"
    }
}
```

#### Step 5: Vulkan ICD

Create `/etc/vulkan/icd.d/pvr.json`:
```json
{
    "file_format_version": "1.0.0",
    "ICD": {
        "library_path": "/usr/lib/libVK_IMG.so",
        "api_version": "1.2.0"
    }
}
```

### Risks and Unknowns

1. **pvrsrvkm version mismatch** — vendor kernel module is DDK v24.2, Mesa pvr driver expects a specific firmware/DDK interface. May need matching versions.

2. **card0/card1 split** — display is on card0 (sunxi-drm), GPU is card1 (PVR). Mesa pvr gallium provides `pvr_dri.so` which talks to card1, but Xorg modesetting is on card0. Need to verify that glamor on card0 can offload to card1 via render nodes.

3. **No DRM render-only support in sunxi-drm** — Xorg modesetting may not support GPU offload from a separate render-only device without PRIME.

4. **Firmware path** — Mesa pvr driver loads firmware from `/lib/firmware/powervr/`. Vendor BSP may use different paths.

5. **Mesa build dependencies** — LLVM, libdrm, libclc, etc. Cross-compiling Mesa is non-trivial.

### Alternative: Vendor DDK Xorg Driver

If Mesa path fails, look for:
- `pvr_drv.so` (Xorg DDX driver) in allwinner-target or Radxa repos
- Imagination DDK release for Allwinner A733
- Orange Pi 4 Pro GPU packages (same SoC)

### Verification

After any change, test with:

```bash
# GLX renderer (should not be llvmpipe)
DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0 glxinfo | grep renderer

# EGL info
eglinfo

# Vulkan
vulkaninfo --summary

# glmark2 benchmark
apt install glmark2
DISPLAY=:0 glmark2

# Firefox compositing
about:support → Graphics → Compositing (should be "WebRender" not "Basic")
```

### References

- [Mesa PowerVR docs](https://docs.mesa3d.org/drivers/powervr.html)
- [Imagination open-source GPU driver](https://developer.imaginationtech.com/solutions/open-source-gpu-driver/)
- [TI AM67 PVR build guide](https://software-dl.ti.com/jacinto7/esd/processor-sdk-linux-am67/10_01_08_01/exports/docs/linux/Foundational_Components/Graphics/Rogue/Build_Guide.html) (same GPU family, useful reference)
- [ChromeOS pvr_dri patch](https://chromium.googlesource.com/chromiumos/overlays/chromiumos-overlay/+/master/media-libs/mesa-img/files/0001-dri-pvr-Introduce-PowerVR-DRI-driver.patch)
- Xorg config: `/etc/X11/xorg.conf.d/` on board
- PVR kernel module: `/usr/lib/modules/6.6.98+/extra/pvrsrvkm.ko`
- Board BVNC: `36.56.104.183` (from Xorg log and GPU build config)
