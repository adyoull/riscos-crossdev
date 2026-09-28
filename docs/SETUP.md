# Setup

Everything here is tested on Ubuntu 24.04 on x86-64. Other Linux
distributions should work if they have the same packages. The prebuilt
toolchain is for x86-64 with glibc 2.39 or later (Ubuntu 24.04, Debian 13
and newer); elsewhere, including ARM64 machines, build it from source.

## 1. Packages

```sh
sudo apt-get install build-essential gcc-multilib \
    gcc-arm-linux-gnueabihf libc6-dev-armhf-cross \
    python3 python3-venv curl xz-utils zip unzip git
# only to build the toolchain from source (make toolchain):
sudo apt-get install autogen autoconf2.69 autoconf2.64 automake1.11 automake \
    libtool texinfo gperf flex bison m4 gawk ninja-build libglib2.0-dev
# optional, for the Unicorn test (emu/):
pip install unicorn          # or: pip install --user unicorn
```

What each is for:

- `gcc-multilib`: the Fake RISC OS tests are built 32-bit (`-m32`), so an
  `int` can hold a pointer, as on RISC OS.
- `gcc-arm-linux-gnueabihf`, `libc6-dev-armhf-cross`: your portable code
  built for ARM Linux, to run under QEMU.
- `libglib2.0-0` (installed with most desktops; `libglib2.0-dev` pulls it
  in): `qemu-arm-aligntrap` needs it at run time.

If apt says `gcc-arm-linux-gnueabihf` has unmet dependencies, install
`gcc-13-arm-linux-gnueabihf` first, then try again.

## 2. The toolchain

Use a tagged release of this repo (`git clone -b v1.0 ...`). Each tag names
one toolchain tarball and its sha256 in `toolchain/PREBUILT`.

**Prebuilt** (a few minutes):

```sh
make prebuilt
```

This downloads the tarball from the GitHub release, checks its sha256 and
unpacks it into `toolchain/env`. If you already have the tarball:
`toolchain/install-prebuilt.sh path/to/riscos-crossdev-toolchain-1.0-x86_64-linux.tar.xz`.

**From source** (an hour or more; about 5 GB of disk while it builds):

```sh
make toolchain
```

That runs `toolchain/fetch.sh` (downloads the sources in
`toolchain/SOURCES` into `toolchain/dl` and checks their sha256),
`toolchain/build.sh all` (binutils, GCC with UnixLib and libstdc++, then
`elf2aif`) and `qemu/build.sh` (`qemu-arm-aligntrap`). The logs are in
`toolchain/work/*.log`; delete `toolchain/work` and `qemu/work` afterwards.
If your machine can't reach GitHub's archive server (codeload.github.com),
put the two GitHub files from `toolchain/SOURCES` into `toolchain/dl` by hand.

Either way you get, in `toolchain/env/bin`:

| Program | What |
|---|---|
| `arm-riscos-gnueabihf-gcc`, `-g++`, `-as`, `-ld`, `-objdump`, ... | The cross toolchain. `-static` only |
| `elf2aif` | ELF to Absolute (AIF). Has the fix for images over 32 MB |
| `qemu-arm-aligntrap` | QEMU user mode that traps unaligned accesses (`qemu/`) |

`toolchain/env/BUILDINFO.txt` says what it was built from.

### Somewhere else

The toolchain can live anywhere. Set `RISCOS_TOOLCHAIN` to its directory,
for example to share one copy between several checkouts:

```sh
export RISCOS_TOOLCHAIN=$HOME/riscos-toolchain-1.0
make prebuilt       # installs there
```

`env.sh` and `riscos.mk` read it, and so does every script here.

## 3. Using it for your own program

From a Makefile:

```make
RCD_DIR := $(HOME)/riscos-crossdev
include $(RCD_DIR)/riscos.mk
# gives RO_CC, RO_CXX, RO_STRIP, ELF2AIF, RISCOS_CFLAGS, RISCOS_LDFLAGS,
# ROZIP, CHECK_ALL, CHECK_UNALIGNED, ALIGNTRAP, QEMU_ALIGNTRAP,
# LINUXARM_CC/CFLAGS and FAKE_CC/FAKE_CFLAGS/FAKE_SRC
```

From a shell script, or for autoconf/CMake builds:

```sh
. $HOME/riscos-crossdev/env.sh     # PATH, RISCOS_CFLAGS, RISCOS_HOST
./configure --host=arm-riscos-gnueabihf CFLAGS="$RISCOS_CFLAGS" LDFLAGS=-static
```

`examples/hello/Makefile` shows the whole path: compile, check, strip,
`elf2aif`, zip. Copy it to start.

Two traps with configure scripts, from the ports:

- Scripts older than about 2018 don't know the `riscos` system: replace
  their `config.sub` and `config.guess` with current ones
  (`/usr/share/automake-*/config.{sub,guess}`).
- autoconf and libtool can't cope with spaces in `--prefix` or in `-I`/`-L`
  paths. Keep your build directories free of spaces.

## 4. Libraries: the riscos-mesa devkit

For OpenGL (OSMesa), EGL, SDL2, GLU, OpenAL and zlib, use the devkit from a
[riscos-mesa release](https://github.com/adyoull/riscos-mesa/releases)
(`riscos-mesa-devkit-VERSION.tgz`; 20.3.5-8 is VFPv3, like this toolchain):

```sh
mkdir -p devkit && tar xzf riscos-mesa-devkit-20.3.5-8.tgz -C devkit
```

Its `README.md` says how to compile and link against it. Check that each
library you link has the FPU level you want:
`checks/check-fpu.sh devkit/*/lib/*.a`.

## 5. Updating

A new toolchain means a new tag of this repo. To move a port to it: check
out the new tag, run `make prebuilt` into a fresh `RISCOS_TOOLCHAIN`,
rebuild everything from clean (object files built by the old compiler, or
against the old UnixLib headers, must not be mixed in), and run the checks.

## 6. Making a release (maintainer)

1. `make toolchain` in a clean clone at the commit to release (it pins
   everything it downloads), then `make check`.
2. `make dist VERSION=x.y`: `out/riscos-crossdev-toolchain-x.y-x86_64-linux.tar.xz`
   and its `.sha256`.
3. Put the file name, sha256 and release URL in `toolchain/PREBUILT`, add
   the version to `CHANGELOG.md`, commit, and tag `vx.y`.
4. In a fresh clone of the tag, `toolchain/install-prebuilt.sh out/...tar.xz`
   and `make check` again: that's what users will get.
5. Push the tag and create the GitHub release with the tarball and its
   `.sha256` attached.
