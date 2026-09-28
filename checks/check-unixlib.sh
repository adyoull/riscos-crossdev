#!/bin/bash
# Check that a linked program has UnixLib 5.0.1's pthread ticker built
# consistently: the start-up code (_syslib.s) must claim the whole 472-byte
# pthread ticker block from the RMA (counters and the RMA copy of the
# ticker routines, used when the PThreadTicker module isn't loaded), and
# agree with the C side's __pthread_callevery_block_size.
#
#   checks/check-unixlib.sh PROGRAM.elf     (the unstripped ELF, before elf2aif)
#
# Why: _syslib.s includes asm_dec.s, and GCCSDK's UnixLib makefile didn't
# rebuild assembler files when an include changed. Two Warzone 2100 test
# builds shipped a stale _syslib.o that claimed a smaller block; the ticker
# handler was then copied past its end, corrupting the RMA and hanging the
# whole machine. After changing UnixLib, rebuild it from clean
# (toolchain/build.sh unixlib). From riscos-warzone2100.
. "$(dirname "$0")/../env.sh"
ELF=$1
[ -f "$ELF" ] || { echo "usage: $0 PROGRAM.elf" >&2; exit 2; }
OBJDUMP=$RISCOS_HOST-objdump
NM=$RISCOS_HOST-nm
"$NM" "$ELF" | grep -q ' __pthread_ticker_init$' ||
  { echo "WRONG: no __pthread_ticker_init: not linked with UnixLib 5.0.1" >&2; exit 1; }
# The claim: "mov r3, #<size>" then OS_Module (svc 0x2001e) in no_dynamic_area.
size=$("$OBJDUMP" -d "$ELF" | awk '/^[0-9a-f]+ <no_dynamic_area>:$/{p=1;next} p&&/^$/{exit}
  p&&/mov\tr3, #/{s=$0} p&&/svc\t0x0002001e/{sub(/.*#/,"",s); sub(/[ \t;].*/,"",s); print s; exit}')
want=472
# __pthread_callevery_block_size, a little-endian word in .data
addr=$("$NM" "$ELF" | awk '$3=="__pthread_callevery_block_size"{print $1}')
csize=$("$OBJDUMP" -s -j .data --start-address=0x$addr --stop-address=$(printf '0x%x' $((0x$addr+4))) "$ELF" |
  awk 'NR>4&&NF>=2{w=$2; print strtonum("0x" substr(w,7,2) substr(w,5,2) substr(w,3,2) substr(w,1,2)); exit}')
[ "$csize" = "$want" ] || { echo "WRONG: __pthread_callevery_block_size is '$csize', not $want" >&2; exit 1; }
case $size in
  $want) echo "OK: UnixLib claims the $want-byte pthread ticker block, and the C side agrees";;
  "") echo "can't find the ticker block claim in $ELF" >&2; exit 1;;
  *) echo "WRONG: UnixLib claims $size bytes for the pthread ticker block, not $want." >&2
     echo "Rebuild UnixLib from clean: toolchain/build.sh unixlib." >&2; exit 1;;
esac
