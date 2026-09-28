#!/bin/bash
# Check that qemu-arm-aligntrap and aligntrap.sh really apply RISC OS's
# rules: an unaligned word load is stopped (SIGBUS, 135), the same load
# aligned runs, and a VFPv4 instruction is stopped on the Cortex-A8 (SIGILL,
# 132). If this passes, a QEMU test that passes means something.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../env.sh"
OUT=$HERE/selftest/out; mkdir -p "$OUT"
export QEMU=${QEMU:-$RISCOS_TOOLCHAIN/bin/qemu-arm-aligntrap}
[ -x "$QEMU" ] || { echo "no $QEMU: run qemu/build.sh (or make prebuilt)" >&2; exit 1; }
CC="arm-linux-gnueabihf-gcc -O2 -no-pie -mno-unaligned-access"
$CC -mcpu=cortex-a8 -mfpu=vfpv3 -mfloat-abi=hard -o "$OUT/unaligned" "$HERE/selftest/unaligned.c"
$CC -mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard -o "$OUT/vfpv4" "$HERE/selftest/vfpv4.c"
fails=0
expect() {  # status what command...
  local want=$1 what=$2; shift 2
  ( "$@" >/dev/null 2>&1; exit $? ) 2>/dev/null; local got=$?
  if [ "$got" = "$want" ]; then echo "ok   $what (exit $got)"
  else echo "FAIL $what: exit $got, expected $want"; fails=$((fails+1)); fi
}
expect 0   "aligned word load runs"          "$HERE/aligntrap.sh" "$OUT/unaligned" aligned
expect 135 "unaligned word load is trapped"  "$HERE/aligntrap.sh" "$OUT/unaligned"
expect 132 "VFPv4 on a Cortex-A8 is trapped" "$HERE/aligntrap.sh" "$OUT/vfpv4"
QEMU_CPU=cortex-a7 expect 0 "VFPv4 on a Cortex-A7 runs" "$HERE/aligntrap.sh" "$OUT/vfpv4"
[ $fails = 0 ] && echo "qemu selftest passed"
exit $fails
