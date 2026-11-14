#!/bin/bash -e
# Prepares an AOSP 16 tree (android-16.0.0_r4) for the Orange Pi 4 build.
#
#   ./setup.sh manifest   - install the local manifest (then run: cd ~/aosp && repo sync -c -j8)
#   ./setup.sh tree       - after the sync: link device/kernel, apply GloDroid a-16 + our patches
#   ./setup.sh device     - copy device/opi4 into the tree again (after editing it here)
#
# The device dir is copied, not symlinked: soong's file finder does not follow symlinks,
# so a symlinked AndroidProducts.mk is invisible to lunch.
#
# Env: AOSP=~/aosp  SRC=~/opi4 (holds linux/, glodroid-a16/)
PORT=$(cd "$(dirname "$0")" && pwd)
AOSP=${AOSP:-$HOME/aosp}
SRC=${SRC:-$HOME/opi4}

sync_device() {
    mkdir -p $AOSP/vendor/devices-community
    [ -L $AOSP/vendor/devices-community/opi4 ] && rm $AOSP/vendor/devices-community/opi4
    rsync -a --delete $PORT/device/opi4/ $AOSP/vendor/devices-community/opi4/
    echo "device/opi4 -> $AOSP/vendor/devices-community/opi4"
}

case "$1" in
device)
    sync_device
    ;;
manifest)
    mkdir -p $AOSP/.repo/local_manifests
    cp $PORT/manifests/opi4.xml $AOSP/.repo/local_manifests/opi4.xml
    echo "Local manifest installed. Now run:  cd $AOSP && repo sync -c -j8 --no-tags"
    ;;
tree)
    [ -d $AOSP/glodroid/configuration ] || { echo "glodroid/ not synced yet: run '$0 manifest' and repo sync first"; exit 1; }

    echo "== device and kernel"
    sync_device
    ln -sfn $SRC/linux $AOSP/glodroid/kernel/mainline 2>/dev/null || { mkdir -p $AOSP/glodroid/kernel; ln -sfn $SRC/linux $AOSP/glodroid/kernel/mainline; }

    apply_dir() {   # $1 = patches root, $2 = project dir relative to AOSP
        local proj=$AOSP/$2
        echo "-- $2"
        (cd $proj && repo sync -l . >/dev/null 2>&1 || true)
        (cd $proj && git am -q --committer-date-is-author-date $1/$2/*.patch) || {
            echo "!! failed to apply patches to $2"; (cd $proj && git am --abort || true); exit 1; }
    }
    for root in $SRC/glodroid-a16/patches-aosp $PORT/patches-aosp; do
        [ -d $root ] || continue
        echo "== applying $(basename $(dirname $root))/patches-aosp"
        for d in $(cd $root && find . -name '*.patch' | xargs -n1 dirname | sed 's#^\./##' | sort -u); do
            apply_dir $root $d
        done
    done
    # same trick as GloDroid unfold_aosp.sh: avoid a full rebuild after the libcxx patch
    touch -c -t 200101010101 $AOSP/external/libcxx/include/chrono
    echo "Done. Build: cd $AOSP && . build/envsetup.sh && lunch opi4-trunk_staging-userdebug && make images"
    ;;
*)
    sed -n '2,8p' "$0"; exit 1 ;;
esac
