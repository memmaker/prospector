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

### Stage 3 (Enter menu + inventory): done

- **Files**: `kbinput.bas` (all new code at the end: `rv_cmdmenu`,
  `rv_itemmenu`, helpers `rv_cmdadd`, `rv_cmdkey`, `rv_kname`; hooks in
  `keyin`), `items.bas` (`get_item` / `findbest` take a preselected item),
  `main.bas` (two lines: `rv_menumode=1/2` before the space and planet
  `keyin(allowed,walking)`), `types.bas` (shared `rv_menumode`, `rv_preitem`,
  `rv_prenum`; declares; `menu()` got an optional last param `pick`),
  `ProsIO.bas` + `texts.bas` (3d), `port/webgfx.c` (native key pool has
  `E` and more Enter).
- **Enter menu**: the main loops set `rv_menumode` (1 space, 2 planet
  surface/ship/station interior) right before their `keyin`; `keyin` copies it
  and clears it (nested `keyin` calls in menus see 0). Enter at that prompt →
  `rv_cmdmenu(allowed,mode)`: the game's own `menu()` with groups (Move and
  explore / Actions / Ship and crew / Game), then the group's commands with
  their keys. Entries come from a fixed table filtered by the prompt's
  `allowed` string (so the menu shows what the prompt accepts), plus the global
  keys `keyin` handles itself (@ A E T L Q ^s ^a m ? = I P ^h). Includes
  `#`/`~`, `<`, `>`. The chosen key is put back into `keyin` as if typed
  (global handlers, `allowed` filter, then the caller's `If Key=` chains).
  Cursor + Enter, or the letter (`menu(...,pick=1)`: letter chooses at once);
  Esc in a group goes back to the groups, Esc there closes (returns "").
- **Item actions**: `E` (`key_equipment`, handled in `keyin`) uses the game's
  own cursor list `get_item(,,num)`; Enter on an item → `rv_itemmenu(i,num,mode)`
  (the game's `menu()`), actions by item type and place: planet/station:
  `h` use (medpack, ty 11), `g` throw (grenade, ty 7), `D` drop; space: `D`
  launch (probe, ty 55); weapons/armor (ty 2-4): assign to a crew member (opens
  the roster `showteam`, its `s set item` takes the item); always `x` examine
  (`ldesc`). Run by **key queue**: the menu sets `rv_preitem`/`rv_prenum` and
  returns the key from `keyin`, so the game's own handler runs;
  `get_item` returns `rv_preitem` (if the type fits) and `findbest` does too
  for types 7/11 only (display code calls findbest for other types). Cleared
  at the next main prompt. Outside the main prompts (`mode` 0) only examine and
  assign.
- **3d**: the 8 `con_sound=2` alert waits (`keyin(" "&Enter&Esc)` after "Fuel
  low", oxygen, jetpack… in ProsIO.bas/texts.bas) are removed in all builds;
  the message stays in the log (`m`).
- **Tested** (web build, own tab, frame POSTed to shotsrv): space Enter menu
  (groups, letter pick `b` → `i` dock), station interior Enter menu (cursor
  pick Actions), planet (letter/ cursor pick `#` autoexplore, landed via menu
  `l`); item menus: medpack use (game's "use your medpack?" with the item
  preselected), drop binoculars in the station and anaesthetics on a planet
  (no item prompt), pick up via the Enter menu, probe launch in space
  ("Which direction?" → "Probe launched"), assign armor via roster `s`
  (preferred `*protective suit`), examine. Native ASan (`E`/Enter in the pool): seed 7 × 3000 random keys found
  the `credits()` overflow below, clean after the fix; seed 11 ran 15 min
  (timeout) without ASan errors.
- **Also fixed**: `credits()` (credits.bas) `z(12)` overflowed with 64-bit
  `Integer` (19 digits) at game end natively → `z(20)`.
- **Open problems**: grenade action not seen in a game (no grenades in the
  test ships; same path as medpack). The planet menus redraw with the game's
  `bg_awayteamtxt` (sidebar only, map hidden while a menu is open), as the
  game's own menus do. Item keys (`h`, `D`) are shown in the item menu but the
  menu reacts to its letters, not those keys. The list does not reopen after an
  action. `dprint`'s own pager (↓ + key when one message is longer than the
  message window) still waits. The sidebar sometimes shows `f attack` when
  `allowed` lacks `f` (fleet index 0; game bug); the menu follows `allowed`.
  Space `C\r` rename key can never be typed (upstream), not in the menu.

Next: **stage 4 (tiles)**. Stage 1 decided: the game's own Gervais/Deon set
(99.6 % coverage: 276 of 277 `ti_no=` literals; the missing one is `ti_no=0`,
`monster.bas:489`), tiles on by default (`config.txt` `tiles:0`), ASCII is the
game's own option. Stage 4 still has to check: nearest-neighbour scaling at
cell size (page `web/prospector.js` scales the canvas by CSS with
`image-rendering: pixelated`; check the sprites at 24 px cells), a tile/text toggle in the page (the game's
`configflag(con_tiles)`), the missing tile 0, the hero/away-team tile. The
blit list: BASIC draws with `put ...,gtiles(gt_no(n))` / `dtile` (ProsIO.bas `dtile`,
ProsIO.bas `display_awayteam`, `display_planetmap`) into the fbgfx page;
`port/webgfx.c` `rv_frame` converts the 16-bit framebuffer to RGBA, JS only
blits it.

### Stage 4 (tiles): done

- **Tile set**: the game's own, by David Gervais and Deon (sprites 24×24, BMP
  sheets in `graphics/*.bmp`, from the author's R197 release `1b928c0`; used
  with the author's permission, `README.txt`). One set only, no fallback.
  Loader: `load_tiles` (`fileIO.bas`) into `gtiles()` via `gt_no(tile no)`;
  drawn by the BASIC blits (`put …gtiles(gt_no(n))`, `dtile`,
  `display_awayteam`, `display_planetmap` in `ProsIO.bas`). No pref files.
- **Coverage**: `sh port/tilecov.sh` (scratch copy whose `load_tiles` dumps the
  loaded numbers, native build) → **285 of 285** tile numbers the source
  assigns (literal `ti_no=<n>` plus the monster fallback `g+1001`) have a
  sprite, **100 %**; 1080 loaded. The stage-1 "missing tile 0" was a false
  hit: `monster.bas:489` is the comparison `if enemy.ti_no=0 then
  enemy.ti_no=g+1001` (1002-1013, all loaded).
- **Scale**: the game blits sprites 1:1 at 24 px cells into its own
  framebuffer; the page `putImageData`s it 1:1 and scales the canvas by whole
  numbers (1-4, Zoom −/+) with `image-rendering: pixelated`: nearest-neighbour
  only. Checked by pixel (4× crops): space (ship, stations, sun, gas cloud,
  system bar), station interior (walls, bar, captain), planet surface (ice,
  rock, ship, captain in spacesuit). Hero = the game's captain sprite
  (`captainsprite` config, red/orange default), looks right.
- **Tiles/Text toggle**: page button `#btn-tiles` (`web/prospector.js`) sends
  `rv_key(120,0)`; `keyin` (`kbinput.bas`) at a main prompt (space / planet /
  station) calls `rv_toggletiles`: flips `configflag(con_tiles)` (the game's own
  ASCII option), sets `_mwx`, `save_config` (config.txt `tiles:` in IndexedDB,
  so it survives reload), `load_fonts` (new `SCREENRES`, as a restart would),
  loads tiles if they never were, `cls`, then `keyin` returns "" and the game
  redraws. Ignored inside menus. The label reads `tiles:` from config.txt.
  Tested: space, station, planet, text→tiles, tiles→text, reload keeps Text.
  Native pool key `` ` `` = the button.
- **Native ASan** (`port/native-test.sh`, pool with `` ` `` = toggle):
  seed 7 × 3000 keys ran 15 min (timeout) without ASan errors. Seed 3 found
  `A_STAR` heap overflow: `L` logbook/autopilot reachable through nested
  `keyin` during new-game setup (captain menus), before the space map exists →
  fixed: `key_logbook` only when `gamerunning=1` (kbinput.bas). Rerun of seed 3
  then hit an upstream `gen_traderoutes` (space.bas) heap overflow in
  `make_spacemap` (random keys likely used "Change mapsize" in the talents
  menu; not fixed, see Open). Web rebuilt after the fix.
- **Open problems**: a toggle costs one game tick in space (as the game's own
  global keys that return ""). Old messages in the log keep the wrap width of
  the mode they were printed in (text mode after tiles shows long lines over the
  sidebar until they scroll off). Monsters/items on a surface not seen in the
  test (none met; same `dtile` path). Space `#` finds nothing until a system is
  in sensor range; station `#` walks toward the vacuum airlocks (asks "walk out
  into the vacuum?"; stage 2 explore should not target airlock exits).
  Random keys (seed 11, 3000) can nest `keyin`→`logbook`→`keyin`… (global keys
  inside nested prompts) until the 8 MB native stack overflows (upstream
  recursion; Enter/L/E in the pool). `gen_traderoutes` writes past `map()` /
  `wpl()` after the talents menu's "Change mapsize" (native seed 3; upstream,
  new-game generation): fix before stage 7.

Next: **stage 5 (web page)**. What stage 5 needs:
- The page is still one canvas (`web/index.html`, `web/prospector.js`, loads
  `rvip-wm.js` but opens no windows). Split into rvip-wm.js windows (Map,
  Messages/log, Status/sidebar, Inventory, pop-ups) fed from the BASIC side,
  as O-Prospector/AlphaMan did: the game draws map, sidebar (`sidebar` x,
  `_mwx`, `_fw1`, `_fh1`) and message window (`dprint`, `_textlines`) into one
  framebuffer; either export the rectangles (C: `rv_frame` + a layout struct
  set from BASIC after `load_fonts`) and cut them into windows, or render text
  windows from BASIC strings. Keep the Tiles/Text button and its config line.
- Memory: 400 MB `INITIAL_MEMORY` (static arrays, `planets(4096)` 260 MB):
  decide on shrinking `max_maps` or keep.
- Death/quit flow: after death the game shows summary + highscore, then exits
  (`restart:1` = off); the page shows its "Prospector has ended" overlay.
- `deploy.sh` from another game's (e.g. `~/Games/alphaman`), target
  `ruzzoli.de/roguelikes/prospector/`; not deployed until stage 7.
- Help button: the Manual `doc/Manual.pdf` (2011) / `Manual.pdf` (2014).

### Stage 5 (web page): done (not deployed, no repo)

- **Windows** (`rvip-wm.js`, loaded from `rvip-tools` by `build.sh`, not forked):
  **Map**, **Messages**, **Status**, **Inventory**, plus a pop-up (`#pop`)
  over the whole game area. The game says which part of its screen is what:
  `keyin` (`kbinput.bas`) calls `rv_webui(rvmode)` on every key poll →
  `rv_regions(mode, (_mwx+1)*_fw1, 22*_fh1, message y, sidebar)` in
  `port/webgfx.c` (read by JS through `_rv_layout`). Mode > 0 (the main
  space/planet/station prompt, `rv_menumode`) → Map = the map part of the
  framebuffer, Status = the sidebar part (x ≥ `sidebar`), both blitted 1:1 and
  scaled by whole numbers; mode 0 (menus, dialogs, questions, title, death
  screens, combat) → the whole screen in the pop-up (fitted, whole numbers when
  ≥ 1). Messages = text from `dprint` (`rv_msg`, the game's colour
  `palette_(col)`, repeats "(xN)" replace the last line, `\C` → `Ctrl-`).
  Inventory = text from `get_item_list` at main prompts (`rv_inv`), headlines
  white, items coloured by category (`check_item_filter`, Angband-style:
  weapons grey, armour umber, medical blue, grenades red, artwork violet,
  resources yellow, equipment cyan; the game's own list has one colour). One
  window mode = Map only, showing the whole screen as before. A−/A+ on Map =
  zoom, on Status = its scale, on Messages/Inventory = font.
- **Layout file**: `/prospector/config/web-layout.json` (IDBFS
  `/prospector/config`): `{scale (0 = auto fit), sscale, font, wm}`; replaces
  stage 1's `web-zoom.json`. Tested: hidden Inventory survived a reload.
- **Memory**: kept `INITIAL_MEMORY=400MB`. `max_maps=4096` (`planets()` 260 MB,
  `_planet` ≈ 63 KB) is the headroom for the largest "Change mapsize" sector
  (150 stars + 20 wormholes, up to 9 planets each, plus event/drifting planets
  that do `lastplanet+=1` without a bound check in 7 places); lowering it could
  overflow on big maps, lazy allocation needs `planets()` dynamic plus `ubound`
  in every `for a=0 to max_maps` loop (7 files). Saves store only
  `0..lastplanet`, so a later change would not break saves.
- **Death / quit flow (W5)**: the game shows its death text, "last messages?",
  mission summary, "save summary?", high scores (Esc), then reaches `End`
  (`config.txt restart:1`); `rv_gameover` (before both `End`s in `main.bas`:
  title "Quit" and after the game) tells the page, which keeps the last screen,
  syncs IndexedDB and on the next key reloads into the title menu (new game /
  load). `rv_gameover` never returns (`emscripten_sleep` loop), no
  `-sEXIT_RUNTIME` any more; `onExit` (error-path `End`s) does the same. Save
  and quit (`S y`) → "Till next time!" → key → same. No-op natively.
- **Bug fixes** (both upstream, found by ASan):
  - `gen_traderoutes` heap overflow: `set_globals` places the three stations
    for the default 75×50 map before the talents menu's "Change mapsize"; a
    narrower map (x < 65) put `basis(2)` outside the new `spacemap`, and
    `gen_traderoutes` wrote past its local `map()`. Fix (`crew.bas`
    `changemap`): recompute `basis(0..2).c` for the new size as `set_globals`
    does. Reproduced natively with keys `{enter}{enter}y{enter}50{enter}50{enter}150{enter}20{enter}b{enter}b{enter}{enter}`, clean after.
  - Nested prompts blowing the stack: `keyin` is now a wrapper counting its
    depth around the old body (`rv_keyin0`); from depth 3 on the global screen
    keys (logbook, E, A, @, ?, m, ...) are ignored (`blocked=1`, the game's own
    switch), so global screens open at most two deep.
  - Native ASan random keys with the fixes: seeds 3 and 11 × 3000 keys, no
    ASan errors (only the 3 known UBSan float→int conversions).
- **Help**: button opens `help.html` (stub: keys to remember, saving, the
  game's `doc/Manual.pdf` embedded + link; `build.sh` copies it to
  `dist/Manual.pdf`); Escape closes, the game gets no keys meanwhile.
  Tiles/Text and Zoom buttons kept (Tiles/Text tested in windows: regions
  follow the new `_mwx`/font sizes).
- **`web/deploy.sh`**: from AlphaMan's plus the step-9 guard, target
  `ruzzoli.de:/var/www/ruzzoli.de/roguelikes/prospector/`. Run once: refused
  ("commit + push first"). **Not deployed, no repo.**
- **Tested** (own tab, hidden pane: frames/canvases POSTed to `shotsrv.py`,
  `setTimeout` ≤ 20 ms via `MessageChannel`, a `resize` event forces a draw):
  new game → space (map, sidebar, inventory, log with "(x2)" fold), station
  interior, landing menu in the pop-up, planet surface; layout survives
  reload; save (`S y`) → key → reload → Load game → same ship/inventory;
  death by boiling water/no oxygen on a planet → summary → high scores → key
  → title; title Quit → key → reload; Help. No console errors.
- **Open problems**: the map window centres the map part, it does not follow
  the ship when the window is smaller than the map part (the game scrolls its
  map itself; at 1024 px width the default split crops ~130 px each side).
  Every non-main prompt (e.g. "Which direction?", `-more-`-like waits after
  docking) switches to the whole-screen pop-up. End of game needs two keys
  (the game's last screen, then the page's). A dead captain's save
  (`NNC - 0001.sav`) stays in the Load list (upstream autosave). No
  `RvipWM.prompt` line (questions are visible in the pop-up instead).
  Ctrl-l conversion in the log not seen in a test (no star in range).

Next: **stage 6 (docs + sound)**. What stage 6 needs:
- Sound: there are no `sound/` or `music/` folders and no music: the game's
  11 effects are `data/*.wav` (alarm_1/2, weap_1..5, wormhole, start, land,
  pain; licence: the game's, `README.txt`), loaded by `load_sounds`
  (`fileIO.bas`) into `sound(n)` (1-12). There is no central play routine:
  about 37 inline pairs `#ifdef _FMODSOUND FSOUND_PlaySound(FSOUND_FREE,
  sound(n))` / `#ifdef _FBSOUND fbs_Play_Wave(sound(n))` (texts.bas,
  exploreplanet.bas, spacecom.bas, main.bas, ProsIO.bas, crew.bas, landing.bas),
  gated by `configflag(con_sound)`; the build defines neither. Add one
  `rv_sound(n)` (C hook like `rv_msg` in `port/webgfx.c`, EM_ASM) next to each
  pair under `#ifdef __FB_JS__` and play `data/*.wav` with `rvip-sound.js`;
  Sound button off by default (no Music button: no music), state in
  `web-layout.json`.
- Docs: a `GAMES` entry in `~/Desktop/Games/Roguelikes/Docs/build-docs.py`
  from `doc/Manual.pdf` (2011, 22 pages) and `Manual.pdf` (2014) plus the
  in-game command list (`?` → Keybindings, `config/keybindings.txt`); mention
  `#`/`~` explore, `<`/`>` walks, Enter menu, `E` items; guide + Tips +
  "In the browser" in `guides.py`; `web/make-help.py` → `dist/help.html`
  (replaces the `web/help.html` stub; keep `Manual.pdf` in dist).
- Credits: Matthias Mennel (game, zlib licence), David Gervais and Deon
  (sprites, used with permission).

### Stage 6 — docs + sound (done)

- **Sound**: the game decides. Each of the 16 `#ifdef _FBSOUND` play blocks
  (texts.bas 6, exploreplanet.bas 3, ProsIO.bas 2, main.bas 2, crew.bas,
  landing.bas, spacecom.bas) got a twin `#ifdef __FB_JS__` block right after it
  with the same conditions (`configflag(con_sound)`, `con_damscream`, range,
  atmosphere) calling `rv_sound(n, _volume)` (declared in `types.bas`).
  `port/webgfx.c` `rv_sound` names the file from the game's `sound()` table
  (`load_sounds`, fileIO.bas: 1 alarm_1 … 12 pain; 6 unused) and calls
  `Module.rvSound(name, vol)`; `web/prospector.js` plays `sound/<name>.wav`
  with the shared `rvip-sound.js` at `min(1, _volume/2)` (fbsound's master
  volume) only if the **Sound** button is on. Button off by default, state in
  `web-layout.json` (`sound`). No music (the game has none), no .cfg (the C
  table names the files). `build.sh` copies `data/*.wav` → `dist/sound/` and
  `rvip-sound.js` from rvip-tools. Native build unchanged (`__FB_JS__` only).
- **Docs**: `~/Desktop/Games/Roguelikes/Docs` (no git there): `build-docs.py`
  GAMES entry `prospector.html` (before Crawl) + `parse_prospector(root)`: the
  complete key list is parsed from the Enter menu table (`rv_cmdadd` lines in
  `kbinput.bas`, space/planet branch) with the default keys of `types.bas`,
  plus space combat keys (58 entries); info About / Tips / In the browser /
  Credits. `guides.py`: GUIDES (first flight, staying alive, getting rich) and
  SAVING. Rebuilt: only `index.html` (new card) and `prospector.html` changed,
  every other page byte-identical.
- **Help**: `web/make-help.py` (LambdaRogue's pattern) → `dist/help.html`
  (replaces the stub `web/help.html`, deleted): about, keys to remember,
  essentials, full list, saving, tips, guide, in the browser, the 2011
  `Manual.pdf` (link + iframe, still `doc/Manual.pdf`), About this version
  (svn r197 + R197 release data, memmaker/prospector link, credits). Help CSS
  copied from LambdaRogue's page.
- **Tested** (own tab, local server, hidden pane: frames POSTed to shotsrv,
  `setTimeout` ≤ 20 ms via `MessageChannel`): fresh load (no IndexedDB) →
  Sound off; real click on Sound → on, saved; new game, flew until the game
  said "Fuel low" → `GET /sound/alarm_2.wav 200` (the game's own alarm
  path); reload → Sound still on; Help shows all 8 sections, 58 keys, the
  manual iframe; no console errors. Test databases `/prospector/*` deleted.
  Native ASan build (`port/native-test.sh`, seed 5, random keys) ran 9 min
  (timeout) without ASan/UBSan reports.
- **Open problems**: sound seen for one site only (fuel alarm); the others use
  the same hook (compiled: 18 calls in the generated C). The game's volume 0
  mutes, the page does no own volume. `Manual.pdf` (2014, root) is newer than
  the shipped 2011 `doc/Manual.pdf`; the key lists in Help are current either
  way. The memmaker/prospector link in Help is dead until stage 7.

Next: **stage 7 (publish)**. What stage 7 needs:
- Repo: `gh repo create memmaker/prospector --public --source . --remote
  memmaker --push` (orchestrator). History is already clean: `7aba66b` = svn
  r197 snapshot (upstream), `1b928c0` = R197 release data, then `port:` /
  `RVIP:` commits.
- README first lines: upstream = Prospector R197 by Matthias Mennel, Google
  Code svn trunk r197 (2014-12-28, archive
  `https://storage.googleapis.com/google-code-archive-source/v2/code.google.com/rlprospector/source-archive.zip`,
  no history, snapshot commit `7aba66b`) + data from `R197prospector_l.zip`
  (web.archive.org copy of prospector.at, commit `1b928c0`); compare view
  `https://github.com/memmaker/prospector/compare/1b928c0...main` (or from
  `7aba66b`). Licence zlib (`README.txt`, keep it; altered source must be
  marked: the README says so). Credits: Matthias Mennel (game), David
  Gervais and Deon (graphics, with permission), FBSound/zlib/cards.bi as in
  `README.txt`.
- W1 base-version text on the card: "Based on Prospector R197 · Google Code
  rlprospector svn r197". Help "About this version" already has it.
- Tree entry: original game (no ancestor), 2008, Matthias Mennel. Card image,
  `og.py`, `deploy.sh` (guard already in `web/deploy.sh`) after the push.
