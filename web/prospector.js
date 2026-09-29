/*
 * Prospector in the browser: port/webgfx.c (FreeBASIC gfx driver) converts
 * the game's SCREENRES framebuffer to RGBA; this file blits it into the
 * windows of rvip-wm.js, scaled by whole pixels, and sends keys to the game
 * as FB key events. The game says which part of its screen is what
 * (Module._rv_layout, set in keyin, kbinput.bas rv_webui): at a main prompt
 * the map part goes to Map and the sidebar to Status; messages and the
 * inventory come as text (rvMsg, rvInv); menus, dialogs and other full
 * screens are shown whole in a pop-up over the windows; one-line questions
 * over the main screen (the game's ask flag) go in a prompt line over Map.
 * Game data is preloaded read-only (/pack); the player's files live in
 * IndexedDB (IDBFS mounts /prospector/savegames, config, bones, summary).
 * Loaded before prospector-core.js.
 */
(function () {
	'use strict';

	/* the player's folders, each an IDBFS mount (the game chdirs into them and
	   back with "..", so no symlinked folders) */
	var ROOT = '/prospector', DIRS = ['savegames', 'config', 'bones', 'summary'];
	/* FB scan codes (fbgfx.bi SC_*); ascii 0 = extended key */
	var SCAN = { ArrowUp: 72, ArrowDown: 80, ArrowLeft: 75, ArrowRight: 77, Home: 71, End: 79, PageUp: 73, PageDown: 81,
		Insert: 82, Delete: 83, F1: 59, F2: 60, F3: 61, F4: 62, F5: 63, F6: 64, F7: 65, F8: 66, F9: 67, F10: 68, F11: 87, F12: 88 };
	var KEYS = { Enter: [28, 13], Escape: [1, 27], Backspace: [14, 8], Tab: [15, 9] };

	var app, ended = false, wantSaveFlag = false, lastSave = 0;
	var off, offCtx, img = null, serial = -1, full = true, wm = null;
	var LAYOUT = ROOT + '/config/web-layout.json', L = { scale: 0, sscale: 1, face: '', wm: null, sound: false }, auto = true;
	var cvs = {};   /* id -> { cv, ctx } : map, stat, pop */

	function $(id) { return document.getElementById(id); }
	function status(msg, isError) { app.status(msg, isError); }
	function latin1(p) { var s = '', c; while ((c = Module.HEAPU8[p++])) s += String.fromCharCode(c); return s; }
	function hexcol(rgb) { return '#' + ('00000' + (rgb & 0xffffff).toString(16)).slice(-6); }

	/* ---------- drawing ---------- */
	function lay() { var p = Module._rv_layout() >> 2, H = Module.HEAP32; return { mode: H[p], mw: H[p + 1], mh: H[p + 2], my: H[p + 3], side: H[p + 4], serial: H[p + 5], hx: H[p + 6], hy: H[p + 7], ask: H[p + 8] }; }
	function fitScale(w, h, vw, vh) { return Math.max(1, Math.min(4, Math.floor(Math.min(vw / w, vh / h)))); }
	/* copy part (sx, sy, w, h) of the frame into window canvas id at scale sc */
	function blit(id, sx, sy, w, h, sc) {
		var c = cvs[id];
		if (c.cv.width !== w || c.cv.height !== h) { c.cv.width = w; c.cv.height = h; c.ctx.imageSmoothingEnabled = false; }
		c.cv.style.width = w * sc + 'px'; c.cv.style.height = h * sc + 'px';
		c.ctx.drawImage(off, sx, sy, w, h, 0, 0, w, h);
	}
	function draw(force) {
		var f = Module._rv_frame(-1) >> 2, H = Module.HEAP32;
		var w = H[f], h = H[f + 1], dirty = H[f + 2], px = H[f + 3];
		if (!w) return;
		if (!img || img.width !== w || img.height !== h) {
			off.width = w; off.height = h;
			img = offCtx.createImageData(w, h);
			dirty = 1;
		}
		var l = lay();
		if (l.serial !== serial) { serial = l.serial; dirty = 1; }
		if (!dirty && !force) return;
		if (dirty) { img.data.set(Module.HEAPU8.subarray(px, px + w * h * 4)); offCtx.putImageData(img, 0, 0); }
		/* ask = a one-line question over the main screen: windows stay, the question goes over Map */
		full = !((l.mode > 0 || l.ask) && wm && wm.shown('map') && wm.shown('stat') && wm.shown('msg') && l.side > 0 && l.side < w);
		RvipWM.prompt.wait(!l.ask);
		RvipWM.prompt.text(l.ask && !full ? lastMsg : '');
		$('pop').hidden = !full;
		if (full) {   /* menus, dialogs, title: the whole screen over the windows */
			var g = $('game'), s = Math.min(g.clientWidth / w, g.clientHeight / h);
			s = s >= 1 ? Math.min(4, Math.floor(s)) : s;
			blit('pop', 0, 0, w, h, s);
			return;
		}
		var mw = Math.min(l.mw, l.side), mh = Math.min(l.mh, h), body = $('map');
		if (auto) L.scale = fitScale(mw, mh, body.clientWidth, body.clientHeight);
		blit('map', 0, 0, mw, mh, L.scale);
		RvipWM.center(cvs.map.cv, l.hx * L.scale, l.hy * L.scale, mw * L.scale, mh * L.scale);   /* the ship, from the game (clamped; centred when it fits) */
		blit('stat', l.side, 0, w - l.side, h, L.sscale);
	}
	function frame() {
		if (app.running) draw();
		requestAnimationFrame(frame);
	}
	function saveLayout() {
		try { Module.FS.writeFile(LAYOUT, JSON.stringify({ scale: auto ? 0 : L.scale, sscale: L.sscale, face: L.face, wm: L.wm, sound: L.sound })); app.sync(); } catch (e) { }
	}
	function zoom(d) {
		auto = false;
		L.scale = Math.max(1, Math.min(4, (L.scale || 1) + d));
		saveLayout(); draw(true);
	}
	function fonts() {
		['msg', 'inv'].forEach(function (id) { var e = $(id); e.style.fontFamily = L.face ? '"' + L.face + '", monospace' : ''; });
	}
	/* text font for Messages and Inventory: a face from the index page's
	   fonts/ (web/build.sh lists them in fonts.json); the map and Status are
	   the game's own bitmap screen */
	function loadFace(n) {
		if (!n) { fonts(); return; }
		var ff = new FontFace(n, 'url(../fonts/' + n + '.woff)');
		ff.load().then(function () { document.fonts.add(ff); fonts(); }).catch(function () { status('Could not load the font ' + n + '.', true); });
	}
	/* windows: the shared tiling window manager (rvip-wm.js, RVIP W4) */
	function makeWM() {
		try { var s = JSON.parse(Module.FS.readFile(LAYOUT, { encoding: 'utf8' })); if (s) { L.scale = s.scale | 0; L.sscale = s.sscale || 1; L.wm = s.wm || null;
			var old = s.fs || (s.font && { msg: s.font, inv: s.font });   /* old layout: sizes move to the WM */
			if (old && L.wm && !L.wm.fs) L.wm.fs = old; L.sound = !!s.sound; L.face = typeof s.face === 'string' ? s.face : ''; } } catch (e) { }
		auto = !L.scale;
		soundLabel();
		$('sel-font').value = L.face;
		loadFace(L.face);
		wm = RvipWM({
			area: $('game'), menu: $('btn-layout'),
			wins: [{ id: 'map', title: 'Map' }, { id: 'msg', title: 'Messages' }, { id: 'stat', title: 'Status' }, { id: 'inv', title: 'Inventory' }],
			multi: { d: 'h', r: 0.7, a: { d: 'v', r: 0.75, a: 'map', b: 'msg' }, b: { d: 'v', r: 0.6, a: 'stat', b: 'inv' } },
			single: 'map',
			state: L.wm,
			save: function (st) { L.wm = st; saveLayout(); },
			layout: function () { if (app.running) draw(true); },
			zoom: {   /* Map and Status: the game's bitmap screen, scaled 1..4x; Messages, Inventory: the WM's size */
				map: function (s, d) { zoom(d); },
				stat: function (s, d) { L.sscale = Math.max(1, Math.min(4, L.sscale + d)); saveLayout(); draw(true); }
			},
			onReset: function () { auto = true; L.scale = 0; L.sscale = 1; L.wm = wm.state(); fonts(); saveLayout(); draw(true); }
		});
		wm.apply();
	}
	/* Sound: the game decides what plays (rv_sound at each of its play sites,
	   port/webgfx.c names data/<name>.wav); this button is the real switch,
	   off by default, kept in web-layout.json. */
	function soundLabel() { $('chk-sound').checked = L.sound; }
	function toggleSound() { L.sound = $('chk-sound').checked; saveLayout(); }
	function rvSound(p, vol) { if (L.sound && vol > 0) RVIPSound.play([latin1(p)], Math.min(1, vol / 2)); }
	/* from the game (port/webgfx.c): messages, inventory, game end */
	var invText = null, lastMsg = '';
	function rvMsg(p, rgb, rep) {
		lastMsg = latin1(p);
		RvipWM.log($('msg'), { t: lastMsg, color: hexcol(rgb) }, !!rep);
		var body = $('msg').parentNode; body.scrollTop = body.scrollHeight;   /* the newest message stays in view */
	}
	function rvInv(p) {
		var t = latin1(p);
		if (t === invText) return;
		invText = t;
		var box = $('inv'); box.textContent = '';
		t.split('\n').forEach(function (line) {
			if (!line) return;
			var d = document.createElement('div');
			d.style.color = '#' + line.slice(0, 6); d.textContent = line.slice(7);
			box.appendChild(d);
		});
	}
	/* the game took its own last key (high scores, "Till next time!", title
	   Quit): save and reload into the title menu, no page key (RVIP W5) */
	function rvGameOver() {
		if (ended) return;
		ended = true; app.running = false;
		status('The game has ended. Starting a new one…');
		app.sync(function () { setTimeout(function () { location.reload(); }, 1500); });
	}

	/* ---------- input ---------- */
	function onKey(e) {
		if (!app.running || e.isComposing || e.metaKey) return;
		var k = e.key, sc = 0, a;
		if (SCAN[k] !== undefined && !/^Numpad/.test(e.code || '')) { sc = SCAN[k]; a = 0; }
		else if (/^Numpad\d$/.test(e.code || '')) a = e.code.charCodeAt(6);   /* the game moves with the digits */
		else if (KEYS[k]) { sc = KEYS[k][0]; a = KEYS[k][1]; }
		else if (k.length === 1) {
			a = k.charCodeAt(0);
			if (e.ctrlKey && !e.altKey) {
				var u = k.toUpperCase().charCodeAt(0);
				if (u >= 65 && u <= 90) a = u & 0x1f; else return;
			}
			if (a > 255) return;
		}
		else return;
		Module._rv_key(sc, a);
		wantSaveFlag = true;
		e.preventDefault();
	}

	/* Tiles/Text: the game's own option (config.txt tiles:0 = tiles). The button
	   sends scancode 120, keyin (kbinput.bas) flips configflag(con_tiles) and
	   saves config.txt (IndexedDB), so the choice survives a reload. */
	function tilesLabel() {
		var on = true;
		try { on = !/^tiles:1/m.test(Module.FS.readFile(ROOT + '/config/config.txt', { encoding: 'utf8' })); } catch (e) { }
		var b = $('btn-tiles');
		b.textContent = 'Tiles: ' + (on ? 'Prospector' : 'None');   /* the game's own set; None = its ASCII mode */
	}
	function toggleTiles() {
		if (!app.running) return;
		Module._rv_key(120, 0);
		wantSaveFlag = true;
	}

	/* ---------- saves: IndexedDB (IDBFS); export, import, help: ../rvip-app.js ---------- */
	function userFiles() {   /* '/savegames/x.sav', ... */
		var out = [];
		DIRS.forEach(function (d) {
			Module.FS.readdir(ROOT + '/' + d).forEach(function (f) {
				if (f !== '.' && f !== '..' && !Module.FS.isDir(Module.FS.stat(ROOT + '/' + d + '/' + f).mode)) out.push('/' + d + '/' + f);
			});
		});
		return out;
	}
	/* Export save: every user file as one JSON bundle {'/savegames/x.sav': base64} (rvip-app.js) */
	var backup = null;
	app = RvipApp({
		name: 'prospector',
		save: function () { return userFiles().map(function (f) { return ROOT + f; }); },
		root: ROOT,
		/* New game, Import save: delete the user files (kept here until an import is known to be good) */
		clear: function () {
			backup = userFiles().map(function (f) { return [f, Module.FS.readFile(ROOT + f)]; });
			backup.forEach(function (e) { Module.FS.unlink(ROOT + e[0]); });
		},
		put: function (file, data) {   /* once per bundle entry, file.name = '/savegames/x.sav' */
			var m = /^\/(\w+)\/([^\/\\]+)$/.exec(file.name);
			if (!m || DIRS.indexOf(m[1]) < 0 || m[2] === '..') {
				(backup || []).forEach(function (e) { Module.FS.writeFile(ROOT + e[0], e[1]); });
				return 'Not a Prospector save bundle.';
			}
			Module.FS.writeFile(ROOT + file.name, data);
		}
	});
	function autosave() {
		if (app.running) tilesLabel();
		if (!app.running || !wantSaveFlag) return;
		var now = performance.now();
		if (now - lastSave < 2000 && !document.hidden) return;
		wantSaveFlag = false; lastSave = now;
		app.sync();
	}

	/* ---------- startup ---------- */
	/* /prospector = the game folder: data and graphics files linked from
	   /pack, data/highscore.dat linked to savegames/highscore.dat */
	function setupFolder() {
		var FS = Module.FS;
		function copyIfMissing(from, to) { try { FS.stat(to); } catch (e) { FS.writeFile(to, FS.readFile(from)); } }
		FS.readdir('/pack/config').forEach(function (f) { if (f[0] !== '.') copyIfMissing('/pack/config/' + f, ROOT + '/config/' + f); });
		copyIfMissing('/pack/data/highscore.dat', ROOT + '/savegames/highscore.dat');
		['data', 'graphics'].forEach(function (d) {
			FS.mkdir(ROOT + '/' + d);
			FS.readdir('/pack/' + d).forEach(function (f) {
				if (f[0] === '.') return;
				FS.symlink(f === 'highscore.dat' ? ROOT + '/savegames/highscore.dat' : '/pack/' + d + '/' + f, ROOT + '/' + d + '/' + f);
			});
		});
		FS.chdir(ROOT);
	}
	window.Module = {
		arguments: [],
		preRun: [function () {
			var FS = Module.FS;
			DIRS.forEach(function (d) { FS.mkdirTree(ROOT + '/' + d); FS.mount(Module.IDBFS, {}, ROOT + '/' + d); });
			Module.addRunDependency('idbfs');
			FS.syncfs(true, function (err) {
				if (err) status('Could not read saved games from IndexedDB (' + err + '). Saving may not work in this browser mode.', true);
				Module.removeRunDependency('idbfs');
			});
		}],
		onRuntimeInitialized: function () {
			setupFolder();   /* the preloaded /pack exists only now */
			$('game').hidden = false;
			makeWM();
			app.running = true; status('');
			requestAnimationFrame(frame);
			setInterval(autosave, 500);
		},
		rvMsg: rvMsg, rvInv: rvInv, rvGameOver: rvGameOver, rvSound: rvSound,
		onExit: function (code) { rvGameOver(); },   /* an END the game reaches without rv_gameover (error paths) */
		print: function (s) { console.log(s); },
		printErr: function (s) { console.warn(s); },
		setStatus: function (s) { if (s && !app.running) status(s.replace(/\(\d+\/\d+\)/, '').trim() || 'Loading…'); },
		onAbort: function (what) { app.crashed(what); }
	};
	document.addEventListener('visibilitychange', function () { if (document.hidden) wantSaveFlag = true; });
	window.addEventListener('resize', function () { if (wm) wm.apply(); });
	document.addEventListener('keydown', onKey);
	document.addEventListener('DOMContentLoaded', function () {
		off = document.createElement('canvas'); offCtx = off.getContext('2d');
		['map', 'stat', 'pop'].forEach(function (id) {
			var cv = document.querySelector('#' + id + ' canvas');
			cvs[id] = { cv: cv, ctx: cv.getContext('2d') };
		});
		$('btn-tiles').onclick = toggleTiles;
		$('chk-sound').onchange = toggleSound;
		RvipWM.dropdown($('btn-file'), $('menu-file'));
		RvipWM.dropdown($('btn-audio'), $('menu-audio'));
		RvipWM.fonts.then(function (list) {
			var sel = $('sel-font');
			RvipWM.fontOptions(sel);
			sel.value = L.face || '';
		}).catch(function () { });
		$('sel-font').onchange = function () { L.face = this.value; saveLayout(); loadFace(L.face); this.blur(); };
		document.querySelectorAll('button').forEach(function (b) {
			b.addEventListener('mousedown', function (e) { e.preventDefault(); });
		});
	});
})();
