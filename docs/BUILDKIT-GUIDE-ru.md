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

---

## Практические рецепты (на плате)

Эти инструкции выполняются **на самой плате** после загрузки, а не при сборке образа.

### Рецепт 1: Смена пароля root или пользователя

```bash
# Сменить пароль root
passwd

# Сменить пароль пользователя cubie
passwd cubie

# Чтобы задать другой пароль при сборке образа,
# отредактируйте config/debian.env:
#   ROOT_PASSWORD="newpass"
#   DEFAULT_PASSWORD="newpass"
```

### Рецепт 2: Добавить нового пользователя

```bash
# Создать пользователя с домашней папкой, bash и sudo
useradd -m -s /bin/bash -G sudo,audio,video,render,input newuser
passwd newuser

# Проверить
su - newuser
whoami
```

### Рецепт 3: Удалить пользователя

```bash
# Удалить пользователя вместе с домашней директорией
userdel -r olduser
```

### Рецепт 4: Установить пакеты из репозиториев Debian

Плата имеет полный доступ к репозиториям Debian Trixie:

```bash
apt update
apt install <пакет>

# Примеры:
apt install python3 python3-pip   # Python
apt install nginx                  # Веб-сервер
apt install mc                     # Файловый менеджер Midnight Commander
apt install neofetch               # Информация о системе
apt install iperf3                 # Бенчмарк сети
apt install nmap                   # Сканер сети
apt install git                    # Контроль версий
```

**Примечание**: На 1 ГБ SKU большие пакеты могут вызвать нехватку RAM при установке.
zram swap (256 МБ) помогает, но тяжёлые компиляции (GCC, Rust) могут вызвать OOM.

### Рецепт 5: Настройка WiFi — полная инструкция

```bash
# 1. Проверить что WiFi чип включён
cat /sys/class/misc/sunxi-rfkill/wlan/state
# Должно быть 1. Если 0:
echo 1 > /sys/class/misc/sunxi-rfkill/wlan/state

# 2. Сканировать сети
iw dev wlan0 scan | grep SSID

# 3. Настроить wpa_supplicant
nano /etc/wpa_supplicant/wpa_supplicant.conf
```

Добавить сеть:
```
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="МояСеть"
    psk="МойПароль"
}
```

```bash
# 4. Перезапустить сеть
systemctl restart networking

# 5. Проверить
ip addr show wlan0     # должен быть IP
ping 8.8.8.8           # должен работать
```

#### Подключение к скрытой сети

```
network={
    ssid="HiddenNetwork"
    scan_ssid=1
    psk="password"
}
```

#### Подключение к корпоративной сети (WPA2-EAP)

```
network={
    ssid="CorpWiFi"
    key_mgmt=WPA-EAP
    eap=PEAP
    identity="user@example.com"
    password="secret"
    phase2="auth=MSCHAPV2"
}
```

#### Подключение к открытой сети

```
network={
    ssid="OpenCafe"
    key_mgmt=NONE
}
```

#### Несколько сетей с приоритетом

```
network={
    ssid="ДомашняяWiFi"
    psk="home123"
    priority=10
}
network={
    ssid="РабочаяWiFi"
    psk="work456"
    priority=5
}
```

Будет использоваться видимая сеть с наивысшим приоритетом.

### Рецепт 6: Статический IP-адрес

```bash
nano /etc/network/interfaces.d/wlan0
```

Заменить `dhcp` на static:
```
allow-hotplug wlan0
iface wlan0 inet static
    address 192.168.1.100
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 8.8.8.8 8.8.4.4
    wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
```

```bash
systemctl restart networking
```

### Рецепт 7: Настройка SSH

#### Сменить порт SSH

```bash
nano /etc/ssh/sshd_config.d/cubie-a7z.conf
```
```
Port 2222
PermitRootLogin yes
PasswordAuthentication yes
```
```bash
systemctl restart ssh
# Подключение: ssh -p 2222 cubie@<ip>
```

#### Настроить SSH-ключи (вход без пароля)

На **хосте**:
```bash
# Сгенерировать ключ (если нет)
ssh-keygen -t ed25519

# Скопировать публичный ключ на плату
ssh-copy-id cubie@<ip-платы>

# Теперь вход без пароля
ssh cubie@<ip-платы>
```

#### Отключить вход по паролю (только ключи)

После подтверждения что ключ работает:
```bash
# На плате:
nano /etc/ssh/sshd_config.d/cubie-a7z.conf
```
```
PasswordAuthentication no
PubkeyAuthentication yes
```
```bash
systemctl restart ssh
```

#### Отключить SSH-доступ для root

```bash
nano /etc/ssh/sshd_config.d/cubie-a7z.conf
```
```
PermitRootLogin no
```
```bash
systemctl restart ssh
```

### Рецепт 8: Передача файлов на/с платы

```bash
# Скопировать файл на плату
scp myfile.txt cubie@<ip>:/home/cubie/

# Скопировать файл с платы
scp cubie@<ip>:/home/cubie/results.txt .

# Скопировать директорию
scp -r my-project/ cubie@<ip>:/home/cubie/

# Интерактивная передача
sftp cubie@<ip>

# rsync (лучше для больших/инкрементальных передач)
rsync -avz my-project/ cubie@<ip>:/home/cubie/my-project/
```

### Рецепт 9: Часовой пояс и локаль

```bash
# Список часовых поясов
timedatectl list-timezones | grep Moscow

# Установить часовой пояс
timedatectl set-timezone Europe/Moscow

# Проверить
date
timedatectl status

# Установить локаль (C.utf8 по умолчанию, locale-gen не нужен)
# Для конкретной локали:
apt install locales
dpkg-reconfigure locales
```

### Рецепт 10: Сменить hostname

```bash
hostnamectl set-hostname my-cubie
# Также обновить /etc/hosts
nano /etc/hosts
# Изменить: 127.0.1.1  my-cubie
```

### Рецепт 11: Подключить USB-накопитель

```bash
# 1. Подключить USB к J4 (верхний USB-C, через OTG-адаптер)

# 2. Найти устройство
lsblk
# Обычно: /dev/sda1

# 3. Смонтировать
mkdir -p /mnt/usb
mount /dev/sda1 /mnt/usb

# 4. Использовать
ls /mnt/usb

# 5. Размонтировать перед извлечением
umount /mnt/usb
```

#### Автомонтирование при загрузке

```bash
# Найти UUID
blkid /dev/sda1

# Добавить в fstab
echo 'UUID=xxxx-xxxx  /mnt/usb  vfat  defaults,nofail  0  2' >> /etc/fstab
```

### Рецепт 12: Проверить состояние системы

```bash
# Температура CPU
cat /sys/class/thermal/thermal_zone3/temp
# Делить на 1000 для градусов (52000 = 52°C)

# Температура GPU
cat /sys/class/thermal/thermal_zone4/temp

# Температура DDR
cat /sys/class/thermal/thermal_zone1/temp

# Все температуры сразу
paste <(cat /sys/class/thermal/thermal_zone*/type) \
      <(cat /sys/class/thermal/thermal_zone*/temp) \
  | awk '{printf "%-20s %d°C\n", $1, $2/1000}'

# Частота CPU
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq

# Использование RAM
free -h

# Использование диска
df -h

# Аптайм и нагрузка
uptime

# Сбойные systemd юниты
systemctl --failed

# Ошибки dmesg
dmesg | grep -i error | tail -20

# Полный тест железа
bash /root/tests/test-all.sh
```

### Рецепт 13: Управление systemd-сервисами

```bash
# Список запущенных сервисов
systemctl list-units --type=service

# Статус конкретного сервиса
systemctl status ssh
systemctl status networking

# Запустить / остановить / перезапустить
systemctl start nginx
systemctl stop nginx
systemctl restart nginx

# Включить/выключить автозапуск
systemctl enable nginx
systemctl disable nginx

# Логи сервиса
journalctl -u ssh -f          # следить в реальном времени
journalctl -u ssh --since today
journalctl -u networking -b   # с последней загрузки
```

### Рецепт 14: Создать свой systemd-сервис

Пример: автозапуск Python-скрипта при загрузке.

```bash
cat > /etc/systemd/system/my-app.service << 'EOF'
[Unit]
Description=My Application
After=network.target

[Service]
Type=simple
User=cubie
WorkingDirectory=/home/cubie
ExecStart=/usr/bin/python3 /home/cubie/my-app.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable my-app
systemctl start my-app
systemctl status my-app
```

### Рецепт 15: Настроить cron-задачу

```bash
# Редактировать crontab для root
crontab -e

# Примеры:
# Запускать скрипт каждые 5 минут
*/5 * * * * /home/cubie/my-script.sh

# Запускать в 3 ночи ежедневно
0 3 * * * apt update && apt upgrade -y

# Запускать при перезагрузке
@reboot /home/cubie/startup.sh

# Сохранить и просмотреть
crontab -l
```

### Рецепт 16: Настроить Bluetooth

```bash
# Запустить bluetoothctl
bluetoothctl

# Внутри bluetoothctl:
power on
agent on
default-agent
scan on
# Ждать появления устройств...
# pair XX:XX:XX:XX:XX:XX
# connect XX:XX:XX:XX:XX:XX
# trust XX:XX:XX:XX:XX:XX
scan off
exit
```

### Рецепт 17: Воспроизведение аудио через HDMI

```bash
# Список звуковых карт
aplay -l
# Должна быть: sndhdmi

# Воспроизвести WAV файл
aplay -D hw:sndhdmi test.wav

# Тест динамиков
speaker-test -D hw:sndhdmi -c 2 -t wav

# Регулировка громкости
amixer -c sndhdmi set PCM 80%
```

### Рецепт 18: Запуск NPU inference

```bash
# Создать конфигурацию
cat > /tmp/resnet50.txt << 'EOF'
[network]
/usr/share/npu/models/resnet50.nb
[input]
/usr/share/npu/input_data/goldfish_224x224.dat
EOF

# Запустить inference
vpm_run -s /tmp/resnet50.txt -l 1
# Результат: время inference ~7.5 мс

# Со случайными данными (224x224x3 = 150528 байт)
dd if=/dev/urandom of=/tmp/random.dat bs=150528 count=1
cat > /tmp/test.txt << 'EOF'
[network]
/usr/share/npu/models/resnet50.nb
[input]
/tmp/random.dat
EOF
vpm_run -s /tmp/test.txt -l 1
```

### Рецепт 19: Работа с GPIO

```bash
# Список GPIO чипов
gpiodetect

# Список всех GPIO линий
gpioinfo

# Прочитать значение GPIO (напр. PB0 = GPIO 32 на gpiochip0)
gpioget gpiochip0 32

# Установить выход в высокий уровень
gpioset gpiochip0 32=1

# Установить в низкий уровень
gpioset gpiochip0 32=0

# Мониторить события GPIO
gpiomon gpiochip0 32
```

Формула номера GPIO:
```
gpiochip0 (порты A-K): GPIO = порт × 32 + пин
  A=0, B=1, C=2, D=3, ..., J=9, K=10

gpiochip1 (порты L-M): GPIO = порт × 32 + пин
  L=0, M=1
```

Пример: PD16 = 3×32 + 16 = GPIO 112

### Рецепт 20: I2C и SPI доступ

```bash
# Список I2C шин
i2cdetect -l

# Сканировать устройства на шине 2
i2cdetect -y 2

# Прочитать регистр
i2cget -y 2 0x50 0x00

# Записать регистр
i2cset -y 2 0x50 0x00 0xFF

# SPI loopback тест (соединить MOSI с MISO на 40-pin header)
# Пины: 19 (MOSI) → 21 (MISO), 23 (CLK), 24 (CS0)
echo -ne '\x01\x02\x03' | spidev_test -D /dev/spidev1.0 -v
```

### Рецепт 21: Бэкап и восстановление SD-карты

```bash
# На хосте: бэкап всей SD-карты
sudo dd if=/dev/sdX bs=4M status=progress | xz -T0 > cubie-backup.img.xz

# На хосте: восстановление из бэкапа
xzcat cubie-backup.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
sync

# На хосте: бэкап только rootfs (меньше, без загрузчика)
sudo dd if=/dev/sdX2 bs=4M status=progress | xz -T0 > rootfs-backup.img.xz

# На плате: бэкап важных конфигов
tar czf /tmp/config-backup.tar.gz \
  /etc/wpa_supplicant/wpa_supplicant.conf \
  /etc/network/interfaces.d/ \
  /etc/ssh/sshd_config.d/ \
  /etc/hostname \
  /etc/hosts
scp /tmp/config-backup.tar.gz user@host:/backups/
```

### Рецепт 22: Ручное расширение файловой системы

Обычно `first-boot-resize` делает это автоматически. Если не сработало:

```bash
# Проверить текущий размер
df -h /

# Расширить раздел до конца SD
echo ", +" | sfdisk -f --no-reread --no-tell-kernel -N 2 /dev/mmcblk0
partx -u /dev/mmcblk0
resize2fs /dev/mmcblk0p2

# Проверить
df -h /
```

### Рецепт 23: Простой веб-сервер

```bash
# Вариант 1: Python (уже установлен, без зависимостей)
cd /var/www && python3 -m http.server 8080 &

# Вариант 2: nginx (промышленный)
apt install nginx
systemctl start nginx
# Открыть http://<ip-платы>/ в браузере

# Вариант 3: lighttpd (лёгкий)
apt install lighttpd
systemctl start lighttpd
```

### Рецепт 24: Установка Python

```bash
# Python 3 доступен из репозиториев Debian
apt install python3 python3-pip python3-venv

# Виртуальное окружение (рекомендуется на 1 ГБ RAM)
python3 -m venv ~/myenv
source ~/myenv/bin/activate

# Установка пакетов
pip install flask requests numpy

# Примечание: компиляция больших пакетов (scipy, pandas, torch)
# может вызвать OOM на 1 ГБ SKU. Используйте готовые wheel или
# кросс-компилируйте на хосте.
```

### Рецепт 25: Установка Node.js

```bash
apt install nodejs npm

# Проверить
node --version
npm --version

# Простой HTTP сервер
cat > ~/server.js << 'EOF'
const http = require('http');
http.createServer((req, res) => {
  res.writeHead(200);
  res.end('Hello from Cubie A7Z!\n');
}).listen(3000);
console.log('Server running on port 3000');
EOF
node ~/server.js &
```

### Рецепт 26: Настройка файрволла

```bash
apt install ufw

# Разрешить SSH (сначала!)
ufw allow 22/tcp

# Разрешить HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Включить файрволл
ufw enable

# Проверить статус
ufw status verbose

# Удалить правило
ufw delete allow 80/tcp
```

### Рецепт 27: Headless-режим (без монитора)

Плата работает headless из коробки — SSH включён по умолчанию.

```bash
# 1. Настроить WiFi до перехода в headless (см. Рецепт 5)

# 2. Найти плату в сети (с другого компьютера):
nmap -sn 192.168.1.0/24 | grep -A1 cubie
# Или проверить таблицу DHCP на роутере

# 3. Подключиться по SSH
ssh cubie@<ip>

# 4. Если не удаётся найти IP — подключить UART:
#    screen /dev/ttyUSB0 115200
#    Войти, выполнить: hostname -I
```

### Рецепт 28: Раздача интернета через USB (тетеринг)

```bash
# Если плата имеет WiFi-интернет и вы подключили ноутбук через USB-C J4:
# Включить IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Настроить NAT (wlan0 имеет интернет)
apt install iptables
iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
```

### Рецепт 29: Мониторинг сетевого трафика

```bash
# Пропускная способность в реальном времени
apt install iftop
iftop -i wlan0

# Список соединений
ss -tulnp

# Статистика интерфейса
ip -s link show wlan0

# Тест DNS
nslookup google.com
dig google.com
```

### Рецепт 30: Обновление ядра или DTB без полной пересборки

Если есть новый kernel Image или DTB и нужно обновить запущенную SD-карту:

```bash
# 1. Смонтировать boot-раздел
mount /dev/mmcblk0p1 /boot

# 2. Скопировать новое ядро
scp user@buildhost:build/kernel/vmlinuz-6.6.98-cubie_a7z /boot/vmlinuz-6.6.98+

# 3. Скопировать новый DTB
scp user@buildhost:build/kernel/sun60i-a733-cubie-a7z.dtb /boot/

# 4. Скопировать новые модули (если изменились)
scp -r user@buildhost:build/modules/lib/modules/6.6.98+/ /lib/modules/
depmod 6.6.98+

# 5. Перезагрузить
reboot
```
