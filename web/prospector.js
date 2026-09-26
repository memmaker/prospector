/*
 * Prospector in the browser: port/webgfx.c (FreeBASIC gfx driver) converts
 * the game's SCREENRES framebuffer to RGBA; this file puts it on a canvas,
 * scaled by whole pixels, and sends keys to the game as FB key events.
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

	var running = false, cv, ctx, img = null, scale = 0, auto = true, wantSaveFlag = false, lastSave = 0;

	function $(id) { return document.getElementById(id); }
	function status(msg, isError) {
		var s = $('status');
		s.textContent = msg; s.hidden = !msg; s.classList.toggle('error', !!isError);
	}

	/* ---------- drawing ---------- */
	function fit(w, h) {
		var g = $('game'), s = Math.floor(Math.min(g.clientWidth / w, g.clientHeight / h));
		return Math.max(1, Math.min(4, s));
	}
	function draw() {
		var f = Module._rv_frame(-1) >> 2, H = Module.HEAP32;
		var w = H[f], h = H[f + 1], dirty = H[f + 2], px = H[f + 3];
		if (!w) return;
		if (!img || img.width !== w || img.height !== h) {
			cv.width = w; cv.height = h;
			img = ctx.createImageData(w, h);
			if (auto) scale = fit(w, h);
			cv.style.width = w * scale + 'px'; cv.style.height = h * scale + 'px';
			dirty = 1;
		}
		if (!dirty) return;
		img.data.set(Module.HEAPU8.subarray(px, px + w * h * 4));
		ctx.putImageData(img, 0, 0);
	}
	function frame() {
		if (running) draw();
		requestAnimationFrame(frame);
	}
	function zoom(d) {
		if (!img) return;
		auto = false;
		scale = Math.max(1, Math.min(4, scale + d));
		cv.style.width = img.width * scale + 'px'; cv.style.height = img.height * scale + 'px';
		try { Module.FS.writeFile(ROOT + '/config/web-zoom.json', JSON.stringify({ scale: scale })); syncFiles(); } catch (e) { }
	}

	/* ---------- input ---------- */
	function onKey(e) {
		if (!running || e.isComposing || e.metaKey) return;
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
		b.textContent = on ? 'Tiles' : 'Text'; b.classList.toggle('on', on);
	}
	function toggleTiles() {
		if (!running) return;
		Module._rv_key(120, 0);
		wantSaveFlag = true;
	}

	/* ---------- saves: IndexedDB (IDBFS) ---------- */
	var syncing = false, syncAgain = false, pendingCbs = [];
	function syncFiles(cb) {
		if (!Module.FS) { if (cb) cb(); return; }
		if (typeof cb === 'function') pendingCbs.push(cb);
		if (syncing) { syncAgain = true; return; }
		syncing = true;
		var cbs = pendingCbs; pendingCbs = [];
		Module.FS.syncfs(false, function (err) {
			syncing = false;
			if (err) status('Saving to browser storage (IndexedDB) failed: ' + err + '. Use "Export save" to keep a copy.', true);
			cbs.forEach(function (f) { f(err); });
			if (syncAgain) { syncAgain = false; syncFiles(); }
		});
	}
	function userFiles() {   /* '/savegames/x.sav', ... */
		var out = [];
		DIRS.forEach(function (d) {
			Module.FS.readdir(ROOT + '/' + d).forEach(function (f) {
				if (f !== '.' && f !== '..' && !Module.FS.isDir(Module.FS.stat(ROOT + '/' + d + '/' + f).mode)) out.push('/' + d + '/' + f);
			});
		});
		return out;
	}
	function b64(u8) { var s = ''; for (var i = 0; i < u8.length; i++) s += String.fromCharCode(u8[i]); return btoa(s); }
	function unb64(s) { var b = atob(s), u = new Uint8Array(b.length); for (var i = 0; i < b.length; i++) u[i] = b.charCodeAt(i); return u; }
	function exportSave() {
		var files = userFiles();
		var bundle = {};
		files.forEach(function (f) { bundle[f] = b64(Module.FS.readFile(ROOT + f)); });
		var a = document.createElement('a');
		a.href = URL.createObjectURL(new Blob([JSON.stringify(bundle)], { type: 'application/json' }));
		a.download = 'prospector-save.json';
		document.body.appendChild(a); a.click();
		setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
	}
	function clearUser() { userFiles().forEach(function (f) { Module.FS.unlink(ROOT + f); }); }
	function importSave(file) {
		var r = new FileReader();
		r.onload = function () {
			var bundle;
			try { bundle = JSON.parse(r.result); } catch (e) { status('Not a Prospector save bundle.', true); return; }
			if (!confirm('Replace the saved games in this browser with "' + file.name + '"?')) return;
			running = false;
			clearUser();
			Object.keys(bundle).forEach(function (f) {
				var m = /^\/(\w+)\/([^\/\\]+)$/.exec(f);
				if (!m || DIRS.indexOf(m[1]) < 0 || m[2] === '..') return;
				Module.FS.writeFile(ROOT + f, unb64(bundle[f]));
			});
			syncFiles(function (err) { if (!err) location.reload(); });
		};
		r.readAsText(file);
	}
	function newGame() {
		if (!confirm('Delete the saved games and settings in this browser and start over?')) return;
		running = false;
		clearUser();
		syncFiles(function (err) { if (!err) location.reload(); });
	}
	function autosave() {
		if (running) tilesLabel();
		if (!running || !wantSaveFlag) return;
		var now = performance.now();
		if (now - lastSave < 2000 && !document.hidden) return;
		wantSaveFlag = false; lastSave = now;
		syncFiles();
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
				try { scale = JSON.parse(FS.readFile(ROOT + '/config/web-zoom.json', { encoding: 'utf8' })).scale || 0; } catch (e) { scale = 0; }
				Module.removeRunDependency('idbfs');
			});
		}],
		onRuntimeInitialized: function () {
			setupFolder();   /* the preloaded /pack exists only now */
			auto = !scale;
			$('game').hidden = false;
			running = true; status('');
			requestAnimationFrame(frame);
			setInterval(autosave, 500);
		},
		onExit: function (code) {
			running = false;
			syncFiles(function () {
				$('overlay-msg').textContent = 'Your saved games stay in this browser. Play again to continue one or start a new one.';
				$('overlay').hidden = false;
			});
		},
		print: function (s) { console.log(s); },
		printErr: function (s) { console.warn(s); },
		setStatus: function (s) { if (s && !running) status(s.replace(/\(\d+\/\d+\)/, '').trim() || 'Loading…'); },
		onAbort: function (what) { crashed(what); }
	};
	function crashed(err) {
		if (!running) return;
		running = false;
		var msg = (err && (err.message || err.reason && err.reason.message)) || String(err);
		console.error('[prospector] crash:', err);
		status('The game crashed (' + msg + '). Reload the page to continue from the last save.', true);
	}
	window.addEventListener('unhandledrejection', function (e) {
		if (e.reason && e.reason.name === 'ExitStatus') return;   /* exit() is the normal end */
		crashed(e.reason);
	});
	window.addEventListener('error', function (e) {
		if (e.error && e.error.name === 'ExitStatus') return;
		if (e.error instanceof WebAssembly.RuntimeError || /prospector-core/.test(e.filename || '')) crashed(e.error || e.message);
	});
	document.addEventListener('visibilitychange', function () { if (document.hidden) wantSaveFlag = true; });
	window.addEventListener('resize', function () { if (auto && img) { img = null; draw(); } });
	document.addEventListener('keydown', onKey);
	document.addEventListener('DOMContentLoaded', function () {
		cv = document.querySelector('#game canvas');
		ctx = cv.getContext('2d');
		cv.style.imageRendering = 'pixelated';
		$('btn-export').onclick = exportSave;
		$('btn-import').onclick = function () { $('import-file').click(); };
		$('import-file').onchange = function () { if (this.files[0]) importSave(this.files[0]); this.value = ''; };
		$('btn-new').onclick = newGame;
		$('btn-zoom-in').onclick = function () { zoom(1); };
		$('btn-zoom-out').onclick = function () { zoom(-1); };
		$('btn-tiles').onclick = toggleTiles;
		$('btn-restart').onclick = function () { location.reload(); };
		document.querySelectorAll('button').forEach(function (b) {
			b.addEventListener('mousedown', function (e) { e.preventDefault(); });
		});
	});
})();
