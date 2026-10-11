# examples/cmake: a CMake project

Tally lists the words used most in a text file (gzipped too, when zlib is
there). A static library (`src/tally.c`) and a program (`src/main.c`),
with one `CMakeLists.txt` built three ways:

| Build | Toolchain file | What you get |
|---|---|---|
| RISC OS | `cmake/riscos.cmake` | `build-riscos/tally` (checked after each link by `riscos_checks`), `build-riscos/!Tally/tally,ff8` (`riscos_aif`). zlib comes from the devkit, found by `find_package(ZLIB)`; without a devkit, it builds without it |
| ARM Linux | `cmake/linux-arm-aligntrap.cmake` | ctest runs `tests/test_tally.c` under `qemu-arm-aligntrap`: an unaligned access or a VFPv4 instruction fails the test |
| The host | none | The same tests natively, for gdb or valgrind |

```sh
make RCD_DIR=../..          # build-riscos/Tally.zip
make RCD_DIR=../.. check    # that, and ctest under QEMU and on the host
```

Or by hand, with `RCD_DIR` set to riscos-crossdev (`../..` here):

```sh
cmake -B build-riscos -DCMAKE_TOOLCHAIN_FILE=$RCD_DIR/cmake/riscos.cmake -DCMAKE_BUILD_TYPE=Release
cmake --build build-riscos
cmake -B build-qemu -DCMAKE_TOOLCHAIN_FILE=$RCD_DIR/cmake/linux-arm-aligntrap.cmake
cmake --build build-qemu && ctest --test-dir build-qemu
```

On the Pi: unzip, double-click `!Tally` (it counts the words in its own
`!Help`); then `*Tally <file>` works from the command line. More in
[docs/USING.md](../../docs/USING.md), section 5.
