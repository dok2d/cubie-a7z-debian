# Cubie A7Z — TODO

Обновлено: 2026-06-08

Полный план: [hardware-enablement.md](hardware-enablement.md)
Зависимости: [rootfs-dependency-map.md](rootfs-dependency-map.md)
Известные проблемы: [known-issues.md](known-issues.md)

---

## Работает (проверено на железе 2026-06-08)

- WiFi: подключение к сети, DHCP, интернет (radxa-pkg/aic8800), wlan0, автостарт
- USB-C host: HID (клавиатура), VBUS через PL2 GPIO
- GPU: pvrsrvkm, renderD128, card0+card1
- HDMI: видео (1080p) + аудио (sndhdmi)
- PCIe: контроллер виден (root port)
- NPU: /dev/vipcore, vpm_run, ResNet50 inference 7.5ms
- SPI1: /dev/spidev1.0 на 40-pin header
- BT: btusb, hci0, bluetoothctl
- CPU freq: schedutil, A55 до 1794 MHz, A76 до 2002 MHz
- SSH, NTP, fake-hwclock, networking — всё автостарт
- Все утилиты: curl, wget, gawk, gpiodetect, i2cdetect, tmux, screen и др.
- SD boot + first-boot-resize (58G)
- LED heartbeat
- 43 регулятора (AXP8191)
- 0 systemd failed units, 0 значимых ошибок в dmesg

## Не сделано

| # | Задача | Приоритет | Блокер | Что даст |
|---|--------|-----------|--------|----------|
| 1 | GPU acceleration (Mesa PVR) | Высокий | Собрать Mesa с `-Dgallium-drivers=pvr` | Аппаратный GL/GLES/Vulkan — сейчас llvmpipe (CPU), Firefox съедает 190% CPU. BXM-4-64 поддерживается upstream Mesa 25.3+ |
| 2 | ET7304Y port nodes | Средний | Реверс vendor драйвера или port nodes | USB-C PD negotiation — зарядка от PD-адаптера, DP Alt Mode через typec framework |
| 3 | Camera MIPI CSI | Низкий | Нужна физическая камера (Radxa Camera 8M 219) | /dev/video*, фото/видео захват, AI inference с камеры через NPU |
| 4 | Fan PWM | Низкий | Нужен Radxa Heatsink 6530B | Активное охлаждение (73C без кулера), thermal throttling policy |
| 5 | PCIe + NVMe | Низкий | Radxa PCIe to M.2 M Key HAT + диск | Быстрое хранилище (~1 GB/s), загрузка с NVMe (через SPI NOR boot) |
| 6 | CPU freq OPP | Низкий | Риск без знания eFuse speed grade | Полный диапазон частот, энергосбережение в idle |
| 7 | mmdebstrap | Низкий | Инфраструктурное | Авто-разрешение зависимостей — не ловить libwrap0 и т.п. вручную |
| 8 | regulatory.db | Низкий | Косметика | Чистый dmesg, корректные WiFi TX power limits по странам |

## Воспроизводимость

Все 9 публичных репозиториев fetch'ятся через `00-fetch-sources.sh`.
Boot0 автоматически скачивается и извлекается из Radxa official image (rsdk-b1)
с верификацией SHA256 — проприетарные блобы не хранятся в git.

Сборка в контейнере (Docker/Podman):

```bash
podman build -t cubie-builder -f docker/Dockerfile.builder .
podman run --rm --user root -v .:/work:Z,exec cubie-builder make all
```
