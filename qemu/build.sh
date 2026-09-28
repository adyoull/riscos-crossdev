#!/bin/bash
# Build qemu-arm-aligntrap: QEMU 8.2.2 (linux-user, ARM only) with
# qemu-8.2.2-align-trap.patch, which makes it trap unaligned accesses the
# way RISC OS does. Installed as $RISCOS_TOOLCHAIN/bin/qemu-arm-aligntrap
# (so the prebuilt toolchain tarball carries it too).
# Needs: build-essential, ninja-build, python3-venv, libglib2.0-dev (SETUP.md).
#   qemu/build.sh
# From riscos-ffmpeg (tests/qemu/build-qemu.sh).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../env.sh"
: "${DL:=$HERE/../toolchain/dl}"
: "${WORK:=$HERE/work}"
TARBALL=qemu_8.2.2+ds.orig.tar.xz
SUM=5e692dd20950a819ff6550cd3974e00319a93f47c0a15f808c58df1a9e4d2478
URL=https://archive.ubuntu.com/ubuntu/pool/main/q/qemu/$TARBALL
mkdir -p "$DL" "$WORK" "$RISCOS_TOOLCHAIN/bin"
[ -s "$DL/$TARBALL" ] || curl -fsSL --retry 3 -o "$DL/$TARBALL" "$URL"
echo "$SUM  $DL/$TARBALL" | sha256sum -c --quiet
cd "$WORK"
rm -rf qemu-8.2.2 && tar xf "$DL/$TARBALL"
cd qemu-8.2.2
patch -p1 -s < "$HERE/qemu-8.2.2-align-trap.patch"
mkdir build && cd build
../configure --target-list=arm-linux-user --disable-system --disable-docs \
  --disable-tools --disable-werror --disable-install-blobs >/dev/null
ninja qemu-arm >/dev/null
cp qemu-arm "$RISCOS_TOOLCHAIN/bin/qemu-arm-aligntrap"
echo "$RISCOS_TOOLCHAIN/bin/qemu-arm-aligntrap (qemu/work can be deleted)"
