# Licences

Files written for riscos-crossdev are under the MIT licence
([LICENSE](LICENSE)). Files copied or adapted from other projects keep
their original licence, listed below. Each of them also says where it came
from in its header.

## Copied or adapted files

| File(s) | From | Licence |
|---|---|---|
| `toolchain/elf2aif/elf2aif.c` | GCCSDK's elf2aif (© GCCSDK Developers, John Tytgat), with the >32 MB image fix from [riscos-openttd](https://github.com/adyoull/riscos-openttd) `tools/elf2aif` (tag 14.1.5, 450f875) | GPL version 2 or later |
| `toolchain/elf2aif/Makefile`, `README.md`, `elf2aif-large-images.diff` | riscos-openttd `tools/elf2aif` (same tag) | GPL version 2 |
| `toolchain/build.sh` | riscos-warzone2100 `build/build-toolchain.sh` (tag v2.3.9-3, 840b38b), which follows GCCSDK's autobuilder recipe | GPL version 2 or later |
| `checks/check-stack-probes.py`, `check-fpu.sh`, `check-unaligned.sh`, `check-unixlib.sh` | [riscos-warzone2100](https://github.com/adyoull/riscos-warzone2100) `tools/` (tag v2.3.9-3) | GPL version 2 or later |
| `checks/neon-align.py` | [riscos-ffmpeg](https://github.com/adyoull/riscos-ffmpeg) `tools/` (tag v5.1.10-riscos9, ffa6402) | GPL version 2 or later |
| `package/rozip.py` | riscos-warzone2100 `tools/rozip.py` (tag v2.3.9-3) | GPL version 2 or later |
| `qemu/qemu-8.2.2-align-trap.patch` | riscos-ffmpeg `tests/qemu/` (tag v5.1.10-riscos9); a patch to QEMU | GPL version 2 (as QEMU) |
| `qemu/build.sh`, `qemu/aligntrap.sh` | riscos-ffmpeg `tests/qemu/build-qemu.sh`, `aligntrap.sh` | GPL version 2 or later |
| `fake/kernel.h`, `fake/swis.h`, `fake/riscos.c` | Based on [riscos-unixlib](https://github.com/adyoull/riscos-unixlib) `tests/host/fake` (tag v5.0.1, ba6bd62) | UnixLib's licences (see its `libunixlib/COPYING`) |
| `fake/swinames.h` | Generated from UnixLib's `swis.h` (riscos-unixlib `libunixlib/include/swis.h`, © UnixLib Developers) by `fake/gen-swinames.sh` | UnixLib's licences |
| `fake/ports/` | The ports' own fakes, unchanged; each file's repository, commit and path are in `fake/ports/MANIFEST` | The licence of the port it came from: riscos-mesa, riscos-gtk, riscos-midisynth MIT; riscos-ffmpeg, riscos-matinee GPL version 2 or later; riscos-reelhwaccel GPL version 2; riscos-ysflight BSD 3-clause; riscos-unixlib UnixLib's licences, and `unixlib/host/eventfd/fake/sys/eventfd.h` FreeBSD's BSD 2-clause. See `fake/ports/README.md` |
| `emu/rcd_emu.py` | Based on riscos-unixlib `tests/emu/ticker_test.py` (tag v5.0.1) | UnixLib's licences (as above) |

## What the toolchain is built from

`toolchain/build.sh` downloads these by checksum (`toolchain/SOURCES`);
none of them is in this repo. The prebuilt toolchain tarball contains the
programs and libraries built from them, under these licences:

| Source | Licence |
|---|---|
| GCC 10.2.0 | GPL version 3 or later; its runtime libraries (libgcc, libstdc++) have the GCC Runtime Library Exception, so programs you build with them can have any licence |
| binutils 2.30 | GPL version 3 or later |
| GMP, MPFR, MPC (used only to build GCC) | LGPL version 3 or later |
| GCCSDK (riscos-gccsdk at 64c6f81): the RISC OS changes to GCC and binutils | As the files they change |
| UnixLib 5.0.3.3 (GCCSDK's UnixLib with riscos-unixlib's changes) | Mainly BSD-style, with some LGPL/GPL-with-exception parts: see `libunixlib/COPYING` in riscos-unixlib |
| PThreadTicker 0.03 (`riscos/PThrTicker`, built with UnixLib) | Revised BSD licence, as UnixLib (`riscos/PThreadTicker-Licence`) |
| QEMU 8.2.2 (`qemu-arm-aligntrap`) | GPL version 2 |

The riscos-mesa devkit (`make devkit`) isn't in this repo or the toolchain
tarball either. Its `LICENCES.txt` lists the licences of its libraries.

A program you build links UnixLib and GCC's runtime libraries statically.
Check UnixLib's licences for what that asks of you when you distribute it.
