# SPDX-License-Identifier: Apache-2.0
#
# Orange Pi 4 v1.3 (RK3399, 4 GB LPDDR4, 16 GB eMMC, AP6256 Wi-Fi/BT, RT5651 audio)

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a53

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv7-a-neon
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a15

PRODUCT_BOARD_PLATFORM := rockchip
PRODUCT_NAME := opi4
PRODUCT_DEVICE := opi4
PRODUCT_BRAND := OrangePI
PRODUCT_MODEL := Orange Pi 4
PRODUCT_MANUFACTURER := Xunlong
PRODUCT_HAS_EMMC := true

# Bootloader: mainline U-Boot + TF-A (BL31). DDR init via rkbin TPL blob for now.
UBOOT_DEFCONFIG := orangepi-4-rk3399_defconfig
ATF_PLAT        := rk3399
RK_MAINLINE_UBOOT := true
RK_TPL_BLOB     := bin/rk33/rk3399_ddr_800MHz_v1.30.bin
# Rockchip BL31: upstream TF-A leaves the PL330 DMA controllers secure (no audio)
RK_BL31_BLOB    := bin/rk33/rk3399_bl31_v1.36.elf
UBOOT_FRAGMENTS := $(LOCAL_PATH)/uboot.config

# Kernel
KERNEL_DEFCONFIG := glodroid/kernel/mainline/arch/arm64/configs/defconfig
KERNEL_FRAGMENTS := $(LOCAL_PATH)/kernel.config
KERNEL_DTB_FILE  := rockchip/rk3399-orangepi-4.dtb

# eMMC on sdhci, SD card on dw-mmc (RK3399)
SYSFS_MMC0_PATH := fe330000.mmc
SYSFS_MMC1_PATH := fe320000.mmc

GD_NO_DEFAULT_CAMERA := true
GD_NO_DEFAULT_MODEM := true
# GloDroid's first-boot apps (F-Droid, SkyTube, Fenix 95 that crashes on Android 16,
# a phone launcher that also lands on the TV build): not wanted here
GD_NO_DEFAULT_APPS := true
# Codec list without the stateful-only c2.v4l2.* components (codecs/media_codecs.xml)
GD_MEDIACODECS_FILE := $(LOCAL_PATH)/codecs/media_codecs.xml

$(call inherit-product, $(LOCAL_PATH)/device.mk)

# Google apps, not part of this repo (proprietary, not redistributable): build
# "WITH_GAPPS=false m" for images meant to be shared.
#  opi4:    MindTheGapps, branch baklava, cloned to vendor/gapps
#  opi4_tv: MindTheGapps ATV full zip, unpacked by tools/gen-gapps-atv.py into vendor/gapps-atv
ifneq ($(WITH_GAPPS),false)
ifeq ($(filter %_tv,$(TARGET_PRODUCT)),)
ifneq ($(wildcard vendor/gapps/arm64/arm64-vendor.mk),)
$(call inherit-product, vendor/gapps/arm64/arm64-vendor.mk)
endif
else
ifneq ($(wildcard vendor/gapps-atv/gapps-atv-vendor.mk),)
$(call inherit-product, vendor/gapps-atv/gapps-atv-vendor.mk)
endif
endif
endif
