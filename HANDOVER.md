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

### Stage 2 (explore + stairs): done

- **Explore key**: the game's own `#` (`key_autoexplore`, rebindable in
  `config/keybindings.txt`; not in either manual, but in the in-game command
  list) plus `~` as a fixed RVIP alias (mapped to `key_autoexplore` right after
  `keyin` in both loops). `<` / `>` are fixed keys (`<` = `key_portal`).
  The command list (`comstr`) on planets now shows `< > stairs/ship`.
- **Code** (all BASIC, no JS):
  - `exploreplanet.bas`: `ep_autoexploreroute` (rover=0) now floods only over
    *seen* cells (`planetmap<0` = unseen blocks the flood) and targets unseen
    passable cells bordering that area (`ep_rvfrontier`); `ep_planetroute`
    takes an optional `slot` and costs unseen cells 1500 (except the target);
    nothing left + ship on another map → -1 (no bogus route). New
    `ep_rvstairs(slot,key,nextmap)`: nearest known portal end on this map
    (`portal().discovered=1`, from/dest) → walk (`walking=13`) and take it on
    arrival (`rv_pend=key_portal`, the game's own Enter y/n prompt); none known:
    `<` walks to the ship (`player.landed`) and launches there (`rv_pend=key_la`,
    `ep_launch`), at the ship it launches at once; `>` says "No known way down".
    `ep_atship` keeps walking 12/13 across its routine messages.
  - `main.bas` `explore_planet` walking block: `walking=12` (explore, re-plans
    at path end) and `walking=13` (fixed path; on the last step `Key=rv_pend`,
    handled later in the same turn by the normal `key_portal`/`key_la` code).
    Hook: `If (Key=key_portal Or Key=">") And portalindex.index(x,y,1)=0 Then
    ep_rvstairs`; `>` on a portal also calls `ep_portal`. Terrain descriptions
    are not printed during walks 12/13.
  - `main.bas` `explore_space`: after `move_ship`: `#`/`~` →
    `rv_spacewalk(0)`, `>` → `rv_spacewalk(1)`, `<` explains. `rv_spacewalk`
    (`logbook2.bas`): 0 = nearest seen, unvisited system/wormhole
    (`map().discovered=1`), 1 = nearest known system, station (`basis`) or
    small station/derelict (`drifting().p>0`); route with the logbook
    autopilot (`ap_astar`, `walking=10`); on arrival `rv_spend` (land `l` /
    dock `d`) is run (landing still asks which planet). Standing on it: runs
    it at once. A pirate/alien fleet (`fleet(a)`, a>5, ty not 1/3) within 1.5
    stops the autopilot.
  - Stop rules: `dprint` (ProsIO.bas) stops walks 12/13 on a new message
    (repeats "(xN)" do not stop); a visible awake hostile (`aggr=0`) stops
    them only within 6 cells (`display_awayteam`, ProsIO.bas; open planets
    show monsters far away); any key stops (keyin); oxygen/jetpack alerts stop
    (texts.bas `alerts`, the game's own).
- **"Known grid" test**: `planetmap(x,y,slot)<0` = not yet seen (abs = tile).
  Passability of the one unseen target cell is read from `tmap` (small leak:
  explore never heads into an unseen wall).
- **Tested** (web build, own tab, frame read via `Module._rv_frame` and POSTed
  to `rvip-tools/shotsrv.py` because the shared pane was hidden; `setTimeout`
  ≤ 20 ms routed through a `MessageChannel`): new game; space `>` walked back
  to the small station and docked; `#` in the station interior; `<` walked to
  the airlock and launched; space `#` flew to an unvisited white giant
  ("Target reached"); `>` there opened the landing menu; on a dark rogue planet
  (visibility 0) `#` × 4 explored the ice field, picked up iron, stopped on
  messages and on the oxygen alert; `<` walked back to the ship and launched.
  Native ASan (`port/native-test.sh`, pool now has `#<>~`): 3 × 3000 random
  keys + a scripted `> # ~ <` run, no ASan errors (only the 3 known UBSan
  float→int conversions).
- **Open problems**: portal/stairs walk (`walking=13` to a portal) not seen in
  a game (no portal found in the tests; same code path as the ship walk).
  Stepping on a station shop tile during explore opens that shop (game
  behaviour). With `con_sound=2` the alerts wait for Space/Enter (a hidden
  `--More--`; stage 3d/auto_more should check `configflag(con_sound)`).
  Hidden browser-pane tab: rAF stops, so the page shows nothing; tests must
  read the frame themselves.

Next: **stage 3 (Enter menu + inventory)**. What stage 3 needs:
- Keys are read only by `keyin(allowed, walking)` in `kbinput.bas` (SCREENEVENT
  loop; global keys handled there: keybindings, HP display, autoinspect;
  `allowed` filters per screen). Dispatch is by `If Key=key_xxx` chains in
  `main.bas` `explore_space` (~l.1120-1460) and `explore_planet` (~l.2440-2560).
  A command can be started from code by setting `Key` before those chains
  (as `rv_pend` / `rv_spend` do) or by posting a key (`rv_key` in
  `port/webgfx.c`, `fb_hPostKey`).
- The game's own menus: `menu(bg, "Title/a/b/...")` (ProsIO.bas), `textbox`,
  `askyn`, `get_item(type)` (item picker), `showteam` (`A`), `@` ship status,
  `E` equipment, `L` logbook, `?` help menu (manual, keybindings,
  configuration). Key names/defaults: `types.bas` ~l.140-215, saved by
  `fileIO.bas` (`key_* = ` lines).
- Manual command lists: `Manual.pdf` (root, 2014) lines ~500-560 of its text
  ("> - use stairs/tunnel ..."), `doc/Manual.pdf` ~l.600-660 (markitdown).
