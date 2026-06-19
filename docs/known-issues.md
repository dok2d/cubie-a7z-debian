# Известные проблемы — Cubie A7Z Debian

Обновлено: 2026-06-11

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

### X11 WM и GPU ускорение: конфликт GLVND

**Суть**: GPU аппаратное ускорение работает, но путь к нему различается
между EGL и GLX. Рабочие столы X11 используют аппаратную glamor-композицию,
но `glxinfo` показывает программный рендеринг (llvmpipe).

**Архитектура — два DRI устройства**:

| Card | Драйвер | KMS | Роль |
|------|---------|-----|------|
| card0 | sunxi-drm | Да | Контроллер дисплея (HDMI выход) |
| card1 | pvrsrvkm | Нет | 3D GPU (PowerVR BXM-4-64), только рендеринг |

Xorg использует card0 (modesetting) для дисплея. GPU ускорение идёт через
card1 по пути EGL → PVR Mesa → pvrsrvkm → renderD128.

**Как это работает**: Radxa поставляет non-GLVND сборку PVR Mesa в `/usr/local/lib/`
(с алиасом `sunxi-drm_dri.so` → `pvr_dri.so`). Процесс Xorg загружает эти
библиотеки через `LD_LIBRARY_PATH=/usr/local/lib`, обходя GLVND-диспетчер Debian.
Glamor-ускорение работает через EGL напрямую.

**Конфликт GLVND**:

```
EGL путь (работает):
  Приложение → /usr/local/lib/libEGL.so.1 (PVR Mesa, non-GLVND)
    → /usr/local/lib/dri/sunxi-drm_dri.so (PVR gallium)
      → pvrsrvkm → GPU аппаратно ✓

GLX путь (программный):
  Приложение → /usr/lib/aarch64-linux-gnu/libGL.so.1 (Debian GLVND)
    → libGLX_mesa.so.0 (системная Mesa)
      → /usr/lib/aarch64-linux-gnu/dri/ (нет sunxi-drm_dri.so)
        → llvmpipe (CPU программный рендеринг) ✗
```

**Что работает**:
- `glamor X acceleration enabled on PowerVR B-Series BXM-4-64` — подтверждено в Xorg.log
- X11 WM (XFCE, i3, LXQt) через lightdm/sddm — композиция аппаратно ускорена
- EGL-приложения (GLES игры, glmark2-es2, Chromium с `--use-gl=egl`)
- Vulkan приложения (через `/usr/lib/libVK_IMG.so`, ICD зарегистрирован)
- OpenCL (`/usr/lib/libPVROCL.so`)
- KMSDRM-игры (Quake II 60fps, Half-Life 60fps) — без X11

**Что не работает**:
- `glxinfo` показывает `llvmpipe (LLVM 19.1.7)` — это GLX путь через GLVND
- Приложения использующие только GLX рендеринг (редко) — программный fallback
- Firefox композиция — программный режим (190% CPU, 460 МБ RAM) без принуждения к EGL
- `glmark2` (не es2 версия) использует GLX → software; использовать `glmark2-es2`

**Wayland WM** (sway, labwc) обходят эту проблему — используют EGL нативно
с `WLR_DRM_DEVICES=/dev/dri/card0`, PVR Mesa обрабатывает рендеринг через EGL.

**Обход для GLX-приложений**:
```bash
# Принудить приложения использовать EGL вместо GLX (где поддерживается)
export __GLX_VENDOR_LIBRARY_NAME=mesa
export MESA_LOADER_DRIVER_OVERRIDE=pvr

# Для Firefox
MOZ_X11_EGL=1 firefox
```

**Возможные исправления** (полный анализ в GPU-TODO.md):
1. **ld.so.conf.d приоритет** — добавить `/usr/local/lib` в глобальный путь линковщика
   (PVR Mesa `libEGL.so.1` получит приоритет над GLVND)
2. **Замена DRI драйверов** — скопировать `sunxi-drm_dri.so` в системный DRI путь
   (риск: несовместимость ABI Mesa между PVR сборкой и Debian Mesa)
3. **Собрать PVR Mesa как GLVND vendor** — пересобрать с `-Dglvnd=enabled`,
   установить как `/etc/glvnd/egl_vendor.d/10_pvr.json` (идеально, но сложно)

**Влияние на выбор WM**:

| WM | Протокол | Ускорение | Примечание |
|----|----------|-----------|------------|
| XFCE4 | X11 | glamor (EGL) | Рекомендуется. ~300 МБ. GPU композиция работает. |
| i3 | X11 | glamor (EGL) | Тайловый, лёгкий. ~200 МБ. Тот же GPU путь. |
| LXQt | X11 | glamor (EGL) | Qt. ~350 МБ. Тот же GPU путь. |
| sway | Wayland | EGL нативный | Нет проблемы GLVND. 200 МБ. `WLR_DRM_DEVICES=/dev/dri/card0`. |
| labwc | Wayland | EGL нативный | Нет проблемы GLVND. 150 МБ. Самый лёгкий с GPU. |
| KMSDRM | Нет | EGL нативный | Нет оверхеда WM. Лучший для игр. Нет рабочего стола. |

**Рекомендация**: Для рабочего стола — XFCE4 или i3 проверены и стабильны. Glamor
композиция аппаратно ускорена. Проблема GLX/llvmpipe косметическая для
большинства задач (композиция, веб, терминал). Для бенчмарков GPU или игр
используйте `glmark2-es2` (EGL) или KMSDRM режим.

### ET7304Y TCPC: probe failed -22 → Решено

- **ET7304Y TCPC probe -22** → бэкпортированы апстримные патчи
  (Yuanshen Cao v3 + Charkov v3 fallback compatible). ET7304 совместим с RT1715,
  VID 0x6DCF. Драйвер: `tcpci_rt1711h`. Compatible:
  `"etekmicro,et7304","richtek,rt1715"`. Проверяется `test-typec.sh`.
- USB-C PD negotiation и role switching теперь работают через mainline TCPM.
- **Статус DP Alt Mode**: TCPC-согласование готово (altmodes node в DTS), но
  видеовыход требует дополнительной работы:
  - PS8743 orientation mux node (нужен I2C адрес из схемы)
  - Подключение `edp0` DP source к typec connector
  - Переключение combo PHY (combo0_usb ↔ combo0_dp)
  - Вынесено в отдельную задачу.

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
