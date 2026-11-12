#!/bin/bash
# Check that a new version of a library pack (!GTKLibs, !MesaLibs...) needs
# nothing new from the programs already linked against the old one
# (docs/MIXED.md, "Updating a library pack").
#
#   checks/check-pack-imports.sh --save LISTDIR PACKDIR   record what PACKDIR's
#                                    libraries need from the program
#   checks/check-pack-imports.sh LISTDIR PACKDIR          compare PACKDIR with
#                                    the lists saved for an earlier version
#
#   PACKDIR  the pack's libraries, as on Linux (libgtk-3.so.0 or ,e1f)
#   LISTDIR  one file per library, NAME.imports; keep it with the pack's
#            source and save it with each release
#
# A library's imports are the names it needs that no library in the pack
# defines: the program has to provide them. A name new since the saved
# list is:
#   - from UnixLib: fine for programs linked by riscos-crossdev 1.12 or
#     later, which export the whole of UnixLib; programs linked by 1.11.x
#     must be relinked (they stop at start-up, naming it);
#   - anything else (libstdc++, libgcc, the program's own): every program
#     linked against the old pack must be relinked. WRONG for a compatible
#     update: give the library its own copy, or make it a new SONAME.
. "$(dirname "$0")/../env.sh"
save=0
[ "${1:-}" = --save ] && { save=1; shift; }
[ $# -eq 2 ] && [ -d "$2" ] || { echo "usage: $0 [--save] LISTDIR PACKDIR" >&2; exit 2; }
lists=$1; pack=$2
nm=$RISCOS_HOST-nm
libs=$(find "$pack" -maxdepth 1 -type f \( -name 'lib*.so*' \) | sort)
[ -n "$libs" ] || { echo "no libraries (lib*.so*) in $pack" >&2; exit 2; }
soname() { $RISCOS_HOST-readelf -dW "$1" | sed -n 's/.*(SONAME).*\[\(.*\)\]/\1/p'; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
for f in $libs; do $nm -D --defined-only "$f" | awk '{print $3}' | sed 's/@.*//'; done | sort -u > "$tmp/defined"
$nm --defined-only "$RISCOS_TOOLCHAIN/$RISCOS_HOST/lib/libunixlib.a" 2>/dev/null | awk 'NF==3 && $2 ~ /[TDBRW]/ {print $3}' | sort -u > "$tmp/unixlib"
mkdir -p "$lists"
bad=0; note=0
for f in $libs; do
  so=$(soname "$f"); [ -n "$so" ] || so=$(basename "$f" ,e1f)
  $nm -D --undefined-only "$f" | awk '$1 == "U" {print $2}' | sed 's/@.*//' |
    grep -v '^__aeabi_unwind_cpp_pr[0-2]$' | sort -u | comm -23 - "$tmp/defined" > "$tmp/imports"
  if [ $save = 1 ]; then
    cp "$tmp/imports" "$lists/$so.imports"
    echo "saved: $lists/$so.imports ($(wc -l < "$tmp/imports") names)"
    continue
  fi
  if [ ! -f "$lists/$so.imports" ]; then
    echo "  $so: new library (no saved list)"; continue
  fi
  new=$(comm -23 "$tmp/imports" "$lists/$so.imports")
  [ -n "$new" ] || continue
  ul=$(echo "$new" | comm -12 - "$tmp/unixlib" | tr '\n' ' ' | sed 's/ $//')
  other=$(echo "$new" | comm -23 - "$tmp/unixlib" | tr '\n' ' ' | sed 's/ $//')
  [ -n "$ul" ] && { echo "NOTE: $so newly needs UnixLib's $ul: programs linked by riscos-crossdev 1.11.x must be relinked"; note=1; }
  [ -n "$other" ] && { echo "WRONG: $so newly needs $other: every program linked against the old pack would stop; give the library its own copy, or a new SONAME" >&2; bad=1; }
done
[ $save = 1 ] && exit 0
if [ $bad = 0 ]; then
  if [ $note = 1 ]; then echo "OK: $pack needs nothing new from programs beyond UnixLib"
  else echo "OK: $pack needs nothing new from programs"; fi
fi
exit $bad
