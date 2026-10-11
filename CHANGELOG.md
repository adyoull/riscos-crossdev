# Changes

## 1.7.1

- **The weekly fakes update works.** Its first run stopped installing
  packages: on Ubuntu 24.04 `gcc-multilib` and `gcc-arm-linux-gnueabihf`
  can't be installed together (apt exit 100). It now installs
  `gcc-13-multilib`, which gives `-m32` without the conflict, and uses the
  Node 24 versions of its actions (checkout v6, cache v5,
  create-pull-request v8).
- **SETUP.md** had the same package list: it now says `gcc-13-multilib`.
- Nothing else changes: the toolchain is 1.4's, the devkit 20.3.5-15.

## 1.7

- **Documentation for using the kit:** `docs/USING.md`, the guide from an
  empty directory to a zip for the Pi (Make, CMake, configure, libraries,
  C++, the app, testing, moving to a new release, a porting checklist), and
  `docs/REFERENCE.md`, every command, setting and file.
- **Two more examples,** built and tested by `make check`:
  `examples/wimp`, a desktop program (icon bar icon, window, menu) whose
  test fakes the ten Wimp SWIs it uses; and `examples/cmake`, one
  `CMakeLists.txt` built for RISC OS, for ARM Linux with ctest under
  `qemu-arm-aligntrap`, and for the host. `make examples` builds all three.
- **CMake:** `cmake/riscos.cmake` (toolchain file: static, the RISC OS
  flags, searches the toolchain and devkit, `pkg_check_modules` reads the
  devkit's `.pc` files), `cmake/RiscOS.cmake` (`riscos_checks()`,
  `riscos_aif()`), and `cmake/linux-arm-aligntrap.cmake`.
- **`package/png2sprite.py`:** sprite files (`!Sprites`) from PNGs, with a
  self-test. `riscos.mk` has `PNG2SPRITE` and `RISCOS_PKG_CONFIG`.
- **The ports' fakes stay current by themselves.** Where each came from is
  now `fake/fake_origin.md` (it replaces `fake/ports/MANIFEST`), with links
  to each file at its commit. `.github/workflows/update-fakes.yml` runs
  `fake/ports/update.sh` and `make check` every Monday and opens a pull
  request when a port's fakes change.
- **One set of SWI numbers:** `fake/swinames.h` is generated from UnixLib's
  `swis.h` and every port's `swis.h`, so a SWI a port adds reaches it
  automatically. `fake_origin.md` lists which SWIs each port defines.
- **The ports' headers are checked:** `fake/ports/check-headers.sh` (in
  `make check`) compares each port's `swis.h` and `kernel.h` with UnixLib's
  (SWI numbers, register masks, `_kernel_oserror`, `_kernel_swi_regs`).
  The ports keep their own headers.
- GitHub Issues are on: report problems there (README, Support).
- The toolchain is unchanged (1.4's tarball), and the devkit is still
  20.3.5-15.

## 1.6

- **Every port's fakes, in `fake/ports/`**: riscos-unixlib, riscos-mesa,
  riscos-gtk, riscos-ffmpeg, riscos-midisynth, riscos-matinee,
  riscos-reelhwaccel and riscos-ysflight, copied unchanged with where each
  came from (`MANIFEST`: repository, commit, path, sha256).
  `fake/ports/update.sh` takes the latest from GitHub and lists what
  changed. `make check` fails if a copy here is edited, and compiles the
  ones that stand on their own. `fake/ports/README.md` says what each fakes.
- The Fake RISC OS's `swis.h` now has every SWI number in UnixLib's
  `swis.h` (`fake/swinames.h`, from `fake/gen-swinames.sh`), and UnixLib's
  register masks: `_OUT(_FLAGS)` and `_RETURN(_FLAGS)` were wrong before
  (`_FLAGS` was the mask bit itself), and `_swix` returns
  `_kernel_oserror *`, as on RISC OS. `fake/selftest.c` tests the fake.
- `examples/hello` relinks when the toolchain changes (a stale `out/hello`
  linked with an older UnixLib went unnoticed until `check-unixlib.sh`).
- The toolchain is unchanged (1.4's tarball).

## 1.5

- The riscos-mesa devkit 20.3.5-15 (was 20.3.5-12). `make check-devkit`
  builds its six examples with the toolchain and runs every check on them.
- The toolchain is unchanged: UnixLib 5.0.3.3 is still riscos-unixlib's
  latest release, so `toolchain/PREBUILT` still names 1.4's tarball.

## 1.4

- Toolchain: UnixLib 5.0.3.3 (was 5.0.3.2), with riscos-unixlib's
  2026-10-04 audit fixes:
  - a wait for another thread inside `read()`/`write()` or stdio no longer
    stops a threaded program (a blocking `/dev/dsp` write through `fwrite`
    did);
  - `fork()` in a threaded EABI program;
  - the services database (`getservent`, `getservbyname_r`...);
  - `swprintf`/`wcsftime` with `%ls`/`%lc`;
  - exit codes 128-255;
  - a small gap after the heap no longer caps later heap areas.

  No ABI change (PThreadTicker 0.03, a 640-byte pthread RMA block): relink
  to get the fixes. New toolchain tarball.
- The riscos-mesa devkit 20.3.5-12. It's on GitHub, so `make devkit`
  downloads it.

## 1.3

- Toolchain: UnixLib 5.0.3.2 (was 5.0.3.1): `LLONG_MIN` is a `long long`,
  `getservbyname_r`, `getservbyport_r` and `getservent_r` exist, and
  eventfd works with threads. No ABI change (PThreadTicker 0.03, a 640-byte
  pthread RMA block); relink to get the fixes. New toolchain tarball.
- **Static only.** The toolchain has no shared target libraries
  (`libunixlib.so`, `libstdc++.so`, `libm.so`, `libgcc_s.so` are gone), and
  the compiler links statically even without `-static` (not with `-shared`,
  `-r` or `-mmodule`). Up to 1.2 a link without `-static` silently used
  `libunixlib.so`, so a newer `libunixlib.a` changed nothing for it, and
  libtool followed `libm.la` to `libm.so` even with `-static` (found by
  riscos-gtk).
- `checks/check-static.sh`, now part of `check-all.sh`: fails on a
  dynamically linked program. The checks self-test covers it.
- The riscos-mesa devkit 20.3.5-11 (UnixLib 5.0.3.1 programs, PThreadTicker
  0.03 in its `riscos/` folder).

## 1.2

- Toolchain: UnixLib 5.0.3.1 (was 5.0.2): a heap past 128 MB, `fork()` in
  EABI programs, `_exit(n)`, threads that run in Wimp programs polling more
  often than every 2 cs, and 5.0.3's SWI wrapper fixes. Everything must be
  relinked: the pthread RMA block is now 640 bytes, and
  `checks/check-unixlib.sh` now expects that (`TICKER_BLOCK=472` checks a
  program linked with 5.0.1 to 5.0.3). New toolchain tarball.
- The toolchain carries the PThreadTicker module (0.03) that UnixLib
  5.0.3.1 uses, in `riscos/` with its ReadMe and Licence. The build checks
  it is byte for byte the riscos-unixlib release's module.
- The riscos-mesa devkit 20.3.5-10 (was 20.3.5-9). Its six examples are
  relinked by `make check-devkit`.

## 1.1

- Toolchain: UnixLib 5.0.2 (was 5.0.1). Programs built with
  `-D_FILE_OFFSET_BITS=64` can use files up to 4GB-1; nothing changes for
  others (docs/RISCOS-RULES.md, rule 8). New toolchain tarball.
- The riscos-mesa devkit 20.3.5-9 (EGL hardware overlays, a scaled render
  size): `make devkit` installs it by checksum (`devkit/DEVKIT`), and
  `make check-devkit` (also run by `make check`) checks its libraries are
  VFPv3 and builds its six examples through every check.
- `riscos.mk`: `RISCOS_DEVKIT`, `DEVKIT_CFLAGS`, `DEVKIT_LDFLAGS`.
- The checks self-test covers the large-file calls.

## 1.0

The first release.

- Toolchain: GCCSDK GCC 10.2.0 (`arm-riscos-gnueabihf`), binutils 2.30,
  UnixLib 5.0.1 (riscos-unixlib), elf2aif with the >32 MB fix, and
  qemu-arm-aligntrap (QEMU 8.2.2 with the alignment-trap patch). Built from
  source by `make toolchain`, or unpacked from the checksummed release
  tarball by `make prebuilt`. The toolchain can be moved anywhere
  (`RISCOS_TOOLCHAIN`).
- Checks: stack probes, FPU level, UnixLib consistency, unaligned casts,
  NEON alignment; a self-test for each.
- Fake RISC OS (`fake/`), QEMU (`qemu/`) and Unicorn (`emu/`) test layers.
- `examples/hello`: build, checks, AIF, zip with filetypes, a Fake RISC OS
  test and a QEMU test.
