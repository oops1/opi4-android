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

$(call inherit-product, $(LOCAL_PATH)/device.mk)
