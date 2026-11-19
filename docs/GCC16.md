# The optional GCC 16 toolchain

riscos-crossdev's toolchain is **GCC 10.2**, and it stays the default for
every port. For a port that needs a newer compiler, mainly for C++23
(WebKitGTK 2.46 and later refuse anything older than GCC 12.2), there's a
second toolchain: **GCC 16.2.0** with **binutils 2.45.1**.

Nothing uses it unless you choose it.

## Using it

Unpack `riscos-crossdev-toolchain-gcc16-VERSION-x86_64-linux.tar.xz`
anywhere and point `RISCOS_TOOLCHAIN` at it:

    export RISCOS_TOOLCHAIN=/opt/riscos-crossdev-toolchain-gcc16-VERSION-x86_64-linux

Everything else is as with the default toolchain:

- the same `arm-riscos-gnueabihf-` names and `riscos.mk`;
- the same checks;
- static links by default;
- mixed programs (`-rdynamic`, `-no-whole-unixlib`) and `-pthread`;
- `elf2aif -e`;
- stack probes on by default.

Or build it: `make prebuilt` (or `make toolchain`) for the default
toolchain, then `toolchain/gcc16/build.sh`. It goes into
`toolchain/env-gcc16`.

## UnixLib

It links **the same `libunixlib.a` as the default toolchain**, the one GCC
10.2 built (riscos-unixlib 5.0.3.9). It also uses the same headers,
PThreadTicker module and start files. UnixLib is C, and the C ABI (AAPCS,
hard float, VFP) is the same under both compilers.

UnixLib's own sources aren't yet built with GCC 16, and need two changes
before they can be. If you build your own copy of UnixLib, build it with
GCC 10.2 for now.

## Mixing with libraries built by GCC 10.2

- **C libraries link as they are.** For example, the riscos-mesa devkit's
  examples pass `make check-devkit` with this toolchain.
- **C++ libraries:** rebuild them. libstdc++ keeps its ABI for C++11, 14
  and 17, but C++20 code compiled by GCC 10 was experimental. Rebuilding
  everything avoids the question.

## What's new when you rebuild old code

- **C:** GCC 16's default is `-std=gnu23`. `bool`, `true` and `false` are
  keywords, and K&R-style declarations have gone. Old code may need
  `-std=gnu17`.
- **Errors since GCC 14:** implicit function declarations, implicit `int`
  and int/pointer conversions are errors. Fix them, or add
  `-Wno-error=implicit-function-declaration -Wno-error=int-conversion`.
- **C++:** the default is `-std=gnu++20` (GCC 10's was `gnu++14`). C++23 needs `-std=c++23` or
  `-std=gnu++23`.
- **NEON:** as with GCC 10, `-mfpu=neon` without `-mcpu` makes the driver add
  `-mcpu=cortex-a8`. With `-march=armv7-a` as well, both compilers warn that
  the two conflict. The code is still built for `-march`.

## Tested

- **On RISC OS** (RISC OS 5.31 in QEMU):
  - a C++23 program built with Thumb-2 throughout, `-mrestrict-it`, NEON,
    `-ffunction-sections -fdata-sections -Wl,--gc-sections` and
    `-pthread` (`std::expected`, `std::format`, ranges, `<span>`, `<bit>`,
    `if consteval`, exceptions, `std::thread`);
  - a program linked with `-Wl,--wrap=_kernel_swi`.
- **In the build:**
  - `-mrestrict-it` makes only single-instruction IT blocks;
  - `-u` keeps a symbol that `--gc-sections` would drop;
  - links at &40000000, &50000000 and &62340000;
  - a call 32 MB away gets a long-branch veneer;
  - `make check` passes with `RISCOS_TOOLCHAIN` pointing at it.

## Where it comes from

The RISC OS patches to GCC, libstdc++ and binutils are **Rob Heaton's**,
from [riscos-gcc16](https://github.com/robheaton/riscos-gcc16), and they are
unchanged (`toolchain/gcc16/README.md`). They are GPL-3.0-or-later, like the
files they change.

riscos-gcc16's UnixLib, SharedUnixLibrary and module kit are **not** used.
