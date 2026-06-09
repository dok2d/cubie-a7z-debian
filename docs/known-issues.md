# Известные проблемы — Cubie A7Z Debian

Обновлено: 2026-06-08

## Решённые

- **WiFi probe fail** → заменён на radxa-pkg/aic8800 driver (USB, D80 native)
- **HDMI alloc failed** → cma=64M, работает
- **GPU pvrsrvkm** → gpu-supply + power-domains, работает
- **USB-C xhci2** → u2phy + serdes + combo PHY, HID работает
- **AXP515 probe -22** → чип не существует на плате (AXP318), disabled в DTS
- **USB-C VBUS** → PL2 GPIO → SGM2576 load switch (по схеме)
- **dbus circular inclusion** → убран /etc/dbus-1/system.conf
- **Boot delay 15с** → GPU power domains (pd_gpu_top/core) раскомментированы
- **ext4 corruption** → CONFIG_ENV_IS_NOWHERE в U-Boot
- **Boot0 не загружается** → allwinner-device boot0 имеет неправильные DRAM params; используем stock boot0 из Radxa rsdk-b1 образа (автоматическая загрузка в 00-fetch-sources.sh)
- **WiFi не подключается после загрузки** → отсутствовал /etc/network/interfaces + networking.service не был enabled
- **NPU не загружается** → vipcore не был в modules-load.d
- **rfkill ошибки в dmesg** → убраны пустые power_en/pinctrl/clocks свойства из DTS
- **SSH Permission denied** → sshd_config не включал PasswordAuthentication; добавлен drop-in в sshd_config.d/
- **SSH libwrap/libwtmpdb** → добавлены libwrap0, libwtmpdb0 в пакеты rootfs
- **Hostname = container ID** → переменная $HOSTNAME конфликтовала с bash builtin; переименована в TARGET_HOSTNAME
- **GPU build /gcc not found** → LICHEE_TOOLCHAIN_PATH/LICHEE_CROSS_COMPILER не были установлены; исправлено
- **GPU .SECONDARY/.NOTINTERMEDIATE** → GNU Make 4.4+ конфликт; .SECONDARY патчится при сборке
- **CPU freq scaling** → schedutil работает: A55 до 1794 MHz, A76 до 2002 MHz (ранее считалось сломанным)
- **GPU software rendering** → PVR Mesa из allwinner-target overlay была в rootfs, но не активирована. Исправление: `LD_LIBRARY_PATH=/usr/local/lib` в `/etc/environment`, `AccelMethod "glamor"` в Xorg конфиге, пакет `libxcb-dri2-0`. Результат: `glamor X acceleration enabled on PowerVR B-Series BXM-4-64`

## Открытые

### UFS: link_startup_fail
- **Чип не впаян** на этом SKU платы. DTS node оставлен для совместимости.
- Не влияет на работу — ошибки в dmesg при загрузке ожидаемы.

### GLX показывает llvmpipe
- Xorg glamor использует EGL+PVR аппаратно (подтверждено)
- Но `glxinfo` показывает llvmpipe — Debian GLVND направляет GLX в системную Mesa
- На реальный рендеринг не влияет — glamor работает через EGL
- Приложения через EGL получают GPU ускорение; GLX-only приложения — software fallback

### ET7304Y TCPC: probe failed -22
- Чип найден на I2C bus 14 addr 0x4E
- Generic `tcpci` драйвер возвращает -EINVAL
- USB-C host работает без PD-negotiation (через usbc2 DTS node)
- **Что даст исправление**: USB-C PD зарядка, DP Alt Mode через typec framework
- Нужен vendor-specific драйвер или правильные port/connector nodes

### Rootfs: dpkg-deb -x не резолвит зависимости
- Shared libs (libwrap0, libwtmpdb0 и т.д.) добавляются вручную в PACKAGES
- Каждая новая утилита может потребовать новые libs
- **Что даст исправление**: mmdebstrap автоматически разрешит все зависимости
- Блокер: mmdebstrap требует binfmt_misc, недоступен в контейнере без --privileged

### TWI2: SCL stuck low
- Disabled в DTS. Нет подключённых устройств на 40-pin I2C2.

### regulatory.db
- `cfg80211: failed to load regulatory.db` — нет wireless-regdb firmware
- WiFi работает в permissive mode
- **Что даст исправление**: корректные TX power limits по странам, чистый dmesg
