#!/bin/bash -e
# Imports third-party files into the port repo (run once, re-run to refresh):
#  - Orange Pi 4 device tree from Armbian -> kernel patch
#  - AP6256 firmware from armbian/firmware
#  - V4L2 request API headers used by ffmpeg (from GloDroid gd_rpi4)
PORT=$(cd "$(dirname "$0")/.." && pwd)
SRC=${SRC:-$HOME/opi4}
DEV=$PORT/device/opi4

# 1. Kernel DT patch: new rk3399-orangepi-4.dts + Makefile entry
KDT=$SRC/armbian/patch/kernel/archive/rockchip64-6.18/dt/rk3399-orangepi-4.dts
mkdir -p $DEV/kernel-patches
TMP=$(mktemp -d)
mkdir -p $TMP/a/arch/arm64/boot/dts/rockchip $TMP/b/arch/arm64/boot/dts/rockchip
cp $SRC/linux/arch/arm64/boot/dts/rockchip/Makefile $TMP/a/arch/arm64/boot/dts/rockchip/Makefile
cp $TMP/a/arch/arm64/boot/dts/rockchip/Makefile $TMP/b/arch/arm64/boot/dts/rockchip/Makefile
sed -i '/rk3399-orangepi\.dtb/a dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3399-orangepi-4.dtb' $TMP/b/arch/arm64/boot/dts/rockchip/Makefile
cp $KDT $TMP/b/arch/arm64/boot/dts/rockchip/rk3399-orangepi-4.dts
{
  echo "From: Armbian (imported by opi4-android)"
  echo "Subject: [PATCH] arm64: dts: rockchip: add Orange Pi 4 (from Armbian rockchip64-6.18)"
  echo
  echo "---"
  (cd $TMP && diff -Nu a/arch/arm64/boot/dts/rockchip/Makefile b/arch/arm64/boot/dts/rockchip/Makefile;
               diff -Nu a/arch/arm64/boot/dts/rockchip/rk3399-orangepi-4.dts b/arch/arm64/boot/dts/rockchip/rk3399-orangepi-4.dts) || true
} > $DEV/kernel-patches/0001-arm64-dts-rockchip-add-Orange-Pi-4.patch
rm -rf $TMP

# 2. Wi-Fi/BT firmware
mkdir -p $DEV/firmware
for f in brcmfmac43456-sdio.bin brcmfmac43456-sdio.clm_blob brcmfmac43456-sdio.txt BCM4345C5.hcd; do
  cp $SRC/armbian-fw/brcm/$f $DEV/firmware/
done

# 3. V4L2 request API headers for ffmpeg
mkdir -p $DEV/codecs
rm -rf $DEV/codecs/request_api_headers
cp -r $SRC/glodroid-a16/aosptree/vendor/devices-community/gd_rpi4/codecs/request_api_headers_v4 $DEV/codecs/request_api_headers

echo "imported:"; find $DEV/kernel-patches $DEV/firmware $DEV/codecs -type f | sed "s#$PORT/##"
