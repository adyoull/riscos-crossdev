#!/bin/bash
# qemu/aligntrap.sh PROGRAM [ARGS...]
#
# Runs an arm-linux-gnueabihf program (dynamically linked) under
# qemu-arm-aligntrap with RISC OS's rules:
#  - alignment checking on (SCTLR.A = 1) for the program's own code: an
#    unaligned LDR/STR/LDRH/STRH, or a NEON access not aligned to its element
#    size, stops the program with SIGBUS (exit status 135), where RISC OS
#    would give "abort on data transfer". glibc and ld.so are exempt: they
#    don't run on RISC OS, and their string functions rely on unaligned loads.
#  - a Cortex-A8 CPU (VFPv3 + NEON; no VFPv4 fused multiply-add), the
#    oldest ARMv7 core RISC OS 5 runs on. A VFPv4 instruction stops the
#    program with SIGILL (exit status 132). QEMU_CPU=cortex-a7 for VFPv4.
#
# Environment: QEMU (default: qemu-arm-aligntrap on PATH, from the toolchain),
# QEMU_ARGS (extra options, e.g. "-g 1234" to wait for gdb-multiarch),
# QEMU_LD_PREFIX (default /usr/arm-linux-gnueabihf).
# From riscos-ffmpeg (tests/qemu/aligntrap.sh).
set -u
prog=$1; shift
seg=$(arm-linux-gnueabihf-readelf -lW "$prog" | awk '$1=="LOAD" && / R E / {print $3, $6; exit}')
[ -n "$seg" ] || { echo "aligntrap.sh: no executable segment in $prog" >&2; exit 2; }
lo=$(( ${seg% *} )); hi=$(( ${seg% *} + ${seg#* } ))
if [ "$lo" = 0 ]; then
  echo "aligntrap.sh: $prog is position-independent; link it with -no-pie" >&2; exit 2
fi
export QEMU_ARM_ALIGN_TRAP=1
export QEMU_ARM_ALIGN_IGNORE=$(printf '0-%x,%x-ffffffff' $lo $hi)
export QEMU_LD_PREFIX=${QEMU_LD_PREFIX:-/usr/arm-linux-gnueabihf}
exec "${QEMU:-qemu-arm-aligntrap}" -cpu "${QEMU_CPU:-cortex-a8}" ${QEMU_ARGS:-} "$prog" "$@"
