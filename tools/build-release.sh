#!/bin/bash
# Images meant to be shared: no GApps / Widevine (WITH_GAPPS=false), full CPU/GPU clocks
# (needs a 5 V / 3 A supply), compressed SD card image + checksums.
# Usage: bash tools/build-release.sh <opi4|opi4_tv> <userdebug|user> [name]
#   opi4 userdebug   -> "tablet" image, adb root for tinkering
#   opi4_tv user     -> TV release image, no root, SELinux enforcing
# Output: /mnt/f/OrangePi4/release/<name>.img.xz (+ .sha256), log: ~/opi4/logs/release-<name>.log
set -o pipefail
P=${1:?product}; V=${2:?variant}
NAME=${3:-opi4-android16-${P#opi4_}-$(date +%Y%m%d)}
[ "$P" = opi4 ] && NAME=${3:-opi4-android16-tablet-$(date +%Y%m%d)}
DEST=${RELEASE_DIR:-/mnt/f/OrangePi4/release}
mkdir -p ~/opi4/logs "$DEST"
LOG=~/opi4/logs/release-$NAME.log
{
  export PATH=$HOME/opi4/hosttools/bin:$HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  (cd ~/opi4/opi4-android && ./setup.sh device) || exit 1   # device/opi4 is copied into the tree
  cd ${AOSP:-$HOME/aosp}
  . build/envsetup.sh >/dev/null
  lunch $P-trunk_staging-$V || exit 1
  export WITH_GAPPS=false OPI4_FULL_CLOCKS=true
  # 'user' images are signed with our own keys (never with the public AOSP test keys)
  if [ "$V" = user ]; then
    export OPI4_RELEASE_KEYS=${OPI4_RELEASE_KEYS:-$HOME/opi4/keys}
    [ -f $OPI4_RELEASE_KEYS/platform.pk8 ] || { echo "== no release keys in $OPI4_RELEASE_KEYS"; exit 1; }
  fi
  echo "== $(date) $NAME: $TARGET_PRODUCT-$TARGET_BUILD_VARIANT WITH_GAPPS=$WITH_GAPPS FULL_CLOCKS=$OPI4_FULL_CLOCKS"
  m installclean && time m && time m images && time m sdcard || { echo "== BUILD FAILED"; exit 1; }
  # nothing proprietary may end up in a shared image
  if find $OUT/system $OUT/product $OUT/system_ext $OUT/vendor -iname '*gms*' -o -iname '*gsf*' \
       -o -iname 'Phonesky*' -o -iname 'com.google.android.widevine*' 2>/dev/null | grep -q .; then
    echo "== PROPRIETARY FILES FOUND, refusing to package"; exit 1
  fi
  xz -T0 -6 -c $OUT/sdcard.img > "$DEST/$NAME.img.xz"
  (cd "$DEST" && sha256sum "$NAME.img.xz" > "$NAME.img.xz.sha256")
  ls -la "$DEST/$NAME".img.xz*
  echo "== $(date) done"
} > $LOG 2>&1
rc=$?
tail -6 $LOG
exit $rc
