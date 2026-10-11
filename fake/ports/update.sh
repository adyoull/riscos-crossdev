#!/bin/bash
# Bring the ports' fakes up to date with each port's latest commit on GitHub:
# clone each repository named in fake/ports/FILES (shallow, into a scratch
# directory), copy the fakes again and regenerate the shared SWI numbers
# (sync.sh), and say what changed.
#
#   fake/ports/update.sh [CHECKOUTS]
#
# With CHECKOUTS (a directory of existing checkouts, as sync.sh takes) it
# uses those instead of cloning. Then run make check and commit; the
# weekly workflow (.github/workflows/update-fakes.yml) does all of this and
# opens a pull request. Writes the summary to $SUMMARY too, if that is set.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OWNER=${OWNER:-adyoull}
export OWNER
if [ $# -gt 0 ]; then
  SRC=$1
else
  SRC=$(mktemp -d); trap 'rm -rf "$SRC"' EXIT
  for repo in $(grep -v '^#' "$HERE/FILES" | awk 'NF {print $2}' | sort -u); do
    echo "clone $repo"
    git clone -q --depth 1 "https://github.com/$OWNER/$repo" "$SRC/$repo"
  done
fi
old=$(mktemp); "$HERE/origin.sh" > "$old" 2>/dev/null || : > "$old"
oldswi=$(mktemp); cp "$HERE/../swinames.h" "$oldswi"
"$HERE/sync.sh" "$SRC"
new=$(mktemp); "$HERE/origin.sh" > "$new"
report=$(awk -v OLD="$old" 'FILENAME == OLD { sha[$1]=$2; c[$1]=$4; next }
     { if (!($1 in sha)) print "- new: `" $1 "` (" $3 " " $4 ")";
       else if (sha[$1] != $2) print "- changed: `" $1 "` (" $3 " " c[$1] " -> " $4 ")";
       seen[$1]=1 }
     END { for (f in sha) if (!(f in seen)) print "- gone: `" f "`" }' "$old" "$new" | sort)
cmp -s "$oldswi" "$HERE/../swinames.h" || report="$report${report:+$'\n'}- \`fake/swinames.h\` changed: see the SWI section of \`fake/fake_origin.md\`"
rm -f "$old" "$new" "$oldswi"
echo "== changes since the last update"
echo "${report:-none}"
[ -z "${SUMMARY:-}" ] || echo "${report:-none}" > "$SUMMARY"
