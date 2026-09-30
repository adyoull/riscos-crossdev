#!/bin/bash
# Download the riscos-mesa devkit named in devkit/DEVKIT, check its sha256,
# and unpack it into $RISCOS_DEVKIT (default devkit/env).
#   devkit/install.sh [TARBALL]
# With TARBALL (a file you already have), it's checked and unpacked
# without downloading. An older devkit already in $RISCOS_DEVKIT is moved
# to $RISCOS_DEVKIT.old first.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../env.sh"
read -r FILE SUM URL < <(grep -v '^#' "$HERE/DEVKIT" | grep .)
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
if [ -n "$(ls -A "$RISCOS_DEVKIT" 2>/dev/null)" ]; then
  rm -rf "$RISCOS_DEVKIT.old"; mv "$RISCOS_DEVKIT" "$RISCOS_DEVKIT.old"
  echo "the previous devkit is in $RISCOS_DEVKIT.old"
fi
mkdir -p "$RISCOS_DEVKIT"
tar xzf "$TARBALL" -C "$RISCOS_DEVKIT" --strip-components=1
echo "installed in $RISCOS_DEVKIT: $(cat "$RISCOS_DEVKIT/VERSION")"
