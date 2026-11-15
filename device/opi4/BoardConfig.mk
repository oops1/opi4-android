# SPDX-License-Identifier: Apache-2.0
#
# Orange Pi 4 (RK3399) board configuration on top of GloDroid (Android 16).

BC_PATH := $(patsubst $(CURDIR)/%,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# No camera and no modem on this board (must be set before board-common.mk)
GD_NO_DEFAULT_CAMERA := true
GD_NO_DEFAULT_MODEM := true

# super = system + system_ext + product + vendor + vendor_dlkm (~2.1 GB with the arm64 defconfig
# module set). 16 GB eMMC leaves plenty for userdata, so give it headroom.
GD_SUPER_PARTITION_SIZE_MB := 3500

include glodroid/configuration/common/board-common.mk

# GloDroid stages the ramdisk at base+0x3300000 = 0x05300000, but our kernel Image is 59 MiB
# (0x02080000..0x05bc0000), so 'bootm' decompressed the kernel over the first 8.8 MiB of the
# ramdisk ("rootfs image is not initramfs"). Stage it at 0x10000000 instead (last option wins).
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset 0x0e000000

# GPU: Mali-T860 MP4 (Midgard) -> Mesa Panfrost, OpenGL ES 3.1. No Vulkan driver for Midgard.
BOARD_MESA3D_GALLIUM_DRIVERS := panfrost
# Mesa >= 25 compiles Panfrost's internal shaders (libpan) with OpenCL C at build time.
# Use host tools prebuilt from the same Mesa tree (tools/build-hosttools.sh, found via PATH)
# instead of building mesa_clc/LLVM inside the Android cross build.
BOARD_MESA3D_EXTRA_MESON_ARGS := -Dmesa-clc=system -Dprecomp-compiler=system

# Board SELinux policy (Widevine HAL domain for the optional vendor/widevine APEX)
BOARD_VENDOR_SEPOLICY_DIRS += $(BC_PATH)sepolicy/vendor

# Kernel: stable 6.18.y (linked by setup.sh) + Orange Pi 4 device tree from Armbian
BOARD_KERNEL_SRC_DIR := glodroid/kernel/mainline
BOARD_KERNEL_PATCHES_DIRS := $(BC_PATH)kernel-patches
# Clock caps for a 5 V / 2 A supply (CPU/GPU OPPs halved). Builds for real use and for
# publication run at full clocks: OPI4_FULL_CLOCKS=true m (needs a 3 A supply).
ifneq ($(OPI4_FULL_CLOCKS),true)
BOARD_KERNEL_PATCHES_DIRS += $(BC_PATH)kernel-patches-psu2a
endif

# Debug console on UART2 at 1.5 Mbaud (same as the stock firmware and U-Boot)
BOARD_KERNEL_CMDLINE += console=ttyS2,1500000n8
ifneq (,$(filter userdebug eng,$(TARGET_BUILD_VARIANT)))
BOARD_KERNEL_CMDLINE += earlycon=uart8250,mmio32,0xff1a0000
endif

# Boot screen: one centred logo, no blinking cursor (fbcon has no text: console=ttyS2)
BOARD_KERNEL_CMDLINE += fbcon=logo-pos:center,logo-count:1 vt.global_cursor_default=0

# Hardware video decoding: ffmpeg_codec2 over the V4L2 request API (rkvdec + Hantro)
BOARD_FFMPEG_ENABLE_REQUEST_API := true
BOARD_FFMPEG_KERNEL_HEADERS_DIR := $(BC_PATH)codecs/request_api_headers

UNSAFE_DISABLE_APEX_ALLOWED_DEPS_CHECK := true
