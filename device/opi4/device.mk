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
    $(LOCAL_PATH)/firmware/dptx.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/rockchip/dptx.bin \

# Init scripts, device node permissions, module blocklist
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/etc/other.opi4.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/other.opi4.rc \
    $(LOCAL_PATH)/etc/debug.opi4.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/debug.opi4.rc \
    $(LOCAL_PATH)/etc/uevent.device.rc:$(TARGET_COPY_OUT_VENDOR)/etc/uevent.device.rc \
    $(LOCAL_PATH)/etc/modules.blocklist:$(TARGET_COPY_OUT_VENDOR_DLKM)/lib/modules/modules.blocklist \
    $(LOCAL_PATH)/etc/modules.options:$(TARGET_COPY_OUT_VENDOR_DLKM)/lib/modules/modules.options \

# Boot animation (bootanimation/README.md): orange outro for opi4, orange -> TV outro
# with the hand-written "TV" for the opi4_tv product
ifneq ($(filter %_tv,$(TARGET_PRODUCT)),)
OPI4_BOOTANIMATION := bootanimation-tv.zip
else
OPI4_BOOTANIMATION := bootanimation.zip
endif
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/bootanimation/$(OPI4_BOOTANIMATION):$(TARGET_COPY_OUT_PRODUCT)/media/bootanimation.zip \

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

# Bluetooth profiles. Since A13 every profile is off unless its sysprop is set, which left
# only GATT running: BLE keyboards bonded but HID host never connected them.
# BCM4345C5 is BT 5.0 without ISO channels, so LE Audio stays off. A2DP is software-encoded
# (no offload); the stack carries SBC, AAC, aptX/aptX HD, LDAC and Opus encoders.
PRODUCT_VENDOR_PROPERTIES += \
    bluetooth.profile.gatt.enabled=true \
    bluetooth.profile.a2dp.source.enabled=true \
    bluetooth.profile.avrcp.target.enabled=true \
    bluetooth.profile.hid.host.enabled=true \
    bluetooth.profile.pan.nap.enabled=true \
    bluetooth.profile.pan.panu.enabled=true \
    bluetooth.profile.opp.enabled=true \
    bluetooth.profile.asha.central.enabled=false \
    bluetooth.profile.bap.broadcast.assist.enabled=false \
    bluetooth.profile.bap.unicast.client.enabled=false \
    bluetooth.profile.bas.client.enabled=false \
    bluetooth.profile.ccp.server.enabled=false \
    bluetooth.profile.csip.set_coordinator.enabled=false \
    bluetooth.profile.hap.client.enabled=false \
    bluetooth.profile.vcp.controller.enabled=false \
    persist.bluetooth.a2dp_offload.disabled=true \

# Audio: GloDroid HAL drives one ALSA card. HDMI (card "hdmisound") is the output a TV box
# needs; the RT5651 analog jack is card 0 (persist.vendor.audio.primary.card_name=realtekrt5651co).
PRODUCT_VENDOR_PROPERTIES += \
    persist.vendor.audio.primary.card_name=hdmisound \
    persist.vendor.audio.primary.card=1 \
    persist.vendor.audio.primary.device=0 \

# Serial shell off by default (etc/other.opi4.rc)
PRODUCT_VENDOR_PROPERTIES += persist.vendor.opi4.console=0

# No Vulkan on Midgard: keep HWUI and RenderEngine on Skia/GL
TARGET_USES_VULKAN := false
