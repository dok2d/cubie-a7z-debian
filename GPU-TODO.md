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
