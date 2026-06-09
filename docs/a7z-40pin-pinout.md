# Cubie A7Z — 40-pin GPIO распиновка

Источник: https://docs.radxa.com/en/cubie/a7z/hardware-use/pin-gpio

## Таблица

| Pin | Название | Pin | Название |
|-----|----------|-----|----------|
| 1 | **3.3V** | 2 | **5V** |
| 3 | PJ23 (TWI3_SDA / UART3_TX / PWM1-5) | 4 | **5V** |
| 5 | PJ22 (TWI3_SCK / UART3_RX / PWM1-4) | 6 | **GND** |
| 7 | PB0 (UART2_TX / UART0_TX / SPI2_CS0) | 8 | PB9 (PWM1-1 / I2S0) |
| 9 | **GND** | 10 | PB10 (PWM1-2 / I2S0) |
| 11 | PB1 (UART2_RX / UART0_RX / SPI2_CLK) | 12 | PB5 (I2S0_BCLK / TWI1_SDA / PWM0-1) |
| 13 | PL6 (S-IR_RX / S-PWM0-4 / S-UART0_TX) | 14 | **GND** |
| 15 | PL7 (S-UART0_RX / S-SPI0_MISO / S-PWM0-5) | 16 | PJ24 (SPI3_CLK / TWI4_SCK / UART4_TX / PWM1-6) |
| 17 | **3.3V** | 18 | PJ25 (SPI3_MOSI / TWI4_SDA / UART4_RX / PWM1-7) |
| 19 | PD12 (SPI1_MOSI / PWM1-2) | 20 | **GND** |
| 21 | PD13 (SPI1_MISO / PWM1-3) | 22 | PL5 (S-PWM0-3 / S-SPI0_CLK / S-TWI2_SDA) |
| 23 | PD11 (SPI1_CLK / PWM1-1) | 24 | PD10 (SPI1_CS0 / PWM1-0) |
| 25 | **GND** | 26 | PD14 (SPI1_HOLD) |
| 27 | PD17 (TWI2_SDA / UART3_RX) | 28 | PD16 (TWI2_SCK / UART3_TX) |
| 29 | PB2 (UART2_RTS / SPI2_MOSI / HDMI_SCL / TWI0_SCK) | 30 | **GND** |
| 31 | PB3 (UART2_CTS / SPI2_MISO / HDMI_SDA / TWI0_SDA) | 32 | PM3 (S-UART0_RX / S-TWI1_SDA) |
| 33 | PM5 (S-IR_RX / S-PWM0-1 / S-TWI1_SDA) | 34 | **GND** |
| 35 | PB6 (I2S0_LRCK / PWM0-2 / CLK_FANOUT1) | 36 | PB4 (TWI1_SCK / I2S0_MCLK / PWM0-0) |
| 37 | PM4 (S-UART0_TX / S-TWI1_SCK / S-PWM0-0) | 38 | PB8 (I2S0_DIN0 / PWM1-0 / TWI1_SDA) |
| 39 | **GND** | 40 | PB7 (I2S0_DOUT0 / PWM0-9 / TWI1_SCK) |

## UART (консоль)

Консольный UART по умолчанию — **UART0** на пинах 7/11 (PB0/PB1) в DTS,
но физически пины 7/11 мультиплексированы. Проверьте DTS для конкретной
конфигурации.

Стандартное подключение UART-адаптера:

```
Pin 8  (PB9 / TX)  → адаптер RX
Pin 10 (PB10 / RX) → адаптер TX
Pin 6  (GND)       → адаптер GND
```

**ВНИМАНИЕ**: только 3.3V адаптер!

## Формула вычисления номера GPIO

```
GPIOCHIP0 (порты A–K):  GPIO = port_index × 32 + pin_number
  A=0, B=1, C=2, D=3, E=4, F=5, G=6, H=7, I=8, J=9, K=10

GPIOCHIP1 (порты L–M):  GPIO = port_index × 32 + pin_number
  L=0, M=1
```

Примеры:
- PB0 = 1×32 + 0 = GPIO 32
- PD16 = 3×32 + 16 = GPIO 112
- PJ22 = 9×32 + 22 = GPIO 310

## Доступные интерфейсы на 40-pin

| Интерфейс | Пины | Примечание |
|---|---|---|
| UART0 (console) | 7 (TX), 11 (RX) | PB0/PB1 |
| UART2 | 7 (TX), 11 (RX), 29 (RTS), 31 (CTS) | PB0-PB3, мультиплексирован с UART0 |
| UART3 | 3 (TX), 5 (RX) или 28 (TX), 27 (RX) | PJ22-PJ23 или PD16-PD17 |
| UART4 | 16 (TX), 18 (RX) | PJ24-PJ25 |
| SPI1 | 23 (CLK), 19 (MOSI), 21 (MISO), 24 (CS0) | PD10-PD13 |
| SPI2 | 7 (CS0), 11 (CLK), 29 (MOSI), 31 (MISO) | PB0-PB3 |
| SPI3 | 16 (CLK), 18 (MOSI) | PJ24-PJ25 |
| TWI0 (I2C) | 29 (SCK), 31 (SDA) | PB2-PB3 |
| TWI1 (I2C) | 36 (SCK), 12 (SDA) | PB4-PB5 |
| TWI2 (I2C) | 28 (SCK), 27 (SDA) | PD16-PD17 |
| TWI3 (I2C) | 5 (SCK), 3 (SDA) | PJ22-PJ23 |
| TWI4 (I2C) | 16 (SCK), 18 (SDA) | PJ24-PJ25 |
| I2S0 | 36 (MCLK), 12 (BCLK), 35 (LRCK), 40 (DOUT0), 38 (DIN0) | PB4-PB8 |
| PWM | 3,5,8,10,12,16,18,19,21,23,24,35,36,38,40 | Множество каналов |
| IR RX | 13 (PL6) или 33 (PM5) | S-IR_RX |
