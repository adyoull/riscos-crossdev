# Changes

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
