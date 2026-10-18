#!/bin/bash
# Check the checks: each must pass good code and fail code with the fault
# it looks for. If this passes, a check that passes means something.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../env.sh"
command -v $RISCOS_HOST-gcc >/dev/null || { echo "no toolchain in $RISCOS_TOOLCHAIN" >&2; exit 1; }
S=$HERE/selftest; OUT=$S/out; mkdir -p "$OUT"
CC="$RISCOS_HOST-gcc -O2 -mfloat-abi=hard"
fails=0
expect() {  # status what command...
  local want=$1 what=$2; shift 2
  ( "$@" >"$OUT/last.log" 2>&1; exit $? ) 2>/dev/null; local got=$?
  if [ "$got" = "$want" ]; then echo "ok   $what"
  else echo "FAIL $what: exit $got, expected $want"; cat "$OUT/last.log"; fails=$((fails+1)); fi
}
$CC -mfpu=vfpv3 -fstack-clash-protection -static -o "$OUT/probed" "$S/bigframe.c"
$CC -mfpu=vfpv3 -fno-stack-clash-protection -static -o "$OUT/unprobed" "$S/bigframe.c"
$CC -mfpu=vfpv3 -c -o "$OUT/fma3.o" "$S/fma.c"
$CC -mfpu=vfpv4 -c -o "$OUT/fma4.o" "$S/fma.c"
expect 0 "stack probes: probed 16 KB frame passes (and the whole C library too)" \
  python3 "$HERE/check-stack-probes.py" "$OUT/probed"
expect 1 "stack probes: unprobed 16 KB frame fails" python3 "$HERE/check-stack-probes.py" "$OUT/unprobed"
expect 0 "FPU: VFPv3 code passes"   "$HERE/check-fpu.sh" "$OUT/fma3.o"
expect 1 "FPU: VFPv4 code fails"    "$HERE/check-fpu.sh" "$OUT/fma4.o"
expect 0 "FPU: the toolchain's own libraries are VFPv3" "$HERE/check-fpu.sh" \
  "$RISCOS_TOOLCHAIN"/arm-riscos-gnueabihf/lib/libunixlib.a \
  "$RISCOS_TOOLCHAIN"/arm-riscos-gnueabihf/lib/libstdc++.a \
  "$RISCOS_TOOLCHAIN"/lib/gcc/arm-riscos-gnueabihf/10.2.0/libgcc.a
expect 0 "FPU: an unstripped VFPv3 program passes" "$HERE/check-fpu.sh" "$OUT/probed"
$RISCOS_HOST-strip -o "$OUT/probed.stripped" "$OUT/probed"
expect 2 "FPU: a stripped program is refused (its data would read as code)" \
  "$HERE/check-fpu.sh" "$OUT/probed.stripped"
$CC -mfpu=vfpv3 -fstack-clash-protection -o "$OUT/nostatic" "$S/bigframe.c"
expect 0 "static: a link without -static is static" "$HERE/check-static.sh" "$OUT/nostatic"
expect 0 "static: the toolchain has no shared target libraries" \
  sh -c "! find '$RISCOS_TOOLCHAIN/arm-riscos-gnueabihf/lib' '$RISCOS_TOOLCHAIN/lib/gcc/arm-riscos-gnueabihf' -path '*/plugin' -prune -o -name '*.so*' -print | grep -q ."
$CC -mfpu=vfpv3 -fPIC -shared -nostdlib -o "$OUT/shared.so" "$S/fma.c"
expect 1 "static: a shared object is reported" "$HERE/check-static.sh" "$OUT/shared.so"
expect 0 "UnixLib: a linked program is consistent" "$HERE/check-unixlib.sh" "$OUT/probed"
expect 1 "UnixLib: the same program fails against the old 472-byte block" \
  env TICKER_BLOCK=472 "$HERE/check-unixlib.sh" "$OUT/probed"
expect 0 "UnixLib: the check needs no gawk" \
  sh -c "! grep -q strtonum '$HERE/check-unixlib.sh'"
expect 0 "toolchain: the .la files name where it is (libtool links of C++ work)" \
  "$HERE/../toolchain/relocate.sh" --check
expect 0 "PThreadTicker 0.03 is in the toolchain" \
  sh -c "strings -a '$RISCOS_TOOLCHAIN/riscos/PThrTicker,ffa' | grep -q 'PThreadTicker.0\.03'"
$CC -mfpu=vfpv3 -fstack-clash-protection -static -D_FILE_OFFSET_BITS=64 -o "$OUT/largefile" "$S/largefile.c"
expect 0 "UnixLib 5.0.2: -D_FILE_OFFSET_BITS=64 programs use the 64-bit calls" \
  sh -c "$RISCOS_HOST-nm '$OUT/largefile' | grep -q ' T __unixlib_fstat64\$' && $RISCOS_HOST-nm '$OUT/largefile' | grep -q ' T lseek64\$'"
expect 1 "unaligned: the bad cast is reported" "$HERE/check-unaligned.sh" "$S/castalign.c"
printf '%s\n' '# checked by hand' 'castalign\.c:.*uint32_t bad \(' > "$OUT/safe.txt"
expect 0 "unaligned: a safe list hides it" "$HERE/check-unaligned.sh" -s "$OUT/safe.txt" "$S/castalign.c"
[ $fails = 0 ] && echo "checks selftest passed"
exit $fails
