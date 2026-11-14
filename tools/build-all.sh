#!/bin/bash
# Full Android build + flashable images (same steps as GloDroid build.sh).
# Usage: bash tools/build-all.sh [opi4|opi4_tv]   log: ~/opi4/logs/build-all-<product>.log
P=${1:-opi4}
mkdir -p ~/opi4/logs
LOG=~/opi4/logs/build-all-$P.log
{
  . ~/opi4/opi4-android/tools/env.sh $P >/dev/null
  echo "== $(date) full build of $TARGET_PRODUCT"
  time m
  rc=$?; echo "== m exit $rc"
  if [ $rc -eq 0 ]; then
    time m images && time m sdcard
    rc=$?; echo "== images/sdcard exit $rc"
  fi
  ls -la $OUT/*.img $OUT/images.tar.gz 2>&1
  echo "== $(date) done, exit $rc"
} > $LOG 2>&1
tail -25 $LOG
