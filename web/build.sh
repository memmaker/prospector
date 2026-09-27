#!/bin/sh
# Web build: FreeBASIC turns the game into C (fbc -gen gcc -r), Emscripten
# builds it with FreeBASIC's runtime and gfxlib2, our own gfx driver
# (port/webgfx.c: framebuffer -> RGBA -> canvas, keys from JS). Needs:
#   FBC   = fbc 1.10+ (FreeBASIC-NG darwin build works)
#   FBSRC = clone of github.com/freebasic/fbc where
#           `make rtlib gfxlib2 TARGET=wasm32-unknown-emscripten` was run
#   emcc on the PATH
# Output: web/dist (index.html, prospector.js, prospector-core.js/.wasm/.data)
set -e
cd "$(dirname "$0")/.."
FBC=${FBC:-$HOME/Games/fbc-tool/freebasic-ng-1.24.4-darwin-aarch64/bin/fbc}
FBSRC=${FBSRC:-$HOME/Games/fbc-tool/fbc}
LIB="$FBSRC/lib/freebasic/js-wasm32"
CFLAGS="-O2 -w -fno-strict-aliasing -fwrapv -I$FBSRC/src/rtlib -I$FBSRC/src/gfxlib2 $EXTRA_CFLAGS"
mkdir -p web/build web/dist
"$FBC" -gen gcc -r -target js-asmjs -m prospector_nosound -i port -maxerr 30 prospector_nosound.bas 2>&1 | grep -v 'warning 36' || true
test -s prospector_nosound.c
mv prospector_nosound.c web/build/
emcc $CFLAGS -c web/build/prospector_nosound.c -o web/build/game.o
emcc $CFLAGS -c port/webgfx.c -o web/build/webgfx.o
emcc $CFLAGS -c port/fbdir.c -o web/build/fbdir.o
# game data: read-only in /prospector; the player's files (savegames,
# config, bones, summary, highscore) in IndexedDB, see web/prospector.js
rm -rf web/build/pack && mkdir -p web/build/pack/graphics
cp -R data config web/build/pack/
cp graphics/*.bmp graphics/*header web/build/pack/graphics/
emcc $CFLAGS web/build/game.o web/build/webgfx.o web/build/fbdir.o "$LIB/libfbgfx.a" "$LIB/libfb.a" \
  -sUSE_ZLIB -sASYNCIFY -sASYNCIFY_STACK_SIZE=524288 -sSTACK_SIZE=${STACK_SIZE:-8MB} \
  -sALLOW_MEMORY_GROWTH -sINITIAL_MEMORY=${INITIAL_MEMORY:-128MB} -sMAXIMUM_MEMORY=${MAXIMUM_MEMORY:-1GB} -sENVIRONMENT=web \
  -lidbfs.js -sFORCE_FILESYSTEM \
  -sEXPORTED_RUNTIME_METHODS=FS,IDBFS,HEAPU8,HEAP32,addRunDependency,removeRunDependency \
  -sEXPORTED_FUNCTIONS=_main,_rv_frame,_rv_key,_rv_layout \
  --pre-js port/fbstub.js --preload-file web/build/pack@/pack \
  $EXTRA_LDFLAGS -o web/dist/prospector-core.js
python3 web/make-help.py > web/dist/help.html
cp web/index.html web/prospector.js web/dist/
rm -rf web/dist/sound && mkdir web/dist/sound && cp data/*.wav web/dist/sound/
cp Manual.pdf web/dist/Manual.pdf
