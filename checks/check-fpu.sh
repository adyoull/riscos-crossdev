#!/bin/bash
# List programs, libraries and objects that use VFPv4-only instructions
# (fused multiply-add, half-precision conversion). Those won't run on VFPv3
# machines (Cortex-A8/A9 boards: BeagleBoard-xM, Panda, IGEPv2, ARMini,
# i.MX6), which RISC OS 5 still supports.
#
#   checks/check-fpu.sh FILE...        (ELF programs, .a or .o files)
#
# Exit status 1 if any file has them. From riscos-warzone2100.
. "$(dirname "$0")/../env.sh"
[ $# -gt 0 ] || { echo "usage: $0 FILE..." >&2; exit 2; }
OD=$RISCOS_HOST-objdump
bad=0
for f in "$@"; do
  [ -e "$f" ] || { echo "no such file: $f" >&2; exit 2; }
  n=$("$OD" -d "$f" 2>/dev/null | grep -cE $'\t(vfma|vfms|vfnma|vfnms)|vcvt[bt]?\\.f(16|32)\\.f(32|16)')
  if [ "$n" -gt 0 ]; then echo "VFPv4: $n instructions in $f"; bad=1; fi
done
[ $bad = 0 ] && echo "OK: no VFPv4-only instructions (runs on VFPv3)"
exit $bad
