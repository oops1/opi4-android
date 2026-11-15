#!/bin/bash
# Patch the freshly built init_boot.img with Magisk (root for apps on the dev build).
# Usage: tools/magisk-patch.sh /path/to/Magisk-vXX.apk [init_boot.img] [out.img]
# Uses Magisk's own boot_patch.sh + x86_64 magiskboot from the APK. PREINITDEVICE is
# normally probed on the device; on this board it is the metadata partition.
# Never use this for the opi4_tv product (no root there).
set -e
APK=${1:?Magisk APK}
IN=${2:-$OUT/init_boot.img}
DST=${3:-$(dirname $IN)/init_boot-magisk.img}
W=$(mktemp -d)
trap 'rm -rf $W' EXIT
unzip -q "$APK" -d $W/apk
mkdir $W/p && cd $W/p
cp ../apk/assets/boot_patch.sh ../apk/assets/util_functions.sh .
cp ../apk/lib/x86_64/libmagiskboot.so magiskboot && chmod +x magiskboot
cp ../apk/lib/arm64-v8a/libmagiskinit.so magiskinit
cp ../apk/lib/arm64-v8a/libmagisk.so magisk
cp ../apk/lib/arm64-v8a/libinit-ld.so init-ld
cp "$IN" init_boot.img
BOOTMODE=false KEEPVERITY=true KEEPFORCEENCRYPT=true PATCHVBMETAFLAG=false \
RECOVERYMODE=false PREINITDEVICE=metadata sh ./boot_patch.sh init_boot.img 2>/dev/null >/dev/null || true
[ -s new-boot.img ] || { echo "patching failed"; exit 1; }
./magiskboot unpack new-boot.img >/dev/null 2>&1
./magiskboot cpio ramdisk.cpio "exists overlay.d/sbin/magisk.xz" || { echo "no magisk in ramdisk"; exit 1; }
cp new-boot.img "$DST"
echo "$DST"
