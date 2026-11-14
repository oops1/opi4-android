# SPDX-License-Identifier: Apache-2.0
#
# Orange Pi 4 (RK3399): tablet-style Android and Android TV variants.
# A product name ending in "_tv" makes glodroid/configuration/common/device-common.mk
# pull in device-tv.mk (device/google/atv, Leanback launcher, TvProvision).

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/opi4.mk \
    $(LOCAL_DIR)/opi4_tv.mk \

COMMON_LUNCH_CHOICES := \
    opi4-trunk_staging-userdebug \
    opi4_tv-trunk_staging-userdebug \
