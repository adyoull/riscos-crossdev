#!/bin/bash
# Check that linked RISC OS programs are static: no dynamic section, no
# program interpreter, no shared libraries needed. Or, for a "mixed"
# program (linked with -rdynamic; riscos-crossdev 1.11), that UnixLib,
# libstdc++ and libgcc are linked in and only its own libraries are shared.
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
    interp=$(echo "$ph" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')
    sys=$(echo "$need" | tr ' ' '\n' | grep -E '^lib(unixlib|stdc\+\+|gcc_s|m|c|pthread)\.so' | tr '\n' ' ')
    mixed=$($RISCOS_HOST-nm "$f" 2>/dev/null | grep -c ' T __gnu_Unwind_Find_exidx$')
    if [ "$interp" = ld-riscos/so/2 ] && [ -n "$need" ] && [ -z "$sys" ] && [ "$mixed" = 1 ]; then
      echo "OK: $f is mixed: UnixLib linked in; shared: $need(needs !SharedLibs with ld-riscos/so/2)"
    elif [ -n "$sys" ]; then
      echo "WRONG: $f needs the shared $sys: UnixLib, libstdc++ and libgcc must be linked in (-static, or -rdynamic for a mixed program)" >&2
      bad=1
    elif [ "$interp" = ld-riscos/so/2 ] && [ -z "$need" ]; then
      echo "WRONG: $f is dynamically linked but needs no shared library: drop -rdynamic" >&2
      bad=1
    elif [ "$interp" = ld-riscos/so/2 ]; then
      echo "WRONG: $f is dynamically linked without crtmixed.o: link it with this toolchain's gcc -rdynamic" >&2
      bad=1
    else
      echo "WRONG: $f is dynamically linked${need:+ (needs $need)}: link it with -static" >&2
      bad=1
    fi
  else
    echo "OK: $f is static"
  fi
done
exit $bad
