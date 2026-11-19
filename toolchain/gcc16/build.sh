#!/bin/bash
# Build the optional GCC 16 toolchain (README.md here): GCC 16.2.0 (C, C++,
# LTO) and binutils 2.45.1 for arm-riscos-gnueabihf, static only, into
# $GCC16_TOOLCHAIN (default toolchain/env-gcc16).
#
# The UnixLib it links (headers, libunixlib.a, libm, crt0.o, libpthread), the
# PThreadTicker module, elf2aif and qemu-arm-aligntrap come from the default
# GCC 10.2 toolchain, $RISCOS_TOOLCHAIN (toolchain/env: make prebuilt or
# make toolchain first), unchanged: libunixlib.a is the one GCC 10.2 built.
#
# Usage: toolchain/gcc16/build.sh [all|binutils|gcc|finish]
#   finish: only the parts taken from the default toolchain, crtmixed.o and
#           the stand-ins, and BUILDINFO.txt.
# Host packages: as the default toolchain (docs/SETUP.md), and autoconf2.69.
#
# Copyright (c) 2026 Andrew Youll. MIT licence (the patches it applies are
# Rob Heaton's, GPL-3.0-or-later: see README.md).
set -eo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
TCDIR=$(dirname "$HERE")
. "$TCDIR/../env.sh"
: "${DL:=$TCDIR/dl}"
: "${GCC16_TOOLCHAIN:=$TCDIR/env-gcc16}"
: "${TC:=$TCDIR/work-gcc16}"             # scratch; delete it after a build
BASE=$RISCOS_TOOLCHAIN
P=$GCC16_TOOLCHAIN
T=arm-riscos-gnueabihf
WHAT=${1:-all}
case "$P|$TC|$DL" in *" "*) echo "build.sh: paths must not contain spaces" >&2; exit 1;; esac
[ -x "$BASE/bin/$T-gcc" ] && [ -f "$BASE/$T/lib/libunixlib.a" ] ||
  { echo "build.sh: needs the default toolchain in $BASE (make prebuilt)" >&2; exit 1; }
[ "$(cd "$BASE" && pwd)" != "$(mkdir -p "$P" && cd "$P" && pwd)" ] ||
  { echo "build.sh: GCC16_TOOLCHAIN must not be the default toolchain's directory" >&2; exit 1; }
SOURCES_FILE=$HERE/SOURCES DL=$DL "$TCDIR/fetch.sh" >/dev/null
mkdir -p "$TC"; cd "$TC"
log() { echo "=== $* ($(date +%H:%M))"; }
export PATH="$P/bin:$PATH"

# The UnixLib side of the sysroot: the default toolchain's, as it is.
sysroot() {
  mkdir -p "$P/$T/lib" "$P/bin" "$P/riscos"
  # UnixLib's headers (not the default toolchain's C++ headers in c++/: GCC
  # 16 installs its own there)
  mkdir -p "$P/$T/include"
  tar -C "$BASE/$T/include" --exclude=./c++ -cf - . | tar -C "$P/$T/include" -xf -
  rm -rf "$P/$T/include/c++/10.2.0"
  for f in crt0.o gcrt0.o libc.a libm.a libpthread.a libunixlib.a libdl.a; do
    cp -a "$BASE/$T/lib/$f" "$P/$T/lib/"
  done
}

if [ "$WHAT" = all ] || [ "$WHAT" = binutils ]; then
  log "binutils 2.45.1"
  rm -rf binutils-2.45.1 binutils-build; tar xf "$DL"/binutils-2.45.1.tar.xz
  for p in "$HERE"/binutils-patches/*.patch; do
    patch -d binutils-2.45.1 -p1 -s --no-backup-if-mismatch < "$p"
  done
  mkdir binutils-build; cd binutils-build
  ../binutils-2.45.1/configure --prefix="$P" --target=$T --disable-nls --disable-werror \
    --disable-gdb --disable-gdbserver --disable-gprofng --enable-gprof --disable-sim --disable-gold \
    --enable-plugins --without-zstd --without-debuginfod --disable-multilib > "$TC"/binutils-configure.log
  make -j"$JOBS" MAKEINFO=true all > "$TC"/binutils-make.log 2>&1
  make MAKEINFO=true install >> "$TC"/binutils-make.log 2>&1
  cd "$TC"
fi

if [ "$WHAT" = all ] || [ "$WHAT" = gcc ]; then
  log "GCC 16.2.0"
  sysroot
  rm -rf gcc-16.2.0 gcc-build; tar xf "$DL"/gcc-16.2.0.tar.xz
  ( cd gcc-16.2.0
    for p in "$HERE"/patches/*.patch "$HERE"/patches-cxx/*.patch; do patch -p1 -l -s < "$p"; done
    cp -r "$HERE"/new-files/* "$HERE"/new-files-cxx/* .
    patch -p1 -s < "$HERE"/crossdev-driver-specs.patch
    ( cd libstdc++-v3 && PATH=/usr/bin:/bin autoconf2.69 -f )
    tar xf "$DL"/gmp_6.2.1+dfsg.orig.tar.xz && mv gmp-6.2.1* gmp
    tar xf "$DL"/mpfr4_4.1.0.orig.tar.xz && mv mpfr-4.1.0* mpfr
    tar xf "$DL"/mpclib3_1.2.1.orig.tar.gz && mv mpc-1.2.1* mpc )
  # (configure can't run these tests when cross compiling: as the default
  # toolchain and riscos-gcc16 do)
  export ac_cv_func_shl_load=no ac_cv_lib_dld_shl_load=no ac_cv_func_dlopen=yes \
         glibcxx_cv_c99_math_tr1=yes glibcxx_cv_c99_math_funcs=yes
  mkdir gcc-build; cd gcc-build
  # Keep build paths out of the libraries' debug information.
  TFLAGS="-O2 -g -fdebug-prefix-map=$TC=/riscos-crossdev"
  ../gcc-16.2.0/configure --prefix="$P" --target=$T \
    --enable-languages=c,c++,lto --enable-lto --disable-shared --enable-static \
    --enable-threads=posix --enable-sjlj-exceptions=no --enable-__cxa_atexit --enable-c99 \
    --enable-cmath --disable-libstdcxx-pch --disable-wchar_t --disable-libquadmath --disable-nls --disable-tls \
    --disable-libssp --disable-libgomp --disable-libitm --disable-libatomic --disable-libsanitizer \
    --disable-libvtv --disable-libcc1 --disable-multilib --disable-bootstrap \
    --with-pkgversion='riscos-crossdev GCC 16.2.0' \
    --with-bugurl=https://github.com/adyoull/riscos-crossdev/issues \
    --with-abi=aapcs-linux --with-float=hard --with-fpu=vfpv3 --with-arch=armv7-a \
    CFLAGS_FOR_TARGET="$TFLAGS" CXXFLAGS_FOR_TARGET="$TFLAGS" > "$TC"/gcc-configure.log 2>&1
  make -j"$JOBS" MAKEINFO=true all > "$TC"/gcc-make.log 2>&1
  make MAKEINFO=true install > "$TC"/gcc-install.log 2>&1
  cd "$TC"
fi

if [ "$WHAT" = all ] || [ "$WHAT" = finish ]; then
  log "UnixLib, PThreadTicker and host tools from $BASE; crtmixed.o"
  sysroot
  cp -a "$BASE"/riscos/. "$P/riscos/"
  for f in elf2aif qemu-arm-aligntrap; do cp -a "$BASE/bin/$f" "$P/bin/"; done
  "$TCDIR"/mixed/install.sh "$P"
  # Stack probes are the target default (riscos-gcc16's patch), as the
  # default toolchain's libraries are built with them.
  printf 'extern void use(char *);\nvoid f(void) { char b[8192]; use(b); }\n' > probe.c
  "$P/bin/$T-gcc" -O2 -S -o - probe.c | grep -q '#4096' ||
    { echo "build.sh: -fstack-clash-protection isn't the default" >&2; exit 1; }
  # GCC 16's own C++ library and headers, with UnixLib's (C++23)
  printf '#include <bit>\n#include <format>\n#include <expected>\n#include <thread>\nint main() { std::expected<int,int> e = std::popcount(7u); std::thread t([]{}); t.join(); return std::format("{}", *e) != "3"; }\n' > smoke.cc
  "$P/bin/$T-g++" -std=c++23 -O2 -pthread -o smoke smoke.cc ||
    { echo "build.sh: a C++23 program doesn't build" >&2; exit 1; }
  {
    echo "riscos-crossdev toolchain gcc16 (optional; $(uname -m) Linux host)"
    echo "Built $(date -u +%Y-%m-%d) from riscos-crossdev $(git -C "$RCD_DIR" describe --always --dirty 2>/dev/null || echo '(no git)')"
    echo
    "$P/bin/$T-gcc" --version | head -1
    "$P/bin/$T-ld" --version | head -1
    echo
    echo "UnixLib, PThreadTicker, elf2aif and qemu-arm-aligntrap are the default toolchain's:"
    head -1 "$BASE/BUILDINFO.txt" 2>/dev/null | sed 's/^/  /'
    grep 'unixlib-riscos-.*\.diff' "$BASE/BUILDINFO.txt" 2>/dev/null || true
    echo
    echo "Sources (sha256):"
    grep -v '^#' "$HERE/SOURCES" | awk 'NF==3 {print "  " $2 "  " $1}'
    echo "  patches: riscos-gcc16 (Rob Heaton) commit 8d6fffd; crossdev-driver-specs.patch"
    echo
    echo "Licences: see LICENCES.md and toolchain/gcc16/README.md in the riscos-crossdev repository."
  } > "$P/BUILDINFO.txt"
fi
log "done: $P"
