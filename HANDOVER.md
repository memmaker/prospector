# Prospector: handover

## RVIP progress

### Stage 1 (get + build): done

- **Folder**: `~/Games/prospector` (git, no remote). **Case O** (FreeBASIC
  graphics game with its own UI; worked example O-AlphaMan for the toolchain).
- **Upstream**: Prospector R197 by Matthias Mennel (2008-2014), zlib licence
  (`README.txt`); graphics by David Gervais and Deon, used with permission.
  Language FreeBASIC (`-lang fb`, fbgfx: `SCREENRES w,h,16,2`, two pages,
  `SCREENSET`/`FLIP`, `DRAW STRING` with bitmap fonts from `graphics/font*.bmp`,
  BMP tile sheets, keys via `SCREENEVENT`). No curses, no SDL.
  - Commit `7aba66b` = trunk of the Google Code svn at **r197** (2014-12-28)
    from `https://storage.googleapis.com/google-code-archive-source/v2/code.google.com/rlprospector/source-archive.zip`
    (sha256 c61c8f9e...ab48). The archive is an svn working copy, no history
    (repoType svn, the server is gone), so the snapshot is the first commit.
  - Commit `1b928c0` = data/graphics/config of the author's matching **R197
    Linux release** `R197prospector_l.zip` (web.archive.org copy of
    prospector.at, sha256 125e648d...cf3df). The svn has no data files; the
    Google Code downloads stop at 0.2.4 (2012), too old for R197.
  - `doc/Manual.pdf`: the Google Code manual (2011, 22 pages, 5.6 MB),
    https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/rlprospector/Manual.pdf
    (for stages 6 docs/help and 8 shrine). `Manual.pdf` in the root is the
    shorter 2014 manual from the R197 release (newer).
  - Main file: `prospector_nosound.bas` (includes `main.bas`, which includes
    everything). Sources are CRLF; edit with byte-exact tools.
- **Web frontend**: `port/webgfx.c` = our FreeBASIC gfxlib2 driver (replaces
  gfxlib2/js, which needs SDL1): `rv_frame(page)` converts the 16-bit
  framebuffer's dirty lines to RGBA for the canvas (page >= 0: that page, for
  tests), `rv_key(scancode, ascii)` posts FB key events + INKEY codes.
  `port/fbdir.c` = DIR$ (the js rtlib's is a stub; the savegame list uses it).
  `port/fbstub.js` stubs the unused termlib console. Page: `web/index.html`,
  `web/prospector.js` (AlphaMan template, loads `rvip-wm.js`; stage 5 adds the
  windows).
- **Build**: `sh web/build.sh` → `web/dist`. `fbc -gen gcc -r -target js-asmjs
  -m prospector_nosound -i port` → C, `emcc -O2 -fwrapv -fno-strict-aliasing`,
  link with `libfbgfx.a libfb.a` from `~/Games/fbc-tool/fbc/lib/freebasic/js-wasm32`
  (`make rtlib gfxlib2 TARGET=wasm32-unknown-emscripten` there; gfxlib2 was
  built for this game) and `-sUSE_ZLIB -sASYNCIFY -sASYNCIFY_STACK_SIZE=524288
  -sSTACK_SIZE=8MB -sALLOW_MEMORY_GROWTH -sINITIAL_MEMORY=400MB -sEXIT_RUNTIME=1
  -sENVIRONMENT=web -lidbfs.js -sFORCE_FILESYSTEM`, `--preload-file` of
  data/graphics/config at `/pack`. Zero wasm-ld warnings.
- **Files in the browser**: the game runs in `/prospector` (cwd). `data/`,
  `graphics/` hold symlinks into `/pack`; `savegames`, `config`, `bones`,
  `summary` are four IDBFS mounts (IndexedDB names `/prospector/<dir>`);
  `data/highscore.dat` links to `savegames/highscore.dat`. No symlinked
  *folders*: the game does `CHDIR "savegames"` / `CHDIR ".."`, and `..` of a
  symlinked folder is the target's parent.
- **Quirks found / fixed** (commit `5cd6726`, all needed for current fbc):
  STRING*N is now space-padded without terminator (FB 1.20+); the game
  expects the old null-terminated N+1 layout, which broke every key binding
  compare (`S` never saved), menu letters, savegame names and hung every new
  game (`gen_shop` waits for `desig<>""`) → all `STRING*N` became
  `ZSTRING*(N+1)`. Blenders `UInteger`→`ULong`; `"&18+x"` lexes as a number;
  `SELECT CASE AS CONST` and `ON ERROR GOTO` compile to computed gotos (not in
  wasm) → plain SELECT, ON ERROR off on `__FB_JS__`; ImageInfo depth `Long`;
  missing `version.bas` (`port/version.bas`); case/backslash in two data paths.
  Wasm: 1 MB stack overflowed (FB locals are big arrays, e.g. `textbox` has
  `words(6023) as string`; KEYIN→CREW_MENU→GET_ITEM→KEYIN recursion) and
  corrupted the heap → 8 MB like native. The static data is 342 MB
  (`planets(4096)` alone 260 MB), hence INITIAL_MEMORY=400MB.
- **ASan**: native headless build `sh port/native-test.sh <keys> <n> <seed>`
  (darwin fbc, gfxlib2 compiled from source, our driver with a key feeder:
  `RV_KEYS` script then `RV_RANDOM` random keys, `RV_SHOT` PPM). 3 × 3000
  random keys from a new game, then save (`S y`) → new process → load: one
  global overflow found and fixed (commit `f7df7fd`, `port: fix an ASan
  global overflow in display_awayteam`). Plus a wasm ASan build (`EXTRA_CFLAGS=
  "-fsanitize=address" EXTRA_LDFLAGS="-fsanitize=address" INITIAL_MEMORY=1400MB
  STACK_SIZE=32MB sh web/build.sh`) with about 1500 random keys in the browser:
  found the stack overflow above, then clean. UBSan (native only) reports
  three float→int conversions (NaN in `makemonster` when gravity is 0,
  `numfromstr` of long digit strings, 64-bit palette in `set__color`); benign
  in wasm (saturating conversions), left alone.
- **Browser test**: new game → first screen → ~1000 random keys without
  console errors → `S`, `y` (saves and quits, "Till next time!") → reload →
  Load game → restored (same ship, fuel, map comment). Loading deletes the
  save (roguelike, upstream).
- **Tiles**: the game ships its own set (Gervais + Deon sprites, 24×24, sheets
  in `graphics/*.bmp`, loaded by `load_tiles` in `fileIO.bas` into
  `gtiles()` via `gt_no(tile number)`), on by default (`config.txt`
  `tiles:0`, ASCII mode is the game's own option). Coverage: 276 of the 277
  distinct tile numbers the source assigns (`ti_no=<literal>`) have a sprite
  (99.6 %; the missing one is `ti_no=0` in `monster.bas:489`); 1080 tile
  numbers loaded. **Decision: own set.**
- **Open problems**: the page draws via requestAnimationFrame (no drawing in a
  hidden tab; tests read `Module._rv_frame` themselves); memory 400 MB
  (could shrink `max_maps`); `web/index.html` is still the one-canvas stage-1
  page (windows are stage 5); sound (`prospector_nosound`) not built.

Next: **stage 2 (explore + stairs)**. What stage 2 needs:
- Main loops in `main.bas`: `explore_space()` (line ~1078, space map, keys
  read by `keyin(allowed)` in `kbinput.bas`, which also handles global keys)
  and `explore_planet(from, orbit)` (~1604, planet surface / ship interiors /
  stations); key reading is always `keyin()` (SCREENEVENT loop).
- Map data: space `spacemap(x,y)` (size `sm_x`×`sm_y`, set at new game) with
  `map()` stars and `basis()` stations; planet surfaces `planetmap(x,y,slot)`
  61×21 per planet (negative = not yet seen: `abs()` is the tile, sign is the
  known flag), tile info `tiles()`/`tmap(x,y)`; the away team is `awayteam`
  (`.c` position), the landed ship `player.landed`.
- The game already has **auto-explore on planets**: `key_autoexplore` = `#`
  (`ep_autoexplore` / `ep_autoexploreroute` in `exploreplanet.bas`, A* in
  `astar.bas`); stage 2 checks it against RVIP step 2 (stops on monsters /
  messages / keys, known-grid BFS, doors) rather than writing a new one. In
  space the logbook autopilot exists (`L`, pick a star, `w`).
- "Stairs" = level changes (manual p. "Commands"): in space `l` lands on a
  planet / enters a wormhole (at a star `s` scans, Ctrl-L target landing),
  `d` docks at a station; on a surface `l` launches when standing at the ship,
  `>` / `<` (`key_portal`) use stairs, tunnels and portals (also `i`nspect),
  `r` radios the ship. So `<`/`>` on a surface: walk to the nearest known
  stairs/portal/tunnel and take it; the useful extra is "walk to ship"
  (then `l` launches), and in space "walk to nearest known station/planet".
- Keys (manual): `@` ship status, `A` crew roster, `T` tactics, `q` quit
  without saving, `S` save and quit, `?` help menu (manual, keybindings,
  configuration), `L` logbook, numpad/arrows move (`5` wait), `w` walk,
  `f` fire, `g` grenade, `h` medpack, `j` jump pack, `x` examine,
  `c` comment/communicate, `,` pick up, `d` drop/dock, `o` offer, `O` oxygen,
  `C` close door, `E` equipment, `t` tow. Rebindable in `config/keybindings.txt`.
