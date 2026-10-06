#!/bin/bash
# Build the RISC OS cross toolchain from source into $RISCOS_TOOLCHAIN
# (default toolchain/env): GCCSDK GCC 10.2.0 for arm-riscos-gnueabihf,
# binutils 2.30, UnixLib 5.0.3.3, the PThreadTicker module and elf2aif.
# Static linking only: there are no shared target libraries, and links are
# static by default.
#
# Follows riscos-mesa's build/TOOLCHAIN.md (GCCSDK's autobuilder recipe
# autobuilder/develop/gcc/setvars, without the GCC 4.7.4 bootstrap), as
# riscos-warzone2100's build/build-toolchain.sh does, plus: the target
# libraries (libgcc, UnixLib, libstdc++) are built with
# -fstack-clash-protection, so none of them has an unprobed frame.
#
# Host packages (Ubuntu 24.04): see docs/SETUP.md.
# Sources: toolchain/fetch.sh puts them in $DL (default toolchain/dl).
#
# Usage: toolchain/build.sh [all|binutils|gcc|unixlib|elf2aif]
#   unixlib: re-patch GCCSDK and rebuild only UnixLib, from clean, in an
#            existing GCC build (after changing the UnixLib diff).
#   elf2aif: only the host tool (toolchain/elf2aif -> $RISCOS_TOOLCHAIN/bin).
set -eo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../env.sh"
: "${DL:=$HERE/dl}"
: "${TC:=$HERE/work}"                  # scratch; delete it after a build
WHAT=${1:-all}
T=arm-riscos-gnueabihf
case "$RISCOS_TOOLCHAIN|$TC|$DL" in *" "*)
  echo "build.sh: RISCOS_TOOLCHAIN, TC and DL must not contain spaces" >&2; exit 1;;
esac
"$HERE/fetch.sh" >/dev/null
UNIXLIB_DIFF=$DL/unixlib-riscos-5.0.3.3.diff
mkdir -p "$TC" "$RISCOS_TOOLCHAIN"; cd "$TC"
log() { echo "=== $* ($(date +%H:%M))"; }

unpack_gccsdk() {
  rm -rf gccsdk; tar xf "$DL"/gccsdk-64c6f81.tar.gz; mv riscos-gccsdk-64c6f81* gccsdk
  # UnixLib 5.0.3.3 (riscos-unixlib, an unofficial fork of GCCSDK's
  # UnixLib): real wide-character functions, a high resolution
  # monotonic clock, nanosleep accuracy, no mmap for large blocks, sched
  # priorities, /dev/dsp and /dev/midi, the pthread ticker fix (its
  # handler and Wimp filters run from the PThreadTicker module or an RMA
  # copy, never from the program's own memory), and files up to 4GB-1
  # with -D_FILE_OFFSET_BITS=64 (5.0.2), SWI wrapper fixes (5.0.3), and
  # in 5.0.3.1: a heap past 128MB in several dynamic areas, fork() in EABI
  # programs, _exit(n), threads in Wimp programs that poll often
  # (PThreadTicker 0.03, a 640-byte pthread RMA block); in 5.0.3.2: LLONG_MIN
  # is a long long, getservby*_r, eventfd with threads; in 5.0.3.3: the
  # 2026-10-04 audit fixes (waits inside read/write and stdio, fork in
  # threaded programs, the services database, exit codes, the heap).
  patch -d gccsdk -p1 -s < "$UNIXLIB_DIFF"
  # Static only (riscos-crossdev 1.3). RISC OS programs are linked
  # statically; GCCSDK's shared libraries need !SharedLibs' ELF loader. A
  # link without -static used to pick libunixlib.so, libstdc++.so and libm.so
  # silently, and libtool followed libm.la to libm.so even with -static (found
  # by riscos-gtk). So the target libraries are built static only
  # (--disable-shared below), and the driver adds -static to every link that
  # doesn't ask for -shared, -r or -mmodule (ld 2.30 crashes on a non-static
  # link when there are no shared libraries to use).
  sed -i 's|^  " %{!munaligned-access:-mno-unaligned-access}" \\$|&\n  " %{!shared:%{!static:%{!r:%{!mmodule:-static}}}}" \\|' \
    gccsdk/autobuilder/develop/gcc/gcc.config.arm.riscos-gnueabihf.h
  grep -q '%{!mmodule:-static}' gccsdk/autobuilder/develop/gcc/gcc.config.arm.riscos-gnueabihf.h ||
    { echo "couldn't add the default -static to GCCSDK's driver specs" >&2; exit 1; }
}
[ -d gccsdk ] || unpack_gccsdk
H=$TC/gccsdk/autobuilder/develop/gcc
UL=$TC/gccsdk/gcc4/recipe/files/gcc/libunixlib

# texinfo 7 can't build the old manuals: a makeinfo that claims 4.2 makes
# both configure scripts skip the docs.
mkdir -p fakebin
printf '#!/bin/sh\necho "makeinfo (GNU texinfo) 4.2"\n' > fakebin/makeinfo
chmod +x fakebin/makeinfo
export PATH="$TC/fakebin:$PATH" MAKEINFO="$TC/fakebin/makeinfo"
export GCCSDK_RISCOS_ABI_VERSION=armeabihf
export ac_cv_func_shl_load=no ac_cv_lib_dld_shl_load=no ac_cv_func_dlopen=yes \
       glibcxx_cv_c99_math_tr1=yes

build_elf2aif() {
  log "elf2aif (host)"
  mkdir -p "$RISCOS_TOOLCHAIN/bin"
  make -s -C "$HERE/elf2aif" CC=gcc GCCSDK_SRC="$TC/gccsdk" elf2aif
  mv "$HERE/elf2aif/elf2aif" "$RISCOS_TOOLCHAIN/bin/elf2aif"
}
if [ "$WHAT" = elf2aif ]; then build_elf2aif; exit 0; fi

if [ "$WHAT" = all ] || [ "$WHAT" = binutils ]; then
  log "binutils 2.30"
  rm -rf binutils-2.30; tar xf "$DL"/binutils_2.30.orig.tar.xz
  ln -sf "$H"/ld.emulparams.armelf_riscos_eabi.sh binutils-2.30/ld/emulparams/armelf_riscos_eabi.sh
  ln -sf "$H"/gas.config.te-riscos.h binutils-2.30/gas/config/te-riscos.h
  for p in "$H"/*.pp; do patch -d binutils-2.30 -p0 -l -s < "$p"; done
  # ld/Makefile.am is patched: regenerate with the versions binutils 2.30 used.
  ( cd binutils-2.30/ld && ACLOCAL=aclocal-1.11 AUTOMAKE=automake-1.11 \
      AUTOCONF=autoconf2.64 AUTOHEADER=autoheader2.64 autoreconf2.64 )
  mkdir -p binutils-2.30/cross-build; cd binutils-2.30/cross-build
  CC=gcc CXX=g++ CFLAGS="-O2 -fcommon" ../configure --prefix="$RISCOS_TOOLCHAIN" \
    --target=$T --disable-nls --disable-werror > "$TC"/binutils-configure.log
  make -j"$JOBS" > "$TC"/binutils-make.log 2>&1
  make install >> "$TC"/binutils-make.log 2>&1
  cd "$TC"
fi

# Keep build paths out of the libraries' debug information.
TFLAGS="-g -O2 -fstack-clash-protection -fdebug-prefix-map=$TC=/riscos-crossdev"

# The PThreadTicker module UnixLib builds (pthticker) goes in
# $RISCOS_TOOLCHAIN/riscos, with the ReadMe and Licence from the release's
# zip: threaded programs ship it and RMLoad it from !Run. UnixLib's own
# install doesn't copy it. It must be byte for byte the release's module.
install_pthticker() {
  local m=$TC/gcc-10.2.0/cross-build/$T/libunixlib/pthticker z=$TC/pthticker-zip
  [ -s "$m" ] || { echo "no $m: UnixLib's build didn't make the module" >&2; exit 1; }
  rm -rf "$z"; mkdir -p "$z" "$RISCOS_TOOLCHAIN/riscos"
  unzip -q "$DL/PThreadTicker-0.03.zip" -d "$z"
  cmp -s "$m" "$z/PThreadTicker/!System/310/Modules/PThrTicker" || {
    echo "the PThreadTicker built here differs from the v5.0.3.3 release's" >&2; exit 1; }
  cp "$m" "$RISCOS_TOOLCHAIN/riscos/PThrTicker,ffa"
  cp "$z/PThreadTicker/ReadMe" "$RISCOS_TOOLCHAIN/riscos/PThreadTicker-ReadMe,fff"
  cp "$z/PThreadTicker/Licence" "$RISCOS_TOOLCHAIN/riscos/PThreadTicker-Licence,fff"
}

if [ "$WHAT" = unixlib ]; then
  log "UnixLib only (from clean)"
  S=$TC/gcc-10.2.0
  [ -d "$S"/cross-build ] || { echo "no GCC build in $S: run toolchain/build.sh gcc" >&2; exit 1; }
  unpack_gccsdk
  rm -rf "$S"/libunixlib; cp -a "$UL" "$S"/libunixlib
  ( cd "$S" && AUTOCONF=autoconf2.69 "$H"/reconf-libunixlib ) > unixlib-autogen.log 2>&1
  cd "$S"/cross-build; rm -rf $T/libunixlib
  make configure-target-libunixlib all-target-libunixlib > "$TC"/unixlib-make.log 2>&1
  make install-target-libunixlib > "$TC"/unixlib-install.log 2>&1
  install_pthticker
  exit 0
fi

if [ "$WHAT" = all ] || [ "$WHAT" = gcc ]; then
  log "GCC 10.2.0 (the longest step)"
  S=$TC/gcc-10.2.0
  rm -rf "$S"; tar xf "$DL"/gcc-10.2.0.tar.gz; mv gcc-releases-gcc-10.2.0 "$S"
  for p in "$H"/*.p; do patch -d "$S" -p0 -l -s < "$p"; done
  # copy_link_gcc
  mkdir -p "$S"/libstdc++-v3/config/os/riscos
  for f in riscos-elf.h riscos-gnueabihf.h riscos-gcc.c riscos.c riscos.md riscos.opt \
           t-arm-riscos-elf t-riscos-gnueabihf xm-riscos.h; do
    ln -sf "$H"/gcc.config.arm.$f "$S"/gcc/config/arm/$f; done
  for f in t-arm-riscos-elf t-riscos-gnueabihf; do
    ln -sf "$H"/libgcc.config.arm.$f "$S"/libgcc/config/arm/$f; done
  for f in ctype_base.h ctype_configure_char.cc ctype_inline.h error_constants.h os_defines.h; do
    ln -sf "$H"/libstdc++-v3.config.os.riscos.$f "$S"/libstdc++-v3/config/os/riscos/$f; done
  cp -a "$UL" "$S"/libunixlib
  # gmp/mpfr/mpc in-tree instead of contrib/download_prerequisites
  tar xf "$DL"/gmp_6.2.1+dfsg.orig.tar.xz; tar xf "$DL"/mpfr4_4.1.0.orig.tar.xz
  tar xf "$DL"/mpclib3_1.2.1.orig.tar.gz
  ln -sfn "$TC"/gmp-6.2.1+dfsg "$S"/gmp; ln -sfn "$TC"/mpfr-4.1.0 "$S"/mpfr; ln -sfn "$TC"/mpc-1.2.1 "$S"/mpc

  # Stubs so UnixLib's and libstdc++'s configure link tests work before
  # UnixLib exists (make install replaces them).
  L=$RISCOS_TOOLCHAIN/$T/lib; mkdir -p "$L"; ( cd "$L"
    printf '.global _start\n_start:\n bx lr\n' | "$RISCOS_TOOLCHAIN"/bin/$T-as -o crt0.o
    : | "$RISCOS_TOOLCHAIN"/bin/$T-as -o empty.o
    for a in libunixlib.a libc.a libpthread.a; do [ -f $a ] || "$RISCOS_TOOLCHAIN"/bin/$T-ar rc $a empty.o; done
    rm empty.o )

  ( cd "$S" && autogen Makefile.def && autoconf2.69 && AUTOCONF=autoconf2.69 "$H"/reconf-libunixlib \
      && AUTOCONF=autoconf2.69 "$H"/reconf-libstdc++ ) > gcc-autogen.log 2>&1
  mkdir -p "$S"/cross-build; cd "$S"/cross-build
  CC=gcc CXX=g++ CFLAGS=-O1 CXXFLAGS=-O1 \
  CFLAGS_FOR_TARGET="$TFLAGS" CXXFLAGS_FOR_TARGET="$TFLAGS" \
  ../configure --prefix="$RISCOS_TOOLCHAIN" --target=$T \
    --disable-shared --enable-languages=c,c++ \
    --enable-threads=posix --enable-sjlj-exceptions=no --enable-__cxa_atexit \
    --enable-c99 --enable-cmath --disable-libstdcxx-pch --disable-libquadmath \
    --disable-nls --disable-tls --disable-libssp --disable-libgomp --disable-libitm \
    --disable-lto --disable-multilib \
    --with-pkgversion='GCCSDK GCC 10.2.0 Release 2 (riscos-crossdev)' \
    --with-bugurl=http://gccsdk.riscos.info/ --with-abi=aapcs-linux \
    --with-float=hard --with-fpu=vfpv3 --with-arch=armv7-a > "$TC"/gcc-configure.log
  make -j"$JOBS" > "$TC"/gcc-make.log 2>&1
  make install > "$TC"/gcc-install.log 2>&1
  install_pthticker
  cd "$TC"
fi

if [ "$WHAT" = all ]; then
  build_elf2aif
  log "smoke test"
  printf '#include <stdio.h>\nint main(void){puts("hi");return 0;}\n' > hello.c
  printf '#include <iostream>\nint main(){std::cout<<"hi"<<std::endl;}\n' > hello.cc
  $T-gcc -static -O2 hello.c -o hello-c
  $T-g++ -static -O2 hello.cc -o hello-cc
  elf2aif -e hello-c hello-c,ff8 >/dev/null
  ls -l hello-c hello-cc hello-c,ff8
  log "done: $RISCOS_TOOLCHAIN (toolchain/work can be deleted)"
fi
