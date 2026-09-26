/* DIR$ for the web build: FreeBASIC's js rtlib has only a stub that finds
   nothing (the game lists savegames with it). The unix version works on
   the Emscripten FS. */
#include "unix/file_dir.c"
