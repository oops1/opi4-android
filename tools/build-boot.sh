#!/bin/bash
# Builds only the platform parts (kernel + DTB, U-Boot/ATF, boot script env) for a quick check.
# Usage: tools/build-boot.sh [opi4|opi4_tv]   log: ~/opi4/logs/build-boot.log
mkdir -p ~/opi4/logs
LOG=~/opi4/logs/build-boot.log
{
  . ~/opi4/opi4-android/tools/env.sh ${1:-opi4} >/dev/null
  echo "== $(date) building platform parts for $TARGET_PRODUCT"
  time m $OUT/kernel $OUT/dtb.img $OUT/bootloader-sd.img $OUT/bootloader-emmc.img $OUT/env.img
  echo "== exit $?"
  ls -la $OUT/kernel $OUT/dtb.img $OUT/bootloader-*.img $OUT/env.img 2>&1
} > $LOG 2>&1
tail -5 $LOG
