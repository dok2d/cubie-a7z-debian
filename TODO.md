# TODO для агента: enable USB-C DP Alt Mode через ET7304 TCPC

## Контекст

Проект: `dok2d/cubie-a7z-debian`. Reproducible Debian-image-builder для Radxa Cubie A7Z (Allwinner A733). Ядро 6.6.98+ из `orangepi-xunlong/linux-orangepi @ orange-pi-6.6-sun60iw2`. BSP из `radxa/allwinner-bsp @ cubie-aiot-v1.4.6`.

Блокер задокументирован в `docs/known-issues-en.md`, секция "ET7304Y TCPC: probe failed -22": TCPC ETEK ET7304(Y) на I2C bus 14 addr 0x4E не пробится generic `tcpci`-драйвером, возвращает -EINVAL. Из-за этого мёртвы USB-C PD-согласование и DP Alt Mode через typec framework.

Фикс: ET7304 функционально идентичен Richtek RT1715, отличается только VID (0x6DCF против 0x29CF, DID = 0x2173 — общий с RT1715). Апстримная серия Yuanshen Cao v3 (Feb 20, 2026, протестирована **на Cubie A7Z**) + follow-up Alexey Charkov v3 (Mar 18, 2026, fallback compatible). Патч уже в `7.1-rc+HEAD`.

Источники:
- Driver patch v3: https://lore.kernel.org/all/20260220-et7304-v3-2-ede2d9634957@gmail.com/raw
- Binding patch v3: https://lore.kernel.org/all/20260220-et7304-v3-1-ede2d9634957@gmail.com/raw
- Charkov fallback v3: https://lkml.iu.edu/hypermail/linux/kernel/2603.2/05539.html
- Vendor BSP fix reference: https://github.com/radxa/allwinner-bsp/commit/156b6578cc173855b41ea311a229403ccbadb17c
- ET7304 datasheet: https://www.etekmicro.com/wp-content/uploads/datasheets/ET7304_datasheet.pdf
- Схема платы v1.10: https://dl.radxa.com/cubie/a7z/docs/hw/radxa_Cubie_A7Z_v1100__schematic.pdf

## Цель PR

После применения PR на свежесобранном образе:

1. `dmesg | grep -iE 'tcpc|rt1711'` показывает успешный probe без -EINVAL.
2. `/sys/class/typec/port0/` существует, читается, роли установлены.
3. При подключении DP-устройства согласуется DisplayPort Alt Mode (минимум Pin Assignment C — 4 lane DP).
4. В идеале — Pin Assignment D (2 DP + 2 USB 3.x) для одновременного видео и USB-данных (зависит от mux-чипа на плате; см. Фаза 7).

## Не входит в scope

- USB-C PD charging (sink). Не критично, отдельный PR.
- Userspace SDK для очков (Viture/Xreal). Отдельный PR.
- Любые правки вне typec / tcpc / DP Alt Mode подсистемы.
- GPU/NPU/Wi-Fi/прочее.

## План работ

### Фаза 0 — ознакомление

Прочитать целиком и не править:

- `README.md`
- `docs/known-issues-en.md` (секция ET7304Y)
- `docs/BUILDKIT-GUIDE.md`
- `docs/hardware-enablement.md`
- `docs/firmware-bom.md`
- `config/board.cubie-a7z.env`
- `Makefile`
- `scripts/00-fetch-sources.sh`
- `scripts/20-build-kernel.sh`
- содержимое `patches/` (для naming convention)
- содержимое `config/dts/` (для понимания, где описана плата)

Зафиксировать стиль коммитов:
```bash
git log --oneline -30
git log --format='%s' | head -20
```

### Фаза 1 — verify, что патч ещё не применён

```bash
# 1. Получить исходники
make fetch || true

# 2. Убедиться, что в ядре нет et7304
grep -RIn 'ET7304\|et7304\|0x6DCF' sources/linux-orangepi/drivers/usb/typec/ || echo "OK: clean"

# 3. Проверить, что в BSP есть ссылочный коммит
cd sources/allwinner-bsp
git log --all --oneline | grep -i et7304 || true
git show 156b6578cc173855b41ea311a229403ccbadb17c -- '*tcpci*' 2>/dev/null | head -50 || \
  echo "Commit not in current branch tree"
cd -

# 4. Проверить, нет ли вендорного драйвера ET7304 как отдельного модуля
find sources -iname '*et7304*' -o -iname '*tcpc*' 2>/dev/null
```

Если в BSP лежит локальная версия фикса в `tcpci_rt1711h.c` — задокументировать в PR-комментарии, но **использовать апстримный путь**, удалив вендорный (Фаза 3). Не применять оба сразу.

### Фаза 2 — забрать патчи

```bash
mkdir -p patches/kernel

curl -fL 'https://lore.kernel.org/all/20260220-et7304-v3-1-ede2d9634957@gmail.com/raw' \
  -o patches/kernel/0050-dt-bindings-usb-document-Etek-ET7304-TCPC.patch

curl -fL 'https://lore.kernel.org/all/20260220-et7304-v3-2-ede2d9634957@gmail.com/raw' \
  -o patches/kernel/0051-usb-typec-tcpm-add-vid-and-chip-info-for-Etek-ET7304.patch
```

Префикс `0050-` — задача не критичная, идёт после базовых A733-патчей. Подобрать свободный номер, если в `patches/kernel/` уже занято.

Sanity-check:
```bash
for p in patches/kernel/0050-*.patch patches/kernel/0051-*.patch; do
  echo "=== $p ==="
  head -5 "$p"
  grep -c '^diff --git' "$p"
done
```

### Фаза 3 — backport на 6.6.98

База серии — мейнлайн ~7.1-rc; целевое ядро — 6.6.98. Файл `tcpci_rt1711h.c` стабилен с 6.1, патч должен применяться чисто.

```bash
cd sources/linux-orangepi
git apply --check ../../patches/kernel/0050-*.patch 2>&1
git apply --check ../../patches/kernel/0051-*.patch 2>&1
cd -
```

Если `--check` падает с конфликтами:

1. Изучить конкретный hunk: `git apply -3 --check` (3-way).
2. Адаптировать руками: правится только контекст, не логика.
3. **НЕ менять** константы: `ET7304_VID = 0x6DCF`, `ET7304_DID = 0x2173`.
4. В новой версии патча в commit message добавить `[backport-6.6]` после subject.
5. Если в BSP уже есть локальный фикс — удалить его отдельным патчем (`patches/kernel/0049-revert-vendor-et7304-fix.patch`), затем применить апстримный.

### Фаза 4 — kernel defconfig

Найти defconfig:
```bash
find sources/linux-orangepi/arch/arm64/configs/ -name '*sun60*' -o -name '*a733*'
```

Убедиться, что включены опции (если нет — добавить отдельным патчем `patches/kernel/0052-defconfig-enable-typec-dp-altmode.patch`, формат — diff к defconfig):
```
CONFIG_TYPEC=y
CONFIG_TYPEC_TCPM=y
CONFIG_TYPEC_TCPCI=y
CONFIG_TYPEC_RT1711H=y      # сюда добавляется ET7304 после патча
CONFIG_TYPEC_DP_ALTMODE=y
CONFIG_USB_ROLE_SWITCH=y
CONFIG_DRM_DISPLAY_DP_HELPER=y
CONFIG_EXTCON=y
```

Все опции — `=y`, не `=m`, во избежание гонок probe order при boot.

### Фаза 5 — DTS: узел TCPC

Найти текущий узел:
```bash
grep -RIn 'usbc2\|0x4e\|tcpci\|et7304\|i2c14\|twi14' \
  config/dts/ sources/linux-orangepi/arch/arm64/boot/dts/
```

Заменить минимальный узел на полноценный (точные пины IRQ — из схемы платы):

```dts
&i2c14 {  /* или &twi14, как в allwinner-naming; уточнить из SoC dtsi */
    status = "okay";

    typec_et7304: usb-pd@4e {
        compatible = "etekmicro,et7304", "richtek,rt1715";
        reg = <0x4e>;
        interrupt-parent = <&pio>;
        interrupts = <PORT IRQ IRQ_TYPE_LEVEL_LOW>;  /* TODO: из схемы */

        connector {
            compatible = "usb-c-connector";
            label = "USB-C";
            data-role = "host";
            power-role = "source";
            try-power-role = "source";
            source-pdos = <PDO_FIXED(5000, 1500, PDO_FIXED_USB_COMM)>;

            altmodes {
                #address-cells = <1>;
                #size-cells = <0>;
                displayport@0 {
                    reg = <0>;
                    svid = /bits/ 16 <0xff01>;
                    /* DP source, supports Pin Assignment C and D, DFP_D */
                    vdo = <0x00001c46>;
                };
            };

            ports {
                #address-cells = <1>;
                #size-cells = <0>;

                port@0 {  /* USB 2.0 HS */
                    reg = <0>;
                    typec_hs_ep: endpoint {
                        remote-endpoint = <&usb_hs_role_switch>;
                    };
                };
                port@1 {  /* USB 3.x SS */
                    reg = <1>;
                    typec_ss_ep: endpoint {
                        remote-endpoint = <&usb_ss_phy_or_mux>;
                    };
                };
                port@2 {  /* DP lanes */
                    reg = <2>;
                    typec_dp_ep: endpoint {
                        remote-endpoint = <&dp_out_or_mux>;
                    };
                };
            };
        };
    };
};
```

IRQ-пин найти в схеме: на даташите ET7304 ножка `INT_N`, на плате трассируется в GPIO SoC. Без правильного IRQ TCPM не получит уведомления о plug/unplug, состояние будет залипать.

### Фаза 6 — DTS: USB role/SS PHY

A733 имеет USB 3.x контроллер и USB 2.0 OTG PHY. Их узлы уже есть в SoC dtsi — нужно убедиться, что:

1. У контроллера USB 3.x прописан `usb-role-switch;` (для динамического переключения host/device).
2. SS-PHY имеет endpoint, который референсится из `typec_ss_ep`.
3. HS-PHY/USB role switcher имеет endpoint для `typec_hs_ep`.

Если узлов нет или они без endpoint — допилить их. Это правится через DT overlay в `config/dts/`, не в `sources/`.

### Фаза 7 — DTS: orientation/mux чип (критическая ручная работа)

**Без этого DP-сигнал не дойдёт до пинов USB-C, даже когда TCPM правильно отнегоциирует Alt Mode.**

Шаги:

1. Скачать схему:
   ```bash
   curl -fL https://dl.radxa.com/cubie/a7z/docs/hw/radxa_Cubie_A7Z_v1100__schematic.pdf \
     -o /tmp/a7z_schematic.pdf
   ```
2. Найти на схеме чип между USB-C 3.1 connector (порт с DP Alt) и SoC SS-PHY/DP-выходом. Возможные варианты:

| Чип | Compatible | Драйвер в апстриме |
|-----|------------|---------------------|
| FSA4480 (ON Semi) | `fcs,fsa4480` | да, `drivers/usb/typec/mux/fsa4480.c` |
| IT5205 (ITE) | `mediatek,it5205` | да |
| PS8830 (Parade) | `parade,ps8830` | да |
| PI3DPX1207 (Diodes) | — | нет |
| PS8743 (Parade) | — | нет |
| HD3SS460 (TI) | `ti,hd3ss460` | частично |
| PTN36043B (NXP) | — | нет |

3. Если чип покрыт апстримом — добавить узел, связать с `&typec_et7304` через graph-of-ports:

```dts
&i2c14 {
    fsa4480: typec-mux@42 {
        compatible = "fcs,fsa4480";
        reg = <0x42>;
        mode-switch;
        orientation-switch;

        port {
            fsa4480_to_typec: endpoint {
                remote-endpoint = <&typec_ss_ep>;
            };
        };
    };
};
```

4. Если чипа нет в апстриме — задокументировать в PR как ограничение, реализовать через generic mux API если возможно, иначе вынести в отдельный issue.
5. Если на плате **вообще нет orientation switch** (мало вероятно для платы с заявленной поддержкой DP Alt) — это hardware-блокер, DP физически не пойдёт. Зафиксировать в `docs/known-issues-en.md`.

### Фаза 8 — DTS: DP source в A733

```bash
grep -RIn 'dp\|displayport\|edp\|dpx' sources/linux-orangepi/arch/arm64/boot/dts/sunxi/ | \
  grep -iE 'sun60iw2|a733'
```

Если DP-узел найден, обычно он `status = "disabled"` — переключить на `okay`, добавить endpoint в `port {}`, связать с `&typec_dp_ep` (напрямую или через mux).

Если DP-узла в `linux-orangepi` для A733 нет:

1. Проверить `sources/allwinner-bsp` на патч, добавляющий DP-bridge для A733.
2. Если есть — портировать в `patches/kernel/0053-drm-sunxi-a733-dp-bridge.patch`.
3. Если нет — **зафиксировать как блокер**, требующий отдельной работы. TCPC заработает (USB PD, role switching, ID), но видеосигнал в очки физически не пойдёт. В PR явно сказать.

### Фаза 9 — тесты

Создать `overlays/rootfs/root/tests/test-typec.sh`:

```bash
#!/bin/bash
# test-typec.sh — USB-C TCPC + DP Alt Mode check
set -e
PASS=true

check() { if "$@"; then echo "  OK"; else echo "  FAIL"; PASS=false; fi; }

echo "=== [1/4] TCPC probe (dmesg) ==="
if dmesg | grep -iE 'tcpci.*-22|tcpci.*EINVAL|tcpci.*ENODEV' > /dev/null; then
    echo "  FAIL: TCPC probe error in dmesg"
    dmesg | grep -iE 'tcpci|rt1711|et7304' | tail -10
    PASS=false
else
    echo "  OK"
fi

echo "=== [2/4] sysfs port presence ==="
check test -d /sys/class/typec/port0
if [ -d /sys/class/typec/port0 ]; then
    echo "  data_role:  $(cat /sys/class/typec/port0/data_role 2>/dev/null)"
    echo "  power_role: $(cat /sys/class/typec/port0/power_role 2>/dev/null)"
fi

echo "=== [3/4] DP altmode driver loaded ==="
check grep -q typec_displayport /proc/modules || \
  check test -d /sys/bus/typec/drivers/typec_displayport

echo "=== [4/4] partner detection (if anything plugged) ==="
if [ -d /sys/class/typec/port0/port0-partner ]; then
    echo "  Partner present"
    for f in /sys/class/typec/port0/port0-partner/*/configuration \
             /sys/class/typec/port0/port0-partner/*/pin_assignment; do
        [ -r "$f" ] && echo "    $(basename $(dirname $f))/$(basename $f) = $(cat $f)"
    done
else
    echo "  No partner — OK if nothing plugged in"
fi

$PASS && echo "=== PASS ===" || { echo "=== FAIL ==="; exit 1; }
```

`chmod +x`. Добавить вызов в `overlays/rootfs/root/tests/test-all.sh` рядом с остальными.

### Фаза 10 — документация

1. `docs/known-issues-en.md`: перенести "ET7304Y TCPC: probe failed -22" из `## Open` в `## Resolved`:
   ```
   - **ET7304Y TCPC probe -22** → backported upstream patches 
     (Yuanshen Cao v3 + Charkov v3). ET7304 is RT1715-compatible 
     with VID 0x6DCF. Driver: tcpci_rt1711h. Compatible: 
     "etekmicro,et7304","richtek,rt1715". Verified by test-typec.sh.
   ```
2. То же в `docs/known-issues.md` (RU).
3. В `README.md`, таблица "What Works", добавить строку:
   ```
   | USB-C PD / DP Alt | Working* | ET7304 TCPC, DP source via mux |
   ```
   Звёздочка с комментарием — какой Pin Assignment удалось согласовать.
4. В `docs/firmware-bom.md` добавить ET7304 → tcpci_rt1711h.
5. В `docs/TODO.md` / `TODO-en.md` снять задачу про DP Alt Mode, если она там была.

### Фаза 11 — PR

1. Ветка по стилю репы (`git branch -a`, `git log --format='%D' | head`). Кандидаты: `feature/et7304-tcpc`, `fix/tcpc-probe-et7304`.
2. Коммиты разбить логически:
   - `patches: kernel: backport ET7304 TCPC binding (Yuanshen Cao v3 1/2)`
   - `patches: kernel: backport ET7304 TCPC driver chip-info (Yuanshen Cao v3 2/2)`
   - `patches: kernel: backport rt1711h fallback compatible (Charkov v3)`
   - `patches: kernel: defconfig: enable TYPEC_DP_ALTMODE`
   - `dts: cubie-a7z: add typec connector node for ET7304`
   - `dts: cubie-a7z: add USB-C orientation mux <chip>` (если применимо)
   - `dts: cubie-a7z: wire DP source through typec connector`
   - `tests: add test-typec.sh`
   - `docs: mark ET7304 TCPC issue as resolved`
3. PR description:
   - Линк на `docs/known-issues-en.md` секцию
   - Линки на lore-mbox обоих upstream-патчей
   - Список оставшихся ограничений (mux/DP source если не закрыты)
   - Инструкция проверки: `bash /root/tests/test-typec.sh` + ручной сценарий

## Артефакты на выходе

Новые:
- `patches/kernel/0050-dt-bindings-usb-document-Etek-ET7304-TCPC.patch`
- `patches/kernel/0051-usb-typec-tcpm-add-vid-and-chip-info-for-Etek-ET7304.patch`
- `patches/kernel/0052-dt-bindings-rt1711h-fallback-compatible.patch` (Charkov v3, опционально)
- `patches/kernel/0053-defconfig-enable-typec-dp-altmode.patch` (если defconfig правится)
- `overlays/rootfs/root/tests/test-typec.sh`

Изменённые:
- `config/dts/*.dts` или `*.dtsi` — узлы typec, mux, DP wiring
- `overlays/rootfs/root/tests/test-all.sh` — вызов test-typec
- `docs/known-issues-en.md`, `docs/known-issues.md`
- `docs/firmware-bom.md`
- `README.md`
- возможно `scripts/20-build-kernel.sh` (если apply-механизм не маска)

## Definition of Done

**Без железа** (отвечает агент):

1. `make all` собирает образ без ошибок.
2. `git apply --check` на каждом патче проходит чисто.
3. В собранном DTB через `fdtdump build/cubie_a7z-trixie.dtb | grep -A20 typec` виден узел с `compatible = "etekmicro,et7304","richtek,rt1715"` и `connector { ... }`.
4. `zcat` финального kernel config показывает `CONFIG_TYPEC_RT1711H=y`, `CONFIG_TYPEC_DP_ALTMODE=y`.
5. Подмонтировать образ, проверить `/root/tests/test-typec.sh` присутствует, исполняемый, вызывается из `test-all.sh`.

**С железом** (отвечает пользователь после возврата A7Z):

6. `dmesg | grep -iE 'tcpci|rt1711'` — успешный probe, без -22.
7. `/sys/class/typec/port0/` существует.
8. Подключение DP-устройства → `port0-partner` появляется, `altmodes/displayport` зарегистрирован.
9. `pin_assignment` показывает `[C]` минимум (или `[D]`, если mux настроен и поддерживает 2+2).
10. Если есть DP source bridge и mux — на DP-мониторе появляется картинка.

## Известные ловушки

1. **Контекст hunks.** Серия v3 базируется на ~7.1-rc; в 6.6.98 окружение `tcpci_rt1711h.c` может слегка отличаться. При конфликте править контекст, **не трогать константы** `0x6DCF` / `0x2173`.
2. **Двойное применение.** Если в `allwinner-bsp` уже есть локальный фикс — удалить отдельным revert-патчем перед апстримным, иначе конфликт.
3. **Отсутствие mux на плате.** Если на A7Z hardware нет orientation switch — DP физически не уходит на пины, никакой софт не поможет. Зафиксировать как hardware-ограничение в `known-issues`, не как баг проекта.
4. **Pin Assignment C vs D.** Конфигурация C (4 lane DP) требует от mux только DP-роутинга. D (2+2) требует разделения DP и USB3 по разным парам. Если mux не умеет D — обратный USB-канал остаётся только на USB 2.0 D+/D- (480 Mbps). Хватит для IMU/HID/audio, но HD-камера UVC не пойдёт.
5. **DP source в SoC.** Самый туманный пункт. Если в `linux-orangepi` нет DRM-bridge для DP A733 — TCPC согласует Alt Mode, но видео из SoC не польётся. Это блокер от Allwinner/Radxa, не лечится в этом PR. Открыть отдельный issue, оставить TODO.
6. **IRQ пин.** Номер GPIO для IRQ ET7304 берётся из схемы, не угадывается. Без правильного прерывания TCPM не получит plug/unplug-уведомлений; роли застрянут.
7. **I2C bus name.** known-issues говорит "bus 14". В Allwinner-naming это обычно `&twi14`, а не `&i2c14`. Проверить в SoC dtsi `sun60iw2*.dtsi`.
8. **Datasheet NDA.** ET7304 публичен. FSA4480 / IT5205 — публичны. PS8743 / PI3DPX1207 / HD3SS460 — частично под NDA. Если на плате окажется закрытый mux — работать по publicly-known register maps или открыть feature request к производителю.
9. **rt1711h_id[] и of_match_table[].** В патче v3 добавляются записи в обе таблицы. Если backport на 6.6 имеет другую структуру — проверить, что добавилось в **обе**, иначе пробинг по compatible или по i2c-id может упасть на старом коде.
10. **vdo в altmode.** Значение `0x00001c46` — для DP source с поддержкой C+D. Перепроверить по VESA DP Alt Mode spec, если используется специфичный сценарий (sink-only, dock и т.п.).

---

Если нужно — могу следующим шагом сразу выкатить конкретные diff'ы (kernel-патчи + DTS-сниппет) под текущую структуру репы. Скажи целевую ветку.
