#!/bin/bash
# Check shared libraries (.so) for "mixed" RISC OS programs (riscos-crossdev
# 1.11): built -fPIC -shared -nostdlib, so that they use the program's
# UnixLib rather than carrying their own.
#
#   checks/check-shared-lib.sh LIBRARY.so...
#
# A library is wrong if it needs a shared UnixLib, libstdc++, libgcc_s or
# libm (those are linked into the program), if it has text relocations
# (non-PIC code: SOManager shares the code between programs), or if it
# defines UnixLib's own functions (it was linked with libunixlib.a: two
# copies of UnixLib, two heaps).
. "$(dirname "$0")/../env.sh"
[ $# -gt 0 ] || { echo "usage: $0 LIBRARY.so..." >&2; exit 2; }
bad=0
for f in "$@"; do
  [ -f "$f" ] || { echo "no such file: $f" >&2; exit 2; }
  dyn=$($RISCOS_HOST-readelf -dW "$f" 2>/dev/null) || { echo "WRONG: $f is not an ELF file" >&2; bad=1; continue; }
  echo "$dyn" | grep -q '(SONAME)' || { echo "WRONG: $f is not a shared library (no SONAME): link it with -shared -Wl,-soname,..." >&2; bad=1; continue; }
  sys=$(echo "$dyn" | awk '/\(NEEDED\)/ {print $NF}' | tr -d '[]' | grep -E '^lib(unixlib|stdc\+\+|gcc_s|m|c|pthread)\.so' | tr '\n' ' ')
  own=$($RISCOS_HOST-nm -D --defined-only "$f" | awk '{print $3}' | grep -xE 'malloc|free|printf|__unixinit|_main|__main' | tr '\n' ' ')
  if [ -n "$sys" ]; then
    echo "WRONG: $f needs $sys: link it with -nostdlib (the program provides them)" >&2; bad=1
  elif echo "$dyn" | grep -q '(TEXTREL)'; then
    echo "WRONG: $f has text relocations: compile all of it with -fPIC" >&2; bad=1
  elif [ -n "$own" ]; then
    echo "WRONG: $f defines UnixLib's $own: link it with -nostdlib, not with libunixlib.a" >&2; bad=1
  else
    echo "OK: $f: $(echo "$dyn" | sed -n 's/.*(SONAME).*\[\(.*\)\]/\1/p'), PIC, uses the program's UnixLib"
  fi
done
exit $bad
