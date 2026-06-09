# User Guide — Cubie A7Z Debian

## Quick Start

1. Flash the image to a microSD card (8+ GB):
   ```bash
   xzcat cubie_a7z-trixie.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
   sync
   ```

2. Insert the SD card into Cubie A7Z

3. Connect power via USB-C (J16, bottom port)

4. Connect:
   - **UART**: 115200 baud, ttyS0 (via 40-pin header: pin 10 TX, pin 12 RX)
   - **SSH**: after WiFi is connected (see below)
   - **HDMI**: micro-HDMI + USB keyboard via USB-C (J4, top port)

## Accounts

| User | Password |
|------|----------|
| root | cubie |
| cubie | cubie |

User `cubie` has sudo access.

## WiFi

### Connecting to a Network

```bash
nano /etc/wpa_supplicant/wpa_supplicant.conf
```

Add a network block:
```
network={
    ssid="YourNetworkName"
    psk="YourPassword"
}
```

Apply:
```bash
systemctl restart networking
```

WiFi connects automatically on every boot once configured.
See also: `/root/help/wifi.txt`.

### Verify

```bash
ip addr show wlan0
ping 8.8.8.8
```

## SSH

SSH server starts automatically on port 22.

```bash
ssh cubie@<ip-address>
```

Find the IP address via UART: `hostname -I`

## Package Updates

```bash
sudo apt update
sudo apt upgrade
```

Repositories: Debian Trixie (main, contrib, non-free, non-free-firmware).

## USB-C Ports

| Port | Location | Function |
|------|----------|----------|
| J16 (bottom) | USB-C 2.0 | Power + USB OTG |
| J4 (top) | USB-C 3.1 | Host (keyboard, hub, monitor via DP Alt) |

USB-C J4 supports:
- HID devices (keyboard, mouse) via OTG adapter
- USB hubs
- DisplayPort Alt Mode (via ET7304Y TCPC)

## HDMI

- Connector: micro-HDMI
- Video: works, hotplug
- Audio: HDMI audio (soundcard `sndhdmi`)

```bash
# Check audio
aplay -l
# Play a wav file
aplay -D hw:sndhdmi test.wav
```

## GPU

PowerVR BXM-4-64 MC1. Module `pvrsrvkm` loads automatically.

```bash
ls /dev/dri/renderD128
```

OpenGL ES, Vulkan, OpenCL — via vendor Mesa/PVR userland (pre-installed).

## NPU

VeriSilicon VIPLite, 3 TOPS @ INT8. Device: `/dev/vipcore`.

### Inference Test

```bash
# Create config
cat > /tmp/sample.txt << 'EOF'
[network]
/usr/share/npu/models/resnet50.nb
[input]
/tmp/input.dat
EOF

# Generate test input (224x224x3)
dd if=/dev/urandom of=/tmp/input.dat bs=150528 count=1

# Run
vpm_run -s /tmp/sample.txt -l 1
```

Pre-installed models: ResNet50, YOLOv5 in `/usr/share/npu/models/`.

## 40-pin GPIO Header

| Function | Pins | Status |
|----------|------|--------|
| UART (debug) | 10 (TX), 12 (RX) | Working |
| SPI1 | 19 (MOSI), 21 (MISO), 23 (CLK), 24 (CS0) | /dev/spidev1.0 |
| I2C (TWI7) | 1 (SDA), 3 (SCK) | Available (disabled by default) |
| I2S0 | 14, 35, 36, 38, 40 | Available for external DAC |
| GPIO | 7, 11, 13, 15, 17, 18, 26, 29, 31 | Via gpiodetect/gpioset |

```bash
gpiodetect
gpioinfo
```

## PCIe

M.2 FPC connector J3, PCIe Gen3 x1.

```bash
lspci
```

## Bluetooth

BT via AIC8800 USB (btusb).

```bash
bluetoothctl
power on
scan on
```

## Time

The board has no RTC battery. On boot, time is restored from
`fake-hwclock`, then synchronized via NTP (systemd-timesyncd).

```bash
timedatectl status
```

## First Boot

On first boot, the following happens automatically:
1. Rootfs is expanded to the full SD card size
2. Time is set from fake-hwclock
3. WiFi chip is powered on via sunxi-rfkill
4. SSH server starts

## Hardware Tests

Run all tests at once:

```bash
bash /root/tests/test-all.sh
```

Or individually:

```bash
bash /root/tests/test-wifi.sh
bash /root/tests/test-npu.sh
bash /root/tests/test-gpu.sh
# ... test-bt, test-hdmi, test-usbc, test-pcie, test-spi, test-i2c, test-gpio, test-thermal
```

## Troubleshooting

### WiFi Won't Connect
```bash
# Check networking status
systemctl status networking
# Restart
systemctl restart networking
# Verify chip is powered
cat /sys/class/misc/sunxi-rfkill/wlan/state
# Should be 1. If 0:
echo 1 > /sys/class/misc/sunxi-rfkill/wlan/state
```

### No Internet After WiFi Connects
```bash
# Check wpa_supplicant is running
pgrep -a wpa_supplicant
# Check IP address
ip addr show wlan0
# If no IP — request manually
dhclient wlan0
```

### Wrong Time
```bash
date -s "2026-06-07 12:00:00"
systemctl restart systemd-timesyncd
```

### Disk Full
```bash
# Check if resize worked
df -h /
# If not — run manually
resize2fs /dev/mmcblk0p2
```

### USB-C Devices Not Detected
Make sure you are using port J4 (top) with an OTG adapter.
Port J16 (bottom) is power-only.
