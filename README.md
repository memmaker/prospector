**RVIP port** of Prospector R197 (Matthias Mennel, 2008–2014), an original
space exploration roguelike in FreeBASIC. Upstream: the Google Code svn trunk
at r197 (2014-12-28) from the
[rlprospector source archive](https://storage.googleapis.com/google-code-archive-source/v2/code.google.com/rlprospector/source-archive.zip)
(a working copy without history; commit `7aba66b` is that snapshot untouched)
plus the data files of the author's release `R197prospector_l.zip`
(web.archive.org copy of prospector.at; commit `1b928c0`, untouched).
Play: https://ruzzoli.de/roguelikes/prospector/
Our changes: https://github.com/memmaker/prospector/compare/1b928c0...main

**This is an altered source version** (zlib licence, point 2): the original
licence and credits are in `README.txt`, unchanged. Game by Matthias Mennel;
graphics by David Gervais and Deon, used with their permission; FBSound by
D.J. Peters, zlib by Greg Roelofs and Mark Adler, `cards.bi` by RDC (see
`README.txt`). Manuals: `Manual.pdf` (version 1.1, 2014) and `doc/Manual.pdf`
(1.0, 2011); change log `changelog.txt`.

You captain a small ship in an unexplored sector: map planets, bring home
minerals and bio data, trade, hire and train a crew, fight pirates and
whatever lives down there, and retire rich.

What this port adds:
- **Web build**: FreeBASIC → C (`fbc -gen gcc`) → Emscripten, with FreeBASIC's
  runtime and gfxlib2 and an own graphics driver `port/webgfx.c` that hands
  the framebuffer to a canvas and takes keys from the page
  (`web/prospector.js`). Saves and config in the browser's IndexedDB.
- **Windows** (shared `rvip-wm.js`): the game names its screen regions, so
  Map (follows the ship), Status and Messages are separate windows; menus
  and questions pop up over them.
- **Explore** `#` / `~` flood only over seen cells and stop on new messages;
  **`<` / `>`** walk to the known ship / stairs and take them.
- **Enter menu** of all commands with their current keys, **item menus**
  (`E`), a Tiles/Text button, **sound** (the game's own WAVs, off by default).
- Upstream bug fixes: `STRING*N` layouts for FreeBASIC 1.2x, map-size
  station placement, nested key prompts overflowing the stack, map count bound.

Build: `sh web/build.sh` → `web/dist` (FreeBASIC-NG fbc, a fbc clone with
`make rtlib gfxlib2 TARGET=wasm32-unknown-emscripten`, emcc; see the script's
header). Native headless test: `sh port/native-test.sh <keys> <n> <seed>`.
Deploy: `sh web/deploy.sh`. Notes: `HANDOVER.md`.
