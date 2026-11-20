# The optional GCC 16 toolchain

riscos-crossdev's default toolchain is GCC 10.2 (`toolchain/build.sh`).
This directory builds a second, optional one: **GCC 16.2.0** and **binutils
2.45.1** for `arm-riscos-gnueabihf`, laid out as the default one, for ports
that need a newer compiler (C++23: WebKitGTK 2.46 and later). Nothing uses it
unless `RISCOS_TOOLCHAIN` points at it.

    toolchain/gcc16/build.sh            # into toolchain/env-gcc16

- The compiler and binutils patches (`patches/`, `new-files/`,
  `patches-cxx/`, `new-files-cxx/`, `binutils-patches/`) are **Rob Heaton's**,
  from riscos-gcc16 (github.com/robheaton/riscos-gcc16, commit 8d6fffd),
  unchanged. They are GPL-3.0-or-later, as the GCC and binutils files they
  change; the libgcc and libstdc++ parts also carry the GCC Runtime Library
  Exception 3.1. Thank you, Rob.
- `crossdev-driver-specs.patch` gives the driver riscos-crossdev 1.12's
  behaviour: static links by default, mixed programs (`-rdynamic`,
  crtmixed.o, the whole of UnixLib exported, `-no-whole-unixlib`) and
  `-pthread`.
- `crossdev-arm-callee-save-cost.patch` fixes a GCC 16 regression on ARM
  (upstream GCC 16 does it too): GCC 16's register allocator gained a cost
  hook for saving callee-saved registers, which AArch64 and x86 implement and
  ARM doesn't, so ARM got the generic cost (a separate store and load per
  register). In Thumb-2 that made it spill values that live across calls to
  the stack rather than use r8-r11. The patch costs a core register as one
  more register in the PUSH/POP the function does anyway, as AArch64 does
  for pairs.
- `crossdev-recursive-inline-depth.patch`: recursive functions are inlined
  at most 2 levels deep by default (GCC's is 8). At -O3 GCC 16 inlines
  recursive functions, and cycles of them, deeply: a recursive-descent
  parser grew from ~700 to ~4600 instructions and ran 11% slower than GCC
  10's on a Pi 4; at depth 2 it runs 6% faster than GCC 10's. The
  `--param=max-inline-recursive-depth[-auto]=N` options still set it.
- `crossdev-libstdcxx-to-chars-table.patch`: libstdc++'s two-digit table
  for integer-to-text conversion lives once in read-only data. GCC 16 made
  it a local constexpr array (so the function can be constexpr), which GCC
  copies onto the stack, 201 bytes by memcpy, on every call:
  `std::to_string` was 2.4 times slower than GCC 10's; with the fix it is
  1.4 times faster. Every C++ mode still works, and so does constexpr
  `std::to_chars` in C++23.
- `crossdev-libstdcxx-hashtable-small-size.patch`: `std::unordered_map` and
  `std::unordered_set` always hash (with cached hash codes), as GCC 10's
  libstdc++ did, rather than scanning tables of up to 20 elements with key
  comparisons: string-keyed lookups in small tables were 17% slower.
  Only the lookup method changes, not any layout.
- `crossdev-libatomic-riscos.patch` (and `libat_cv_have_ifunc=no`): GCC's
  libatomic is built, without IFUNCs (UnixLib's static start-up doesn't run
  their resolvers). Link it with `-latomic`, as on Linux, for atomics LDREXD
  can't do (16-byte objects such as `std::atomic<std::optional<double>>`).
- UnixLib is riscos-crossdev's own (riscos-unixlib), **not** riscos-gcc16's:
  the GCC 16 toolchain links the same `libunixlib.a` as the default
  toolchain, built by GCC 10.2 (the C ABI is the same).
- Built static only (`--disable-shared`), as the default toolchain.
