# Reproducible builder for Cubie A7Z Debian images.
#
# Host arch: x86_64. The Allwinner SPL packer in brandy-2.0 ships as an
# x86_64 binary, so an ARM host will not work for the bootloader stage.

FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C.UTF-8

# Pin apt to a snapshot for reproducibility. Update the date when you want
# to refresh the toolchain.
ARG APT_SNAPSHOT=20260101T000000Z
RUN echo "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/${APT_SNAPSHOT} trixie main contrib non-free-firmware" \
      > /etc/apt/sources.list \
 && echo "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian-security/${APT_SNAPSHOT} trixie-security main" \
      >> /etc/apt/sources.list \
 && echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/10no-check-valid-until

RUN apt-get update && apt-get install -y --no-install-recommends \
      # Core build tooling
      build-essential \
      ca-certificates \
      git \
      curl \
      wget \
      make \
      cmake \
      pkg-config \
      python3 \
      python3-pip \
      python3-pyelftools \
      python3-setuptools \
      swig \
      bc \
      bison \
      flex \
      kmod \
      cpio \
      rsync \
      file \
      xz-utils \
      zstd \
      gzip \
      # Cross toolchain (aarch64 for kernel, arm32 for U-Boot/brandy-2.0)
      gcc-aarch64-linux-gnu \
      g++-aarch64-linux-gnu \
      libc6-dev-arm64-cross \
      gcc-arm-linux-gnueabi \
      g++-arm-linux-gnueabi \
      libc6-dev-armel-cross \
      # Kernel/U-Boot deps
      xxd \
      libssl-dev \
      libgnutls28-dev \
      libncurses-dev \
      device-tree-compiler \
      u-boot-tools \
      # Image assembly
      parted \
      gdisk \
      dosfstools \
      e2fsprogs \
      mtools \
      util-linux \
      openssh-client \
      # Debian rootfs creation
      debootstrap \
      qemu-user-static \
      binfmt-support \
      sudo \
      # Misc tools used by vendor pack scripts
      busybox \
      # Patch management
      quilt \
      # FEL flashing
      sunxi-tools \
 && rm -rf /var/lib/apt/lists/*

# Non-root build user matched to a common host UID. Override at build time
# with --build-arg if your host UID differs.
ARG BUILDER_UID=1000
ARG BUILDER_GID=1000
RUN groupadd -g ${BUILDER_GID} builder \
 && useradd  -m -u ${BUILDER_UID} -g ${BUILDER_GID} -s /bin/bash builder \
 && echo 'builder ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/builder

USER builder
WORKDIR /work
