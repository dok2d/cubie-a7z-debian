# Rootfs: карта зависимостей пакетов

Обновлено: 2026-06-03

Для каждого верхнеуровневого пакета указаны все библиотечные пакеты из нашего
PACKAGES, которые он требует. При удалении пакета — удаляйте его зависимости,
если они не используются другими пакетами (проверить обратные ссылки в таблице).

> dpkg-deb -x не разрешает зависимости — каждая библиотека явно в PACKAGES.

---

## Верхнеуровневые пакеты → зависимости

| Пакет | Зависимости из PACKAGES |
|-------|------------------------|
| **systemd** | libapparmor1, libfdisk1, libffi8, libkmod2, libp11-kit0, libsystemd-shared |
| **systemd-sysv** | (через systemd) |
| **udev** | libkmod2 |
| **dbus** | libapparmor1, libdbus-1-3, libexpat1 |
| **dbus-daemon** | libapparmor1, libdbus-1-3, libexpat1 |
| **dbus-system-bus-common** | — |
| **kmod** | libkmod2 |
| **initramfs-tools** | libkmod2 |
| **u-boot-tools** | libffi8, libidn2-0, libp11-kit0, libtasn1-6 |
| **e2fsprogs** | libcom-err2, libext2fs2t64 |
| **fdisk** | libfdisk1, libncursesw6, libreadline8t64, libsmartcols1 |
| **dosfstools** | — |
| **ifupdown** | (через iproute2) |
| **iproute2** | libbpf1, libcom-err2, libgssapi-krb5-2, libk5crypto3, libkrb5-3, libkrb5support0, libmnl0, libtirpc3t64, libxtables12 |
| **netbase** | — |
| **isc-dhcp-client** | libbpf1, libgssapi-krb5-2, libmnl0, libxtables12 |
| **util-linux** | libsmartcols1 |
| **util-linux-extra** | libsmartcols1 |
| **procps** | libncursesw6, libproc2-0 |
| **less** | — |
| **vim-tiny** | — |
| **openssh-server** | libcom-err2, libgssapi-krb5-2, libk5crypto3, libkeyutils1, libkrb5-3, libkrb5support0, libncursesw6, libproc2-0 |
| **firmware-linux-free** | — |
| **ca-certificates** | — |
| **curl** | libcurl4t64 → libbrotli1, libcom-err2, libgssapi-krb5-2, libidn2-0, libk5crypto3, libkrb5-3, libkrb5support0, libldap2 (→ libsasl2-2), libnghttp2-14, libnghttp3-9, libpsl5t64, librtmp1, libssh2-1t64 |
| **wget** | libgnutls30t64 → libp11-kit0 (→ libffi8), libtasn1-6, libidn2-0, libpsl5t64 |
| **locales** | — |
| **console-setup** | — |
| **sudo** | — |
| **parted** | libparted2t64 |
| **wpasupplicant** | libnl-3-200, libnl-genl-3-200, libnl-route-3-200, libpcsclite1, libdbus-1-3 |
| **iw** | libnl-3-200, libnl-genl-3-200 |
| **alsa-utils** | libasound2t64, libasound2-data, libfftw3-single3 (→ libgomp1), libncursesw6, libsamplerate0 |
| **wireless-regdb** | — |
| **iputils-ping** | libidn2-0 (→ libunistring5) |
| **tzdata** | — |
| **tree** | — |
| **gawk** | libsigsegv2, libmpfr6 |
| **nano** | libncursesw6 |
| **usbutils** | libusb-1.0-0 |
| **pciutils** | libpci3, libkmod2 |
| **i2c-tools** | libi2c0, libkmod2 |
| **gpiod** | libgpiod3, libstdc++6 |
| **rfkill** | libsmartcols1 |
| **ethtool** | libmnl0 |
| **htop** | libncursesw6, libnl-3-200, libnl-genl-3-200 |
| **strace** | — |
| **file** | libmagic1t64, libmagic-mgc |

---

## Библиотечные пакеты → кто использует

Обратная карта: если библиотека нужна хотя бы одному пакету — её нельзя удалять.

| Библиотека | Используется |
|------------|-------------|
| **libapparmor1** | systemd, dbus, dbus-daemon |
| **libasound2t64** | alsa-utils |
| **libasound2-data** | alsa-utils |
| **libbpf1** | iproute2, isc-dhcp-client, ifupdown |
| **libbrotli1** | curl (через libcurl4t64) |
| **libcom-err2** | e2fsprogs, iproute2, openssh-server, curl |
| **libcurl4t64** | curl |
| **libdbus-1-3** | dbus, dbus-daemon, wpasupplicant |
| **libdrm2** | GPU userland |
| **libelf1t64** | libbpf1 |
| **libexpat1** | dbus, dbus-daemon |
| **libext2fs2t64** | e2fsprogs |
| **libfdisk1** | fdisk, systemd |
| **libffi8** | systemd (через libp11-kit0), wget, u-boot-tools |
| **libfftw3-single3** | alsa-utils |
| **libgnutls30t64** | wget |
| **libgomp1** | alsa-utils (через libfftw3-single3) |
| **libgpiod3** | gpiod |
| **libgssapi-krb5-2** | openssh-server, iproute2, isc-dhcp-client, curl |
| **libi2c0** | i2c-tools |
| **libidn2-0** | iputils-ping, curl, wget, u-boot-tools |
| **libk5crypto3** | openssh-server, iproute2, curl (через libgssapi-krb5-2) |
| **libkeyutils1** | openssh-server (через libkrb5-3) |
| **libkmod2** | systemd, udev, kmod, initramfs-tools, pciutils, i2c-tools |
| **libkrb5-3** | openssh-server, iproute2, curl (через libgssapi-krb5-2) |
| **libkrb5support0** | openssh-server, iproute2, curl (через libgssapi-krb5-2) |
| **libldap2** | curl (через libcurl4t64) |
| **libmagic-mgc** | file |
| **libmagic1t64** | file |
| **libmnl0** | ethtool, iproute2, isc-dhcp-client |
| **libmpfr6** | gawk |
| **libncursesw6** | fdisk, nano, htop, procps, openssh-server, alsa-utils |
| **libnghttp2-14** | curl (через libcurl4t64) |
| **libnghttp3-9** | curl (через libcurl4t64) |
| **libnl-3-200** | iw, wpasupplicant, htop |
| **libnl-genl-3-200** | iw, wpasupplicant, htop |
| **libnl-route-3-200** | wpasupplicant |
| **libp11-kit0** | systemd, wget, u-boot-tools |
| **libparted2t64** | parted |
| **libpci3** | pciutils |
| **libpciaccess0** | GPU/Xorg |
| **libpcsclite1** | wpasupplicant |
| **libpixman-1-0** | GPU/Xorg |
| **libproc2-0** | procps, openssh-server |
| **libpsl5t64** | curl, wget |
| **libreadline8t64** | fdisk |
| **librtmp1** | curl (через libcurl4t64) |
| **libsamplerate0** | alsa-utils |
| **libsasl2-2** | curl (через libldap2) |
| **libsigsegv2** | gawk |
| **libsmartcols1** | fdisk, rfkill, util-linux, util-linux-extra |
| **libss2** | e2fsprogs (debugfs) |
| **libssh2-1t64** | curl (через libcurl4t64) |
| **libstdc++6** | gpiod, GPU userland |
| **libsystemd-shared** | systemd |
| **libtasn1-6** | wget, u-boot-tools (через libgnutls30t64) |
| **libtirpc3t64** | iproute2 |
| **libunistring5** | iputils-ping (через libidn2-0) |
| **libusb-1.0-0** | usbutils |
| **libxau6** | GPU/Xorg |
| **libxdmcp6** | GPU/Xorg |
| **libxfont2** | GPU/Xorg |
| **libxshmfence1** | GPU/Xorg |
| **libxtables12** | iproute2, isc-dhcp-client |

---

## Группы зависимостей

Пакеты, которые всегда идут вместе:

| Группа | Пакеты |
|--------|--------|
| **Kerberos** | libgssapi-krb5-2, libk5crypto3, libkrb5-3, libkrb5support0, libkeyutils1, libcom-err2 |
| **TLS/crypto** | libgnutls30t64, libp11-kit0, libtasn1-6, libffi8 |
| **curl stack** | libcurl4t64, libbrotli1, libnghttp2-14, libnghttp3-9, libpsl5t64, librtmp1, libssh2-1t64, libldap2, libsasl2-2 |
| **netlink** | libnl-3-200, libnl-genl-3-200, libnl-route-3-200 |
| **GPU/Xorg** | libdrm2, libexpat1, libstdc++6, libpixman-1-0, libpciaccess0, libxfont2, libxau6, libxshmfence1, libxdmcp6 |
| **kmod chain** | libkmod2 (used by systemd, udev, kmod, initramfs-tools, pciutils, i2c-tools) |

---

## Нерешаемое

| Бинарник | Missing lib | Причина |
|----------|------------|---------|
| `/usr/bin/Xorg` (vendor) | `libcrypto.so.1.1` | Собран с OpenSSL 1.1, Trixie имеет 3.x. Для GUI — `apt install xorg`. |
