#!/bin/bash
# Bring fake/ports up to date with the ports' latest commits on GitHub:
# clone each repository named in fake/ports/FILES (shallow, into a scratch
# directory), copy the fakes again with sync.sh, and say which changed.
#
#   fake/ports/update.sh [CHECKOUTS]
#
# With CHECKOUTS (a directory of existing checkouts, as sync.sh takes) it
# uses those instead of cloning. Review the changes (git diff fake/ports),
# run make check, and commit.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OWNER=${OWNER:-adyoull}
if [ $# -gt 0 ]; then
  SRC=$1
else
  SRC=$(mktemp -d); trap 'rm -rf "$SRC"' EXIT
  for repo in $(grep -v '^#' "$HERE/FILES" | awk 'NF {print $2}' | sort -u); do
    echo "clone $repo"
    git clone -q --depth 1 "https://github.com/$OWNER/$repo" "$SRC/$repo"
  done
fi
old=$(mktemp); cp "$HERE/MANIFEST" "$old"
"$HERE/sync.sh" "$SRC"
echo "== changes since the last sync (FILE: old commit -> new commit)"
awk 'FNR==NR { if ($0 !~ /^#/) { sha[$1]=$2; c[$1]=$4 } next }
     $0 !~ /^#/ { if (!($1 in sha)) print "  new:     " $1 " (" $3 " " $4 ")";
                  else if (sha[$1] != $2) print "  changed: " $1 " (" c[$1] " -> " $4 ")";
                  seen[$1]=1 }
     END { for (f in sha) if (!(f in seen)) print "  gone:    " f }' "$old" "$HERE/MANIFEST"
rm -f "$old"
