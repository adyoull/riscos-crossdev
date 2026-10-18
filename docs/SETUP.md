# Setup

Everything here is tested on Ubuntu 24.04 on x86-64. Other Linux
distributions should work if they have the same packages. The prebuilt
toolchain is for x86-64 with glibc 2.39 or later (Ubuntu 24.04, Debian 13
and newer); elsewhere, including ARM64 machines, build it from source.

## 1. Packages

```sh
sudo apt-get install build-essential gcc-13-multilib \
    gcc-arm-linux-gnueabihf libc6-dev-armhf-cross \
    python3 python3-venv curl xz-utils zip unzip git
# only to build the toolchain from source (make toolchain):
sudo apt-get install autogen autoconf2.69 autoconf2.64 automake1.11 automake \
    libtool texinfo gperf flex bison m4 gawk ninja-build libglib2.0-dev
# optional: CMake builds (cmake/, examples/cmake), the Unicorn test (emu/),
# and compiling riscos-gtk's fake desktop in make check:
sudo apt-get install cmake libcairo2-dev
pip install unicorn          # or: pip install --user unicorn
# optional: what several ports' builds use (meson builds such as GLib, GTK
# and Mesa; C++ code tested under QEMU). The container image has these too:
sudo apt-get install meson python3-packaging python3-mako g++-arm-linux-gnueabihf
```

What each is for:

- `gcc-13-multilib`: the Fake RISC OS tests are built 32-bit (`-m32`), so an
  `int` can hold a pointer, as on RISC OS. Not `gcc-multilib`: on Ubuntu
  24.04 that conflicts with `gcc-arm-linux-gnueabihf`, and apt either
  refuses or removes the ARM compiler.
- `gcc-arm-linux-gnueabihf`, `libc6-dev-armhf-cross`: your portable code
  built for ARM Linux, to run under QEMU.
- `libglib2.0-0` (installed with most desktops; `libglib2.0-dev` pulls it
  in): `qemu-arm-aligntrap` needs it at run time.

If apt says `gcc-arm-linux-gnueabihf` has unmet dependencies, install
`gcc-13-arm-linux-gnueabihf` first, then try again.

## 2. The toolchain

Use a tagged release of this repo (`git clone -b v1.8.2 ...`). Each tag names
one toolchain tarball and its sha256 in `toolchain/PREBUILT`. When a
release doesn't change the toolchain, it keeps the previous one's tarball:
1.5 to 1.8.2 use 1.4's.

**Prebuilt** (a few minutes):

```sh
make prebuilt
```

This downloads the tarball from the GitHub release, checks its sha256 and
unpacks it into `toolchain/env`. If you already have the tarball:
`toolchain/install-prebuilt.sh path/to/riscos-crossdev-toolchain-1.4-x86_64-linux.tar.xz`.

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
| `arm-riscos-gnueabihf-gcc`, `-g++`, `-as`, `-ld`, `-objdump`, ... | The cross toolchain. Static only: there are no shared target libraries, and links are static without `-static` too |
| `elf2aif` | ELF to Absolute (AIF). Has the fix for images over 32 MB |
| `qemu-arm-aligntrap` | QEMU user mode that traps unaligned accesses (`qemu/`) |

`toolchain/env/BUILDINFO.txt` says what it was built from.

### Somewhere else

The toolchain can live anywhere. Set `RISCOS_TOOLCHAIN` to its directory,
for example to share one copy between several checkouts:

```sh
export RISCOS_TOOLCHAIN=$HOME/riscos-toolchain-1.4
make prebuilt       # installs there
```

`env.sh` and `riscos.mk` read it, and so does every script here.

## 3. Using it for your own program

[USING.md](USING.md) is the guide: starting from an example, pointing your
project at a release, building with Make, CMake or configure, libraries,
making the application, and testing. In short:

```make
RCD_DIR := $(HOME)/riscos-crossdev
include $(RCD_DIR)/riscos.mk          # RO_CC, RISCOS_CFLAGS, the checks, the fake...
```

```sh
cmake -B build -DCMAKE_TOOLCHAIN_FILE=$HOME/riscos-crossdev/cmake/riscos.cmake
```

```sh
. $HOME/riscos-crossdev/env.sh        # PATH, RISCOS_CFLAGS, RISCOS_HOST
./configure --host=arm-riscos-gnueabihf CFLAGS="$RISCOS_CFLAGS" LDFLAGS=-static
```

Configure tests and libtool link the static libraries: the toolchain has
no `libunixlib.so`, `libstdc++.so` or `libm.so` to pick up, and adds
`-static` to links that don't say `-shared`, `-r` or `-mmodule` (keeping
`-static` in `LDFLAGS` does no harm).

## 4. Libraries: the riscos-mesa devkit

For OpenGL (OSMesa), EGL, OpenGL ES, GLU, SDL2, freeglut, OpenAL and zlib,
use the riscos-mesa devkit. Each version of riscos-crossdev names the one
it's tested with in `devkit/DEVKIT` (1.8.2: **20.3.5-16**, VFPv3 like the
toolchain), with its sha256:

```sh
make devkit          # download, check and unpack it into devkit/env
make check-devkit    # its libraries are VFPv3, and its six examples build
                     # with this toolchain and pass every check
```

`make check` runs `check-devkit` too once a devkit is installed. If you
already have the tarball: `devkit/install.sh path/to/riscos-mesa-devkit-20.3.5-16.tgz`.
Set `RISCOS_DEVKIT` to keep it somewhere else; a devkit already there is
moved to `$RISCOS_DEVKIT.old`.

In a Makefile that includes `riscos.mk`:

```make
$(RO_CC) $(RISCOS_CFLAGS) $(DEVKIT_CFLAGS) -o prog prog.c \
    $(RISCOS_LDFLAGS) $(DEVKIT_LDFLAGS) -lEGL -lOSMesa -lstdc++ -lz -lm
```

The devkit's `README.md` (in `devkit/env`) lists the libraries each part
needs and in what order, explains every flag, and has six small example
programs. Threaded programs (OpenAL, SDL sound, and anything using
pthreads) should ship the PThreadTicker module 0.03, which UnixLib 5.0.3.1
and later use: `toolchain/env/riscos/PThrTicker,ffa`, or the same module in
the devkit's `riscos/` folder (devkit 20.3.5-11 and later; earlier devkits have 0.01,
which programs built with this toolchain don't use).

## 5. Updating

A new toolchain or devkit means a new tag of this repo. To move a port to
it: check out the new tag, run `make prebuilt` into a fresh
`RISCOS_TOOLCHAIN` and `make devkit`,
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
