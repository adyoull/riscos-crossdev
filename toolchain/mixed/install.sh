#!/bin/bash
# Build crtmixed.o (crtmixed.c) and the stand-in libraries (stub.c) with the toolchain and install it next to
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
# The stand-ins for a shared UnixLib, libstdc++, libgcc_s and libm (stub.c), under
# the SONAMEs GCCSDK's libraries need. They go in a mixed app's lib directory.
STUBS=$DIR/arm-riscos-gnueabihf/lib/mixed-stubs
mkdir -p "$STUBS"
for so in libunixlib.so.5 libstdc++.so.6 libgcc_s.so.1 libm.so.1; do
  "$CC" $RISCOS_CFLAGS -fPIC -shared -nostdlib -Wl,-soname,$so -o "$STUBS/$so" "$HERE/stub.c"
done
echo "installed the stand-ins: $STUBS"
install -m 755 "$HERE/riscos-mixed-exports" "$DIR/bin/riscos-mixed-exports"
echo "installed $DIR/bin/riscos-mixed-exports"
