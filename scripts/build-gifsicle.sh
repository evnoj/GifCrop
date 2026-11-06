#!/bin/zsh
# Builds a universal (arm64 + x86_64) gifsicle binary into build/gifsicle.
set -euo pipefail

VERSION=1.98
ROOT=${0:A:h:h}
BUILD="$ROOT/build"
SRC="$BUILD/gifsicle-$VERSION"
OUT="$BUILD/gifsicle"

if [[ -x "$OUT" ]]; then
  exit 0
fi

mkdir -p "$BUILD"
if [[ ! -d "$SRC" ]]; then
  curl -fsSL "https://www.lcdf.org/gifsicle/gifsicle-$VERSION.tar.gz" | tar -xz -C "$BUILD"
fi

cd "$SRC"
./configure --disable-gifview --disable-gifdiff \
  CFLAGS="-O2 -arch arm64 -arch x86_64 -mmacosx-version-min=12.0" >/dev/null
make -j"$(sysctl -n hw.ncpu)" >/dev/null
cp src/gifsicle "$OUT"
