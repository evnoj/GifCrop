#!/bin/zsh
# Builds build/GifCrop.app with gifsicle bundled inside.
set -euo pipefail

ROOT=${0:A:h:h}
cd "$ROOT"

./scripts/build-gifsicle.sh

SWIFT_FLAGS=(-c release --arch arm64 --arch x86_64)
swift build "${SWIFT_FLAGS[@]}"
BIN=$(swift build "${SWIFT_FLAGS[@]}" --show-bin-path)

APP=build/GifCrop.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Support/Info.plist "$APP/Contents/"
cp "$BIN/GifCrop" build/gifsicle "$APP/Contents/MacOS/"

ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size Support/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) Support/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP/Contents/MacOS/gifsicle"
codesign --force --sign - "$APP"

echo "$ROOT/$APP"
