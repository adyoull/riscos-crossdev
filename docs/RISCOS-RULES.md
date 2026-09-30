# What RISC OS enforces that Linux doesn't

Code that runs on ARM Linux can still abort, hang or take other programs
down with it on RISC OS. These are the rules found so far by the ports this
repo comes from, what breaks each one, and what catches it.

## 1. Stack frames over 4 KB must probe (`-fstack-clash-protection`)

ARMEABISupport gives a program its stack a page at a time, with a guard
page below. A function whose frame is bigger than a page moves `sp` down in
one step and can land past the guard page: the program aborts, often far
from the cause.

- **Do:** build everything with `-fstack-clash-protection` (it's in
  `RISCOS_CFLAGS`), including every library you link. The toolchain's own
  libraries (libgcc, UnixLib, libstdc++) are built with it.
- **Catches it:** `checks/check-stack-probes.py PROGRAM.elf` lists every
  frame of 4 KB or more that doesn't probe. Run it on the linked program:
  that covers the libraries too.

## 2. No unaligned loads and stores

RISC OS runs with alignment checking on. A 16- or 32-bit load or store to
an address that isn't a multiple of its size aborts: "abort on data
transfer", which UnixLib reports as `Fatal signal received: EMT trap`. On
ARMv7, `LDRD`/`STRD`, `LDM`/`STM` and VFP loads need word alignment, and
NEON loads need alignment to their element size (`vld1.32` needs 4 bytes).
Linux on ARM fixes these up silently, so code from Linux is full of them.

Typical sources: `*(uint32_t *)(buf + offset)` on file or network data;
structs from a byte stream; packed network headers read field by field;
codec assembly written for Linux.

- **Do:** `memcpy` into a local, read byte by byte, or use a packed struct
  (GCC then generates safe code). The RISC OS compiler has
  `-mno-unaligned-access` on by default, so it doesn't merge byte loads
  into word loads; never add `-munaligned-access`. For NEON assembly,
  `checks/neon-align.py` rewrites element loads into byte loads, which are
  the same on little-endian and never fault.
- **Catches it:** `checks/check-unaligned.sh` (every cast that raises the
  required alignment, on the sources); the QEMU tests (the real code, with
  the trap on, see TESTING.md). Neither is complete: the cast check can't
  see through `void *`, and QEMU only sees the paths your tests run.

## 3. VFPv3, not VFPv4

RISC OS 5 still runs on Cortex-A8 and A9 machines (BeagleBoard-xM,
PandaBoard, IGEPv2, ARMini, i.MX6 boards), which have VFPv3: no fused
multiply-add (`vfma`), no half-precision conversion. Code built with
`-mfpu=vfpv4` or `neon-vfpv4` runs on a Pi 2 or later and stops with
"undefined instruction" on those.

- **Do:** `-mfpu=vfpv3` (the default here, `FPU=vfpv3`), and libraries built
  the same way. On a Pi 4 the difference measured by riscos-mesa was under
  0.5%. If you really need VFPv4, say so in your requirements.
- **Catches it:** `checks/check-fpu.sh` on the program and on every `.a`
  you link; the QEMU tests run on an emulated Cortex-A8.

## 4. UnixLib must be built consistently

UnixLib's start-up code (`_syslib.s`) and its C code must agree on the size
of the pthread ticker block. GCCSDK's makefile didn't rebuild the assembler
files when an included header changed; two test builds of Warzone 2100
shipped a stale `_syslib.o`, and the ticker then overwrote the RMA and hung
the whole machine.

- **Do:** use the toolchain as built; after changing UnixLib, rebuild it
  from clean (`toolchain/build.sh unixlib`) and relink everything.
- **Catches it:** `checks/check-unixlib.sh PROGRAM.elf`.

## 5. The Wimp pages other tasks' memory in and out

Under the Wimp, only the current task's application memory is mapped. Code
that runs from an interrupt, a ticker event, a callback or a filter while
another task is paged in must not touch your program's memory (code or
data). UnixLib (since 5.0.1) runs its thread switcher from the PThreadTicker module
or a copy in the RMA for exactly this reason: before that, a threaded
program could crash other tasks.

- **Do:** keep interrupt-time code and its data in a module or the RMA.
  Ship PThreadTicker with threaded programs (from the
  [riscos-unixlib release](https://github.com/adyoull/riscos-unixlib/releases))
  and load it from `!Run`.
- **Catches it:** nothing on Linux. A Pi, with other tasks running (see
  PI-TESTING.md). The Unicorn runner (`emu/`) can check that such code
  preserves registers and only uses the memory it's given.

## 6. No `fork`, and be careful with `system`/`popen`

UnixLib runs a child as a command inside the parent's memory. From a large
Wimp program that isn't safe. Avoid starting other programs; if you must,
use `Wimp_StartTask`.

## 7. Absolute files and the WimpSlot

Convert programs with `elf2aif -e` (after stripping), so they don't need
!SharedLibs' ELF loader. The toolchain's `elf2aif` has the fix for images
over 32 MB (the stock one wrote a broken branch). Give `!Run` a `WimpSlot`
big enough for the program: UnixLib puts a large heap in a dynamic area,
so the slot mostly has to hold the image itself.

## 8. Filetypes and filenames

RISC OS files have types, not extensions. In the repo, name files
`name,xxx` (`!Run,feb`, `hello,ff8`) and zip them with `package/rozip.py`,
which stores the type in the zip so SparkFS and InfoZip restore it. UnixLib
maps Unix paths for you (`data/base.wz` is `data.base/wz` on RISC OS).
