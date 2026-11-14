# SPDX-License-Identifier: Apache-2.0
#
# Orange Pi 4 (RK3399) product configuration

$(call inherit-product, glodroid/configuration/common/device-common.mk)

# Wi-Fi / Bluetooth: AP6256 (BCM43456 + BCM4345C5), brcmfmac + hci_uart
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/firmware/brcmfmac43456-sdio.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/brcm/brcmfmac43456-sdio.bin \
    $(LOCAL_PATH)/firmware/brcmfmac43456-sdio.clm_blob:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/brcm/brcmfmac43456-sdio.clm_blob \
    $(LOCAL_PATH)/firmware/brcmfmac43456-sdio.txt:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/brcm/brcmfmac43456-sdio.xunlong,orangepi-4.txt \
    $(LOCAL_PATH)/firmware/BCM4345C5.hcd:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/brcm/BCM4345C5.hcd \

# Disable suspend while bringing the board up
PRODUCT_COPY_FILES += \
    glodroid/configuration/common/no_suspend.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/no_suspend.opi4.rc \

# 196609 == 0x00030001 == GLES v3.1 (Panfrost on Mali-T860)
PRODUCT_VENDOR_PROPERTIES += \
    ro.opengles.version=196609

# Hardware codecs through ffmpeg_codec2 (V4L2 request API: rkvdec H.264/HEVC/VP9, Hantro MPEG-2/VP8)
PRODUCT_VENDOR_PROPERTIES += \
    persist.ffmpeg_codec2.v4l2.h264=true \
    persist.ffmpeg_codec2.v4l2.h265=true \
    persist.ffmpeg_codec2.rank.audio=16 \
    persist.ffmpeg_codec2.rank.video=128 \

# No Vulkan on Midgard: keep HWUI and RenderEngine on Skia/GL
TARGET_USES_VULKAN := false
