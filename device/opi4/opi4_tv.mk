# SPDX-License-Identifier: Apache-2.0
#
# Orange Pi 4 as an Android TV box. Same hardware/board config as opi4;
# the "_tv" suffix switches GloDroid to device-tv.mk (atv system/product/vendor).

$(call inherit-product, $(LOCAL_PATH)/opi4.mk)

PRODUCT_NAME := opi4_tv
PRODUCT_MODEL := Orange Pi 4 TV

PRODUCT_CHARACTERISTICS := tv
