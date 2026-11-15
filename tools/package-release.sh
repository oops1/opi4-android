#!/bin/bash
# Package the images of the last build ($OUT) for publication:
#   <name>-sdcard.img.xz   SD card image (balenaEtcher / Rufus / dd)
#   <name>-emmc.zip        eMMC install kit: deploy SD image + partition images + flash-all.sh/.bat
# Usage: bash tools/package-release.sh <name> [out dir]   (after tools/build-release.sh)
set -e
NAME=${1:?name}
OUT=${2:-$HOME/aosp/out/target/product/opi4}
DEST=${RELEASE_DIR:-/mnt/f/OrangePi4/release}
PORT=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$DEST"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

xz -T0 -6 -c "$OUT/sdcard.img" > "$DEST/$NAME-sdcard.img.xz"

mkdir "$T/$NAME-emmc"
tar -xzf "$OUT/images.tar.gz" -C "$T/$NAME-emmc"
# GloDroid's tarball may nest the files in a directory: flatten
inner=$(find "$T/$NAME-emmc" -name super.img -printf '%h\n' | head -1)
[ "$inner" != "$T/$NAME-emmc" ] && mv "$inner"/* "$T/$NAME-emmc/" && rmdir -p --ignore-fail-on-non-empty "$inner" 2>/dev/null || true
for f in deploy-sd-for-emmc.img deploy-gpt.img bootloader-emmc.img env.img boot.img init_boot.img \
         vendor_boot.img vbmeta.img vbmeta_system.img super.img; do
    [ -f "$T/$NAME-emmc/$f" ] || cp "$OUT/$f" "$T/$NAME-emmc/"
done
[ -f "$T/$NAME-emmc/flash-all.sh" ] || sed 's/__SUFFIX__/-emmc/g' \
    "$HOME/aosp/glodroid/configuration/platform/tools/flash-all.sh" > "$T/$NAME-emmc/flash-all.sh"
chmod +x "$T/$NAME-emmc/flash-all.sh"
cp "$PORT/device/opi4/release/flash-all.bat" "$T/$NAME-emmc/"
cp "$PORT/docs/INSTALL.ru.md" "$T/$NAME-emmc/"
rm -f "$T/$NAME-emmc/"fastboot* "$T/$NAME-emmc/"adb* 2>/dev/null || true   # users bring their own platform-tools
(cd "$T" && rm -f "$DEST/$NAME-emmc.zip" && zip -qr -1 "$DEST/$NAME-emmc.zip" "$NAME-emmc")

cd "$DEST"
sha256sum "$NAME-sdcard.img.xz" "$NAME-emmc.zip" > "$NAME.sha256"
ls -la "$NAME"*
