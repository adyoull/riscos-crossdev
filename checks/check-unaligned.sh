#!/bin/bash
# List casts that can produce unaligned 16/32-bit loads or stores.
#
# RISC OS runs with alignment checking on: an unaligned LDR/STR/LDRH/STRH
# aborts ("abort on data transfer", which UnixLib reports as "Fatal signal
# received: EMT trap"). Linux doesn't, so code from Linux often has them.
# Fix what this finds with memcpy, a byte-wise load, or a packed struct.
#
#   checks/check-unaligned.sh [-a] [-s SAFE_FILE] [CFLAGS...] FILE.c|.cc|.cpp...
#
# Compiles each file with -fsyntax-only -Wcast-align=strict and prints each
# warning with its source line. Arguments that aren't C/C++ sources are
# passed to the compiler (-I, -D ...).
#   -s SAFE_FILE  extended regular expressions, one per line, for warnings
#                 you have checked by hand (matched against "warning @@ line");
#                 they're hidden.
#   -a            show everything, even what SAFE_FILE hides.
# Exit status 1 if anything is left to review.
# From riscos-warzone2100 (tools/check-unaligned.sh), made general.
. "$(dirname "$0")/../env.sh"
SAFE=; ALL=0; FLAGS=(); FILES=()
while [ $# -gt 0 ]; do
  case $1 in
    -a) ALL=1;;
    -s) SAFE=$2; shift;;
    *.c|*.cc|*.cpp|*.cxx) FILES+=("$1");;
    *) FLAGS+=("$1");;
  esac
  shift
done
[ ${#FILES[@]} -gt 0 ] || { echo "usage: $0 [-a] [-s SAFE_FILE] [CFLAGS...] FILE.c..." >&2; exit 2; }
LOG=$(mktemp); trap 'rm -f "$LOG"' EXIT
for f in "${FILES[@]}"; do
  case $f in *.c) C=$RISCOS_HOST-gcc;; *) C=$RISCOS_HOST-g++;; esac
  $C -fsyntax-only -Wcast-align=strict "${FLAGS[@]}" "$f" 2>&1 \
    | awk '/warning: cast increases required alignment/ { w=$0; getline src; print w " @@ " src }'
done > "$LOG"
if [ -n "$SAFE" ] && [ "$ALL" = 0 ]; then
  grep -vE -f <(grep -v '^[[:space:]]*\(#\|$\)' "$SAFE") "$LOG" > "$LOG.left" || true
else
  cp "$LOG" "$LOG.left"
fi
cat "$LOG.left"
total=$(wc -l < "$LOG"); left=$(wc -l < "$LOG.left"); rm -f "$LOG.left"
echo "$total cast-align warnings, $left to review"
[ "$left" = 0 ]
