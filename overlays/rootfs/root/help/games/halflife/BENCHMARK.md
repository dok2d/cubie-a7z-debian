# Half-Life Benchmark — Cubie A7Z (Allwinner A733)

## Hardware

- SoC: Allwinner A733 (4x Cortex-A55 + 4x Cortex-A76)
- GPU: PowerVR BXM-4-64 MC1 (OpenGL ES 3.2, Vulkan 1.3)
- RAM: 1 GB
- Display: 1920x1080 @ 60 Hz HDMI
- Cooling: passive heatsinks 20x20x10 mm on SoC and RAM

## Engine

- Xash3D FWGS (master), built from source on board
- Renderer: gles3compat (native OpenGL ES, no gl4es)
- SDL2 KMSDRM backend
- Game data: Steam Half-Life valve/ directory

## Results

| Mode | Renderer | FPS | Start °C | End °C | RAM |
|------|----------|----:|---------:|-------:|----:|
| KMSDRM | gles3compat | 60.0* | 66 | 68 | ~200 MB |

\* Monitor-limited (60 Hz DRM page flip).

## Notes

- **gles2 renderer has a bug**: lightmap corruption on even-numbered map
  transitions (c0a0a, c0a0c appear fully black). gles3compat fixes this.
- Map c0a0 (Black Mesa Inbound tram ride) renders correctly.
- Map transitions c0a0 → c0a0a → c0a0b all work with gles3compat.
- Temperature barely rises (+2 °C) — GPU has significant headroom.
- No timedemo mode in Xash3D; FPS measured via cl_showfps on screen.

## Commands

```
# KMSDRM (no window manager)
kmsdrm-run halflife-kmsdrm

# Under X11 desktop
halflife-x11
```
