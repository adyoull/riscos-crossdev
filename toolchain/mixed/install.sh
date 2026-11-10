#!/bin/bash
# Build crtmixed.o (crtmixed.c) with the toolchain and install it next to
# crt0.o, where the driver links it into every "mixed" program
# (gcc -rdynamic: UnixLib static, other libraries shared). Run by
# make prebuilt and make toolchain; safe to run again.
#   toolchain/mixed/install.sh [DIR]        (default $RISCOS_TOOLCHAIN)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../env.sh"
DIR=$(cd "${1:-$RISCOS_TOOLCHAIN}" && pwd)
CC=$DIR/bin/arm-riscos-gnueabihf-gcc
[ -x "$CC" ] || { echo "no toolchain in $DIR" >&2; exit 1; }
"$CC" $RISCOS_CFLAGS -Wall -Werror -c -o "$DIR/arm-riscos-gnueabihf/lib/crtmixed.o" "$HERE/crtmixed.c"
echo "installed crtmixed.o: $DIR/arm-riscos-gnueabihf/lib/crtmixed.o"
