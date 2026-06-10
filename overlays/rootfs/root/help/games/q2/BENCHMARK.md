# Quake II Benchmark — Cubie A7Z (Allwinner A733)

## Hardware

- SoC: Allwinner A733 (4x Cortex-A55 + 4x Cortex-A76)
- GPU: PowerVR BXM-4-64 MC1 (OpenGL ES 3.2, Vulkan 1.3)
- RAM: 1 GB
- Display: 1920x1080 @ 60 Hz HDMI
- Cooling: passive heatsinks 20x20x10 mm on SoC and RAM

## Test conditions

- Game: Yamagi Quake II, timedemo demo1 (shareware)
- Resolution: 1920x1080
- VSync: disabled where possible
- Cooldown: each test started at ≤66 °C CPU (idle ~64 °C)
- Config wiped between runs

## Results

### Group A — KMSDRM (PowerVR GPU, no window manager)

| # | SDL | Renderer | FPS | Frames | Time | Start °C | End °C | Notes |
|---|-----|----------|----:|-------:|-----:|---------:|-------:|-------|
| A1 | SDL3 | gles3 | 60.0* | 1243 | 20.7s | 64/64 | 64/64 | Primary KMSDRM mode |
| A2 | SDL3 | gl3 | 60.0* | 1309 | 21.8s | 64/64 | 65/65 | GL3 via PVR EGL |
| A3 | SDL3 | soft | — | — | — | 65/65 | 66/65 | Crashed (no KMSDRM support) |
| A4 | SDL2 | gles3 | 60.0* | 1426 | 23.8s | 65/65 | 66/66 | SDL2 comparison |
| A5 | SDL2 | gl3 | 60.0* | 1425 | 23.8s | 66/66 | 67/66 | SDL2 comparison |

\* **Monitor-limited.** KMSDRM uses DRM page flip which hard-locks to display
refresh rate (60 Hz). GPU throughput is higher but unmeasurable without a
higher refresh rate monitor. Temperature barely rises (+0–2 °C), confirming
the GPU is idle most of the frame.

### Group B — X11 Vulkan (PowerVR GPU, vsync off)

| # | SDL | Renderer | FPS | Frames | Time | Start °C | End °C | Notes |
|---|-----|----------|----:|-------:|-----:|---------:|-------:|-------|
| B1 | SDL3 | vk (master) | **67.3** | 1400 | 20.8s | 65/66 | 70/70 | **Best result** |
| B2 | SDL2 | vk (v1.0.5) | 8.9 | 188 | 21.1s | 66/67 | 86/84 | Broken swapchain |

B1 is the only mode that exceeds the 60 fps monitor cap. PVR Vulkan 1.3
via `VK_KHR_xlib_surface` under Xorg. Moderate thermal load (+5 °C).

B2 is anomalous: old ref_vk v1.0.5 with SDL2 achieves only 8.9 fps while
heating to 86 °C — indicates a busy-wait spin in swapchain presentation.
SDL3 master ref_vk is 7.5x faster.

### Group C — X11 OpenGL (llvmpipe CPU, for reference)

| # | SDL | Renderer | FPS | Frames | Time | Start °C | End °C | Notes |
|---|-----|----------|----:|-------:|-----:|---------:|-------:|-------|
| C1 | SDL3 | gles3 | 6.2 | 120 | 19.3s | 66/67 | 88/84 | llvmpipe (CPU) |
| C2 | SDL3 | gl3 | 9.1 | 188 | 20.6s | 66/67 | 86/83 | llvmpipe (CPU) |
| C3 | SDL3 | gl1 | 15.3 | 318 | 20.7s | 66/67 | 88/84 | llvmpipe (CPU) |
| C4 | SDL3 | soft | 13.3 | 269 | 20.2s | 66/66 | 74/73 | CPU software |

All OpenGL renderers under X11 fall back to **llvmpipe** (Mesa CPU rasterizer)
because Xorg loads Debian system Mesa (`/usr/lib/.../libGL.so`) instead of
PVR Mesa (`/usr/local/lib/libGL.so`). GLVND dispatch ignores PowerVR GPU.

These modes cause severe thermal load (+18–22 °C) due to 100% CPU usage on
all cores, while delivering only 6–15 fps.

C4 (software renderer) is actually cooler than C1–C3 because it uses a
simpler single-threaded path without llvmpipe's multi-core overhead.

## Summary

| Rank | Mode | FPS | GPU used | Thermal | Verdict |
|-----:|------|----:|----------|---------|---------|
| 1 | X11 + SDL3 + Vulkan | **67.3** | PowerVR VK 1.3 | +5 °C | **Fastest measurable** |
| 2 | KMSDRM + SDL3 + GLES3 | 60.0* | PowerVR GLES 3.2 | +0 °C | Monitor-limited, coolest |
| 2 | KMSDRM + SDL3 + GL3 | 60.0* | PowerVR GLES 3.2 | +1 °C | Monitor-limited |
| 2 | KMSDRM + SDL2 + GLES3 | 60.0* | PowerVR GLES 3.2 | +1 °C | Monitor-limited |
| 2 | KMSDRM + SDL2 + GL3 | 60.0* | PowerVR GLES 3.2 | +1 °C | Monitor-limited |
| 6 | X11 + SDL3 + GL1 | 15.3 | llvmpipe (CPU) | +22 °C | Wrong Mesa, avoid |
| 7 | X11 + SDL3 + soft | 13.3 | CPU | +8 °C | Software renderer |
| 8 | X11 + SDL3 + GL3 | 9.1 | llvmpipe (CPU) | +20 °C | Wrong Mesa, avoid |
| 9 | X11 + SDL2 + Vulkan | 8.9 | PowerVR VK 1.3 | +20 °C | Broken ref_vk v1.0.5 |
| 10 | X11 + SDL3 + GLES3 | 6.2 | llvmpipe (CPU) | +22 °C | Wrong Mesa, avoid |

\* DRM page flip locks to 60 Hz. Real GPU throughput exceeds 60 fps.

## Key findings

1. **SDL3 + Vulkan (X11) is the fastest mode** at 67.3 fps with only +5 °C
   thermal load. Vulkan bypasses the GLVND/Mesa conflict entirely.

2. **KMSDRM modes are all monitor-limited at 60 fps.** SDL2 and SDL3 perform
   identically. GLES3 and GL3 are indistinguishable. Temperature barely rises,
   confirming the GPU has headroom to spare.

3. **OpenGL under X11 is unusable** (6–15 fps). Xorg loads Debian llvmpipe
   instead of PVR Mesa. This is a GLVND routing issue, not a GPU limitation.

4. **SDL2 + ref_vk v1.0.5 is broken** (8.9 fps, +20 °C). The old pinned tag
   has a swapchain timing bug that causes CPU busy-wait. SDL3 master ref_vk
   is 7.5x faster.

5. **No heatsink = 88 °C peak** under CPU-bound workloads. GPU-accelerated
   modes stay below 70 °C. A heatsink (Radxa 6530B) is recommended for
   sustained desktop/gaming use.

## Recommendations

| Use case | Mode | Command |
|----------|------|---------|
| No desktop, max perf | KMSDRM + GLES3 (SDL2 or SDL3) | `kmsdrm-run quake2-kmsdrm` |
| Desktop, max perf | X11 + Vulkan (SDL3) | `quake2-yamagi` |
| Benchmarking | X11 + Vulkan (SDL3) | Only mode exceeding 60 Hz cap |

## Vulkan limitations

- `VK_KHR_display` not supported by PVR ICD — no Vulkan on KMSDRM
- `VK_KHR_xlib_surface` and `VK_KHR_xcb_surface` only — X11 required
