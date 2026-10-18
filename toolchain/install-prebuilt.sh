#!/bin/bash
# Download the prebuilt toolchain named in toolchain/PREBUILT, check its
# sha256, and unpack it into $RISCOS_TOOLCHAIN (default toolchain/env).
#   toolchain/install-prebuilt.sh [TARBALL]
# With TARBALL (a file you already have), it's checked and unpacked
# without downloading. The toolchain can live anywhere: set
# RISCOS_TOOLCHAIN to the directory when you use it from elsewhere.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../env.sh"
read -r FILE SUM URL < <(grep -v '^#' "$HERE/PREBUILT" | grep .)
[ "$(uname -m)" = x86_64 ] || echo "warning: the prebuilt toolchain is for x86_64 Linux; this is $(uname -m). Use toolchain/build.sh." >&2
: "${DL:=$HERE/dl}"
TARBALL=${1:-$DL/$FILE}
if [ ! -s "$TARBALL" ]; then
  mkdir -p "$DL"
  echo "fetch $URL"
  curl -fSL --retry 3 -o "$TARBALL.part" "$URL"
  mv "$TARBALL.part" "$TARBALL"
fi
echo "$SUM  $TARBALL" | sha256sum -c --quiet || {
  echo "checksum wrong: $TARBALL is not the $FILE this version of riscos-crossdev expects" >&2; exit 1; }
if [ -e "$RISCOS_TOOLCHAIN" ] && [ -n "$(ls -A "$RISCOS_TOOLCHAIN" 2>/dev/null)" ]; then
  echo "$RISCOS_TOOLCHAIN is not empty: move it away first" >&2; exit 1
fi
mkdir -p "$RISCOS_TOOLCHAIN"
tar xJf "$TARBALL" -C "$RISCOS_TOOLCHAIN" --strip-components=1
"$HERE/relocate.sh" "$RISCOS_TOOLCHAIN"
echo "installed in $RISCOS_TOOLCHAIN:"
head -1 "$RISCOS_TOOLCHAIN/BUILDINFO.txt"
"$RISCOS_TOOLCHAIN/bin/arm-riscos-gnueabihf-gcc" --version | head -1
