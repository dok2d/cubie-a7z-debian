# Cubie A7Z hardware BoM and firmware checklist

Source of truth for what blobs, drivers, and DT bindings each onboard chip
needs. Derived from:

- Radxa schematic v1.10: <https://dl.radxa.com/cubie/a7z/docs/hw/radxa_Cubie_A7Z_v1100__schematic.pdf>
- Radxa product brief and docs at <https://docs.radxa.com/en/cubie/a7z>
- Live `lsusb -t` from a booting Cubie A7Z (smarthomecircle.com review,
  2026-03)
- Allwinner A733 user manual / AIOT SDK (GitLab, no NDA)
- linux-sunxi mainlining tracker

If a row says "verify on hardware" — that means it has not been confirmed
on a real A7Z and the choice is inferred from the schematic, sister boards
(Cubie A7A, Orange Pi 4 Pro), or the AIOT SDK. Confirm with `lsmod`,
`dmesg`, `lspci`, `lsusb`, and `/proc/device-tree/...` on first boot.

---

## SoC

| Field | Value |
|---|---|
| Marking | `A733MX_HN3` (per schematic page 5) |
| Family  | Allwinner sun60iw2p1 |
| Cores   | 2× Cortex-A76 @ 2.0 GHz + 6× Cortex-A55 @ 1.8 GHz |
| Also    | 1× Alibaba XuanTie E902 RISC-V @ 200 MHz (AR100 CPUS / sensor hub) |
| GPU     | Imagination PowerVR BXM-4-64 MC1 (OpenGL ES 3.2 / Vulkan 1.3 / OpenCL 3.0) |
| NPU     | Vivante VIP9000, 3 TOPS @ INT8 |
| Video   | VPU block (decode AV1/H.265/H.264/VP9; encode H.265/H.264) |
| Crypto  | "Security System" block on chip |

### Firmware / drivers
- **CPU/SMP/PSCI**: ATF (TF-A) v2.x built from `brandy-2.0` tree, not
  upstream. Vendor ships `bl31.bin` already linked into `sboot.bin`.
- **Mali equivalent (PowerVR)**: requires Imagination proprietary userland
  (`pvrsrvkm.ko` kernel module + `libsrv_um.so`, `libIMGegl.so`, etc.).
  **Not redistributable** in Debian. v1 ships software rendering only.
- **NPU**: needs Vivante VIP `galcore.ko` kernel module + Cubie ACUITY SDK
  userland. **Not in v1**.
- **VPU**: vendor `cedrus`-style driver inside BSP. Mainline `cedrus` does
  not yet support sun60iw2. Mark as BSP-only.
- **RISC-V AR100/CPUS firmware**: pre-built blob in
  `allwinner-target/.../boot-resource/`. Loaded by boot0.

---

## PMIC

| Field | Value |
|---|---|
| Part | **X-Powers AXP318** (schematic page 4, designator UP1) |
| Package | 0.4mm-pitch BGA |
| Rails | 9× DCDC (DCDC1..DCDC9), 6× ALDO, 5× BLDO, 5× CLDO, 6× DLDO, 6× ELDO + 2× SWOUT |
| Control | I2C (`PMU-SDA`/`PMU-SCK`), IRQ on `PMU-IRQ` |
| Special | DC8SET pin selects DCDC8 default (LPDDR4/4X/5 voltage) |

### Firmware / drivers
- **U-Boot 2018.07**: vendor `drivers/power/axp/axp318_*.c` from
  `u-boot-vendor/drivers/power/axp/`. Used during DRAM init, before kernel.
- **Kernel 6.6 BSP**: `drivers/mfd/axp2202_mfd.c` family in
  `bsp/drivers/mfd/` (Allwinner names the AXP318 driver inconsistently
  across BSP versions — sometimes `axp2202`, sometimes `axp_pmu`). Verify
  the actual `compatible` string in the DTS for orangepi4pro and reuse.
- **Mainline**: no upstream support for AXP318. Out of scope for v1.

### DT bindings (BSP)
```
&twi0 {
    axp318: pmic@34 {
        compatible = "x-powers,axp318";
        reg = <0x34>;
        interrupt-parent = <&r_intc>;
        interrupts = <...>;
        /* regulator subnodes for DCDC1..9, ALDO1..6, BLDO1..5, ... */
    };
};
```

---

## DRAM

| Field | Value |
|---|---|
| Part | **SK Hynix H9HCNNNCPUMLHR-NEE** (schematic page 5) |
| Type | LPDDR4X |
| Decoded P/N | H9HCNNNCPxMLHR-NEE = LPDDR4X, dual-channel x32, 8 GB density on the 16 GB SKU; smaller capacities use shorter Hynix part numbers (verify per SKU) |
| Voltage | VCC-DRAM 1.1 V, VDDQ 0.6 V, VDD18 1.8 V (per AXP318 rail table) |
| Topology | 1-rank-per-channel, x16 + x16 on each CH (visible in pinout DQ0..DQ31 A/B) |

### Firmware / drivers
- **DRAM init**: vendor `boot0` ("brom→boot0") contains the DRAM
  controller setup. Parameters live in
  `allwinner-target/.../sys_config*.fex` as the `dram_para` block
  (`dram_para_00`..`dram_para_29`). **Don't touch unless you know exactly
  which Hynix part is on your SKU.**
- **Kernel**: nothing to do — DRAM is already initialised by boot0 and ATF.

---

## Boot / mass storage

### microSD slot (always populated)
- Bus: SoC SD3.0 controller, no PHY blob.
- Driver: `drivers/mmc/host/sunxi-mmc.c` (BSP version with sun60i quirks).
  Mainline `sunxi-mmc` does NOT yet handle sun60iw2 — BSP-only for v1.
- Pin power: 3.3V default, switches to 1.8V for UHS-I.

### Onboard UFS 3.0 (optional, soldered per SKU; 0 GB / 64 / 128 / 256 / 512)
- Per schematic page 9. UFS attaches via the SoC UFS3.1 controller.
- Voltages: VCC12-UFS (1.2 V) + VCC18-UFS (1.8 V) + VCC-UFS (3.3 V for
  UFS 2.2; 1.8 V for UFS 3.x — board is wired for 3.x).
- Driver: `drivers/scsi/ufs/ufs-sunxi.c` in BSP. No mainline.
- The specific UFS chip varies by SKU and is not on the public schematic;
  identify on hardware with `cat /sys/class/scsi_device/*/device/model`.

### SPI NOR (optional, for NVMe boot)
- Radxa docs: "NVMe/SSD boot requires flashing the SPI Nor Flash firmware"
  — a small SPI NOR holds bootloader so the kernel can be on NVMe.
- Identify on hardware before relying on it.

### eMMC (Cubie A7A has it; A7Z does NOT in current SKUs)
- Schematic shows eMMC pads but **A7Z product brief says only microSD +
  optional UFS**. Treat eMMC as absent on A7Z. Confirm by inspection of
  the actual board.

---

## Networking

### WiFi 6 + Bluetooth 5.4 (onboard)
| Field | Value |
|---|---|
| Chipset | **AICSemi AIC8800** (confirmed by `lsusb -t` showing `aic_btusb` + `aic8800_fdrv` drivers) |
| Bus | **USB 2.0**, internal (sunxi-ehci shows the device under bus 3) |
| Antenna | Single u.FL (IPEX gen 1) external connector |

**Critical**: This is NOT a Broadcom AP6275 module. Earlier DECISIONS.md
guessed AP6275 — that was wrong. Update accordingly.

### Firmware / drivers
- **Kernel driver**: out-of-tree `aic8800_fdrv` (WiFi) and `aic_btusb`
  (Bluetooth). Sources at
  `https://github.com/radxa-pkg/aic8800` (Radxa fork) and upstream at
  `https://github.com/AICSemi/aic8800`. Not in mainline Linux.
- **Firmware blobs**: `fmacfw_*.bin`, `fmacfw_patch_*.bin`,
  `lmacfw_rf_*.bin`, BT patches. Live in `/lib/firmware/aic8800/`.
  Source: `radxa-pkg/aic8800-firmware` Debian package.
- **In orangepi-build**: the same driver lands as DKMS package
  `aic8800-dkms` plus a firmware tarball.

### DT
- AIC8800 over USB does NOT need a DT node for the radio itself
  (USB devices are enumerated). Only the USB host controller + any
  WAKE-on-WLAN GPIO needs DT.

### Action items
- Install `aic8800-dkms` and `aic8800-firmware` (.deb from Radxa apt repo
  or build from `radxa-pkg/aic8800`) in the rootfs.
- Stage firmware blobs at `overlays/firmware/lib/firmware/aic8800/`.
- DT: ensure the USB host port the module sits on is enabled and powered
  (look at orangepi4pro DTS — same SoC, same internal wiring on the
  hub the module hangs off).

### Ethernet
- **NONE on A7Z**. No PHY, no MAC pins routed out. PCIe FPC + USB are the
  only options for wired LAN.

---

## Display

### Micro HDMI (HDMI 2.0, up to 4K60, with CEC)
- SoC HDMI TX block, no external PHY chip needed.
- Voltages: VCC18-HDMI, VDD08-HDMI.
- Driver: BSP `drivers/gpu/drm/sunxi/de/disp_hdmi.c` (DRM/KMS).
- HDMI audio: out of scope for v1 (per DECISIONS.md).
- CEC: BSP supports it via `drivers/cec/sunxi-cec.c`.

### USB-C DisplayPort Alt mode
- Schematic page 12. Routed through the USB 3.1 Type-C connector.
- Needs USB-PD controller for alt-mode negotiation (identify on schematic
  page 12 — likely a TI TUSB-family chip or Allwinner's own combo PHY).
- **Out of scope for v1.**

### MIPI DSI / LVDS / RGB / eDP
- SoC supports them, no connectors on A7Z PCB. Ignore.

---

## Camera

### MIPI CSI
- 1× 4-lane or 2× 2-lane MIPI CSI on the camera FPC.
- Voltage: VCC-MCSI (1.8 V from PMIC).
- Driver: BSP `drivers/media/platform/sunxi-vin/`.
- Without a connected camera module, nothing to load. Module-specific
  firmware (sensor I2C init) lives in the sensor driver itself.

---

## USB

| Port | Schematic | Role | Notes |
|---|---|---|---|
| USB-C #1 (power+data) | page 12 | USB 2.0 OTG, accepts 5V power | also FEL entry |
| USB-C #2 | page 12 | USB 3.1 OTG with DP alt-mode | downstream current limit ~1A |

- USB host controllers visible in `lsusb -t`:
  - sunxi-ohci (12 Mbps)
  - sunxi-ehci (480 Mbps) — AIC8800 hangs here
  - xhci-hcd × 2 (480 Mbps + 10 Gbps)
- Drivers all in BSP kernel under `drivers/usb/host/sunxi_*`. No firmware
  blobs needed for the controllers themselves.

### USB-PD controller (if discrete chip is fitted)
- Find on schematic page 12. If present, likely needs a TI/CYPRESS PD
  driver or vendor handler. Defer until v1 boots.

---

## PCIe

- One PCIe Gen3 x1 lane on the FPC connector (no M.2/NVMe on board, only
  via expansion HAT).
- Driver: BSP `drivers/pci/controller/sunxi-pcie/`.
- No PCIe-specific firmware; downstream NVMe drives bring their own.

---

## I/O headers and minor parts

| Block | Schematic | Driver / firmware needed |
|---|---|---|
| 40-pin GPIO header | page 14 | sunxi-pinctrl (BSP); pin mux declared in DTS |
| Fan header (5 V, PWM-capable) | page 16 | sunxi PWM driver (BSP) |
| User LED | page 16 | gpio-leds |
| FEL / U-Boot button | page 16 | gpio-keys (input) |
| Onboard 26 MHz XTAL + 32.768 kHz | page 6 | clock-init by boot0, RTC by sun6i-rtc |

---

## Reference clock crystals

- 26 MHz main XTAL (for PLL and DCXO).
- 32.768 kHz RTC XTAL (`X32K_IN`/`X32K_OUT`).

Both feed the AXP318 / SoC clocks directly; nothing to load in firmware.

---

## Firmware bundle layout for `overlays/firmware/`

```
overlays/firmware/
└── lib/
    └── firmware/
        └── aic8800/
            ├── fmacfw_8800dc_h_u02.bin       # WiFi MAC firmware (variant per chip rev)
            ├── fmacfw_patch_8800dc_h_u02.bin
            ├── lmacfw_rf_8800dc.bin
            ├── fw_adid_8800dc_u02b0.bin
            ├── fw_patch_8800dc_u02b0.bin
            ├── fw_patch_table_8800dc_u02b0.bin
            └── BT/                            # BT patch RAM files
                └── aic_bt_patch_8800dc_u02b0.bin
```

The exact chip revision (`u02`, `u02b0`, `h_u02`, …) is detected at
runtime by the driver — ship all the variants Radxa ships in their
firmware package and let the driver pick.

Source of these blobs:
- `https://github.com/radxa-pkg/aic8800-firmware`
- mirrored inside `orangepi-build` external/ tree (verify path after
  fetch)

---

## Subsystem Status (as of 2026-06-09)

| Function | Status | Notes |
|---|---|---|
| 3D graphics (PowerVR) | **Working** | pvrsrvkm + PVR Mesa from allwinner-target overlay, glamor acceleration |
| NPU | **Working** | VIPLite v2.0 runtime + vpm_run, ResNet50 inference 7.5ms |
| HDMI audio | **Working** | sndhdmi soundcard, aplay works |
| GPU gaming | **Working** | Quake II 60fps GLES3, Half-Life 60fps GLES3 |
| Hardware video decode | Not tested | BSP `cedrus`-equivalent untested on sun60i; defer |
| USB-C DP alt mode | Not working | Needs ET7304Y TCPC driver (probe -22) |
| Wake-on-WLAN | Not tested | Driver-side; not a current goal |
| Suspend / resume | Not tested | Allwinner BSP support varies; defer |

---

## Verified on Hardware (2026-06-09)

1. AIC8800 chip rev: **D80** (AIC8800D80, USB), driver: radxa-pkg/aic8800
2. UFS chip: **not soldered** on tested SKU — link_startup_fail is expected
3. PMIC: **AXP8191** (not AXP318/AXP515) — I2C-13 addr 0x36, 43 regulators working
4. USB-PD controller: **ET7304Y** — I2C bus 14 addr 0x4E, generic tcpci probe fails (-22)
5. SPI NOR: not confirmed on tested board revision
6. DRAM: LPDDR4X, 1 GB on tested SKU, stock boot0 from Radxa rsdk-b1 image works

## Open verification items

Remaining items for other SKUs:

1. Exact UFS chip on UFS-equipped SKUs → `cat /sys/class/scsi_device/*/device/{vendor,model,rev}`
2. SPI NOR presence on different board revisions
3. Hynix DRAM part number suffix per SKU (4/8/16 GB) — may affect boot0 dram_para
