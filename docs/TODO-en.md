# Cubie A7Z — TODO

Updated: 2026-06-08

Full plan: [hardware-enablement.md](hardware-enablement.md)
Dependencies: [rootfs-dependency-map.md](rootfs-dependency-map.md)
Known issues: [known-issues-en.md](known-issues-en.md)

---

## Working (verified on hardware 2026-06-09)

- WiFi: network connection, DHCP, internet (radxa-pkg/aic8800), wlan0, autostart
- USB-C host: HID (keyboard), VBUS via PL2 GPIO
- **GPU: glamor acceleration on PowerVR BXM-4-64** (PVR Mesa via allwinner-target overlay)
- HDMI: video (1080p) + audio (sndhdmi)
- PCIe: controller visible (root port)
- NPU: /dev/vipcore, vpm_run, ResNet50 inference 7.5ms
- SPI1: /dev/spidev1.0 on 40-pin header
- BT: btusb, hci0, bluetoothctl
- CPU freq: schedutil, A55 up to 1794 MHz, A76 up to 2002 MHz
- SSH, NTP, fake-hwclock, networking — all autostart
- All utilities: curl, wget, gawk, gpiodetect, i2cdetect, tmux, screen, etc.
- SD boot + first-boot-resize (58G)
- LED heartbeat
- 43 regulators (AXP8191)
- 0 systemd failed units, 0 meaningful dmesg errors

## Not Done

| # | Task | Priority | Blocker | What it unlocks |
|---|------|----------|---------|-----------------|
| 1 | ET7304Y port nodes | Medium | Reverse-engineer vendor driver or port nodes | USB-C PD negotiation — charging from PD adapters, DP Alt Mode via typec framework |
| 3 | Camera MIPI CSI | Low | Need Radxa Camera 8M 219 | /dev/video*, photo/video capture, AI inference from camera via NPU |
| 4 | Fan PWM | Low | Need Radxa Heatsink 6530B | Active cooling (73C without fan), thermal throttling policy |
| 5 | PCIe + NVMe | Low | Need Radxa PCIe to M.2 M Key HAT + drive | Fast storage (~1 GB/s), NVMe boot (via SPI NOR boot) |
| 6 | CPU freq OPP | Low | Risky without eFuse speed grade knowledge | Full frequency range, power saving in idle |
| 7 | mmdebstrap | Low | Infrastructure | Auto dependency resolution — no more hunting for libwrap0 etc. |
| 8 | regulatory.db | Low | Cosmetic | Clean dmesg, correct WiFi TX power limits per country |

## Reproducibility

All 9 public repositories are fetched by `00-fetch-sources.sh`.
Boot0 is automatically downloaded and extracted from the Radxa official image (rsdk-b1)
with SHA256 verification — no proprietary blobs stored in git.

Building in a container (Docker/Podman):

```bash
podman build -t cubie-builder -f docker/Dockerfile.builder .
podman run --rm --privileged --user root -v .:/work:Z cubie-builder make all
```
