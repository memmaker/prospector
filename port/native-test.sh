#!/bin/sh
# Native headless ASan build + random-key run (RVIP step 1). Same game C as
# the web build (darwin target), gfxlib2 compiled from $FBSRC, our driver
# port/webgfx.c with its native key feeder. Run dir: a copy of data/,
# graphics/, config/ in $OUT/run. Usage:
#   sh port/native-test.sh [keys-file] [random-count] [seed]
set -e
cd "$(dirname "$0")/.."
FBC=${FBC:-$HOME/Games/fbc-tool/freebasic-ng-1.24.4-darwin-aarch64/bin/fbc}
FBSRC=${FBSRC:-$HOME/Games/fbc-tool/fbc}
OUT=${OUT:-${TMPDIR:-/tmp}/prospector-native}
SAN="-fsanitize=address,undefined -fno-sanitize=alignment,shift,signed-integer-overflow -fno-omit-frame-pointer"
mkdir -p "$OUT/gfx" "$OUT/run"
if [ ! -f "$OUT/libgfx.a" ]; then
  for f in "$FBSRC"/src/gfxlib2/*.c; do
    clang -c -O1 -g -w -DHOST_UNIX -DHOST_DARWIN -I"$FBSRC/src/rtlib" -I"$FBSRC/src/gfxlib2" "$f" -o "$OUT/gfx/$(basename "$f" .c).o"
  done
  ar rcs "$OUT/libgfx.a" "$OUT"/gfx/*.o
fi
if [ ! -f "$OUT/prospector" ] || [ -n "$REBUILD" ]; then
  "$FBC" -gen gcc -r -m prospector_nosound -i port prospector_nosound.bas >/dev/null 2>&1 || true
  mv prospector_nosound.c "$OUT/"
  clang -O1 -g -w -fno-strict-aliasing -fwrapv $SAN -I"$FBSRC/src/rtlib" -I"$FBSRC/src/gfxlib2" -DHOST_UNIX -DHOST_DARWIN \
    "$OUT/prospector_nosound.c" port/webgfx.c "$OUT/libgfx.a" \
    "$(dirname "$FBC")/../lib/freebasic/darwin-aarch64/fbrt0.o" "$(dirname "$FBC")/../lib/freebasic/darwin-aarch64/libfb.a" \
    -lz -lncurses -lm -lpthread -o "$OUT/prospector"
fi
cd "$OUT/run"
[ -d data ] || cp -R ~/Games/prospector/data ~/Games/prospector/graphics ~/Games/prospector/config .
RV_KEYS=${1:-/dev/null} RV_RANDOM=${2:-0} RV_SEED=${3:-1} RV_SHOT="$OUT/shot.ppm" \
  ASAN_OPTIONS=detect_leaks=0 UBSAN_OPTIONS=print_stacktrace=1 "$OUT/prospector"
