# Руководство пользователя — Cubie A7Z Debian

## Быстрый старт

1. Записать образ на microSD (8+ ГБ):
   ```bash
   xzcat cubie_a7z-trixie.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
   sync
   ```

2. Вставить SD в Cubie A7Z

3. Подключить питание через USB-C (J16, нижний порт)

4. Подключиться:
   - **UART**: 115200 бод, ttyS0 (через 40-pin header: pin 10 TX, pin 12 RX)
   - **SSH**: после подключения WiFi (см. ниже)
   - **HDMI**: micro-HDMI + USB клавиатура через USB-C (J4, верхний порт)

## Учётные записи

| Пользователь | Пароль |
|-------------|--------|
| root | cubie |
| cubie | cubie |

Пользователь `cubie` имеет sudo.

## WiFi

### Подключение к сети

```bash
# Отредактировать конфигурацию
nano /etc/wpa_supplicant/wpa_supplicant.conf
```

Добавить блок:
```
network={
    ssid="ИмяСети"
    psk="Пароль"
}
```

Применить:
```bash
systemctl restart networking
```

WiFi подключается автоматически при каждой загрузке.
Подробная инструкция: `/root/help/wifi.txt`.

### Проверка

```bash
ip addr show wlan0
ping 8.8.8.8
```

## SSH

SSH сервер запускается автоматически на порту 22.

```bash
ssh cubie@<ip-адрес>
```

IP-адрес можно узнать через UART: `hostname -I`

## Обновление пакетов

```bash
sudo apt update
sudo apt upgrade
```

Репозитории: Debian Trixie (main, contrib, non-free, non-free-firmware).

## USB-C порты

| Порт | Расположение | Функция |
|------|-------------|---------|
| J16 (нижний) | USB-C 2.0 | Питание + USB OTG |
| J4 (верхний) | USB-C 3.1 | Host (клавиатура, хаб, монитор через DP Alt) |

USB-C J4 поддерживает:
- HID устройства (клавиатура, мышь) через OTG адаптер
- USB хабы
- DisplayPort Alt Mode (через ET7304Y TCPC)

## HDMI

- Разъём: micro-HDMI
- Видео: работает, hotplug
- Аудио: HDMI audio (soundcard `sndhdmi`)

```bash
# Проверить аудио
aplay -l
# Воспроизвести (если есть wav файл)
aplay -D hw:sndhdmi test.wav
```

## GPU

PowerVR BXM-4-64 MC1. Модуль `pvrsrvkm` загружается автоматически.

```bash
ls /dev/dri/renderD128
```

OpenGL ES, Vulkan, OpenCL — через vendor Mesa/PVR userland (установлены).

## NPU

VeriSilicon VIPLite, 3 TOPS @ INT8. Устройство `/dev/vipcore`.

### Тест inference

```bash
# Создать конфигурацию
cat > /tmp/sample.txt << 'EOF'
[network]
/usr/share/npu/models/resnet50.nb
[input]
/tmp/input.dat
EOF

# Сгенерировать тестовый вход (224x224x3)
dd if=/dev/urandom of=/tmp/input.dat bs=150528 count=1

# Запустить
vpm_run -s /tmp/sample.txt -l 1
```

Предустановлены модели: ResNet50, YOLOv5 в `/usr/share/npu/models/`.

## 40-pin GPIO Header

| Функция | Пины | Статус |
|---------|------|--------|
| UART (debug) | 10 (TX), 12 (RX) | Работает |
| SPI1 | 19 (MOSI), 21 (MISO), 23 (CLK), 24 (CS0) | /dev/spidev1.0 |
| I2C (TWI7) | 1 (SDA), 3 (SCK) | Доступен (disabled по умолчанию) |
| I2S0 | 14, 35, 36, 38, 40 | Доступен для внешнего DAC |
| GPIO | 7, 11, 13, 15, 17, 18, 26, 29, 31 | Через gpiodetect/gpioset |

```bash
gpiodetect
gpioinfo
```

## PCIe

M.2 FPC разъём J3, PCIe Gen3 x1.

```bash
lspci
```

## Bluetooth

BT через AIC8800 USB (btusb).

```bash
bluetoothctl
power on
scan on
```

## Время

Плата не имеет батарейки RTC. При загрузке время восстанавливается
из `fake-hwclock`, затем синхронизируется через NTP (systemd-timesyncd).

```bash
timedatectl status
```

## Первая загрузка

При первой загрузке автоматически:
1. Расширяется rootfs до полного размера SD-карты
2. Время устанавливается из fake-hwclock
3. WiFi чип включается через sunxi-rfkill
4. SSH сервер запускается

## Тесты оборудования

Запустить все тесты:

```bash
bash /root/tests/test-all.sh
```

Или по отдельности:

```bash
bash /root/tests/test-wifi.sh
bash /root/tests/test-npu.sh
bash /root/tests/test-gpu.sh
# ... test-bt, test-hdmi, test-usbc, test-pcie, test-spi, test-i2c, test-gpio, test-thermal
```

## Устранение проблем

### WiFi не подключается
```bash
# Проверить статус networking
systemctl status networking
# Перезапустить
systemctl restart networking
# Проверить что чип включён
cat /sys/class/misc/sunxi-rfkill/wlan/state
# Должно быть 1. Если 0:
echo 1 > /sys/class/misc/sunxi-rfkill/wlan/state
```

### Нет интернета после подключения WiFi
```bash
# Проверить что wpa_supplicant работает
pgrep -a wpa_supplicant
# Проверить IP адрес
ip addr show wlan0
# Если нет IP — запросить вручную
dhclient wlan0
```

### Неправильное время
```bash
date -s "2026-06-04 12:00:00"
systemctl restart systemd-timesyncd
```

### Диск заполнен
```bash
# Проверить что resize сработал
df -h /
# Если нет — запустить вручную
resize2fs /dev/mmcblk0p2
```

### USB-C устройства не определяются
Убедитесь что используете порт J4 (верхний) с OTG адаптером.
Порт J16 (нижний) — только питание.
