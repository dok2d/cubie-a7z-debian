# Cubie A7Z Debian

Reproducible Debian Trixie (arm64) image builder for the **Radxa Cubie A7Z** — a compact SBC powered by the Allwinner A733 octa-core SoC.

```bash
root@cubie-a7z:~# screenfetch
         _,met$$$$$gg.           root@cubie-a7z
      ,g$$$$$$$$$$$$$$$P.        OS: Debian
    ,g$$P""       """Y$$.".      Kernel: aarch64 Linux 6.6.98+
   ,$$P'              `$$$.      Uptime: 2m
  ',$$P       ,ggs.     `$$b:    Packages: 676
  `d$$'     ,$P"'   .    $$$     Shell: bash 5.2.37
   $$P      d$'     ,    $$P     Disk: 2.3G / 62G (4%)
   $$:      $$.   -    ,d$$'     CPU: ARM Cortex-A55 Cortex-A76 @ 8x 1.794GHz
   $$\;      Y$b._   _,d$P'      RAM: 230MiB / 891MiB
   Y$$.    `.`"Y$$$$P"'
   `$$b      "-.__
    `Y$$
     `Y$$.
       `$$b.
         `Y$$b.
            `"Y$b._
                `""""
```

> WiFi, GPU, NPU, HDMI, USB-C, Bluetooth, PCIe — all working out of the box.

## Hardware at a Glance

| | |
|---|---|
| **SoC** | Allwinner A733 — 2x Cortex-A76 + 6x Cortex-A55 |
| **GPU** | PowerVR BXM-4-64 (OpenGL ES 3.2 / Vulkan 1.3) |
| **NPU** | VeriSilicon VIP9000, 3 TOPS @ INT8 |
| **RAM** | LPDDR4X (1 / 4 / 8 / 16 GB depending on SKU) |
| **WiFi/BT** | AIC8800D80 WiFi 6 + BT 5.4 (USB) |
| **Video** | micro-HDMI 2.0 (4K60), HDMI audio |
| **USB** | 2x USB-C (one 3.1 host + DP Alt, one 2.0 OTG/power) |
| **Storage** | microSD, optional UFS 3.0 |
| **PCIe** | Gen3 x1 via FPC connector |
| **Docs** | [Radxa product page](https://docs.radxa.com/en/cubie/a7z) &bull; [Schematic v1.10](https://dl.radxa.com/cubie/a7z/docs/hw/radxa_Cubie_A7Z_v1100__schematic.pdf) |

## Quick Start

### Build

```bash
# Clone
git clone https://github.com/dok2d/cubie-a7z-debian.git
cd cubie-a7z-debian

# Host prerequisite: arm64 chroot needs binfmt_misc with qemu
sudo apt install qemu-user-static binfmt-support

# Build in container (recommended)
podman build -t cubie-builder -f docker/Dockerfile.builder .
podman run --rm --privileged --user root -v .:/work:Z cubie-builder make all

# Or with Docker
docker build -t cubie-builder -f docker/Dockerfile.builder .
docker run --rm -v $(pwd):/work cubie-builder make all
```

### Flash

```bash
sudo make flash DEV=/dev/sdX
```

Or manually:

```bash
xzcat build/cubie_a7z-trixie.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
sync
```

### Boot

1. Insert SD into Cubie A7Z
2. Connect power via USB-C (bottom port, J16)
3. Connect via UART (115200, pin 10 TX / pin 12 RX) or HDMI + USB keyboard

Default credentials: `root` / `cubie` or `cubie` / `cubie` (has sudo).

### Connect WiFi

```bash
nano /etc/wpa_supplicant/wpa_supplicant.conf
# Add: network={ ssid="..." psk="..." }
systemctl restart networking
```

## What Works

Verified on real hardware (2026-06-09, 80/80 diagnostic checks pass):

| Subsystem | Status | Details |
|-----------|--------|---------|
| WiFi | **Working** | AIC8800D80, wlan0, auto-connect on boot |
| Bluetooth | **Working** | btusb, hci0, bluetoothctl |
| GPU | **Working** | pvrsrvkm, glamor acceleration, /dev/dri/renderD128 |
| NPU | **Working** | vipcore, vpm_run inference, ResNet50/YOLOv5 |
| HDMI | **Working** | Video + audio (sndhdmi), hotplug daemon |
| USB-C Host | **Working** | HID, hubs, VBUS power control |
| USB-C PD / TCPC | **Working** | ET7304 TCPC via rt1711h driver, PD negotiation |
| USB-C DP Alt Mode | **Implemented*** | Full pipeline: phy_switcher + edp0 + tv1 |
| PCIe | **Working** | Root port visible, needs M.2 adapter for NVMe |
| SPI | **Working** | /dev/spidev1.0 on 40-pin header |
| SSH | **Working** | Auto-start, port 22 |
| NTP | **Working** | systemd-timesyncd + fake-hwclock |
| zram swap | **Working** | 256 MB compressed swap (critical for 1 GB SKU) |

*USB-C DP Alt Mode: Full signal pipeline wired (sunxi-phy-switcher → combo PHY →
edp0 DP source → tcon4). Needs hardware testing with a USB-C DP monitor/adapter.
Lane invert values may need board-specific tuning.

See [known issues](docs/known-issues-en.md) for edge cases (UFS, CPU freq).

## External Source Repositories

No vendor binaries in git. Everything is fetched from public repos at build time.
All commits are pinned to specific SHAs in [`config/board.cubie-a7z.env`](config/board.cubie-a7z.env).

| # | Repository | URL | Branch | Purpose |
|---|------------|-----|--------|---------|
| 1 | orangepi-build | https://github.com/orangepi-xunlong/orangepi-build.git | `next` | Kernel defconfig, pack-uboot tools |
| 2 | linux-orangepi | https://github.com/orangepi-xunlong/linux-orangepi.git | `orange-pi-6.6-sun60iw2` | BSP kernel 6.6.98+ (A733 support) |
| 3 | u-boot-orangepi | https://github.com/orangepi-xunlong/u-boot-orangepi.git | `v2018.05-sun60iw2` | U-Boot 2018.07 via brandy-2.0 |
| 4 | allwinner-bsp | https://github.com/radxa/allwinner-bsp.git | `cubie-aiot-v1.4.6` | Boot0, SCP firmware, chip configs |
| 5 | allwinner-target | https://github.com/radxa/allwinner-target.git | `target-a733-v1.4.6` | Firmware overlay (GPU/WiFi/Xorg userland) |
| 6 | allwinner-device | https://github.com/radxa/allwinner-device.git | `device-a733-v1.4.6` | Board configs (sys_config.fex) |
| 7 | aic8800 | https://github.com/radxa-pkg/aic8800.git | `main` | WiFi/BT USB driver (AIC8800D80) |
| 8 | ai-sdk | https://github.com/ZIFENG278/ai-sdk.git | `main` | NPU SDK (VIPLite v2.0, vpm_run, models) |
| 9 | Radxa stock image | https://github.com/radxa-build/radxa-cubie-a7z/releases | `rsdk-b1` | Stock boot0 extraction (SHA256-verified) |

**Additional references:**

- [Radxa Cubie A7Z docs](https://docs.radxa.com/en/cubie/a7z)
- [Radxa schematic v1.10 (PDF)](https://dl.radxa.com/cubie/a7z/docs/hw/radxa_Cubie_A7Z_v1100__schematic.pdf)
- [Mesa PowerVR docs](https://docs.mesa3d.org/drivers/powervr.html) — GPU driver reference
- [TI AM67 PVR build guide](https://software-dl.ti.com/jacinto7/esd/processor-sdk-linux-am67/10_01_08_01/exports/docs/linux/Foundational_Components/Graphics/Rogue/Build_Guide.html) — same GPU family
- [geerlingguy/sbc-reviews#100](https://github.com/geerlingguy/sbc-reviews/issues/100) — community review with GPU benchmarks

## How It Works

```
make fetch       →  Clone 9 repos (kernel, U-Boot, BSP, drivers, SDK)
                     + extract boot0 from Radxa official image (SHA256-verified)
make bootloader  →  Build U-Boot via vendor brandy-2.0 tooling
make kernel      →  Cross-compile BSP kernel 6.6.98+ with WiFi/GPU/NPU modules
make rootfs      →  debootstrap Debian Trixie + configure services
make image       →  Partition, format, populate → cubie_a7z-trixie.img.xz
```

## Project Structure

```
config/
  board.cubie-a7z.env     Pinned repo URLs and commit SHAs
  debian.env              Rootfs defaults (suite, user, hostname)
  dts/                    Our device tree (GPL-2.0+/MIT)
scripts/
  00-fetch-sources.sh     Fetch + pin vendor sources, extract boot0
  10-build-bootloader.sh  U-Boot + boot_package via dragonsecboot
  20-build-kernel.sh      Kernel + out-of-tree WiFi/GPU/NPU modules
  30-build-rootfs.sh      debootstrap + packages + services + config
  40-assemble-image.sh    Partition image, write bootloader, populate FS
  90-flash-sd.sh          Safe SD card writer with confirmation (requires root)
overlays/rootfs/          Custom files copied into rootfs as-is (see below)
patches/                  git-am patches for kernel and U-Boot
docker/                   Dockerfile for reproducible builds
docs/                     Hardware BoM, boot layout, pinout, guides
```

## Customization

Place files in `overlays/rootfs/` — they are copied verbatim into the rootfs
as the last step before packaging. Directory structure mirrors the target:

```
overlays/rootfs/
├── root/
│   ├── help/                       → /root/help/
│   │   ├── wifi.txt                    WiFi setup guide
│   │   ├── setup-gpu.sh                GPU acceleration setup
│   │   ├── setup-vulkan.sh             Vulkan ICD configuration
│   │   ├── setup-sdl3.sh               SDL3 build from source
│   │   ├── setup-kmsdrm.sh             KMSDRM (console gaming without X11)
│   │   ├── wm/                         Desktop environment installers
│   │   │   ├── install-xfce.sh             XFCE4 desktop (X11, recommended)
│   │   │   ├── install-i3.sh               i3 tiling WM (X11)
│   │   │   ├── install-lxqt.sh             LXQt desktop (X11, Qt)
│   │   │   ├── install-sway.sh             Sway tiling WM (Wayland)
│   │   │   └── install-labwc.sh            labwc compositor (Wayland)
│   │   └── games/                      Game install/run scripts
│   │       ├── q2/                         Yamagi Quake II (60 fps GLES3)
│   │       ├── q3/                         ioquake3 / Q3lite
│   │       ├── halflife/                   Xash3D FWGS (60 fps GLES3)
│   │       └── serioussam/                 Serious Engine 1
│   └── tests/                      → /root/tests/ (hardware test scripts)
│       ├── test-all.sh
│       ├── test-wifi.sh, test-gpu.sh, test-npu.sh, ...
```

On the board:

```bash
bash /root/help/wm/install-xfce.sh     # install a desktop
bash /root/tests/test-all.sh            # verify hardware
bash /root/help/games/q2/install-quake2.sh  # install Quake II
```

## GPU Gaming

Verified games running at 60 fps on real hardware:

| Game | Engine | FPS | Renderer |
|------|--------|-----|----------|
| Yamagi Quake II | Yamagi Q2 | 60 (GLES3 KMSDRM), 67 (Vulkan X11) | ref_gles3 / ref_vk |
| Half-Life | Xash3D FWGS | 60 (GLES3 KMSDRM) | gles3compat |

See [GPU-GAMES.md](GPU-GAMES.md) for the full game compatibility list (17 titles rated).

## Documentation

| Document | Description |
|----------|-------------|
| [Build Guide](docs/BUILDKIT-GUIDE.md) | Full build instructions ([RU](docs/BUILDKIT-GUIDE-ru.md)) |
| [User Guide](docs/USER-GUIDE.md) | Board usage, WiFi, peripherals ([RU](docs/USER-GUIDE-ru.md)) |
| [Known Issues](docs/known-issues-en.md) | Open and resolved issues ([RU](docs/known-issues.md)) |
| [TODO](docs/TODO-en.md) | Remaining work items ([RU](docs/TODO.md)) |
| [Boot Layout](docs/boot-layout.md) | SD card partition map, sector offsets |
| [Firmware BoM](docs/firmware-bom.md) | Per-chip driver and firmware checklist |
| [40-pin Pinout](docs/a7z-40pin-pinout.md) | GPIO header pin assignments |
| [Rootfs Deps](docs/rootfs-dependency-map.md) | Shared library dependency tree |
| [Hardware Enablement](docs/hardware-enablement.md) | Full peripheral bring-up plan |
| [GPU Games](GPU-GAMES.md) | Game compatibility list and install guides |
| [GPU TODO](GPU-TODO.md) | GPU acceleration research and GLVND notes |

## Requirements

- x86_64 host (vendor pack tools are x86-only binaries)
- Docker or Podman (recommended), or Debian 12+ with [dependencies](docs/BUILDKIT-GUIDE.md#installing-dependencies)
- `qemu-user-static` + `binfmt-support` on the host (rootfs build uses arm64 chroot)
- ~20 GB disk, ~8 GB download on first build
- microSD card (8+ GB) for flashing

## License

Build scripts and device tree: GPL-2.0-or-later.
Vendor kernel, U-Boot, and BSP sources are subject to their respective licenses.
No proprietary blobs are stored in this repository.
