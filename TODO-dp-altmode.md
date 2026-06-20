# TODO: USB-C DisplayPort Alt Mode — полная реализация

## Контекст

Проект: `dok2d/cubie-a7z-debian`. Ядро 6.6.98+ BSP (orangepi-xunlong).
SoC: Allwinner A733 (sun60iw2p1). Плата: Radxa Cubie A7Z v1.10.

**Предыдущий PR** (`feature/et7304-tcpc-dp-altmode`) решил probe -22:
ET7304 TCPC теперь пробится через `tcpci_rt1711h`, TCPM создаёт
`/sys/class/typec/port0/`, altmodes зарегистрированы в DTS.

**Проблема**: видеосигнал из SoC не доходит до USB-C пинов. Нужны
три компонента: orientation mux, DP source controller, combo PHY switching.

## Цепочка сигнала (целевая)

```
SoC Display Engine
  → tcon4 (TV timing controller 4, 0x05731000)
    → edp0 (eDP/DP controller, 0x05740000)
      → combo0_dp (serdes combophy0, DP mode)
        → PS8743 orientation mux (I2C, переключает lanes по CC)
          → USB-C connector (J4, 24-pin)
            → DP sink (монитор, AR-очки, dock)

Управление:
  ET7304 TCPC (I2C 0x4E на S_TWI1)
    → TCPM framework
      → type-c-mux → PS8743 (orientation + mode switch)
      → typec-switch → combo PHY (USB ↔ DP lane config)
      → altmode driver → DP Alt Mode negotiation
```

## Схема платы

Скачать: https://dl.radxa.com/cubie/a7z/docs/hw/radxa_Cubie_A7Z_v1100__schematic.pdf

Ключевые страницы:
- **p.12**: USB-C connector J4 pinout, ET7304 подключение, SS lanes routing
- **p.11**: Serdes/combo PHY, PCIe/DP/USB3 мультиплексирование
- **p.4**: PMIC AXP8191 — питание PHY (cldo5 = serdes 1.8V)

---

## Фаза 1 — Ресёрч: PS8743 orientation mux

### 1.1 Найти PS8743 на схеме

```
Цель: определить I2C-адрес, шину, GPIO (если есть) для PS8743
```

1. Открыть схему p.12 (USB-C section)
2. Найти микросхему PS8743 (Parade Technology USB-C mux/redriver)
   - Альтернативные маркировки: PS8743B, PS8743A
   - Если не PS8743 — определить, какой чип реально стоит
3. Записать:
   - [ ] I2C шина: какой TWI? (twi0..twi8, s_twi0, s_twi1?)
   - [ ] I2C адрес: типовые для PS8743 — 0x10, 0x11, 0x20, 0x28 (зависит от ADDR pin)
   - [ ] Есть ли отдельный GPIO для reset/enable?
   - [ ] Какие SoC-пины подключены к SS_TX1±, SS_RX1±, SS_TX2±, SS_RX2±?
   - [ ] Куда идут SBU1/SBU2 (AUX channel для DP)?
   - [ ] Как подключён DP_HPD?

### 1.2 Изучить PS8743 драйвер в ядре

```bash
# Путь в BSP ядре
cat sources/kernel/drivers/usb/typec/mux/Kconfig | grep -A10 PS8743
cat sources/kernel/drivers/usb/typec/mux/ps8743.c | head -100

# Или на GitHub
# https://github.com/orangepi-xunlong/linux-orangepi/blob/orange-pi-6.6-sun60iw2/drivers/usb/typec/mux/ps8743.c
```

Что выяснить:
- [ ] Compatible string (`"parade,ps8743"` или иной?)
- [ ] Какие DT-свойства принимает (mode-switch, orientation-switch, ports)
- [ ] Как интегрируется с TCPM (через typec_mux_desc / typec_switch_desc?)
- [ ] Есть ли поддержка DP Alt Mode lane config (2-lane, 4-lane)?

### 1.3 Изучить vendor mux driver (SUNXI_PHY_SWITCHER)

BSP defconfig имеет `CONFIG_TYPEC_MUX_SUNXI_PHY_SWITCHER=y`.

```bash
find sources/kernel -name '*phy_switcher*' -o -name '*sunxi*mux*' | head -20
cat sources/kernel/bsp/drivers/usb/typec/mux/*.c | head -200
```

Что выяснить:
- [ ] Это wrapper поверх PS8743 или отдельная логика?
- [ ] Как взаимодействует с combo PHY?
- [ ] Поддерживает ли DP lane switching?
- [ ] Нужен ли он вместо/вместе с ps8743.c?

### 1.4 Проверить Orange Pi 4 Pro DTS

Тот же SoC A733. Если у них есть mux — скопировать подход.

```bash
grep -A30 'ps8743\|mux\|orientation\|TYPEC_DP\|typec-mux' \
  sources/kernel/arch/arm64/boot/dts/allwinner/sun60i-a733-orangepi-4-pro.dts
```

Известно: в текущем DTS OrangePi 4 Pro DP Alt Mode **тоже не реализован**.
Но стоит проверить, не появился ли в свежих коммитах.

### 1.5 Результат фазы 1

Документ с:
- Точный I2C адрес и шина PS8743
- Compatible string для DTS
- Понимание, какой драйвер использовать (ps8743.c vs sunxi_phy_switcher)
- Решение: нужен ли отдельный GPIO reset

---

## Фаза 2 — Ресёрч: eDP/DP source controller (edp0)

### 2.1 Изучить edp0 в SoC dtsi

Уже найдено в `sun60iw2p1.dtsi`:

```dts
edp0: edp0@5720000 {
    compatible = "allwinner,drm-edp";
    reg = <0x0 0x05740000 0x0 0x1000>,    /* edp base */
          <0x0 0x05760000 0x0 0x0020>;     /* edp pad base */
    interrupts = <GIC_SPI 62 IRQ_TYPE_LEVEL_HIGH>;
    power-domains = <&pd SUN60IW2_PCK_VO1>;
    clocks = <&ccu CLK_EDP_TV>, <&ccu CLK_EDP>;
    clock-names = "clk_edp", "clk_bus_edp";
    phys = <&combo0_dp>, <&aux_hpd_phy>;
    phy-names = "dp-phy", "aux-phy";
    status = "disabled";

    ports {
        edp_in: port@0 {
            edp0_in_tcon4: endpoint@0 {
                remote-endpoint = <&tcon4_out_edp0>;
            };
        };
        edp_out: port@1 {
            /* пусто — для board-level endpoint */
        };
    };
};
```

### 2.2 Изучить BSP eDP/DP драйвер

```bash
find sources/kernel -path '*/drm/*edp*' -name '*.c' | head -10
find sources/kernel -path '*/drm/*sunxi*' -name '*dp*' | head -10

# Изучить driver:
grep -rn 'allwinner,drm-edp' sources/kernel/
```

Что выяснить:
- [ ] Поддерживает ли драйвер DP (не только eDP)?
  - eDP = embedded display (панель), фиксированный link
  - DP = external display, требует link training, HPD
  - USB-C DP Alt Mode = DP через типовой коннектор
- [ ] Принимает ли драйвер hotplug (HPD) от TCPM/AUX PHY?
- [ ] Есть ли в драйвере обработка `connector_type = DRM_MODE_CONNECTOR_DisplayPort`?
- [ ] Как делается link training? Auto или нужна конфигурация?
- [ ] Поддерживает ли разные lane counts (1, 2, 4)?

### 2.3 Проверить tcon4

```bash
grep -A20 'tcon4' sources/kernel/arch/arm64/boot/dts/allwinner/sun60iw2p1.dtsi
```

- [ ] tcon4 уже включён или disabled?
- [ ] Какие power-domains нужны?
- [ ] Связан ли tcon4 с Display Engine (`&de`)?

### 2.4 Проверить Display Engine pipeline

```
DE (Display Engine) → tcon4 → edp0 → combo0_dp → USB-C
```

- [ ] `&de` уже `status = "okay"` (да, в нашем DTS)
- [ ] Но привязан ли channel к tcon4? (`chn_cfg_mode = <0>`)
- [ ] Нужен ли `&vo1` для DP pipe? (уже `status = "okay"`)

### 2.5 Проверить, работает ли edp0 хоть в каком-то режиме

Самый простой тест на железе:

```bash
# Добавить в DTS:
# &edp0 { status = "okay"; };

# После загрузки проверить:
ls /sys/class/drm/card0-DP-*
cat /sys/class/drm/card0-DP-*/status
dmesg | grep -iE 'edp|dp|drm.*connector'
```

### 2.6 Результат фазы 2

- Понимание, способен ли BSP edp0 работать как DP source для USB-C
- Если да — какие DTS-настройки нужны
- Если нет — это hardware/driver блокер, фиксируем и идём дальше

---

## Фаза 3 — Ресёрч: Combo PHY runtime switching

### 3.1 Изучить Cadence combo PHY драйвер

```bash
grep -rn 'cadence-combophy\|allwinner,cadence' sources/kernel/drivers/phy/
find sources/kernel/bsp/drivers/phy/ -name '*combo*' -o -name '*serdes*' | head -10
```

Уже найдено в dtsi:

```dts
serdes: serdes@6c00000 {
    compatible = "allwinner,cadence-combophy";
    ...
    combophy0: combo-phy0@6c01000 {
        combo0_dp: combo0-dp-phy { #phy-cells = <0>; };
        combo0_usb: combo0-usb-phy { #phy-cells = <0>; };
    };
};
```

Что выяснить:
- [ ] Может ли драйвер переключаться runtime между USB и DP?
- [ ] Или конфигурация фиксируется при probe?
- [ ] Есть ли API `phy_set_mode()` / `phy_configure()` для lane reconfig?
- [ ] Поддерживает ли режим 2+2 (2 lanes DP + 2 lanes USB3)?

### 3.2 Как TCPM управляет PHY switching

В mainline Linux цепочка:
```
TCPM → typec_mux_set() → mux driver → phy_set_mode()
```

- [ ] Есть ли в vendor combo PHY хук для typec_mux?
- [ ] Или нужен отдельный glue-driver (как sunxi_phy_switcher)?
- [ ] Как PS8743 mux связывается с combo PHY?

### 3.3 Изучить как Rockchip / Mediatek решают это

Для reference — другие SoC с combo PHY + USB-C DP Alt Mode:
- Rockchip RK3588: `drivers/phy/rockchip/phy-rockchip-samsung-hdptx.c`
  + `drivers/usb/typec/altmodes/displayport.c`
- Mediatek MT8195: `drivers/phy/mediatek/phy-mtk-dp.c`

```bash
grep -rn 'typec_mux\|phy_set_mode.*DP\|PHY_MODE_DP' sources/kernel/drivers/phy/ | head -20
```

### 3.4 Worst case: static DP mode

Если runtime switching невозможен — можно зафиксировать combo0 в DP mode:

```dts
/* Отключить USB3 — оставить только USB2 через ehci/ohci */
&xhci2 {
    phys = <&u2phy>;  /* убрать combo0_usb */
    phy-names = "usb2-phy";
    maximum-speed = "high-speed";  /* 480 Mbps max */
};

/* Включить DP */
&edp0 {
    status = "okay";
};
```

Плюсы: DP заработает без сложного PHY switching.
Минусы: USB-C порт теряет USB 3.x (остаётся 480 Mbps USB 2.0).

### 3.5 Результат фазы 3

- Вердикт: runtime switching возможен / невозможен
- Если да — план реализации (какие endpoints, какой glue driver)
- Если нет — static DP mode как fallback + issue на vendor

---

## Фаза 4 — Реализация: PS8743 DTS node

**Зависит от**: Фаза 1 (I2C адрес)

```dts
/* Пример — адрес и шина уточняются из схемы */
&twi_X {
    ps8743: typec-mux@XX {
        compatible = "parade,ps8743";
        reg = <0xXX>;
        mode-switch;
        orientation-switch;

        ports {
            #address-cells = <1>;
            #size-cells = <0>;
            port@0 {
                reg = <0>;
                ps8743_usb: endpoint {
                    remote-endpoint = <&typec_ss_ep>;
                };
            };
        };
    };
};
```

Задачи:
- [ ] Добавить узел PS8743 в board DTS
- [ ] Добавить port@1 (SS) в connector node → ps8743
- [ ] Добавить port@2 (DP) в connector node → edp0 или ps8743
- [ ] Тест: при загрузке `dmesg | grep ps8743` — probe OK

---

## Фаза 5 — Реализация: edp0 enable + wiring

**Зависит от**: Фаза 2 (driver capability) + Фаза 4 (mux ready)

```dts
&edp0 {
    status = "okay";
    ports {
        edp_out: port@1 {
            edp0_out_typec: endpoint@0 {
                remote-endpoint = <&typec_dp_ep>;
                /* или через PS8743 если mux on DP path */
            };
        };
    };
};
```

Задачи:
- [ ] Включить edp0 в board DTS
- [ ] Связать edp0 → connector port@2 (или через mux)
- [ ] Проверить power-domains, clocks
- [ ] Тест: `ls /sys/class/drm/card0-DP-*` — connector появляется

---

## Фаза 6 — Реализация: Combo PHY integration

**Зависит от**: Фаза 3 (runtime switching вердикт)

### Вариант A: Runtime switching работает

- [ ] Подключить typec_mux → combo PHY через graph endpoints
- [ ] Проверить, что TCPM при DP negotiation вызывает mux switch
- [ ] Тест: подключить DP sink → combo PHY переключается → видео идёт
- [ ] Тест: отключить DP sink → combo PHY обратно в USB mode

### Вариант B: Static DP mode

- [ ] Создать два варианта DTS (или DT overlay):
  - `sun60i-a733-cubie-a7z.dts` — USB3 mode (по умолчанию)
  - `sun60i-a733-cubie-a7z-dp.dtso` — DP mode overlay
- [ ] В DP overlay: убрать combo0_usb из xhci2, включить edp0
- [ ] Документировать: "для DP пересоберите с overlay, USB3 потеряется"
- [ ] Тест: загрузка с DP overlay → видео на мониторе

### Вариант C: Vendor PHY switcher

Если `SUNXI_PHY_SWITCHER` — это allwinner'овский glue для runtime switching:
- [ ] Включить `CONFIG_TYPEC_MUX_SUNXI_PHY_SWITCHER=y` (уже есть!)
- [ ] Добавить DTS-узел для sunxi-phy-switcher
- [ ] Связать с combo PHY + TCPM
- [ ] Тест: всё как в варианте A

---

## Фаза 7 — Тестирование на железе

### 7.1 Минимальный тест (TCPC + mux probe)

```bash
# После загрузки:
dmesg | grep -iE 'tcpci|rt1711|et7304|ps8743|edp|combo'
ls /sys/class/typec/port0/
cat /sys/class/typec/port0/data_role
cat /sys/class/typec/port0/power_role
```

### 7.2 Тест DP negotiation

```bash
# Подключить USB-C → DP адаптер или DP монитор
ls /sys/class/typec/port0/port0-partner/
ls /sys/class/typec/port0/port0-partner/*/
cat /sys/class/typec/port0/port0-partner/altmode.0/svid
cat /sys/class/typec/port0/port0-partner/altmode.0/mode
# svid должен быть ff01 (DisplayPort)
```

### 7.3 Тест DRM connector

```bash
ls /sys/class/drm/card0-DP-*/
cat /sys/class/drm/card0-DP-*/status    # connected?
cat /sys/class/drm/card0-DP-*/modes     # supported resolutions
cat /sys/class/drm/card0-DP-*/enabled

# Force mode через modetest:
modetest -M sunxi-drm -c  # list connectors
modetest -M sunxi-drm -s <connector_id>:<mode>
```

### 7.4 Тест Pin Assignment

```bash
# Проверить какой pin assignment согласовался:
for f in /sys/class/typec/port0/port0-partner/*/pin_assignment; do
    [ -r "$f" ] && echo "$(dirname $f | xargs basename): $(cat $f)"
done

# C = 4 lane DP (нет USB3)
# D = 2 lane DP + 2 lane USB3 (если mux поддерживает)
```

### 7.5 Тест видеовыхода

```bash
# Если X11/Wayland настроен:
xrandr --listproviders
xrandr --output DP-1 --auto

# Если headless:
cat /sys/class/drm/card0-DP-*/edid | edid-decode
# Или через fbset / modetest
```

---

## Фаза 8 — Документация и PR

- [ ] Обновить `docs/known-issues-en.md` / `docs/known-issues.md`
- [ ] Обновить `docs/firmware-bom.md` (PS8743 секция)
- [ ] Обновить `README.md` — "USB-C DP Alt Mode: Working"
- [ ] Обновить `docs/hardware-enablement.md`
- [ ] Обновить `test-typec.sh` — добавить проверку DRM connector
- [ ] PR с разбивкой коммитов:
  - `dts: cubie-a7z: add PS8743 typec mux node`
  - `dts: cubie-a7z: enable edp0 DP source controller`
  - `dts: cubie-a7z: wire DP source through typec connector`
  - `tests: test-typec.sh: add DRM connector check`
  - `docs: mark DP Alt Mode as working`

---

## Приоритеты

| Фаза | Требует железо? | Блокер | Приоритет | Статус |
|------|-----------------|--------|-----------|--------|
| 1. PS8743 ресёрч | Да (схема PDF) | Нет | **Высокий** | ✅ Решено: используем SUNXI_PHY_SWITCHER вместо PS8743 |
| 2. edp0 ресёрч | sources/ | Нет | **Высокий** | ✅ Решено: `"allwinner,drm-dp"` поддерживает DP source |
| 3. Combo PHY ресёрч | sources/ | Нет | **Высокий** | ✅ Решено: runtime switching через phy_set_mode() |
| 4. PHY switcher DTS | Нет | Фаза 1 | Средний | ✅ Реализовано |
| 5. edp0 enable | Нет | Фаза 2 | Средний | ✅ Реализовано |
| 6. PHY integration | Нет | Фаза 3 | **Критический** | ✅ Реализовано |
| 7. Тестирование | Да | Фазы 4-6 | Средний | ⏳ Нужен тест на железе |
| 8. Документация | Нет | Фаза 7 | Низкий | ✅ Обновлено |

## Риски (обновлено 2026-06-20)

1. ~~**Combo PHY не переключается runtime**~~ → **Решено**: BSP драйвер
   (`sunxi-cadence-combophy.c`) поддерживает `phy_set_mode(PHY_MODE_DP)`,
   включая 2+2 mode (Pin Assignment D). SUNXI_PHY_SWITCHER — glue layer.

2. ~~**edp0 драйвер не поддерживает DP**~~ → **Решено**: драйвер имеет
   два compatible: `"allwinner,drm-edp"` (eDP) и `"allwinner,drm-dp"` (DP).
   DP mode: `controller_mode = 1`, `DRM_MODE_CONNECTOR_DisplayPort`.

3. ~~**PS8743 не тот чип**~~ → **Решено**: используем SUNXI_PHY_SWITCHER
   вместо PS8743. Референс: OrangePi Zero3W (тот же SoC, рабочий DP Alt Mode).
   PHY switcher управляет combo PHY напрямую, PS8743 не нужен.

4. **AUX channel routing** — aux_hpd_phy в combo PHY обрабатывает AUX канал.
   SUNXI_PHY_SWITCHER может управлять AUX polarity через GPIO (aux_p/aux_n),
   но на Cubie A7Z пины PL12/PL13 заняты S_TWI1. AUX routing через combo PHY
   hardware. **Может потребовать подбора lane_invert на железе.**

5. **Lane inversion** — board-specific. OPi 4 Pro: `<0 0 0 0>`, Zero3W: `<1 1 1 1>`.
   Начинаем с `<0 0 0 0>`. Если DP не заработает — попробовать `<1 1 1 1>`.

## Полезные ссылки

- ET7304 datasheet: https://www.etekmicro.com/wp-content/uploads/datasheets/ET7304_datasheet.pdf
- Схема A7Z v1.10: https://dl.radxa.com/cubie/a7z/docs/hw/radxa_Cubie_A7Z_v1100__schematic.pdf
- PS8743 datasheet: https://www.paradetech.com/products/ps8743/ (может требовать NDA)
- USB Type-C DP Alt Mode spec: VESA DisplayPort Alt Mode on USB Type-C Standard v2.0
- Kernel typec mux API: Documentation/driver-api/usb/typec.rst
- Kernel DP altmode driver: drivers/usb/typec/altmodes/displayport.c
- Radxa BSP fix reference: https://github.com/radxa/allwinner-bsp/commit/156b6578cc173855b41ea311a229403ccbadb17c
- OrangePi 4 Pro DTS (тот же SoC): arch/arm64/boot/dts/allwinner/sun60i-a733-orangepi-4-pro.dts
