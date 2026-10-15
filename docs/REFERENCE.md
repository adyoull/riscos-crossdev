# Reference

Every command, setting and file in riscos-crossdev, in one place. The
guide to using them is [USING.md](USING.md).

## Settings

Read by `env.sh`, `riscos.mk`, `cmake/riscos.cmake` and every script. Set
them in the environment (or on the `make` command line) to override.

| Variable | Default | What |
|---|---|---|
| `RISCOS_TOOLCHAIN` | `toolchain/env` | The installed toolchain: `bin/arm-riscos-gnueabihf-*`, `elf2aif`, `qemu-arm-aligntrap` |
| `RISCOS_DEVKIT` | `devkit/env` | The riscos-mesa devkit: `include/`, `lib/`, `lib/pkgconfig/` |
| `FPU` | `vfpv3` | `vfpv3` runs on every ARMv7 RISC OS machine; `vfpv4` on Cortex-A7 and later only |
| `JOBS` | `nproc` | Parallel jobs when building the toolchain |
| `RCD_DIR` | where `riscos.mk` or `env.sh` is | riscos-crossdev itself. `env.sh` works it out in bash and zsh; in other shells set it before sourcing |

## make targets (in riscos-crossdev)

| Target | What |
|---|---|
| `make prebuilt` | Download the toolchain named in `toolchain/PREBUILT`, check its sha256, unpack it into `RISCOS_TOOLCHAIN` |
| `make toolchain` | Build it from source instead (an hour or more), with `qemu-arm-aligntrap` |
| `make devkit` | Download the devkit named in `devkit/DEVKIT`, check it, unpack it into `RISCOS_DEVKIT` |
| `make check-devkit` | The devkit's libraries are VFPv3, and its six examples build and pass every check |
| `make hello` | `examples/hello/out/Hello.zip` |
| `make examples` | Every example: hello, wimp, cmake |
| `make check` | Everything that runs on Linux: the self-tests, the Fake RISC OS, the ports' fakes, QEMU, every example's build and tests, Unicorn, the devkit |
| `make image` | The container image, tagged `riscos-crossdev` (needs Docker) |
| `make dist VERSION=x.y` | The toolchain release tarball (maintainer) |
| `make clean` | Remove build output (not the toolchain or devkit) |

## `riscos.mk` (include it from your Makefile)

| Variable | Value |
|---|---|
| `RISCOS_HOST` | `arm-riscos-gnueabihf` |
| `RO_BIN` | `$(RISCOS_TOOLCHAIN)/bin` |
| `RO_CC`, `RO_CXX`, `RO_AR`, `RO_STRIP` | The cross compiler, C++ compiler, archiver, strip |
| `ELF2AIF` | `elf2aif` (`$(ELF2AIF) -e in.elf out,ff8`) |
| `QEMU_ALIGNTRAP` | `qemu-arm-aligntrap` |
| `RISCOS_CFLAGS` | `-O2 -mfpu=$(FPU) -mfloat-abi=hard -fstack-clash-protection` |
| `RISCOS_LDFLAGS` | `-static` |
| `DEVKIT_CFLAGS`, `DEVKIT_LDFLAGS` | `-I` and `-L` for the devkit |
| `RISCOS_PKG_CONFIG` | `pkg-config` reading only the devkit's `.pc` files |
| `CHECK_ALL`, `CHECK_UNALIGNED` | `checks/check-all.sh`, `checks/check-unaligned.sh` |
| `ROZIP` | `package/rozip.py` |
| `PNG2SPRITE` | `package/png2sprite.py` |
| `ALIGNTRAP` | `qemu/aligntrap.sh` (run with `QEMU=$(QEMU_ALIGNTRAP)`) |
| `LINUXARM_CC`, `LINUXARM_CFLAGS` | `arm-linux-gnueabihf-gcc` and the flags that make its code behave as RISC OS code does under QEMU (`-mno-unaligned-access`, Cortex-A8, `-no-pie`) |
| `FAKE_CC`, `FAKE_CFLAGS`, `FAKE_SRC` | The Fake RISC OS: `gcc`; `-m32 -funsigned-char -I fake ...`; and `fake/riscos.c` to link in (from `fake/fake.mk`) |
| target `riscos-toolchain-present` | Fails with a clear message if the toolchain isn't installed |

`env.sh` sets the same for shell scripts: `PATH`, `RISCOS_HOST`,
`RISCOS_CFLAGS`, `RISCOS_TOOLCHAIN`, `RISCOS_DEVKIT`, `FPU`, `JOBS`,
`RCD_DIR`.

## CMake (`cmake/`)

| File | Use |
|---|---|
| `cmake/riscos.cmake` | `-DCMAKE_TOOLCHAIN_FILE=` for RISC OS builds. Sets `RISCOS` and `UNIX`; static only; Release unless another build type is given; searches the toolchain and devkit; `pkg_check_modules` reads the devkit's `.pc` files |
| `cmake/RiscOS.cmake` | `include(RiscOS)`: `riscos_checks(target)` runs `check-all.sh` after each link; `riscos_aif(target path,ff8)` adds `target-aif`, the stripped Absolute file |
| `cmake/linux-arm-aligntrap.cmake` | Toolchain file for ARM Linux builds whose tests ctest runs under `qemu-arm-aligntrap` |
| `cmake/Platform/RISCOS.cmake` | CMake's description of the platform (used by `riscos.cmake`) |

## Scripts

### `checks/`: run on every build

| Command | Fails when |
|---|---|
| `checks/check-all.sh PROGRAM.elf [LIB.a...]` | Any of static, stack probes, FPU or UnixLib below fails (libraries: FPU only) |
| `checks/check-static.sh PROGRAM.elf...` | The program needs a shared library |
| `checks/check-stack-probes.py PROGRAM.elf [OBJDUMP]` | A frame of 4 KB or more doesn't probe its stack |
| `checks/check-fpu.sh FILE...` | A program, `.a` or `.o` uses VFPv4-only instructions |
| `checks/check-unixlib.sh PROGRAM.elf` | UnixLib's pthread ticker block sizes disagree (`TICKER_BLOCK=472` for UnixLib before 5.0.3.1) |
| `checks/check-unaligned.sh [-a] [-s SAFE] [CFLAGS...] FILE.c...` | A cast raises the alignment a pointer needs (`-Wcast-align=strict`); `-s` names a file of regular expressions for the ones checked by hand |
| `checks/neon-align.py [--check] [--allow F:L] [--whole F:L] FILE.S...` | NEON assembly assumes more alignment than it has (without `--check`, rewrites what is safe to rewrite) |
| `checks/selftest.sh` | One of the checks above no longer catches its fault |

Run the checks on the unstripped ELF, before `elf2aif`: they need the
symbols.

### `package/`: making the app

| Command | What |
|---|---|
| `package/rozip.py OUT.zip [-C DIR] PATH...` | Zip with RISC OS filetypes (from `name,xxx`) that SparkFS and InfoZip restore |
| `package/png2sprite.py OUT,ff9 NAME=FILE.png...` | Sprite file from PNGs: 32 bpp with a 1 bpp mask, 90 dpi, RISC OS 3.5 and later |
| `package/selftest.py` | `png2sprite.py` writes sprites as the PRMs describe them |

### `fake/`: the Fake RISC OS

| File | What |
|---|---|
| `fake/kernel.h`, `fake/swis.h` | Stand-ins for UnixLib's: `_swix`, `_swi`, `_kernel_swi`, UnixLib's register masks |
| `fake/swinames.h` | Every SWI number in UnixLib's `swis.h`, plus any the ports' fakes add. Generated |
| `fake/fake.h` | The test side: `fake_reset`, `fake_swi`, `fake_output`, `fake_set_time`, `fake_advance`, `fake_setvar`, `fake_calls`, `CHECK`, `fake_done` |
| `fake/riscos.c` | The SWI dispatcher and the built-in SWIs |
| `fake/fake.mk` | `FAKE_CC`, `FAKE_CFLAGS`, `FAKE_SRC` |
| `fake/selftest.c` | Tests the fake itself |
| `fake/gen-swinames.sh [SWIS_H]`, `--check` | Regenerate `swinames.h` and the SWI section of `fake_origin.md` |
| `fake/fake_origin.md` | Where every fake in `fake/ports/` came from, and which SWIs each port's `swis.h` defines. Generated |

### `fake/ports/`: the ports' fakes

| Command or file | What |
|---|---|
| `FILES` | What to copy: port, repository, prefix to drop, path. Edit it to take another fake |
| `update.sh [CHECKOUTS]` | Take every port's latest fakes from GitHub (or your checkouts), regenerate, and list what changed |
| `sync.sh CHECKOUTS` | The copying part of `update.sh` |
| `origin.sh` | Print the table in `fake_origin.md` as `FILE SHA256 REPO COMMIT PATH` lines |
| `check.sh` | Copies match `fake_origin.md`; the fakes that stand alone compile |
| `check-headers.sh` | The ports' `swis.h` and `kernel.h` agree with UnixLib's: SWI numbers, register masks, `_kernel_oserror`, `_kernel_swi_regs` |
| `REPORTED` | Problems from `check-headers.sh` already sent to the port: warnings, not failures |
| `README.md` | What each fake fakes, and which test uses it |

`.github/workflows/update-fakes.yml` runs `update.sh` and `make check` every
Monday and opens a pull request when a port's fakes have changed.

### `qemu/` and `emu/`: running ARM code on Linux

| Command | What |
|---|---|
| `qemu/aligntrap.sh PROGRAM [ARGS]` | Run an ARM Linux program with RISC OS's alignment rules on a Cortex-A8. Exit 135: unaligned access; 132: VFPv4 instruction. `QEMU_CPU=cortex-a7` allows VFPv4; `QEMU_ARGS="-g 1234"` waits for gdb |
| `qemu/build.sh` | Build `qemu-arm-aligntrap` (part of `make toolchain`) |
| `qemu/selftest.sh` | It still traps what it should |
| `emu/rcd_emu.py` | Python: `load_object`, `Machine` (`load`, `on_swi`, `call`, `called`, `error`, `claim`, `string`), `Checks`. Needs `pip install unicorn` |

### `toolchain/` and `devkit/`

| Command or file | What |
|---|---|
| `toolchain/install-prebuilt.sh [TARBALL]` | `make prebuilt` |
| `toolchain/fetch.sh`, `toolchain/build.sh all` | `make toolchain`: fetch the sources in `SOURCES` (sha256-checked), build |
| `toolchain/package.sh VERSION` | `make dist` |
| `toolchain/SOURCES`, `toolchain/PREBUILT` | What the toolchain is built from; which tarball this release uses |
| `toolchain/env/BUILDINFO.txt` | What an installed toolchain was built from |
| `toolchain/env/riscos/PThrTicker,ffa` | The PThreadTicker module, for threaded programs to ship |
| `devkit/install.sh [TARBALL]`, `devkit/check.sh` | `make devkit`, `make check-devkit` |
| `devkit/DEVKIT` | Which devkit this release uses |

## The container image and CI

| File | What |
|---|---|
| `docker/Dockerfile` | The image: Ubuntu 24.04, the packages in SETUP.md, the release's toolchain and devkit. `RCD_DIR`, `RISCOS_TOOLCHAIN`, `RISCOS_DEVKIT` set; working directory `/src` |
| `.github/workflows/docker.yml` | For each release tag (or by hand): build the image, `make check` in it, build `examples/wimp` as a port would, publish `ghcr.io/adyoull/riscos-crossdev:<version>` and `:latest` |
| `ci/riscos-build.yml` | For a port's repository: build in the image named by the `riscos-crossdev` line of `.riscos-deps`, on every push and pull request; keep the zips |
| `ci/riscos-deps-update.yml` | For a port's repository: daily, when anything in `.riscos-deps` has a newer release, move the pin (and run `ci/riscos-deps-hook.sh`), build, and open a pull request |
| `.riscos-deps`, `toolchain/deps-hook.sh`, `.github/workflows/update-deps.yml` | riscos-crossdev's own: daily pull requests when riscos-mesa or riscos-unixlib has a newer release |

`docs/CI.md` explains them.

## Exit statuses worth knowing

| Status | From | Means |
|---|---|---|
| 135 | `qemu/aligntrap.sh` | SIGBUS: an unaligned access, which aborts on RISC OS |
| 132 | `qemu/aligntrap.sh` | SIGILL: a VFPv4 instruction on the Cortex-A8 |
| 134 | a Fake RISC OS test | SIGABRT: the code called a SWI with no fake (its number is printed), or used `_BLOCK` |
