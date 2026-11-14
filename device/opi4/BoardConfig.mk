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

# GPU: Mali-T860 MP4 (Midgard) -> Mesa Panfrost, OpenGL ES 3.1. No Vulkan driver for Midgard.
BOARD_MESA3D_GALLIUM_DRIVERS := panfrost
# Mesa >= 25 compiles Panfrost's internal shaders (libpan) with OpenCL C at build time.
# Use host tools prebuilt from the same Mesa tree (tools/build-hosttools.sh, found via PATH)
# instead of building mesa_clc/LLVM inside the Android cross build.
BOARD_MESA3D_EXTRA_MESON_ARGS := -Dmesa-clc=system -Dprecomp-compiler=system

# Kernel: stable 6.18.y (linked by setup.sh) + Orange Pi 4 device tree from Armbian
BOARD_KERNEL_SRC_DIR := glodroid/kernel/mainline
BOARD_KERNEL_PATCHES_DIRS := $(BC_PATH)kernel-patches

# Debug console on UART2 at 1.5 Mbaud (same as the stock firmware and U-Boot)
BOARD_KERNEL_CMDLINE += console=ttyS2,1500000n8
ifneq (,$(filter userdebug eng,$(TARGET_BUILD_VARIANT)))
BOARD_KERNEL_CMDLINE += earlycon=uart8250,mmio32,0xff1a0000
endif

# Hardware video decoding: ffmpeg_codec2 over the V4L2 request API (rkvdec + Hantro)
BOARD_FFMPEG_ENABLE_REQUEST_API := true
BOARD_FFMPEG_KERNEL_HEADERS_DIR := $(BC_PATH)codecs/request_api_headers

UNSAFE_DISABLE_APEX_ALLOWED_DEPS_CHECK := true
