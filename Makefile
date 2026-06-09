# Cubie A7Z Debian build — top-level orchestration.
#
# Runs native on the build host (no Docker). All tools are expected on PATH.
# See docker/Dockerfile.builder for the reference dependency list.

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

# Reproducibility: freeze build timestamp from the last git commit.
SOURCE_DATE_EPOCH ?= $(shell git log -1 --pretty=%ct 2>/dev/null || date +%s)
export SOURCE_DATE_EPOCH

# Scripts are run directly on the host.
RUN := scripts

.PHONY: help
help:
	@echo "Targets:"
	@echo "  deps          Check that all required tools are on PATH"
	@echo "  fetch         Fetch + pin vendor sources"
	@echo "  bootloader    Build boot0/SPL/U-Boot via brandy-2.0"
	@echo "  kernel        Cross-compile kernel + bindeb-pkg"
	@echo "  rootfs        debootstrap arm64 Debian rootfs"
	@echo "  image         Assemble final .img.xz"
	@echo "  all           fetch -> bootloader -> kernel -> rootfs -> image"
	@echo "  flash DEV=... Write image to a removable device"
	@echo "  clean         Remove build/ (keeps sources/)"
	@echo "  distclean     Remove build/ AND sources/"

.PHONY: deps
deps:
	@missing=; \
	for cmd in aarch64-linux-gnu-gcc debootstrap qemu-aarch64-static \
	           parted mkfs.fat mkfs.ext4 xz bc bison flex swig dtc make git wget; do \
	  command -v $$cmd >/dev/null 2>&1 || missing="$$missing $$cmd"; \
	done; \
	if [ -n "$$missing" ]; then \
	  echo "Missing tools:$$missing"; exit 1; \
	fi; \
	echo "All dependencies found."

.PHONY: fetch
fetch:
	$(RUN)/00-fetch-sources.sh

.PHONY: bootloader
bootloader:
	$(RUN)/10-build-bootloader.sh

.PHONY: kernel
kernel:
	$(RUN)/20-build-kernel.sh

.PHONY: rootfs
rootfs:
	$(RUN)/30-build-rootfs.sh

.PHONY: image
image:
	$(RUN)/40-assemble-image.sh

.PHONY: all
all: fetch bootloader kernel rootfs image

.PHONY: flash
flash:
	@test -n "$(DEV)" || (echo "Usage: make flash DEV=/dev/sdX" && exit 1)
	$(RUN)/90-flash-sd.sh "$(DEV)"

.PHONY: clean
clean:
	rm -rf build/

.PHONY: distclean
distclean: clean
	rm -rf sources/*
	touch sources/.gitkeep
