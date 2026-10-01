# riscos-crossdev

Build and test RISC OS software on Linux.

riscos-crossdev packages the cross-build and test setup used by the RISC OS
ports at [github.com/adyoull](https://github.com/adyoull) (Warzone 2100,
OpenTTD, FFmpeg, riscos-mesa, UnixLib), so that others can use it for their
own programs. It doesn't emulate RISC OS. Instead, the testing is done in
layers, each catching what the one before it can't:

| Layer | What it is | What it catches |
|---|---|---|
| 1. Cross-compiler | GCCSDK GCC 10.2 (`arm-riscos-gnueabihf`) with UnixLib 5.0.3.1, built from source; `elf2aif` turns the static ELF into an Absolute (AIF) file | Doesn't compile or link |
| 2. Checks | Run on every build: stack probes, unaligned casts, FPU level, UnixLib consistency | Code that builds, but aborts or hangs on RISC OS |
| 3. Fake RISC OS | Your RISC OS-specific C, compiled for Linux against C fakes of the SWIs it calls | Wrong SWI use and logic errors, in a debugger, in seconds |
| 4. QEMU user mode | Your portable code as real ARM code, on a QEMU patched to trap unaligned accesses like RISC OS, emulating a Cortex-A8 (VFPv3). Unicorn for module and assembler routines | Alignment aborts, VFPv4-only instructions, ARM code-generation bugs |
| 5. A Raspberry Pi | The final test | Wimp paging, other tasks, timing, the real modules |

Layers 1 to 4 run from `make check`. Layer 5 is you, with
[docs/PI-TESTING.md](docs/PI-TESTING.md).

## Quick start (Ubuntu 24.04, x86-64)

```sh
sudo apt-get install ...          # the list is in docs/SETUP.md
git clone -b v1.2 https://github.com/adyoull/riscos-crossdev
cd riscos-crossdev
make prebuilt      # download the checksummed toolchain into toolchain/env
                   # (or: make toolchain, to build it from source: an hour or more)
make devkit        # optional: the riscos-mesa devkit (OpenGL, EGL, SDL2, OpenAL)
make check         # the checks, a Fake RISC OS test and a QEMU test
make hello         # examples/hello/out/Hello.zip, ready for the Pi
```

Use a tagged release, not `main`: each tag names exactly one toolchain
tarball and its sha256, and `main` may be ahead of it.

To start your own program, copy `examples/hello` and point its `RCD_DIR`
at this repo. [docs/SETUP.md](docs/SETUP.md) covers the toolchain,
[docs/TESTING.md](docs/TESTING.md) the tests, and
[docs/RISCOS-RULES.md](docs/RISCOS-RULES.md) the rules RISC OS enforces
that Linux doesn't (read this one before porting anything).

## Layout

| Path | What |
|---|---|
| `env.sh`, `riscos.mk` | Settings and flags, for shell scripts and Makefiles |
| `toolchain/` | Build the toolchain from source, or install the prebuilt one; `elf2aif` with the >32 MB fix; the PThreadTicker module |
| `devkit/` | Install and check the riscos-mesa devkit (named, with its sha256, in `devkit/DEVKIT`) |
| `checks/` | The checks, and a self-test that shows each one catching its fault |
| `package/` | `rozip.py`: zips that keep RISC OS filetypes |
| `fake/` | The Fake RISC OS: `kernel.h`, `swis.h` and a SWI dispatcher for Linux builds |
| `qemu/` | The alignment-trap patch for QEMU, its build script, `aligntrap.sh` |
| `emu/` | Unicorn runner for module and assembler code, with an example |
| `examples/hello/` | A small program with all of the above wired up |
| `docs/` | Setup, testing, RISC OS rules, testing on a Pi |

The large pieces are linked, not copied: UnixLib comes from
[riscos-unixlib](https://github.com/adyoull/riscos-unixlib) (tag v5.0.3.1; an unofficial fork of GCCSDK's UnixLib)
and is fetched by checksum. So is the devkit for OpenGL, EGL, SDL2, OpenAL
and GLU, from [riscos-mesa](https://github.com/adyoull/riscos-mesa)
(release 20.3.5-10, `make devkit`; see docs/SETUP.md).

## Support

As is. Fixes happen at the maintainer's own pace, and there's no issue
tracker. You're welcome to fork it.

## Licence

The files written for this repo are under the MIT licence ([LICENSE](LICENSE)).
Files copied from other projects keep their own licences, listed in
[LICENCES.md](LICENCES.md). The toolchain it builds is GCC, binutils and
UnixLib, each under its own licence.

## How this was made

Written with Claude (Anthropic's AI) as a coding assistant. Andrew Youll
directs the work, makes the decisions, and tests on a Raspberry Pi 4.
