# Prospector: handover

All RVIP stages 1-9 done. Live: https://ruzzoli.de/roguelikes/prospector/ ·
repo https://github.com/memmaker/prospector (remote `memmaker`) · shrine
https://ruzzoli.de/roguelikes/shrine/prospector.html. **Case O** (FreeBASIC
graphics game with its own UI; see RVIP.md 5.3 / 5.5).

## Upstream

- Prospector R197 by Matthias Mennel (first release 0.1.0, Feb 2009; last R210,
  2018), zlib licence (`README.txt`, keep; `README.md` marks the altered
  source). Graphics by David Gervais and Deon, used with permission.
- `7aba66b` = Google Code svn trunk r197 (2014-12-28, source-archive.zip, no
  history); `1b928c0` = data/graphics/config from the R197 Linux release
  `R197prospector_l.zip` (web.archive.org copy of prospector.at). Compare view
  `compare/1b928c0...main`.
- `Manual.pdf` (root, 1.1, 2014) is shipped in Help; `doc/Manual.pdf` (1.0, 2011).
- Main file `prospector_nosound.bas` (includes `main.bas`, which includes the
  rest). Sources are CRLF: edit byte-exact.

## Build, test, deploy

- `sh web/build.sh` → `web/dist`. fbc `-gen gcc -r -target js-asmjs` → C →
  emcc, linked with `libfbgfx.a libfb.a` from
  `~/Games/fbc-tool/fbc/lib/freebasic/js-wasm32` (`make rtlib gfxlib2
  TARGET=wasm32-unknown-emscripten` there). `-sASYNCIFY`, 8 MB stack (FB locals
  are big arrays; 1 MB overflowed), `INITIAL_MEMORY=128MB` + growth, max 1 GB.
  Loads the shared `../rvip-wm.js`, `rvip-app.js`, `rvip-sound.js`.
  wasm ASan: `EXTRA_CFLAGS=-fsanitize=address EXTRA_LDFLAGS=-fsanitize=address
  INITIAL_MEMORY=1400MB STACK_SIZE=32MB sh web/build.sh`.
- `port/webgfx.c`: our gfxlib2 driver (`rv_frame` framebuffer → RGBA,
  `rv_key`, `rv_regions` layout, `rv_msg`, `rv_sound`, `rv_beacon`,
  `rv_gameover`); `port/fbdir.c` DIR$; `port/fbstub.js`; `port/version.bas`.
- Native headless ASan test: `sh port/native-test.sh <keys> <n> <seed>`
  (key feeder `RV_KEYS`/`RV_RANDOM`, `RV_SHOT` PPM). Tile coverage:
  `sh port/tilecov.sh` (285/285).
- `web/deploy.sh` (target `ruzzoli.de:/var/www/ruzzoli.de/roguelikes/prospector/`,
  refuses uncommitted/unpushed). Help: `web/make-help.py` → `dist/help.html`.
  Docs: `~/Desktop/Games/Roguelikes/Docs` `build-docs.py` (`parse_prospector`
  reads the Enter-menu table in `kbinput.bas`) + `guides.py`.
- Browser files: cwd `/prospector`; `data/`, `graphics/` hold symlinks into the
  `/pack` preload (no symlinked folders: the game does `CHDIR ".."`);
  `savegames`, `config`, `bones`, `summary` are IDBFS mounts (IndexedDB
  `/prospector/<dir>`). Page layout/sound state: `config/web-layout.json`.
  A hidden browser pane stops rAF: tests read `Module._rv_frame` themselves.

## Port changes worth knowing

- FB 1.20+ fixes (`5cd6726`): `STRING*N` → `ZSTRING*(N+1)` everywhere, no
  `SELECT CASE AS CONST` / `ON ERROR GOTO` in wasm.
- Explore `#` (game's own) + `~` alias; flood over seen cells only
  (`ep_autoexploreroute`, `ep_rvfrontier`). `<`/`>` walk to the nearest known
  stairs/portal, ship or station and stop there; pressing again takes it
  (`ep_rvstairs`, `rv_spacewalk` in `logbook2.bas`).
- Enter menu `rv_cmdmenu` / item menu `rv_itemmenu` (`kbinput.bas`), filtered by
  the prompt's `allowed`. `keyin` is a depth-counting wrapper (`rv_keyin0`):
  from depth 3 global screen keys are ignored (stack overflow fix).
- Windows: `rv_webui` → `rv_regions` tells the page which framebuffer part is
  Map / Status; mode 0 screens go to the whole-screen pop-up; one-line
  questions (`rv_onmap`, `Cls` redefined to `rv_cls`) go to `RvipWM.prompt`.
  Map follows the ship. Messages from `dprint`, Inventory from `get_item_list`.
- Tiles button toggles the game's own ASCII option (`rv_toggletiles`,
  config.txt `tiles:`). Sound: a `#ifdef __FB_JS__` `rv_sound` twin after each
  of the 16 `_FBSOUND` blocks; no music.
- `planets()` is sparse (`planet_at(i)`, `#define planets(i) planet_at(i)[0]`,
  `planets_reset`); the `_stars` field is `plnum()`. `rv_nomaps` bounds the 7
  map-adding functions. Saves unchanged.
- Beacon: `death_message()` → `rv_endrun` (98 retired = win, 6 = quit, else
  death); `depth` = discovered systems; no `lvl` in the game.
- Upstream bugs fixed: `display_awayteam` global overflow, `credits()` `z(20)`,
  `gen_traderoutes` after "Change mapsize" (`crew.bas changemap`), `A_STAR`
  overflow (`key_logbook` only when `gamerunning=1`), `fixstarmap` `p(max_maps)`.

## Open

- Station `#` explore targets the vacuum airlocks ("walk out into the vacuum?").
- Portal walk, grenade item action and the win (retire) beacon never seen in a
  test (same code paths as tested ones).
- `dprint`'s own pager still waits when one message is longer than the message
  window; `gettext`/`getnumber` don't poll `keyin`, so the layout stays stale
  while typing.
- Item menu shows `h`/`D` but reacts to its letters; the list does not reopen
  after an action. Sidebar may show `f attack` though `allowed` lacks `f`
  (upstream).
- Old log lines keep the wrap width of the mode they were printed in after a
  Tiles toggle; the toggle costs one tick in space.
- A dead captain's autosave stays in the Load list (upstream).
- UBSan (native): 3 benign float→int conversions (`makemonster`, `numfromstr`,
  `set__color`).
