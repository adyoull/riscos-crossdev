#!/bin/bash
# Pack the optional GCC 16 toolchain ($GCC16_TOOLCHAIN, built by
# toolchain/gcc16/build.sh) as a release tarball:
#   toolchain/gcc16/package.sh VERSION     e.g. toolchain/gcc16/package.sh 1.13
# Output: out/riscos-crossdev-toolchain-gcc16-VERSION-x86_64-linux.tar.xz and
# its .sha256. It unpacks to a directory used as RISCOS_TOOLCHAIN.
# Copyright (c) 2026 Andrew Youll. MIT licence.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../env.sh"
VERSION=${1:?usage: $0 VERSION}
: "${GCC16_TOOLCHAIN:=$HERE/../env-gcc16}"
P=$GCC16_TOOLCHAIN
NAME=riscos-crossdev-toolchain-gcc16-$VERSION-$(uname -m)-linux
OUT=$RCD_DIR/out
for f in bin/arm-riscos-gnueabihf-gcc bin/elf2aif bin/qemu-arm-aligntrap BUILDINFO.txt \
         arm-riscos-gnueabihf/lib/libunixlib.a arm-riscos-gnueabihf/lib/crtmixed.o; do
  [ -e "$P/$f" ] || { echo "missing $P/$f: run toolchain/gcc16/build.sh" >&2; exit 1; }
done
# No build paths in what ships (the .la files name the prefix).
find "$P" -name '*.la' -delete
if grep -rlI --exclude=BUILDINFO.txt -e "$RCD_DIR" -e /opt/gcc16 "$P" | grep -v '/plugin/include/' | head -1 | grep -q .; then
  echo "package.sh: build paths in:"; grep -rlI -e "$RCD_DIR" -e /opt/gcc16 "$P" | grep -v '/plugin/include/' | head; exit 1
fi
sed -i "1s/.*/riscos-crossdev toolchain gcc16 $VERSION (optional; $(uname -m) Linux host)/" "$P/BUILDINFO.txt"
mkdir -p "$OUT"
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime="@$(date +%s)" \
    --transform "s|^\.|$NAME|" -C "$P" -cf - . | xz -T0 -9 > "$OUT/$NAME.tar.xz"
( cd "$OUT" && sha256sum "$NAME.tar.xz" > "$NAME.tar.xz.sha256" )
ls -l "$OUT/$NAME.tar.xz"; cat "$OUT/$NAME.tar.xz.sha256"
