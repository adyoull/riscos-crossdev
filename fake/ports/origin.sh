#!/bin/bash
# Print the record of the ports' fakes from fake/fake_origin.md, one file a
# line, for the other scripts to read:
#
#   FILE SHA256 REPOSITORY COMMIT PATH
#
#   fake/ports/origin.sh [FAKE_ORIGIN_MD]
#
# FILE is relative to fake/ports. fake_origin.md is written by
# fake/ports/sync.sh; its table is the only record of where each came from.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
MD=${1:-$HERE/../fake_origin.md}
[ -f "$MD" ] || { echo "no $MD: run fake/ports/sync.sh or update.sh" >&2; exit 2; }
awk -F'|' '
  function strip(s) { gsub(/\]\([^)]*\)/, "", s); gsub(/[][`]/, "", s); gsub(/^ +| +$/, "", s); return s }
  /^<!-- files -->/ { on = 1; next }
  /^<!-- \/files -->/ { on = 0 }
  on && /^\| `/ { print strip($2), strip($6), strip($3), strip($4), strip($5) }' "$MD"
