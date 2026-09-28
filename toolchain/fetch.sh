#!/bin/bash
# Download the toolchain sources listed in toolchain/SOURCES into $DL
# (default toolchain/dl) and check their sha256. Files already there are
# only checked. If this machine can't reach a URL, put the file in $DL by
# hand under the name in SOURCES.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
: "${DL:=$HERE/dl}"
mkdir -p "$DL"
bad=0
while read -r file sum url; do
  case $file in ''|'#'*) continue;; esac
  if [ ! -s "$DL/$file" ]; then
    echo "fetch $file"
    if ! curl -fsSL --retry 3 -o "$DL/$file.part" "$url"; then
      rm -f "$DL/$file.part"; echo "  FAILED: $url" >&2; bad=1; continue
    fi
    mv "$DL/$file.part" "$DL/$file"
  fi
  if [ "$(sha256sum < "$DL/$file" | cut -d' ' -f1)" != "$sum" ]; then
    echo "  CHECKSUM WRONG: $DL/$file" >&2; bad=1
  fi
done < "$HERE/SOURCES"
[ $bad = 0 ] && echo "all toolchain sources present and checked in $DL"
exit $bad
