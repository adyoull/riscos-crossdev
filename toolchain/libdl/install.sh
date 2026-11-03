#!/bin/bash
# Build the libdl stub (dlstub.c) with the toolchain and install it as
# libdl.a, so that builds linking -ldl link. Run by make prebuilt and make
# toolchain; safe to run again (it replaces the stub, and leaves a libdl.a
# that isn't the stub alone).
#   toolchain/libdl/install.sh [DIR]        (default $RISCOS_TOOLCHAIN)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../env.sh"
DIR=$(cd "${1:-$RISCOS_TOOLCHAIN}" && pwd)
LIB=$DIR/arm-riscos-gnueabihf/lib
CC=$DIR/bin/arm-riscos-gnueabihf-gcc
[ -x "$CC" ] || { echo "no toolchain in $DIR" >&2; exit 1; }
if [ -e "$LIB/libdl.a" ] && ! "$DIR/bin/arm-riscos-gnueabihf-ar" t "$LIB/libdl.a" | grep -qx dlstub.o; then
  echo "$LIB/libdl.a is not riscos-crossdev's stub: left as it is"; exit 0
fi
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
"$CC" $RISCOS_CFLAGS -Wall -Werror -c -o "$TMP/dlstub.o" "$HERE/dlstub.c"
rm -f "$LIB/libdl.a"
"$DIR/bin/arm-riscos-gnueabihf-ar" rcs "$LIB/libdl.a" "$TMP/dlstub.o"
echo "installed the libdl stub: $LIB/libdl.a"
