#!/bin/bash
# Check fake/ports: every copy is what fake/fake_origin.md recorded (fix
# fakes in the port they came from, then fake/ports/update.sh), and the
# fakes that stand on their own still compile on this host. Fakes that need their port's
# sources (reelcore, the HEVC block, mmaldecode, UnixLib internals for the
# emulator stubs) are only checked by their own port's tests.
#   fake/ports/check.sh            (run by make check)
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../env.sh"
cd "$HERE"
fails=0
echo "-- copies match fake/fake_origin.md"
n=0
while read -r f sum repo commit path; do
  case $f in ''|'#'*) continue;; esac
  n=$((n+1))
  if [ ! -f "$f" ]; then echo "WRONG: $f is missing"; fails=$((fails+1)); continue; fi
  [ "$(sha256sum < "$f" | cut -d' ' -f1)" = "$sum" ] ||
    { echo "WRONG: $f was edited here (it's $repo $commit:$path; fix it there and run update.sh)"; fails=$((fails+1)); }
done < <(./origin.sh)
extra=$(find . -type f ! -name FILES ! -name REPORTED ! -name README.md ! -name '*.sh' | sed 's|^\./||' |
        grep -vxF -f <(./origin.sh | cut -d' ' -f1))
[ -z "$extra" ] || { echo "WRONG: not in fake/fake_origin.md: $extra"; fails=$((fails+1)); }
echo "$n files checked"

echo "-- the standalone fakes compile"
OUT=$(mktemp -d); trap 'rm -rf "$OUT"' EXIT
compile() {  # name flags... file
  local name=$1; shift
  if gcc -fsyntax-only -w "$@" 2>"$OUT/err"; then echo "ok   $name"
  else echo "FAIL $name"; head -3 "$OUT/err"; fails=$((fails+1)); fi
}
DK=$RISCOS_DEVKIT/include
compile "unixlib: sound modules (SharedSoundBuffer, StreamManager, DigitalRenderer)" \
  -D_GNU_SOURCE -include unixlib/host/fake/prelude.h -Iunixlib/host/fake unixlib/host/fake/riscos.c
compile "mesa: Wimp, screen, sprites (egl/fake_riscos.c)" -Imesa/egl/fake -Imesa/egl mesa/egl/fake_riscos.c
compile "mesa: the port runner (egl/portrun.c)" -Imesa/egl/fake -Imesa/egl mesa/egl/portrun.c
compile "mesa: VideoOverlay (ovl/fake_ovl.c)" -Imesa/ovl/fake -Imesa/egl/fake -Imesa/egl mesa/ovl/fake_ovl.c
compile "ffmpeg: AcornSSL (fake_acornssl.c)" -Iffmpeg/fake ffmpeg/fake_acornssl.c
compile "midisynth: sound SWIs (fake_swi.c)" -Imidisynth/fake -Imidisynth midisynth/fake_swi.c
if [ -f "$DK/EGL/eglext_riscos.h" ]; then
  compile "ffmpeg: TaskWindow, screen, EGL (fake_riscos.c)" -Iffmpeg/fake -Iffmpeg -I"$DK" ffmpeg/fake_riscos.c
  compile "ffmpeg: SDL and GL for ffplay (fake_sdl_gl.c)" -Iffmpeg -I"$DK" -I"$DK/SDL2" ffmpeg/fake_sdl_gl.c
else
  echo "SKIP ffmpeg: fake_riscos.c, fake_sdl_gl.c (need the devkit's EGL/SDL headers: make devkit)"
fi
if pkg-config --exists cairo 2>/dev/null; then
  compile "gtk: Wimp, screen, sprites, AcornSSL with cairo (mesa-egl/fake_riscos.c)" \
    -Igtk/mesa-egl/fake -Igtk/mesa-egl $(pkg-config --cflags cairo) gtk/mesa-egl/fake_riscos.c
else
  echo "SKIP gtk: mesa-egl/fake_riscos.c (needs cairo's headers: libcairo2-dev)"
fi
python3 -m py_compile matinee/fakeplex.py unixlib/emu/*.py && rm -rf matinee/__pycache__ unixlib/emu/__pycache__ &&
  echo "ok   python fakes parse (fakeplex.py, the Unicorn tests)" || fails=$((fails+1))
[ $fails = 0 ] && echo "fake/ports check passed"
exit $fails
