#!/bin/bash
# Check a mixed program's package (docs/MIXED.md): every shared library
# it needs, and every library those need in turn, is in the app's own lib
# directory, and each was built for mixed programs (check-shared-lib.sh).
#
#   checks/check-mixed-package.sh PROGRAM LIBDIR
#     PROGRAM  the program (ELF; stripped or not)
#     LIBDIR   the directory the app ships its libraries in, as on Linux
#              (libgtk-3.so.0 or libgtk-3.so.0,e1f)
#
# Why: SOManager looks in the app's LD_LIBRARY_PATH first and then in
# !SharedLibs. A library missing from the app would be found in
# !SharedLibs instead, built for fully shared programs: it would bring a
# shared UnixLib with it, and the program would have two C libraries. (The
# program stops at start-up if that happens: crtmixed.o checks.)
. "$(dirname "$0")/../env.sh"
[ $# -eq 2 ] && [ -f "$1" ] && [ -d "$2" ] || { echo "usage: $0 PROGRAM LIBDIR" >&2; exit 2; }
prog=$1; dir=$2; bad=0
needed() { $RISCOS_HOST-readelf -dW "$1" 2>/dev/null | awk '/\(NEEDED\)/ {print $NF}' | tr -d '[]'; }
find_lib() { for f in "$dir/$1" "$dir/$1,e1f"; do [ -f "$f" ] && { echo "$f"; return 0; }; done; return 1; }
declare -A seen
queue=$(needed "$prog")
[ -n "$queue" ] || { echo "WRONG: $prog needs no shared library: is it a mixed program?" >&2; exit 1; }
while [ -n "$queue" ]; do
  next=
  for n in $queue; do
    [ -n "${seen[$n]:-}" ] && continue; seen[$n]=1
    case $n in libunixlib.so*|libstdc++.so*|libgcc_s.so*|libm.so*|libc.so*|libpthread.so*)
      echo "WRONG: $n is needed: UnixLib, libstdc++ and libgcc must be linked into the program" >&2; bad=1; continue;;
    esac
    if f=$(find_lib "$n"); then
      "$(dirname "$0")/check-shared-lib.sh" "$f" >/dev/null 2>&1 || { "$(dirname "$0")/check-shared-lib.sh" "$f"; bad=1; }
      next="$next $(needed "$f")"
    else
      echo "WRONG: $n isn't in $dir: SOManager would look for it in !SharedLibs, and use one built with a shared UnixLib" >&2; bad=1
    fi
  done
  queue=$next
done
[ $bad = 0 ] && echo "OK: $prog: all ${#seen[@]} libraries it needs are in $dir, built for mixed programs"
exit $bad
