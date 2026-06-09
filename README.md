# Cubie A7Z Debian

Reproducible Debian Trixie (arm64) image builder for the **Radxa Cubie A7Z** — a compact SBC powered by the Allwinner A733 octa-core SoC.

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
podman run --rm --user root -v .:/work:Z,exec cubie-builder make all

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

Verified on real hardware (2026-06-07, 80/80 diagnostic checks pass):

| Subsystem | Status | Details |
|-----------|--------|---------|
| WiFi | **Working** | AIC8800D80, wlan0, auto-connect on boot |
| Bluetooth | **Working** | btusb, hci0, bluetoothctl |
| GPU | **Working** | pvrsrvkm, /dev/dri/renderD128 |
| NPU | **Working** | vipcore, vpm_run inference, ResNet50/YOLOv5 |
| HDMI | **Working** | Video + audio (sndhdmi) |
| USB-C Host | **Working** | HID, hubs, VBUS power control |
| PCIe | **Working** | Root port visible, needs M.2 adapter for NVMe |
| SPI | **Working** | /dev/spidev1.0 on 40-pin header |
| SSH | **Working** | Auto-start, port 22 |
| NTP | **Working** | systemd-timesyncd + fake-hwclock |

See [known issues](docs/known-issues-en.md) for edge cases (UFS, CPU freq, TCPC).

## How It Works

No vendor binaries in git. Everything is fetched from public repos at build time:

```
make fetch       →  Clone 9 repos (kernel, U-Boot, BSP, drivers, SDK)
                     + extract boot0 from Radxa official image (SHA256-verified)
make bootloader  →  Build U-Boot via vendor brandy-2.0 tooling
make kernel      →  Cross-compile BSP kernel 6.6.98+ with WiFi/GPU/NPU modules
make rootfs      →  debootstrap Debian Trixie + configure services
make image       →  Partition, format, populate → cubie_a7z-trixie.img.xz
```

All source commits are pinned in [`config/board.cubie-a7z.env`](config/board.cubie-a7z.env).
Patches live in [`patches/`](patches/). Our device tree: [`config/dts/`](config/dts/).

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
│   │   ├── install-xfce.sh            XFCE4 desktop (X11, recommended)
│   │   ├── install-i3.sh              i3 tiling WM (X11)
│   │   ├── install-lxqt.sh            LXQt desktop (X11, Qt)
│   │   ├── install-sway.sh            Sway tiling WM (Wayland)
│   │   └── install-labwc.sh           labwc compositor (Wayland)
│   └── tests/                      → /root/tests/ (hardware test scripts)
│       ├── test-all.sh
│       ├── test-wifi.sh, test-gpu.sh, test-npu.sh, ...
```

The default overlay ships WiFi guide, desktop environment installers,
and per-subsystem hardware tests. On the board:

```bash
bash /root/help/install-xfce.sh     # install a desktop
bash /root/tests/test-all.sh        # verify hardware
```

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
