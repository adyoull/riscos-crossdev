#!/bin/bash
# Run every check on a linked RISC OS program (the unstripped ELF):
# stack probes, FPU level and UnixLib consistency. The unaligned-access
# check works on sources instead (checks/check-unaligned.sh).
#
#   checks/check-all.sh PROGRAM.elf [LIBRARY.a ...]
#
# Libraries given after the program are checked for VFPv4 instructions too
# (useful for a devkit you link against). Exit status 1 if any check fails.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../env.sh"
ELF=$1
[ -f "$ELF" ] || { echo "usage: $0 PROGRAM.elf [LIBRARY.a ...]" >&2; exit 2; }
rc=0
echo "-- stack probes"; python3 "$HERE/check-stack-probes.py" "$ELF" || rc=1
echo "-- FPU level";    "$HERE/check-fpu.sh" "$@" || rc=1
echo "-- UnixLib";      "$HERE/check-unixlib.sh" "$ELF" || rc=1
[ $rc = 0 ] && echo "all checks passed: $ELF" || echo "CHECKS FAILED: $ELF"
exit $rc
