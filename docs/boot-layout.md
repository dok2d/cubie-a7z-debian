# Boot layout — Cubie A7Z (sun60iw2p1)

Обновлено: 2026-06-11

All offsets are in 512-byte sectors unless noted.

| Component          | Start sector | Size             | Notes                                    |
|--------------------|-------------|------------------|------------------------------------------|
| MBR                | 0           | 1 sector         | `parted mklabel msdos` (GPT конфликтует с boot0) |
| boot0 (SPL)        | 256         | ~256 KiB         | `boot0_stock.bin` (extracted from Radxa rsdk-b1 image by 00-fetch-sources.sh) |
| boot_package       | 24576       | ~1.4 MiB         | Наш U-Boot (ENV_IS_NOWHERE) + DTB + SCP  |
| FAT32 /boot        | 69632       | 256 MiB          | Kernel Image, DTB, boot.scr, extlinux.conf |
| ext4 /             | 593920      | rest of disk     | Root filesystem (auto-resize at first boot) |

## Sector offset derivation for `dd`

```
boot0:         bs=512 seek=256    → 128 KiB offset (A733 BROM reads from sector 256!)
boot_package:  bs=512 seek=24576  → 12 MiB offset
```

**Важно**: A733 BROM читает boot0 с **сектора 256** (128 KiB), НЕ сектора 16 как старые Allwinner SoC!

## U-Boot build config

- Defconfig: `sun60iw2p1_t736_defconfig`
- Toolchain: `arm-linux-gnueabi-` (32-bit ARM, vendor brandy-2.0)
- `CONFIG_ENV_IS_NOWHERE=y` (ext4 env storage портит rootfs)
- boot_package собирается через vendor `dragonsecboot -pack`

## Flash command

```bash
xzcat build/cubie_a7z-trixie.img.xz | dd of=/dev/sdX bs=4M iflag=fullblock status=progress
sync
```

Или через Makefile:

```bash
sudo make flash DEV=/dev/sdX
```

boot0 и boot_package уже записаны внутри образа скриптом `40-assemble-image.sh`.
Ручная перезапись boot0 после dd не требуется.
