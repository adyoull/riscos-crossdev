#!/bin/bash
# Check that linked RISC OS programs are static: no dynamic section, no
# program interpreter, no shared libraries needed.
#
#   checks/check-static.sh PROGRAM.elf...     (before elf2aif)
#
# Why: elf2aif and RISC OS run static programs. A program that needs
# libunixlib.so (or libstdc++.so, libm.so) only runs through !SharedLibs'
# ELF loader, and it doesn't use the libunixlib.a you just built. Up to
# riscos-crossdev 1.2 a link without -static did exactly that, silently
# (found by riscos-gtk); from 1.3 the toolchain has no shared libraries and
# links statically by default, but a build that brings its own shared
# libraries, or another toolchain, can still produce one.
. "$(dirname "$0")/../env.sh"
[ $# -gt 0 ] || { echo "usage: $0 PROGRAM.elf..." >&2; exit 2; }
bad=0
for f in "$@"; do
  [ -f "$f" ] || { echo "no such file: $f" >&2; exit 2; }
  ph=$($RISCOS_HOST-readelf -lW "$f" 2>/dev/null) || { echo "WRONG: $f is not an ELF file" >&2; bad=1; continue; }
  if echo "$ph" | grep -qE '^ +(DYNAMIC|INTERP) '; then
    need=$($RISCOS_HOST-readelf -dW "$f" | awk '/\(NEEDED\)/ {print $NF}' | tr -d '[]' | tr '\n' ' ')
    echo "WRONG: $f is dynamically linked${need:+ (needs $need)}: link it with -static" >&2
    bad=1
  else
    echo "OK: $f is static"
  fi
done
exit $bad
