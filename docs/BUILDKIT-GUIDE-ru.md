# Руководство по сборке образа — Cubie A7Z Debian

## Обзор

Этот репозиторий содержит скрипты для сборки загрузочного образа Debian arm64
для одноплатного компьютера Radxa Cubie A7Z (Allwinner A733).

Все исходники сторонних проектов (ядро, U-Boot, драйверы, firmware) скачиваются
автоматически при сборке из публичных репозиториев. В git хранятся только
наши скрипты, конфиги и DTS.

## Требования к хосту

- Debian 12+ или Ubuntu 22.04+ (x86_64)
- ~20 ГБ свободного места
- Интернет для скачивания source repos (~8 ГБ)

### Установка зависимостей

```bash
sudo apt install -y \
  make git wget curl build-essential bc flex bison libssl-dev \
  gcc-arm-linux-gnueabi gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
  swig device-tree-compiler xxd busybox \
  debootstrap qemu-user-static binfmt-support \
  parted dosfstools e2fsprogs mtools xz-utils \
  u-boot-tools kmod cpio binutils
```

Или используйте Docker/Podman (рекомендуется):

```bash
# Зависимость хоста: qemu-user-static с binfmt_misc (нужен для arm64 chroot)
sudo apt install qemu-user-static binfmt-support
sudo systemctl restart binfmt-support
# Проверка: в flags должен быть "F"
cat /proc/sys/fs/binfmt_misc/qemu-aarch64

# Docker
docker build -t cubie-builder -f docker/Dockerfile.builder .
docker run --rm -v $(pwd):/work cubie-builder make all

# Podman (rootless)
podman build -t cubie-builder -f docker/Dockerfile.builder .
podman run --rm --privileged --user root -v .:/work:Z cubie-builder make all
```

### Проверка зависимостей

```bash
make deps
```

## Структура проекта

```
├── config/
│   ├── board.cubie-a7z.env    # Репозитории и pinned SHAs
│   ├── debian.env             # Конфигурация Debian rootfs
│   └── dts/                   # Device Tree Source (наш, не vendor)
├── scripts/
│   ├── 00-fetch-sources.sh    # Скачивание vendor sources
│   ├── 10-build-bootloader.sh # Сборка U-Boot + boot_package
│   ├── 20-build-kernel.sh     # Сборка ядра + WiFi + GPU + NPU
│   ├── 30-build-rootfs.sh     # Сборка корневой ФС
│   ├── 40-assemble-image.sh   # Сборка финального образа .img.xz
│   ├── 90-flash-sd.sh         # Запись на SD-карту
│   └── lib/common.sh          # Общие функции
├── patches/
│   ├── kernel/                # Патчи для ядра (git am)
│   └── u-boot/                # Патчи для U-Boot (git am)
├── overlays/rootfs/           # Пользовательские файлы для rootfs (тесты, гайды)
├── sources/                   # Скачанные vendor sources (gitignored)
├── build/                     # Артефакты сборки (gitignored)
└── docs/                      # Документация
```

## Кастомизация

Файлы в `overlays/rootfs/` копируются в rootfs как есть на последнем этапе
перед упаковкой. Структура каталогов повторяет целевую ФС:

```
overlays/rootfs/etc/motd              → /etc/motd
overlays/rootfs/root/my-script.sh     → /root/my-script.sh
```

По умолчанию overlay содержит `/root/help/` (WiFi гайд, установка рабочих столов) и скрипты тестирования
в `/root/tests/`. Запуск на плате: `bash /root/tests/test-all.sh`.

## Полная сборка

```bash
make all
```

Или по шагам:

```bash
make fetch         # Скачать vendor sources (~8 ГБ, ~5 мин)
make bootloader    # Собрать U-Boot (~1 мин)
make kernel        # Собрать ядро + WiFi + GPU + NPU (~15 мин)
make rootfs        # Собрать корневую ФС (~5 мин)
make image         # Собрать финальный образ .img.xz (~5 мин)
```

## Запись на SD-карту

```bash
sudo make flash DEV=/dev/sdX
```

Или вручную:

```bash
xzcat build/cubie_a7z-trixie.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
sync
# boot0 и boot_package записываются скриптом assemble-image внутри образа
```

**Важно**: A733 BROM читает boot0 с сектора 256 (128 КБ), не сектора 16!

## Конфигурация

### Vendor sources

Репозитории и коммиты зафиксированы в `config/board.cubie-a7z.env`:

| Репозиторий | Назначение |
|-------------|------------|
| orangepi-build | defconfig, pack-uboot tools |
| linux-orangepi | Vendor BSP ядро 6.6.98+ |
| u-boot-orangepi | U-Boot (brandy-2.0) |
| allwinner-bsp | Boot0, SCP, configs |
| allwinner-target | Firmware overlay (GPU, WiFi, Xorg) |
| allwinner-device | Board configs (sys_config.fex) |
| aic8800 | WiFi USB driver (radxa-pkg) |
| ai-sdk | NPU SDK (VIPLite v2.0) |

### Патчи

Патчи для ядра и U-Boot кладутся в `patches/kernel/` и `patches/u-boot/`.
Формат: `git format-patch`. Применяются автоматически через `git am`
в лексическом порядке после fetch.

### Device Tree

DTS хранится в `config/dts/sun60i-a733-cubie-a7z.dts` и копируется
в дерево ядра при сборке. Это **наш** DTS, не vendor.

## Воспроизводимость

- Все vendor sources зафиксированы конкретными commit SHA
- Патчи применяются детерминистично
- Debian пакеты скачиваются из стабильного зеркала
- Docker обеспечивает одинаковое окружение сборки

## Известные особенности

- `dpkg-deb -x` не разрешает зависимости — shared libs добавляются вручную
  (см. `docs/rootfs-dependency-map.md`)
- GPU module (pvrsrvkm) собирается out-of-tree, требует симлинки `/gcc` → cross-compiler
- UFS может отсутствовать на некоторых SKU (ошибки в dmesg — нормально)
- Первая загрузка: `first-boot-resize` расширяет rootfs до полного размера SD
