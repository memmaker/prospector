// FreeBASIC's js console (fb_rtlib.js, termlib) is not used: the game runs
// in a graphics screen from its first statement. The rtlib's EM_ASM calls
// still name __fb_rtlib, so give them no-ops.
var __fb_rtlib = { console: new Proxy({}, { get: function (t, k) {
  return k === 'size_get' ? function () { return 80 | (25 << 16); } : k === 'pos_get' ? function () { return 0; } : function () {};
} }) };
