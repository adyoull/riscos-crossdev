#!/bin/bash
# Move riscos-crossdev to a new release of one of its upstreams, as named
# in .riscos-deps. Run by .github/workflows/update-deps.yml (which then
# builds, checks and opens a pull request); it can be run by hand too.
#
#   toolchain/deps-hook.sh NAME OLD_TAG NEW_TAG
#
#   riscos-mesa     devkit/DEVKIT: the new riscos-mesa-devkit-<v>.tgz, its
#                   sha256 and URL.
#   riscos-unixlib  toolchain/SOURCES: the new unixlib-riscos.diff and
#                   PThreadTicker zip, checked against the release's
#                   SHA256SUMS. The toolchain must then be rebuilt
#                   (make toolchain) and released with a new tarball.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$HERE/..
NAME=${1:?usage: $0 NAME OLD_TAG NEW_TAG}; OLD=${2:?}; NEW=${3:?}
OWNER=${OWNER:-adyoull}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fetch() { curl -fsSL --retry 3 -o "$2" "$1"; }

case $NAME in
  riscos-mesa)
    v=${NEW#v}
    f=riscos-mesa-devkit-$v.tgz
    url=https://github.com/$OWNER/riscos-mesa/releases/download/$NEW/$f
    fetch "$url" "$TMP/$f"
    sum=$(sha256sum "$TMP/$f" | cut -d' ' -f1)
    awk -v line="$f $sum $url" '/^riscos-mesa-devkit-/ {print line; next} {print}' \
      "$ROOT/devkit/DEVKIT" > "$TMP/DEVKIT"
    mv "$TMP/DEVKIT" "$ROOT/devkit/DEVKIT"
    echo "devkit/DEVKIT: $f ($sum)"
    ;;
  riscos-unixlib)
    v=${NEW#v}
    base=https://github.com/$OWNER/riscos-unixlib/releases/download/$NEW
    fetch "$base/SHA256SUMS" "$TMP/SHA256SUMS"
    diffsum=$(awk '$2 == "unixlib-riscos.diff" {print $1}' "$TMP/SHA256SUMS")
    tick=$(awk '$2 ~ /^PThreadTicker-.*\.zip$/ {print $2}' "$TMP/SHA256SUMS")
    ticksum=$(awk -v t="$tick" '$2 == t {print $1}' "$TMP/SHA256SUMS")
    [ -n "$diffsum" ] && [ -n "$tick" ] || { echo "$NEW's SHA256SUMS has no unixlib-riscos.diff or PThreadTicker zip" >&2; exit 1; }
    fetch "$base/unixlib-riscos.diff" "$TMP/d"; fetch "$base/$tick" "$TMP/t"
    echo "$diffsum  $TMP/d" | sha256sum -c --quiet
    echo "$ticksum  $TMP/t" | sha256sum -c --quiet
    awk -v d="unixlib-riscos-$v.diff $diffsum $base/unixlib-riscos.diff" \
        -v t="$tick $ticksum $base/$tick" -v old="${OLD#v}" -v new="$v" '
      /^unixlib-riscos-.*\.diff / {print d; next}
      /^PThreadTicker-.*\.zip / {print t; next}
      /^#/ {gsub("UnixLib " old, "UnixLib " new); gsub("tag v" old, "tag v" new)}
      {print}' "$ROOT/toolchain/SOURCES" > "$TMP/SOURCES"
    mv "$TMP/SOURCES" "$ROOT/toolchain/SOURCES"
    echo "toolchain/SOURCES: unixlib-riscos-$v.diff ($diffsum), $tick ($ticksum)"
    echo "The toolchain must be rebuilt and released: make toolchain, make dist, toolchain/PREBUILT."
    ;;
  *)
    echo "deps-hook.sh: nothing to do for $NAME" >&2
    ;;
esac
