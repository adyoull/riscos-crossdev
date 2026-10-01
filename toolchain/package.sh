#!/bin/bash
# Pack the built toolchain ($RISCOS_TOOLCHAIN) as a release tarball:
#   toolchain/package.sh VERSION      e.g. toolchain/package.sh 1.2
# Output: out/riscos-crossdev-toolchain-VERSION-x86_64-linux.tar.xz and its
# .sha256. Put the sha256 in toolchain/PREBUILT before tagging vVERSION.
# Run it on a clean build (toolchain/build.sh all, then qemu/build.sh).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../env.sh"
VERSION=${1:?usage: $0 VERSION}
ARCH=$(uname -m)
NAME=riscos-crossdev-toolchain-$VERSION-$ARCH-linux
OUT=$RCD_DIR/out
T=$RISCOS_TOOLCHAIN
for f in bin/arm-riscos-gnueabihf-gcc bin/elf2aif bin/qemu-arm-aligntrap; do
  [ -x "$T/$f" ] || { echo "missing $T/$f: build it first" >&2; exit 1; }
done
mkdir -p "$OUT"
# What's in it, for anyone who unpacks it later.
{
  echo "riscos-crossdev toolchain $VERSION ($ARCH Linux host)"
  echo "Built $(date -u +%Y-%m-%d) from riscos-crossdev $(git -C "$RCD_DIR" describe --always --dirty 2>/dev/null || echo '(no git)')"
  echo "Host: $(. /etc/os-release && echo "$PRETTY_NAME"), $(gcc --version | head -1)"
  echo
  "$T/bin/arm-riscos-gnueabihf-gcc" --version | head -1
  "$T/bin/arm-riscos-gnueabihf-ld" --version | head -1
  "$T/bin/qemu-arm-aligntrap" --version | head -1
  echo
  echo "Sources (sha256):"
  grep -v '^#' "$HERE/SOURCES" | awk 'NF==3 {print "  " $2 "  " $1}'
  echo "  $(grep ^SUM= "$RCD_DIR/qemu/build.sh" | cut -d= -f2)  qemu_8.2.2+ds.orig.tar.xz (+ qemu/qemu-8.2.2-align-trap.patch)"
  echo
  echo "Licences: see LICENCES.md in the riscos-crossdev repository."
} > "$T/BUILDINFO.txt"
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime="@$(date +%s)" \
    --transform "s|^\.|$NAME|" -C "$T" -cf - . | xz -T0 -9 > "$OUT/$NAME.tar.xz"
( cd "$OUT" && sha256sum "$NAME.tar.xz" > "$NAME.tar.xz.sha256" )
ls -l "$OUT/$NAME.tar.xz"; cat "$OUT/$NAME.tar.xz.sha256"
