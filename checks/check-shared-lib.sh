#!/bin/bash
# Check shared libraries (.so) for "mixed" RISC OS programs (riscos-crossdev
# 1.11): built -fPIC -shared -nodefaultlibs, so that they use the program's
# UnixLib rather than carrying their own.
#
#   checks/check-shared-lib.sh [--stand-ins] LIBRARY.so...
#
# --stand-ins accepts a library built for fully shared programs (GCCSDK's,
# say) that needs libunixlib.so.5, libstdc++.so.6, libgcc_s.so.1 or
# libm.so.1: the
# app ships riscos-crossdev's stand-ins under those names, so it still
# uses the program's UnixLib (docs/MIXED.md). Libraries you build yourself
# don't need them.
#
# A library is wrong if it needs a shared UnixLib, libstdc++, libgcc_s or
# libm (those are linked into the program), if it has text relocations
# (non-PIC code: SOManager shares the code between programs), or if it
# defines UnixLib's own functions (it was linked with libunixlib.a: two
# copies of UnixLib, two heaps).
#
# It warns (without failing) if the library exports its own copy of a
# function UnixLib or libstdc++ has, such as a private strlcpy. A mixed
# program exports the whole of UnixLib (from 1.12), and the loader looks
# in the program first, so the library would get UnixLib's instead of its
# own. Make the library's copy hidden (static, or -fvisibility=hidden).
. "$(dirname "$0")/../env.sh"
stand_ins=0
[ "${1:-}" = --stand-ins ] && { stand_ins=1; shift; }
[ $# -gt 0 ] || { echo "usage: $0 [--stand-ins] LIBRARY.so..." >&2; exit 2; }
bad=0
tc=$RISCOS_TOOLCHAIN/$RISCOS_HOST/lib
clash_list=$(mktemp); trap 'rm -f "$clash_list"' EXIT
{ $RISCOS_HOST-nm --defined-only "$tc/libunixlib.a" 2>/dev/null | awk 'NF==3 && $2 ~ /^[TDBRWV]$/ {print $3}'
  $RISCOS_HOST-nm --defined-only "$tc/libstdc++.a" 2>/dev/null | awk 'NF==3 && $2 ~ /^[TDBR]$/ {print $3}'; } | sort -u > "$clash_list"
for f in "$@"; do
  [ -f "$f" ] || { echo "no such file: $f" >&2; exit 2; }
  dyn=$($RISCOS_HOST-readelf -dW "$f" 2>/dev/null) || { echo "WRONG: $f is not an ELF file" >&2; bad=1; continue; }
  echo "$dyn" | grep -q '(SONAME)' || { echo "WRONG: $f is not a shared library (no SONAME): link it with -shared -Wl,-soname,..." >&2; bad=1; continue; }
  sys=$(echo "$dyn" | awk '/\(NEEDED\)/ {print $NF}' | tr -d '[]' | grep -E '^lib(unixlib|stdc\+\+|gcc_s|m|c|pthread)\.so' | tr '\n' ' ')
  via=
  if [ $stand_ins = 1 ] && [ -n "$sys" ]; then
    rest=$(for n in $sys; do case $n in libunixlib.so.5|libstdc++.so.6|libgcc_s.so.1|libm.so.1) ;; *) echo $n;; esac; done | tr '\n' ' ')
    [ -z "$rest" ] && { via=" (through the stand-ins for ${sys% })"; sys=; }
  fi
  own=$($RISCOS_HOST-nm -D --defined-only "$f" | awk '{print $3}' | grep -xE 'malloc|free|printf|__unixinit|_main|__main' | tr '\n' ' ')
  if [ -n "$sys" ]; then
    echo "WRONG: $f needs $sys: link it with -nodefaultlibs (the program provides them)" >&2; bad=1
  elif echo "$dyn" | grep -q '(TEXTREL)'; then
    echo "WRONG: $f has text relocations: compile all of it with -fPIC" >&2; bad=1
  elif [ -n "$own" ]; then
    echo "WRONG: $f defines UnixLib's $own: link it with -nodefaultlibs, not with libunixlib.a" >&2; bad=1
  else
    echo "OK: $f: $(echo "$dyn" | sed -n 's/.*(SONAME).*\[\(.*\)\]/\1/p'), PIC, uses the program's UnixLib$via"
    clash=$($RISCOS_HOST-nm -D --defined-only "$f" | awk '$2 ~ /^[TDBR]$/ {print $3}' | sed 's/@.*//' | sort -u | comm -12 - "$clash_list" | head -8 | tr '\n' ' ' | sed 's/ $//')
    [ -z "$clash" ] || echo "WARNING: $f exports its own $clash: the program's (UnixLib or libstdc++) is used instead; make the library's copy hidden" >&2
  fi
done
exit $bad
