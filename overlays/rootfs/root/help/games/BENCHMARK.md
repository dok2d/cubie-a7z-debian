# Game Benchmarks — Cubie A7Z (Allwinner A733)

## Hardware

- SoC: Allwinner A733 (4x Cortex-A55 + 4x Cortex-A76)
- GPU: PowerVR BXM-4-64 MC1 (OpenGL ES 3.2, Vulkan 1.3)
- RAM: 1 GB
- Display: 1920x1080 @ 60 Hz HDMI
- Cooling: passive heatsinks 20x20x10 mm on SoC and RAM

## Test conditions

- Resolution: native HDMI (1920x1080)
- VSync: disabled where possible (KMSDRM is always vsync-locked)
- Cooldown: each test started at ≤66 °C CPU (idle ~64 °C)
- Config wiped between runs

---

## Quake II (Yamagi)

Timedemo: demo1 (shareware), 1920x1080.

### KMSDRM (PowerVR GPU, no window manager)

| SDL | Renderer | FPS | Frames | Time | Temp +/- | Notes |
|-----|----------|----:|-------:|-----:|---------:|-------|
| SDL3 | gles3 | 60.0* | 1243 | 20.7s | +0 °C | Primary KMSDRM mode |
| SDL3 | gl3 | 60.0* | 1309 | 21.8s | +1 °C | GL3 via PVR EGL |
| SDL2 | gles3 | 60.0* | 1426 | 23.8s | +1 °C | SDL2 comparison |
| SDL2 | gl3 | 60.0* | 1425 | 23.8s | +1 °C | SDL2 comparison |
| SDL3 | soft | — | — | — | — | Crashed |

### X11 Vulkan (PowerVR GPU, vsync off)

| SDL | Renderer | FPS | Frames | Time | Temp +/- | Notes |
|-----|----------|----:|-------:|-----:|---------:|-------|
| SDL3 | vk (master) | **67.3** | 1400 | 20.8s | +5 °C | **Fastest measurable** |
| SDL2 | vk (v1.0.5) | 8.9 | 188 | 21.1s | +20 °C | Broken swapchain |

### X11 OpenGL (llvmpipe CPU — GLVND conflict)

| SDL | Renderer | FPS | Temp +/- | Notes |
|-----|----------|----:|---------:|-------|
| SDL3 | gl1 | 15.3 | +22 °C | llvmpipe CPU fallback |
| SDL3 | soft | 13.3 | +8 °C | CPU software |
| SDL3 | gl3 | 9.1 | +20 °C | llvmpipe CPU fallback |
| SDL3 | gles3 | 6.2 | +22 °C | llvmpipe CPU fallback |

---

## Half-Life (Xash3D FWGS)

Map: c0a0 (Black Mesa Inbound), 30 second run, 1920x1080.

| Mode | Renderer | FPS | Temp +/- | Notes |
|------|----------|----:|---------:|-------|
| KMSDRM | gles3compat | 60.0* | +2 °C | **Native GLES on PowerVR, verified working** |

- gles2 renderer has lightmap corruption on some map transitions
- gles3compat fixes this on PowerVR BXM-4-64
- RAM usage: ~200 MB (game running)

---

## Notes

\* **Monitor-limited.** KMSDRM uses DRM page flip which locks to display
refresh rate (60 Hz). Real GPU throughput is higher but unmeasurable
without a higher refresh rate monitor. Temperature barely rises,
confirming the GPU is idle most of the frame.

## Key findings

1. **SDL3 + Vulkan (X11) is the fastest measurable mode** — 67.3 fps.
   Vulkan bypasses the GLVND/Mesa conflict entirely.

2. **KMSDRM modes are all monitor-limited at 60 fps.** SDL2 and SDL3
   perform identically. Temperature stays below 68 °C.

3. **OpenGL under X11 is unusable** (6–15 fps). Xorg loads Debian
   llvmpipe instead of PVR Mesa (GLVND routing issue).

4. **Half-Life runs at 60 fps on KMSDRM** with native GLES via Xash3D.
   Use `gles3compat` renderer (not `gles2`) for correct map transitions.

## Rendering paths

| Path | GPU | Performance | Use case |
|------|-----|-------------|----------|
| KMSDRM + GLES3/gles3compat | PowerVR | 60 fps (vsync) | No WM, max efficiency |
| X11 + Vulkan | PowerVR | 67+ fps | Desktop, benchmarking |
| X11 + OpenGL | llvmpipe (CPU) | 6–15 fps | **Broken — avoid** |

## Vulkan limitations

- PVR ICD supports `VK_KHR_xlib_surface` / `VK_KHR_xcb_surface` only
- `VK_KHR_display` absent — no Vulkan on KMSDRM
- Vulkan works only under X11
