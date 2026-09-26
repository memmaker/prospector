/* FreeBASIC gfxlib2 driver for the web build (web/build.sh). Replaces
   gfxlib2/js (SDL1): the game's 16-bit SCREENRES framebuffer is converted
   to RGBA here and web/prospector.js blits it to a canvas. Keys come from
   JS through rv_key() as FB key events (scancode + ascii) and INKEY codes.
   Linked before libfbgfx.a, so gfxlib2/js/gfx_driver.o is never pulled. */
#include <stdlib.h>
#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#else   /* native headless test build (port/native-test.sh) */
#include <stdio.h>
#include <unistd.h>
#define EMSCRIPTEN_KEEPALIVE
#define emscripten_sleep(ms) usleep((ms) * 1000)
static void native_poll(void);
#endif
#include <string.h>
#include "fb_gfx.h"

static int inited, W, H;
static uint32_t *rgba;
static struct { int w, h, dirty; uint32_t *px; } frame;

static int driver_init(char *title, int w, int h, int depth, int refresh, int flags) {
  if (flags & DRIVER_OPENGL) return -1;
  if (!w || !h) return 0;
  free(rgba);
  W = w; H = h;
  rgba = calloc((size_t)w * h, 4);
  inited = 1;
  return 0;
}
static void driver_exit(void) { inited = 0; }
static void driver_nop(void) {}
#ifdef __EMSCRIPTEN__
#define driver_poll driver_nop
#else
#define driver_poll native_poll
#endif
static void driver_wait_vsync(void) { emscripten_sleep(16); }
static int driver_get_mouse(int *x, int *y, int *z, int *buttons, int *clip) {
  return -1;   /* the game uses no mouse */
}
static void driver_set_mouse(int x, int y, int cursor, int clip) {}
static void driver_set_window_title(char *title) {}
static int *driver_fetch_modes(int depth, int *size) { *size = 0; return NULL; }

static const GFXDRIVER fb_gfxDriverWeb = {
  "web", driver_init, driver_exit, driver_nop, driver_nop, NULL, driver_wait_vsync,
  driver_get_mouse, driver_set_mouse, driver_set_window_title, NULL, driver_fetch_modes,
  NULL, driver_poll, NULL
};
const GFXDRIVER *__fb_gfx_drivers_list[] = { &fb_gfxDriverWeb, NULL };

void fb_hScreenInfo(ssize_t *width, ssize_t *height, ssize_t *depth, ssize_t *refresh) {
  *width = 1920; *height = 1080; *depth = 32; *refresh = 60;
}
FBCALL int fb_GfxGetJoystick(int id, ssize_t *buttons, float *a1, float *a2, float *a3, float *a4,
                             float *a5, float *a6, float *a7, float *a8) {
  *buttons = -1;
  *a1 = *a2 = *a3 = *a4 = *a5 = *a6 = *a7 = *a8 = -1000.0f;
  return fb_ErrorSetNum(FB_RTERROR_ILLEGALFUNCTIONCALL);
}

/* Called by JS every animation frame: converts the dirty lines of the
   visible page (16 bpp RGB565 or 32 bpp) to RGBA; frame.dirty says whether
   anything changed. page >= 0: all of that page instead (tests look at the
   hidden work page with it). */
EMSCRIPTEN_KEEPALIVE void *rv_frame(int page) {
  frame.dirty = 0;
  if (!inited || !__fb_gfx || !__fb_gfx->framebuffer || __fb_gfx->w != W || __fb_gfx->h != H) {
    frame.w = frame.h = 0; frame.px = NULL; return &frame;
  }
  int bpp = __fb_gfx->bpp;
  const uint8_t *fb = page >= 0 && page < __fb_gfx->num_pages ? __fb_gfx->page[page] : __fb_gfx->framebuffer;
  for (int y = 0; y < H; y++) {
    if (page < 0) {
      if (!__fb_gfx->dirty[y * __fb_gfx->scanline_size]) continue;
      __fb_gfx->dirty[y * __fb_gfx->scanline_size] = 0;
    }
    frame.dirty = 1;
    const uint8_t *src = fb + (size_t)y * __fb_gfx->pitch;
    uint32_t *d = rgba + (size_t)y * W;
    if (bpp == 2) {
      const uint16_t *s = (const uint16_t *)src;
      for (int x = 0; x < W; x++) {
        unsigned c = s[x], r = (c >> 11) & 31, g = (c >> 5) & 63, b = c & 31;
        d[x] = ((r << 3) | (r >> 2)) | (((g << 2) | (g >> 4)) << 8) | (((b << 3) | (b >> 2)) << 16) | 0xFF000000u;
      }
    } else if (bpp == 4) {
      const uint32_t *s = (const uint32_t *)src;
      for (int x = 0; x < W; x++) { unsigned c = s[x]; d[x] = ((c >> 16) & 0xFF) | (c & 0xFF00) | ((c & 0xFF) << 16) | 0xFF000000u; }
    } else {
      const uint32_t *pal = __fb_gfx->device_palette;
      for (int x = 0; x < W; x++) { unsigned c = pal[src[x]]; d[x] = ((c >> 16) & 0xFF) | (c & 0xFF00) | ((c & 0xFF) << 16) | 0xFF000000u; }
    }
  }
  if (page >= 0) memset(__fb_gfx->dirty, 1, H * __fb_gfx->scanline_size);   /* next visible frame repaints */
  frame.w = W; frame.h = H; frame.px = rgba;
  return &frame;
}

/* Windows of the web page (web/prospector.js). The game says which part of
   its screen is what (rv_regions from keyin, kbinput.bas): mode > 0 = at a
   main prompt, map / messages / sidebar are split into windows; mode 0 = a
   menu, dialog or other full screen, shown whole over the map. Messages and
   the inventory come as text (Latin-1) with the game's colours. */
static int layout[6];   /* mode, map w, map h, messages y, sidebar x, serial */
EMSCRIPTEN_KEEPALIVE int *rv_layout(void) { return layout; }
void rv_regions(int mode, int mw, int mh, int my, int side) {
  if (layout[0] == mode && layout[1] == mw && layout[2] == mh && layout[3] == my && layout[4] == side) return;
  layout[0] = mode; layout[1] = mw; layout[2] = mh; layout[3] = my; layout[4] = side; layout[5]++;
}
#ifdef __EMSCRIPTEN__
/* rgb = FB colour (&hAARRGGBB); rep = 1: replaces the last line ("(x2)") */
void rv_msg(const char *s, int rgb, int rep) {
  EM_ASM({ if (Module.rvMsg) Module.rvMsg($0, $1, $2); }, s, rgb, rep);
}
/* lines "rrggbb text\n" */
void rv_inv(const char *s) {
  EM_ASM({ if (Module.rvInv) Module.rvInv($0); }, s);
}
/* the game is over (before its END): the page waits for a key, saves and
   reloads for a new game; exit() never runs (no EXIT_RUNTIME, RVIP W5) */
void rv_gameover(void) {
  EM_ASM({ if (Module.rvGameOver) Module.rvGameOver(); });
  for (;;) emscripten_sleep(1000);
}
#else
void rv_msg(const char *s, int rgb, int rep) {}
void rv_inv(const char *s) {}
void rv_gameover(void) {}
#endif

/* A key from JS: scancode (FB SC_*), ascii (0 for extended keys). */
EMSCRIPTEN_KEEPALIVE void rv_key(int scancode, int ascii) {
  EVENT e;
  memset(&e, 0, sizeof e);
  e.type = EVENT_KEY_PRESS; e.scancode = scancode; e.ascii = ascii;
  fb_hPostEvent(&e);
  fb_hPostKey(ascii ? ascii : ((scancode << 8) | 0xFF));
}

#ifndef __EMSCRIPTEN__
/* Keys for the native test: RV_KEYS = file of keys ({esc} {enter} {up}
   {down} {left} {right} {bs}, else one char each), then RV_RANDOM random
   keys (seed RV_SEED), then exit(0). RV_SHOT = PPM of the screen, written
   every 200 keys and at the end. */
static void shot(void) {
  const char *f = getenv("RV_SHOT");
  if (!f || !W) return;
  rv_frame(-1);
  FILE *o = fopen(f, "wb");
  if (!o) return;
  fprintf(o, "P6 %d %d 255\n", W, H);
  for (int i = 0; i < W * H; i++) { uint32_t c = rgba[i]; fputc(c & 255, o); fputc((c >> 8) & 255, o); fputc((c >> 16) & 255, o); }
  fclose(o);
}
void *fb_hGL_GetProcAddress(const char *name) { return NULL; }
/* the game polls ScreenEvent with SLEEP 1: feed a key on every delay, no waiting */
FBCALL void fb_Delay(int msecs) { native_poll(); }
static void native_poll(void) {
  static FILE *kf; static int opened, left = -1, n;
  static const char pool[] = "12346789123467891234678955ssssllldddiiaaeexxooppRr#<>CcTtLlWw@A?.,mzy##<<>>~~EEE`` \033\033\r\r\r\r";
  if (__fb_gfx->event_head != __fb_gfx->event_tail) return;
  if (!opened) {
    opened = 1;
    if (getenv("RV_KEYS")) kf = fopen(getenv("RV_KEYS"), "r");
    left = getenv("RV_RANDOM") ? atoi(getenv("RV_RANDOM")) : 0;
    srand(getenv("RV_SEED") ? atoi(getenv("RV_SEED")) : 1);
  }
  int c = kf ? fgetc(kf) : EOF;
  if (c == '\n') c = kf ? fgetc(kf) : EOF;
  if (c == '{') {
    char t[16]; int i = 0;
    while ((c = fgetc(kf)) != EOF && c != '}' && i < 15) t[i++] = c;
    t[i] = 0;
    if (!strcmp(t, "esc")) rv_key(1, 27); else if (!strcmp(t, "enter")) rv_key(28, 13);
    else if (!strcmp(t, "bs")) rv_key(14, 8); else if (!strcmp(t, "up")) rv_key(72, 0);
    else if (!strcmp(t, "down")) rv_key(80, 0); else if (!strcmp(t, "left")) rv_key(75, 0);
    else if (!strcmp(t, "right")) rv_key(77, 0); else if (!strcmp(t, "shot")) shot();
  } else if (c != EOF) {
    rv_key(c == '\r' ? 28 : c == 27 ? 1 : 0, c);
  } else if (left-- > 0) {
    c = pool[rand() % (sizeof pool - 1)];
    if (c == '`') rv_key(120, 0);   /* the page's Tiles/Text button */
    else rv_key(c == '\r' ? 28 : c == 27 ? 1 : 0, c);
  } else { shot(); fprintf(stderr, "rv: keys done after %d\n", n); exit(0); }
  if (++n % 200 == 0) shot();
}
#endif
