#!/bin/bash
# Check the ports' own RISC OS headers against UnixLib's real ones, so a
# mistake in a port's fake is found here and sent back to the port:
#
#  - every SWI number in a port's swis.h is UnixLib's;
#  - the register-mask macros a port's swis.h defines (_IN, _INR, _OUT,
#    _OUTR, _BLOCK, _RETURN, _FLAGS, _C, _Z, _N) give UnixLib's values;
#  - a port's kernel.h has _kernel_oserror as on RISC OS (int errnum,
#    char errmess[252]) and ten registers in _kernel_swi_regs. Registers
#    may be int or long: long is a port's choice for 64-bit host tests.
#
#   fake/ports/check-headers.sh        (run by make check)
#
# The ports keep their own headers; this only reports. A problem already
# sent to its port in a handoff goes in fake/ports/REPORTED, one line as
# printed here, and is then a warning instead of a failure until the port
# fixes it (then delete the line).
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../env.sh"
UL=$RISCOS_TOOLCHAIN/arm-riscos-gnueabihf/include/swis.h
[ -f "$UL" ] || { echo "no $UL: install the toolchain" >&2; exit 2; }
cd "$HERE"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
./origin.sh > "$TMP/origin"
problems=$TMP/problems; : > "$problems"
repo() { awk -v f="$1" '$1 == f {print $3}' "$TMP/origin"; }
CC=${HOST_CC:-gcc}

echo "-- SWI numbers"
for f in $(awk '$1 ~ /(^|\/)swis\.h$/ {print $1}' "$TMP/origin"); do
  gawk -v F="$f" -v R="$(repo "$f")" '
    function v(t) { gsub(/[()]/, "", t); return t ~ /^0[xX][0-9A-Fa-f]+$/ ? strtonum(t) : -1 }
    /^[ \t]*#[ \t]*define[ \t]/ { sub(/^[ \t]*#[ \t]*define[ \t]+/, "")
      if (v($2) < 0 || $1 !~ /^X?[A-Z][A-Za-z0-9]*_[A-Za-z0-9_]+$/) next
      if (FNR == NR) { u[$1] = v($2); next }
      if (($1 in u) && u[$1] != v($2)) printf "%s (%s): %s is 0x%x, UnixLib has 0x%x\n", F, R, $1, v($2), u[$1] }' \
    "$UL" "$f" >> "$problems"
done

echo "-- register masks"
# UnixLib's macros, renamed R_..., to compare against.
sed -nE '/^#define[[:space:]]+_(FLAGS|IN|INR|OUT|OUTR|BLOCK|RETURN|C|Z|N)\b/{
  s/\b_(FLAGS|IN|INR|OUT|OUTR|BLOCK|RETURN|C|Z|N)\b/R_\1/g; p }' "$UL" > "$TMP/real.h"
for f in $(awk '$1 ~ /(^|\/)swis\.h$/ {print $1}' "$TMP/origin"); do
  grep -E '^[[:space:]]*#[[:space:]]*define[[:space:]]+_(FLAGS|IN|INR|OUT|OUTR|BLOCK|RETURN|C|Z|N)\b' "$f" > "$TMP/port.h" || continue
  cat > "$TMP/masks.c" <<'EOF'
#include <stdio.h>
#include "real.h"
#include "port.h"
static int bad;
#define EQ(what, a, b) do { if ((unsigned) (a) != (unsigned) (b)) { \
  printf("%s gives 0x%x, UnixLib's 0x%x\n", what, (unsigned) (a), (unsigned) (b)); bad = 1; } } while (0)
int main(void) {
  char w[64]; int i, j;
  for (i = 0; i < 10; i++) {
#ifdef _IN
    sprintf(w, "_IN(%d)", i); EQ(w, _IN(i), R_IN(i));
#endif
#ifdef _OUT
    sprintf(w, "_OUT(%d)", i); EQ(w, _OUT(i), R_OUT(i));
#endif
#ifdef _BLOCK
    sprintf(w, "_BLOCK(%d)", i); EQ(w, _BLOCK(i), R_BLOCK(i));
#endif
#ifdef _RETURN
    sprintf(w, "_RETURN(%d)", i); EQ(w, _RETURN(i), R_RETURN(i));
#endif
    for (j = i; j < 10; j++) {
#ifdef _INR
      sprintf(w, "_INR(%d,%d)", i, j); EQ(w, _INR(i, j), R_INR(i, j));
#endif
#ifdef _OUTR
      sprintf(w, "_OUTR(%d,%d)", i, j); EQ(w, _OUTR(i, j), R_OUTR(i, j));
#endif
    }
  }
#ifdef _FLAGS
  EQ("_FLAGS", _FLAGS, R_FLAGS);
# ifdef _OUT
  EQ("_OUT(_FLAGS)", _OUT(_FLAGS), R_OUT(R_FLAGS));
# endif
# ifdef _RETURN
  EQ("_RETURN(_FLAGS)", _RETURN(_FLAGS), R_RETURN(R_FLAGS));
# endif
#endif
#ifdef _C
  EQ("_C", _C, R_C);
#endif
#ifdef _Z
  EQ("_Z", _Z, R_Z);
#endif
#ifdef _N
  EQ("_N", _N, R_N);
#endif
  return bad;
}
EOF
  if $CC -w -o "$TMP/masks" "$TMP/masks.c" 2>"$TMP/err"; then
    "$TMP/masks" | sed "s|^|$f ($(repo "$f")): |" >> "$problems"
  else
    echo "$f ($(repo "$f")): its mask macros don't compile on their own: $(head -1 "$TMP/err")" >> "$problems"
  fi
done

echo "-- kernel.h types"
mkdir -p "$TMP/inc" && ln -s "$HERE/.." "$TMP/inc/rcdfake"   # ysflight's fakeplus includes <rcdfake/...>
for f in $(awk '$1 ~ /(^|\/)kernel\.h$/ {print $1}' "$TMP/origin"); do
  { echo '#include <stddef.h>'; echo "#include \"$HERE/$f\""
    if grep -q '_kernel_oserror' "$f"; then
      echo '_Static_assert(offsetof(_kernel_oserror, errnum) == 0 && sizeof(((_kernel_oserror *) 0)->errnum) == 4, "_kernel_oserror: errnum is a 4-byte int first");'
      echo '_Static_assert(offsetof(_kernel_oserror, errmess) == 4 && sizeof(((_kernel_oserror *) 0)->errmess) == 252, "_kernel_oserror: errmess is char[252] after errnum");'
    fi
    if grep -q '_kernel_swi_regs' "$f"; then
      echo '_Static_assert(sizeof(((_kernel_swi_regs *) 0)->r) / sizeof(((_kernel_swi_regs *) 0)->r[0]) == 10, "_kernel_swi_regs: ten registers, r[10]");'
    fi; } > "$TMP/k.c"
  $CC -fsyntax-only -w -I"$TMP/inc" "$TMP/k.c" 2>"$TMP/err" ||
    grep -E '^[^ ].*: error: ' "$TMP/err" | sed -E "s|.*: error: (static assertion failed: )?|$f ($(repo "$f")): |" >> "$problems"
done

fails=0
[ -f REPORTED ] || : > REPORTED
while IFS= read -r p; do
  if grep -qxF -- "$p" REPORTED; then echo "known (reported): $p"
  else echo "WRONG: $p"; fails=$((fails+1)); fi
done < "$problems"
grep -v '^#' REPORTED | grep . | while IFS= read -r p; do
  grep -qxF -- "$p" "$problems" || echo "fixed now: remove from fake/ports/REPORTED: $p"
done
n=$(awk '$1 ~ /(^|\/)(swis|kernel)\.h$/' "$TMP/origin" | wc -l)
if [ $fails = 0 ]; then echo "the ports' headers agree with UnixLib ($n headers checked)"
else echo "$fails problems: send each to its port in a handoff, then list it in fake/ports/REPORTED"; fi
exit $fails
