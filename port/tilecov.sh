#!/bin/sh
# Tile coverage (RVIP stage 4): which tile numbers the source assigns have a
# sprite. Builds a scratch copy whose load_tiles dumps the loaded gt_no()
# numbers (2048 = not loaded) and exits, then compares with every literal
# `ti_no=<n>` assignment (comparisons like `if x.ti_no=0 then` skipped) plus
# the monster fallback g+1001 (g 1..12, monster.bas). Usage: sh port/tilecov.sh
set -e
cd "$(dirname "$0")/.."
T=${OUT:-${TMPDIR:-/tmp}/prospector-tilecov}
rm -rf "$T/src" && mkdir -p "$T/src"
cp -R *.bas *.bi port data graphics config "$T/src/" 2>/dev/null || true
perl -0pi -e 's/(function load_tiles\(\) as short.*?)(\n\s*return 0\r?\n\s*end function)/$1\n    dim rvf as long=freefile\n    open "tiles-loaded.txt" for output as #rvf\n    for a=0 to 4096\n        if gt_no(a)<>2048 then print #rvf,a\n    next\n    close #rvf\n    end$2/s' "$T/src/fileIO.bas"
rm -rf "$T/native"
OUT="$T/native" sh "$T/src/port/native-test.sh" >/dev/null 2>&1 || true
tr -d " \r" < "$T/native/run/tiles-loaded.txt" | sort > "$T/loaded"
{ perl -ne 'print "$1\n" while /(?<!if )(?<!and )(?<!or )\bti_no\s*=\s*(\d+)(?!\d|\s*(then|and|or))/gi' *.bas; seq 1002 1013; } | sort -u > "$T/used"
echo "loaded $(wc -l < "$T/loaded"), used $(wc -l < "$T/used"), missing: $(comm -13 "$T/loaded" "$T/used" | tr '\n' ' ')"
