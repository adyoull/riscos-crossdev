# riscos-crossdev

Build and test RISC OS software on Linux.

riscos-crossdev packages the cross-build and test setup used by the RISC OS
ports at [github.com/adyoull](https://github.com/adyoull) (Warzone 2100,
OpenTTD, FFmpeg, riscos-mesa, UnixLib), so that others can use it for their
own programs. It doesn't emulate RISC OS. Instead, the testing is done in
layers, each catching what the one before it can't:

| Layer | What it is | What it catches |
|---|---|---|
| 1. Cross-compiler | GCCSDK GCC 10.2 (`arm-riscos-gnueabihf`) with UnixLib 5.0.3.3, built from source and static only; `elf2aif` turns the static ELF into an Absolute (AIF) file | Doesn't compile or link |
| 2. Checks | Run on every build: static linking, stack probes, unaligned casts, FPU level, UnixLib consistency | Code that builds, but aborts or hangs on RISC OS |
| 3. Fake RISC OS | Your RISC OS-specific C, compiled for Linux against C fakes of the SWIs it calls | Wrong SWI use and logic errors, in a debugger, in seconds |
| 4. QEMU user mode | Your portable code as real ARM code, on a QEMU patched to trap unaligned accesses like RISC OS, emulating a Cortex-A8 (VFPv3). Unicorn for module and assembler routines | Alignment aborts, VFPv4-only instructions, ARM code-generation bugs |
| 5. A Raspberry Pi | The final test | Wimp paging, other tasks, timing, the real modules |

Layers 1 to 4 run from `make check`. Layer 5 is you, with
[docs/PI-TESTING.md](docs/PI-TESTING.md).

## Quick start (Ubuntu 24.04, x86-64)

```sh
sudo apt-get install ...          # the list is in docs/SETUP.md
git clone -b v1.7.1 https://github.com/adyoull/riscos-crossdev
cd riscos-crossdev
make prebuilt      # download the checksummed toolchain into toolchain/env
                   # (or: make toolchain, to build it from source: an hour or more)
make devkit        # optional: the riscos-mesa devkit (OpenGL, EGL, SDL2, OpenAL)
make check         # the self-tests, and every example built and tested
make examples      # three example programs, zipped and ready for the Pi
```

Use a tagged release, not `main`: each tag names exactly one toolchain
tarball and its sha256, and `main` may be ahead of it.

## Documentation

| Read | For |
|---|---|
| [docs/SETUP.md](docs/SETUP.md) | Installing: packages, the toolchain (prebuilt or from source), the devkit |
| [docs/USING.md](docs/USING.md) | **Your own program:** starting from an example, building with Make, CMake or configure, libraries, making the app, testing, porting |
| [docs/RISCOS-RULES.md](docs/RISCOS-RULES.md) | What RISC OS enforces that Linux doesn't. Read it before porting anything |
| [docs/TESTING.md](docs/TESTING.md) | Each test layer: the checks, the Fake RISC OS and the ports' fakes, QEMU, Unicorn |
| [docs/PI-TESTING.md](docs/PI-TESTING.md) | Testing on a Raspberry Pi |
| [docs/REFERENCE.md](docs/REFERENCE.md) | Every command, setting and file |

## Examples

Each builds, passes every check, has tests that run on Linux, and makes a
zip for the Pi. Copy the closest one to start (USING.md, section 2).

| Example | What | Shows |
|---|---|---|
| [`examples/hello`](examples/hello) | A command-line program | A Makefile with every step; a Fake RISC OS test; a QEMU test |
| [`examples/wimp`](examples/wimp) | A desktop program: icon bar icon, window, menu | Testing Wimp code by faking the Wimp's SWIs; `!Sprites` from PNGs |
| [`examples/cmake`](examples/cmake) | A library and a program, with CMake | One `CMakeLists.txt` built for RISC OS, for ARM Linux under QEMU (ctest), and for the host; a devkit library via `find_package` |

The devkit adds six more for OpenGL, OpenGL ES, SDL2 and OpenAL
(`devkit/env/examples`).

## Layout

| Path | What |
|---|---|
| `env.sh`, `riscos.mk` | Settings and flags, for shell scripts and Makefiles |
| `toolchain/` | Build the toolchain from source, or install the prebuilt one; `elf2aif` with the >32 MB fix; the PThreadTicker module |
| `devkit/` | Install and check the riscos-mesa devkit (named, with its sha256, in `devkit/DEVKIT`) |
| `checks/` | The checks, and a self-test that shows each one catching its fault |
| `cmake/` | CMake toolchain files for RISC OS and for ARM Linux under QEMU, and `riscos_checks()`/`riscos_aif()` |
| `package/` | `rozip.py`: zips that keep RISC OS filetypes; `png2sprite.py`: sprite files from PNGs |
| `fake/` | The Fake RISC OS: `kernel.h`, `swis.h` (every SWI number in UnixLib and the ports) and a SWI dispatcher for Linux builds; `fake/ports/`, every port's own fakes, kept up to date from the ports, with where each came from in `fake/fake_origin.md` |
| `qemu/` | The alignment-trap patch for QEMU, its build script, `aligntrap.sh` |
| `emu/` | Unicorn runner for module and assembler code, with an example |
| `examples/` | Three programs with all of the above wired up |
| `.github/workflows/` | Every Monday: take the ports' latest fakes, `make check`, open a pull request |
| `docs/` | Setup, testing, RISC OS rules, testing on a Pi |

The large pieces are linked, not copied: UnixLib comes from
[riscos-unixlib](https://github.com/adyoull/riscos-unixlib) (tag v5.0.3.3; an unofficial fork of GCCSDK's UnixLib)
and is fetched by checksum. So is the devkit for OpenGL, EGL, SDL2, OpenAL
and GLU, from [riscos-mesa](https://github.com/adyoull/riscos-mesa)
(release 20.3.5-15, `make devkit`; see docs/SETUP.md).

## Support

As is. Report problems and ideas in
[GitHub Issues](https://github.com/adyoull/riscos-crossdev/issues): say
which release you used (`git describe --tags`), what you ran, and what
`make check` says. Fixes happen at the maintainer's own pace. You're
welcome to fork it.

## Licence

The files written for this repo are under the MIT licence ([LICENSE](LICENSE)).
Files copied from other projects keep their own licences, listed in
[LICENCES.md](LICENCES.md). The toolchain it builds is GCC, binutils and
UnixLib, each under its own licence.

## How this was made

Written with Claude (Anthropic's AI) as a coding assistant. Andrew Youll
directs the work, makes the decisions, and tests on a Raspberry Pi 4.
