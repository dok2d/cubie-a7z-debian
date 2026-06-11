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
- Интернет для скачивания source repos (~8 ГБ при первой сборке)
- Только x86_64 — vendor pack tools (dragonsecboot, script, update_dtb) — x86 бинарники

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
# Проверка: в flags должен быть "F" (fix-binary)
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

По умолчанию overlay содержит `/root/help/` (WiFi гайд, установка рабочих столов,
скрипты игр, настройка GPU/Vulkan) и тестовые скрипты в `/root/tests/`.
Запуск на плате: `bash /root/tests/test-all.sh`.

---

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

---

## Конфигурация

### Vendor sources

Репозитории и коммиты зафиксированы в `config/board.cubie-a7z.env`:

| Репозиторий | URL | Назначение |
|-------------|-----|------------|
| orangepi-build | [orangepi-xunlong/orangepi-build](https://github.com/orangepi-xunlong/orangepi-build) | defconfig, pack-uboot tools |
| linux-orangepi | [orangepi-xunlong/linux-orangepi](https://github.com/orangepi-xunlong/linux-orangepi) | Vendor BSP ядро 6.6.98+ |
| u-boot-orangepi | [orangepi-xunlong/u-boot-orangepi](https://github.com/orangepi-xunlong/u-boot-orangepi) | U-Boot (brandy-2.0) |
| allwinner-bsp | [radxa/allwinner-bsp](https://github.com/radxa/allwinner-bsp) | Boot0, SCP firmware |
| allwinner-target | [radxa/allwinner-target](https://github.com/radxa/allwinner-target) | GPU/WiFi/Xorg overlay |
| allwinner-device | [radxa/allwinner-device](https://github.com/radxa/allwinner-device) | sys_config.fex |
| aic8800 | [radxa-pkg/aic8800](https://github.com/radxa-pkg/aic8800) | WiFi USB driver |
| ai-sdk | [ZIFENG278/ai-sdk](https://github.com/ZIFENG278/ai-sdk) | NPU SDK (VIPLite v2.0) |
| Radxa stock image | [radxa-build/radxa-cubie-a7z](https://github.com/radxa-build/radxa-cubie-a7z/releases) | Извлечение boot0 |

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
- `MANIFEST.lock` фиксирует реальные SHA после fetch

## Известные особенности

- `dpkg-deb -x` не разрешает зависимости — shared libs добавляются вручную
  (см. `docs/rootfs-dependency-map.md`)
- GPU module (pvrsrvkm) собирается out-of-tree, требует симлинки `/gcc` → cross-compiler
- UFS может отсутствовать на некоторых SKU (ошибки в dmesg — нормально)
- Первая загрузка: `first-boot-resize` расширяет rootfs до полного размера SD
- GNU Make 4.4+ конфликтует с GPU kbuild — `.SECONDARY` патчится автоматически

---

## Руководство для новичков

### Кейс 1: Первая сборка с нуля (Docker/Podman)

Рекомендуемый путь. Кросс-компиляторы на хосте не нужны.

```bash
# 1. Клонировать репозиторий
git clone https://github.com/dok2d/cubie-a7z-debian.git
cd cubie-a7z-debian

# 2. Установить единственную зависимость хоста
sudo apt install qemu-user-static binfmt-support
sudo systemctl restart binfmt-support

# 3. Проверить что binfmt_misc настроен корректно
cat /proc/sys/fs/binfmt_misc/qemu-aarch64
# Должен показать "flags: F" — флаг "F" (fix-binary) критически важен.
# Без него chroot в arm64 rootfs не заработает.

# 4. Собрать Docker-образ (один раз, ~5 мин)
docker build -t cubie-builder -f docker/Dockerfile.builder .

# 5. Собрать всё (первый запуск: ~30 мин, ~8 ГБ скачивание)
docker run --rm -v $(pwd):/work cubie-builder make all

# 6. Результат: build/cubie_a7z-trixie.img.xz (~800 МБ)
ls -lh build/cubie_a7z-trixie.img.xz
```

**Для Podman**: замените `docker` на `podman`, добавьте `--privileged --user root` и суффикс `:Z`:
```bash
podman run --rm --privileged --user root -v .:/work:Z cubie-builder make all
```

### Кейс 2: Первая сборка без Docker (на хосте)

```bash
# 1. Установить ВСЕ зависимости сборки
sudo apt install -y \
  make git wget curl build-essential bc flex bison libssl-dev \
  gcc-arm-linux-gnueabi gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
  swig device-tree-compiler xxd busybox \
  debootstrap qemu-user-static binfmt-support \
  parted dosfstools e2fsprogs mtools xz-utils \
  u-boot-tools kmod cpio binutils

# 2. Проверить что все инструменты найдены
make deps

# 3. Сборка (требуется root для debootstrap/chroot)
sudo make all

# 4. Результат
ls -lh build/cubie_a7z-trixie.img.xz
```

### Кейс 3: Пересборка после изменений

Скрипты сборки идемпотентны — пропускают этапы, если выходные файлы уже существуют.

```bash
# Пересобрать всё с нуля
rm -rf build/
make all

# Пересобрать только rootfs (после изменений overlays/ или пакетов)
rm -rf build/rootfs build/rootfs-*.tar build/cubie_a7z-trixie.img*
make rootfs image

# Пересобрать только ядро (после изменений DTS или defconfig)
rm -rf build/kernel build/modules
make kernel rootfs image

# Пересобрать только загрузчик (после патча U-Boot)
rm -rf build/bootloader
make bootloader image

# Полная очистка (скачанные исходники остаются)
make clean

# Полная очистка включая скачанные исходники (~8 ГБ перекачивание)
make distclean
```

### Кейс 4: Изменение Device Tree

Кастомный DTS находится в `config/dts/sun60i-a733-cubie-a7z.dts`.

```bash
# 1. Редактировать DTS
nano config/dts/sun60i-a733-cubie-a7z.dts

# 2. Пересобрать ядро (DTS копируется в дерево ядра автоматически)
rm -rf build/kernel build/modules
make kernel

# 3. Пересобрать rootfs + образ (ядро встроено в rootfs)
rm -rf build/rootfs build/rootfs-*.tar build/cubie_a7z-trixie.img*
make rootfs image
```

### Кейс 5: Добавление пакета в rootfs

Пакеты перечислены в `scripts/30-build-rootfs.sh` как переменная `PACKAGES` через запятую.

```bash
# 1. Редактировать скрипт
nano scripts/30-build-rootfs.sh
# Найти строки PACKAGES= и добавить свой пакет, например:
# PACKAGES+=",htop,neofetch"

# 2. Проверить нужны ли shared-библиотеки, которых ещё нет в PACKAGES
# Запустить на Debian arm64 системе или в chroot:
apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts \
  --no-breaks --no-replaces --no-enhances your-package | grep "Depends:" | sort -u

# 3. Пересобрать rootfs + образ
rm -rf build/rootfs build/rootfs-*.tar build/cubie_a7z-trixie.img*
make rootfs image
```

**Почему ручное отслеживание зависимостей?** Мы используем `dpkg --unpack` вместо `apt install`,
потому что `apt install` в foreign-arch chroot требует `--privileged` Docker.
Каждая новая библиотека должна быть явно добавлена в `PACKAGES`. См. `docs/rootfs-dependency-map.md`.

### Кейс 6: Добавление файлов в образ

Поместите файлы в `overlays/rootfs/`, повторяя путь на целевой системе:

```bash
# Пример: свой MOTD
echo "Добро пожаловать на Cubie A7Z" > overlays/rootfs/etc/motd

# Пример: скрипт автозапуска
mkdir -p overlays/rootfs/usr/local/bin
cp my-script.sh overlays/rootfs/usr/local/bin/

# Пересборка
rm -rf build/rootfs build/rootfs-*.tar build/cubie_a7z-trixie.img*
make rootfs image
```

### Кейс 7: Добавление патча ядра

```bash
# 1. Клонировать исходники ядра (если ещё не скачаны)
make fetch

# 2. Внести изменения в sources/kernel/
cd sources/kernel
# ... редактировать файлы ...

# 3. Создать патч
git add -A && git commit -m "моё изменение"
git format-patch -1 -o ../../patches/kernel/

# 4. Пересборка (очистить ядро, патчи применяются при fetch)
cd ../..
rm -rf build/kernel build/modules
make fetch kernel rootfs image
```

### Кейс 8: Добавление патча U-Boot

Аналогично патчам ядра, но в `patches/u-boot/`:

```bash
cd sources/u-boot-vendor
# ... редактировать, коммитить ...
git format-patch -1 -o ../../patches/u-boot/
cd ../..
rm -rf build/bootloader
make fetch bootloader image
```

### Кейс 9: Обновление vendor sources

Для обновления vendor-репо до нового коммита:

```bash
# 1. Найти последний коммит
git ls-remote https://github.com/orangepi-xunlong/linux-orangepi.git orange-pi-6.6-sun60iw2

# 2. Обновить SHA в config/board.cubie-a7z.env
nano config/board.cubie-a7z.env
# Изменить KERNEL_COMMIT="..."

# 3. Очистить старые исходники и пересобрать
rm -rf sources/kernel build/
make all
```

**Внимание**: обновление vendor SHA может внести регрессии. Всегда тестируйте на железе.

### Кейс 10: Запись на SD-карту

```bash
# Определить устройство SD-карты
lsblk

# Способ 1: безопасный скрипт (с подтверждением и проверками)
sudo make flash DEV=/dev/sdX

# Способ 2: ручной dd
xzcat build/cubie_a7z-trixie.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
sync

# Способ 3: запись на несъёмное устройство (ОПАСНО)
sudo scripts/90-flash-sd.sh /dev/nvme0n1 --force
```

Скрипт записи:
- Отказывается писать на несъёмные устройства (без `--force`)
- Проверяет размер устройства vs размер образа
- Проверяет что разделы не смонтированы
- Запускает `fsck` после записи
- Показывает учётные данные по умолчанию

### Кейс 11: Отладка проблем загрузки

```bash
# 1. Подключить UART-адаптер к 40-pin header
#    Pin 10 (TX) → адаптер RX
#    Pin 12 (RX) → адаптер TX
#    Pin 6  (GND) → адаптер GND
#    ТОЛЬКО 3.3V адаптер!

# 2. Открыть терминал
screen /dev/ttyUSB0 115200
# или: minicom -D /dev/ttyUSB0 -b 115200

# 3. Вставить SD, подать питание. Должны увидеть:
#    - boot0 сообщения инициализации DRAM
#    - U-Boot баннер
#    - Лог загрузки ядра
#    - Приглашение для входа

# Типичные проблемы:
# - Нет вывода → неправильные пины UART, или boot0 не на секторе 256
# - boot0 зависает → неправильные DRAM params (нужен stock boot0)
# - U-Boot зависает → boot_package на неправильном смещении (должен быть 24576)
# - Kernel panic → отсутствует rootfs, неправильный параметр root=
# - Нет сети → wpa_supplicant.conf не настроен
```

### Кейс 12: Тестирование без полной пересборки

Если нужно обновить файл на уже записанной SD-карте:

```bash
# Смонтировать SD на хосте
sudo mount /dev/sdX2 /mnt          # rootfs (ext4)
sudo mount /dev/sdX1 /mnt/boot    # boot (FAT32)

# Скопировать файлы
sudo cp overlays/rootfs/root/tests/test-all.sh /mnt/root/tests/
sudo cp build/kernel/sun60i-a733-cubie-a7z.dtb /mnt/boot/

# Размонтировать
sudo umount /mnt/boot /mnt
```

### Кейс 13: Сборка отдельного модуля

```bash
# Только WiFi драйвер
make fetch
cd sources/kernel
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=$(pwd)/../../sources/aic8800/src/USB/driver_fw/drivers/aic8800 \
  CONFIG_AIC_LOADFW_SUPPORT=m CONFIG_AIC8800_WLAN_SUPPORT=m modules

# Только GPU драйвер (требуется собранное ядро)
make kernel  # если ещё не собрано
cd sources/kernel/bsp/modules/gpu/img-bxm/linux/rogue_km/build/linux/sunxi_linux
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KERNELDIR=$(pwd)/../../../../../../.. BUILD=release
```

### Кейс 14: Создание своего варианта образа

```bash
# 1. Скопировать конфиг
cp config/debian.env config/debian-custom.env
# Редактировать: hostname, user, password

# 2. Скопировать rootfs скрипт (или просто редактировать оригинал)
# Кастомизировать PACKAGES, сервисы, содержимое overlay

# 3. Собрать
make all
```

### Кейс 15: Работа с Docker-контейнером сборки

```bash
# Собрать Docker-образ
docker build -t cubie-builder -f docker/Dockerfile.builder .

# Запустить один этап сборки
docker run --rm -v $(pwd):/work cubie-builder make fetch
docker run --rm -v $(pwd):/work cubie-builder make kernel

# Интерактивная shell внутри контейнера
docker run --rm -it -v $(pwd):/work cubie-builder bash

# UID/GID, совпадающие с хостом (избегает проблем с правами)
docker build --build-arg BUILDER_UID=$(id -u) --build-arg BUILDER_GID=$(id -g) \
  -t cubie-builder -f docker/Dockerfile.builder .

# Примечание: rootfs этап требует root (debootstrap/chroot)
# Docker запускает от root по умолчанию. Podman нуждается в --privileged --user root.
```

### Кейс 16: Процесс загрузки платы

```
Подача питания
  → BROM (ROM-код в SoC)
    → Читает boot0 с SD сектора 256 (смещение 128 КБ)
      → boot0 инициализирует DRAM, загружает boot_package с сектора 24576
        → boot_package содержит U-Boot + DTB + SCP firmware
          → U-Boot читает extlinux.conf или boot.scr с FAT32 раздела
            → Загружает образ ядра Image + DTB
              → Ядро стартует, монтирует ext4 rootfs
                → systemd запускает сервисы
```

См. [boot-layout.md](boot-layout.md) для секторных смещений и карты разделов.

### Кейс 17: Ошибки «отсутствует shared-библиотека»

Когда бинарник падает с "error while loading shared libraries":

```bash
# 1. На плате, найти что отсутствует
ldd /usr/bin/проблемный-бинарник

# 2. Найти какой Debian пакет содержит эту библиотеку
apt-file search libmissing.so
# или: dpkg -S libmissing.so (если apt-file недоступен)

# 3. Добавить пакет в PACKAGES в scripts/30-build-rootfs.sh
# 4. Пересобрать rootfs + образ
```

См. `docs/rootfs-dependency-map.md` для текущего дерева зависимостей.

### Кейс 18: Кросс-компиляция программы для платы

```bash
# Используя кросс-компилятор напрямую
aarch64-linux-gnu-gcc -o hello hello.c

# Скопировать на плату
scp hello cubie@<ip>:/home/cubie/

# Или поместить в overlay для включения в образ
cp hello overlays/rootfs/usr/local/bin/
```

### Кейс 19: Установка рабочего стола на плате

Образ поставляется минимальным (CLI). Скрипты установки рабочих столов в `/root/help/wm/`:

```bash
# На плате:
bash /root/help/wm/install-xfce.sh     # XFCE4 (рекомендуется, X11)
bash /root/help/wm/install-i3.sh       # i3 тайловый WM (X11, лёгкий)
bash /root/help/wm/install-lxqt.sh     # LXQt (X11, Qt)
bash /root/help/wm/install-sway.sh     # Sway (Wayland)
bash /root/help/wm/install-labwc.sh    # labwc (Wayland, openbox-подобный)
```

### Кейс 20: Настройка GPU ускорения

GPU аппаратное ускорение предустановлено, но требует X11:

```bash
# На плате:
bash /root/help/wm/install-xfce.sh   # Установить X11 рабочий стол
# Перезагрузить, войти через HDMI

# Проверить что GPU активен
DISPLAY=:0 glxinfo | grep renderer
# Должен показать: PowerVR B-Series BXM-4-64

# Если показывает llvmpipe, проверить:
cat /etc/environment     # Должен содержать LD_LIBRARY_PATH=/usr/local/lib
ls /dev/dri/renderD128   # Должен существовать (модуль pvrsrvkm загружен)
```

См. [GPU-TODO.md](../GPU-TODO.md) для технических деталей стека GLVND/Mesa.
