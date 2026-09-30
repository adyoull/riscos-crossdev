#!/bin/bash
# Check the installed riscos-mesa devkit against this toolchain:
#  - every library is VFPv3 (checks/check-fpu.sh);
#  - its six examples build with this toolchain, and each linked program
#    passes checks/check-all.sh (stack probes, FPU, UnixLib).
# The examples are built unstripped in devkit/out (the checks need the
# symbols); the devkit itself isn't changed.
#   devkit/check.sh
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../env.sh"
[ -f "$RISCOS_DEVKIT/VERSION" ] || { echo "no devkit in $RISCOS_DEVKIT: run make devkit" >&2; exit 1; }
echo "$(cat "$RISCOS_DEVKIT/VERSION") in $RISCOS_DEVKIT"
rc=0
"$HERE/../checks/check-fpu.sh" "$RISCOS_DEVKIT"/lib/*.a || rc=1
OUT=$HERE/out; rm -rf "$OUT"; mkdir -p "$OUT"
cp -r "$RISCOS_DEVKIT/examples" "$OUT/examples"
if ! make -s -C "$OUT/examples" DEVKIT="$RISCOS_DEVKIT" GCCSDK_ENV="$RISCOS_TOOLCHAIN" \
     LDFLAGS="-static -L$RISCOS_DEVKIT/lib" > "$OUT/build.log" 2>&1; then
  cat "$OUT/build.log"; echo "FAIL: the devkit examples don't build"; exit 1
fi
n=0
for p in "$OUT"/examples/build/*/'!RunImage,e1f'; do
  n=$((n+1))
  echo "-- $(basename "$(dirname "$p")")"
  "$HERE/../checks/check-all.sh" "$p" > "$OUT/check.log" 2>&1 || { cat "$OUT/check.log"; rc=1; continue; }
  tail -1 "$OUT/check.log"
done
[ "$n" = 6 ] || { echo "FAIL: $n examples built, expected 6"; rc=1; }
[ $rc = 0 ] && echo "devkit check passed: $n examples"
exit $rc
