#!/bin/bash
# Point the toolchain's libtool archives (.la files) at where it is now.
#   toolchain/relocate.sh [DIR]          (default $RISCOS_TOOLCHAIN)
#   toolchain/relocate.sh --check [DIR]  (exit 1 if a .la names a file or
#                                         directory that isn't there)
#
# The .la files name the directory the toolchain was built in (the
# prebuilt tarball's say /opt/b14/toolchain/env). libtool follows them when
# a port links a C++ library: libstdc++.la names libm.la and libunixlib.la
# by that path, and the link fails with "is not a valid libtool archive".
# install-prebuilt.sh runs this; run it yourself after moving a toolchain,
# or on one installed by riscos-crossdev 1.8.1 or earlier.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../env.sh"
check=; [ "${1:-}" = --check ] && { check=1; shift; }
DIR=$(cd "${1:-$RISCOS_TOOLCHAIN}" && pwd)
if [ -n "$check" ]; then
  bad=0
  while IFS= read -r -d '' f; do
    # libdir='DIR' and dependency_libs=' 'DIR'/libm.la ...': drop the quotes
    for p in $(sed -n "s/^\(libdir\|dependency_libs\)='\(.*\)'\$/\2/p" "$f" | tr -d "'"); do
      case $p in
        /*.la) [ -f "$p" ] || { echo "$f names $p, which isn't there"; bad=1; } ;;
        /*) [ -d "$p" ] || { echo "$f names $p, which isn't there"; bad=1; } ;;
      esac
    done
  done < <(find "$DIR" -name '*.la' -print0)
  [ $bad = 0 ] && echo "OK: the .la files name $DIR"
  exit $bad
fi
REF=$DIR/arm-riscos-gnueabihf/lib/libunixlib.la
[ -f "$REF" ] || { echo "no toolchain in $DIR ($REF is missing)" >&2; exit 1; }
# The build's directory: libunixlib.la's libdir, less /arm-riscos-gnueabihf/lib
old=$(sed -n "s|^libdir='\(.*\)/arm-riscos-gnueabihf/lib'\$|\1|p" "$REF")
[ -n "$old" ] || { echo "can't read libdir in $REF" >&2; exit 1; }
if [ "$old" = "$DIR" ]; then echo "the .la files already name $DIR"; exit 0; fi
n=0
while IFS= read -r -d '' f; do
  grep -qF "$old/" "$f" || grep -qF "'$old'" "$f" || continue
  sed -i "s|$old/|$DIR/|g; s|'$old'|'$DIR'|g" "$f"
  n=$((n+1))
done < <(find "$DIR" -name '*.la' -print0)
echo "relocated $n .la files: $old -> $DIR"
