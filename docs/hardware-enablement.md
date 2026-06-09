# Cubie A7Z — План включения всего железа

Обновлено: 2026-06-03

Схема: Radxa Cubie A7Z RS503 v1.10

---

## Статус периферии

### Работает

| # | Периферия | Чип/Интерфейс | Примечание |
|---|-----------|---------------|------------|
| 1 | CPU 2×A76 + 6×A55 | A733 | Загрузка, login |
| 2 | LPDDR4 | Samsung KLUDG4UHDC | Работает |
| 3 | MicroSD (SDC0) | Слот J22 | Boot, rootfs |
| 4 | WiFi | AIC8800 FCU760K, USB1 | Scan работает, radxa driver |
| 5 | Bluetooth | AIC8800 FCU760K, USB1 | btusb подключился, не тестирован |
| 6 | GPU | PowerVR BXM-4-64 | pvrsrvkm, renderD128 |
| 7 | HDMI видео | Micro-HDMI J2 | Работает, hotplug |
| 8 | HDMI audio | I2S3 → hdmi_codec | sndhdmi soundcard |
| 9 | USB-C host (J4) | xHCI + DWC3 | HID работает |
| 10 | USB-C VBUS | SGM2576, EN=PL2 | regulator-fixed GPIO |
| 11 | LED | PM2, heartbeat | Работает |
| 12 | NPU | VIPcore | Модуль загружается |
| 13 | Video Engine | sunxi-cedar | Модуль загружается |
| 14 | 2D Engine | g2d_sunxi | Модуль загружается |
| 15 | PMIC AXP8191 | I2C-13 addr 0x36 | Регуляторы работают |

### Не работает / не включено

| # | Периферия | Чип/Интерфейс | Приоритет | Статус | Что нужно сделать |
|---|-----------|---------------|-----------|--------|-------------------|
| 1 | UFS storage | Samsung KLUDG4UHDC, MPHY | ~~Высокий~~ N/A | В DTS, link_startup_fail | **Чип не впаян на этом SKU.** DTS node оставлен — заработает на платах с UFS. |
| 2 | PCIe M.2 | FPC J3, Gen3 x1 | **Высокий** | Нет в DTS | Добавить `&pcie_rc` с power/reset/wake GPIOs. По схеме: PCIE_PWR_EN, PCIE-WAKEn (PD21), PCIE-PERSTn. Питание: bldo1 (1.8V), dcdc1 (3.3V). |
| 3 | ET7304Y TCPC | I2C на S_TWI1 | **Средний** | Нет в DTS | Включить `&s_twi1`, добавить tcpci node (addr уточнить по datasheet, вероятно 0x4E). Interrupt: TYPEC_INT GPIO. Нужен для USB-PD, role switch, DP Alt Mode. |
| 4 | USB0 OTG (J16) | USB-C 16pin, USB0 | **Средний** | Host mode | Сейчас usb_port_type=1 (host). J16 по схеме — power input (sink only, 5.1K pull-down на CC). OTG переключение не нужно, но USB0 host можно использовать если подключить хаб. Проверить что ehci0/ohci0 видят устройства. |
| 5 | Camera MIPI CSI | FPC J5, 4-lane | **Средний** | Disabled в DTS | `&vind0 { status = "okay" }`, включить TWI3 для I2C к камере. Нужна конкретная камера для теста. Reset: MCSI-RST-R, Standby: MCSI-STBY-R. |
| 6 | Fan PWM | J6, 5-pin | **Средний** | Частично | PWM0_4 включён в DTS. Нужно: добавить `pwm-fan` node с thermal-cooling-cells, привязать к thermal zone CPU. Тахометр: GPIO. |
| 7 | Power button | SW1, AXP318 | **Средний** | Не работает | DTS говорит AXP515 — чипа нет на плате. PMIC = AXP318. Power key подключён к AXP318 PWRON. Нужно: исправить compatible на axp318 или проверить, совместим ли AXP8191 pek. |
| 8 | BT audio (PCM) | AIC8800 PCM pins | **Низкий** | Не настроен | BT HFP требует PCM шину между AIC8800 и SoC. Нужен I2S/PCM link в DTS. |
| 9 | CPU freq scaling | AXP8191 DCDC5/DCDC3 | **Низкий** | OPP rejected | Vendor OPP использует named voltages (vfXXXX) + eFuse speed grade. Регуляторы работают, но cpufreq framework не подхватывает. Рискованно менять без понимания speed grade. |
| 10 | HDMI CEC | Встроен в SoC | **Низкий** | Не проверено | Возможно работает из коробки. Проверить `cec-ctl` если cec модуль загружен. |
| 11 | DisplayPort Alt Mode | Через COMBO0 + ET7304Y | **Низкий** | Нет | Требует рабочий ET7304Y TCPC + serdes combo PHY в DP mode. |

### 40-pin GPIO Header (J11)

| Сигнал | Пины | Статус | Что нужно |
|--------|------|--------|-----------|
| TWI7 (I2C) | pin 1 (SDA), pin 3 (SCK) | **Не в DTS** | Добавить `&twi7 { status = "okay" }` |
| TWI2 (I2C) | pin 27 (SDA), pin 28 (SCK) | Включён, **SCL stuck** | Bus 2 залипает. Проверить pull-up, отключить пока нет подключённых устройств |
| SPI1 | pin 19/21/23/24 | **Не в DTS** | Добавить `&spi1 { status = "okay" }` с pinctrl |
| UART (debug) | pin 10 (TX), pin 12 (RX) | Работает | UART console |
| I2S0 | pin 14/35/36/38/40 | Disabled в DTS | Нет внешнего кодека — отключено правильно |
| PWM | pin 32/33/35 | Частично | PWM0_4 на PD22 включён |
| GPIO | pin 7/11/13/15/17/18/26/29/31 | Доступны | Не проверено |

---

## Порядок работ (рекомендуемый)

### Спринт 1 — Core functionality ✅ (в скриптах)
- [x] libnl-route-3-200 → wpa_supplicant
- [x] libasound2-data → HDMI audio
- [x] udev rule wlan0 rename
- [x] twi2 disabled (SCL stuck)
- [ ] Проверить WiFi подключение к реальной сети + DHCP

### Спринт 2 — Storage & Expansion ✅ (в DTS)
- [x] **UFS**: `&ufs` node, vcc=dldo6, vccq/vccq2=dcdc8
- [x] **PCIe**: `&pcie_rc`, reset=PD22, wake=PD21, bldo1/dcdc1
- [ ] Тест UFS: `lsblk`, mkfs, mount
- [ ] Тест PCIe: `lspci` с NVMe модулем

### Спринт 3 — USB-C + Периферия ✅ (в DTS)
- [x] **ET7304Y TCPC**: S_TWI1 + tcpci node at 0x4E, INT=PL9
- [x] **Fan PWM**: PWM1_9 на PK5, pwm-fan + thermal binding
- [x] **Power button**: AXP8191 powerkey enabled
- [x] **TWI7**: 40-pin I2C (PJ22/PJ23)
- [x] **NPU SDK**: VIPLite v2.0 + vpm_run + test models (ai-sdk)
- [ ] Тест ET7304Y: USB-PD negotiation
- [ ] Тест fan: `cat /sys/class/thermal/*/temp`, нагрузка
- [ ] Тест power button: нажатие → shutdown
- [ ] Тест NPU: `vpm_run` с ResNet50
- [ ] Тест BT: `bluetoothctl`

### Спринт 4 — Оставшееся
- [ ] **SPI1**: pinctrl (нужен datasheet для пинов)
- [ ] **Camera**: включить vind0 + TWI3 (нужна камера)
- [ ] **BT audio**: PCM link между AIC8800 и SoC
- [ ] **HDMI CEC**: проверить cec-ctl
- [ ] **DP Alt Mode**: требует рабочий ET7304Y

### Спринт 5 — Оптимизация
- [ ] CPU freq scaling (исследовать OPP + eFuse) — **рискованно**
- [ ] mmdebstrap миграция (убрать ручные shared libs)
- [ ] Boot0: перейти на allwinner-device boot0

### Спринт 6 — Чистка и документация ✅
- [x] sources/tools/ перемещён в /workspace/trash/
- [x] TODO.md → ссылка на hardware-enablement.md
- [x] driver-action-plan.md → ссылка на hardware-enablement.md
- [x] known-issues.md актуализирован
- [x] boot-layout.md актуализирован (sector 256, MBR)
- [ ] Документация: README с инструкцией сборки

---

## Аппаратные ограничения (не решаемые софтом)

- **AXP515 не существует** на плате (схема показывает AXP318). I2C addr 0x34 пустой. Disabled в DTS.
- **J16 (USBC0)** — sink-only (5.1K pull-down на CC), не может быть host. Это порт питания платы.
- **Нет Ethernet** — WiFi only networking.
- **Нет eMMC** — UFS + microSD.
- **Нет аудиокодека** — только HDMI audio + I2S0 на 40-pin (для внешнего DAC).

---

## Зависимости хоста для сборки

```bash
sudo apt install -y \
  make git wget curl build-essential bc flex bison libssl-dev \
  gcc-arm-linux-gnueabi gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
  swig device-tree-compiler xxd busybox \
  debootstrap qemu-user-static binfmt-support \
  parted dosfstools e2fsprogs mtools xz-utils \
  u-boot-tools kmod cpio binutils
```
