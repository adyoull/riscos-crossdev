# Changes

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
