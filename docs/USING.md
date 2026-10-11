# Using riscos-crossdev for your own program

This is the guide to building and testing your own RISC OS program with
riscos-crossdev, from an empty directory to a zip for the Pi. It assumes the
kit is set up ([SETUP.md](SETUP.md): `make prebuilt`, and `make devkit` if
you need OpenGL, SDL2, OpenAL or zlib). Every command and variable is
listed in [REFERENCE.md](REFERENCE.md).

Contents:

1. [The pieces, and the order you use them](#1-the-pieces-and-the-order-you-use-them)
2. [Start from an example](#2-start-from-an-example)
3. [Point your project at riscos-crossdev](#3-point-your-project-at-riscos-crossdev)
4. [Build with Make](#4-build-with-make)
5. [Build with CMake](#5-build-with-cmake)
6. [Build with configure (autotools)](#6-build-with-configure-autotools)
7. [Libraries: the devkit and your own](#7-libraries-the-devkit-and-your-own)
8. [C++](#8-c)
9. [Make the application: !App, !Run, !Sprites, the zip](#9-make-the-application-app-run-sprites-the-zip)
10. [Test it on Linux](#10-test-it-on-linux)
11. [Test it on the Pi](#11-test-it-on-the-pi)
12. [Moving to a new release](#12-moving-to-a-new-release)
13. [Porting an existing program: a checklist](#13-porting-an-existing-program-a-checklist)

## 1. The pieces, and the order you use them

```
 your sources ──► arm-riscos-gnueabihf-gcc ──► static ELF ──► checks ──► strip, elf2aif ──► !App ──► zip ──► Pi
                  (RISCOS_CFLAGS, -static)                  (check-all)  (AIF, &FF8)                (rozip)
      │
      ├─ code that calls SWIs ─────► gcc -m32 + the Fake RISC OS (fake/) ─────► test on Linux
      ├─ portable code ────────────► arm-linux-gnueabihf-gcc + qemu-arm-aligntrap ─► test as ARM code
      └─ modules, assembler ───────► Unicorn (emu/) ─────────────────────────► test with faked SWIs
```

- **The compiler** is GCCSDK GCC 10.2 with UnixLib, a POSIX C library for
  RISC OS. Most Unix C and C++ builds, with the limits in
  [RISCOS-RULES.md](RISCOS-RULES.md). Read that page before you port
  anything: each rule there is a crash on RISC OS that Linux never shows.
- **The checks** run on every linked program and catch what compiles but
  then aborts or hangs on RISC OS.
- **The Linux tests** run your code in seconds, under a debugger if you
  like. They don't replace the Pi; they mean the Pi run tests the things
  only the Pi can.

## 2. Start from an example

Copy the example closest to what you're making:

| Example | What it is | Shows |
|---|---|---|
| [`examples/hello`](../examples/hello) | A command-line program that runs in a task window | A Makefile with every step; a Fake RISC OS test of its SWI calls; a QEMU test of its portable part |
| [`examples/wimp`](../examples/wimp) | A desktop program: icon bar icon, window, menu | The Wimp poll loop kept apart from the event handling, so the handling can be tested; every Wimp SWI it uses faked in the test; `!Sprites` from PNGs |
| [`examples/cmake`](../examples/cmake) | A library and a program, built with CMake | One `CMakeLists.txt` built for RISC OS, for ARM Linux with ctest under QEMU, and for the host; a library from the devkit found by `find_package` |

The devkit has six more, for OpenGL, OpenGL ES, SDL2 and OpenAL, in
`devkit/env/examples` (see its `README.md`); `make check-devkit` builds them
with this toolchain.

```sh
cp -r riscos-crossdev/examples/wimp myprog
cd myprog
make RCD_DIR=../riscos-crossdev check all
```

Then rename things: the app directory and zip in the `Makefile`,
`APP_NAME` in `src/app.c` (the wimp example), the sprite names, the `$Dir`
variable in `!Run`.

## 3. Point your project at riscos-crossdev

Your project needs to know where riscos-crossdev is (`RCD_DIR`) and which
release it uses. Use a tagged release, never `main`: a tag names exactly
one toolchain tarball and devkit, by sha256, so everyone building your
project gets the same compiler and libraries. Three ways, best first:

- **A git submodule at a tag:**

  ```sh
  git submodule add https://github.com/adyoull/riscos-crossdev crossdev
  git -C crossdev checkout v1.7.1
  git add crossdev && git commit -m "riscos-crossdev 1.7.1"
  ```

  The tag is recorded in your repository, and `RCD_DIR := crossdev` is
  always right. Others run `git submodule update --init`, then
  `make -C crossdev prebuilt devkit`.
- **A path and a version check.** Keep riscos-crossdev anywhere
  (`RCD_DIR=~/riscos-crossdev`) and make your build fail on the wrong
  version: `git -C $(RCD_DIR) describe --tags` must print the tag you
  expect.
- **Only the toolchain.** If all you need is the compiler, unpack the
  release's toolchain tarball anywhere and set `RISCOS_TOOLCHAIN` to it.
  You lose the checks and the tests.

In a shell, the commands in this guide use `$RCD_DIR` for that directory:

```sh
export RCD_DIR=$HOME/riscos-crossdev     # or your submodule's path
```

To share one toolchain between several projects or checkouts, install it
once and set `RISCOS_TOOLCHAIN` (and `RISCOS_DEVKIT`) in your environment:
every script, `riscos.mk`, `env.sh` and the CMake toolchain file read them.

## 4. Build with Make

Include `riscos.mk`. It gives you the compiler, the flags, the tools and
the Fake RISC OS:

```make
RCD_DIR ?= ../riscos-crossdev
include $(RCD_DIR)/riscos.mk

SRC := src/main.c src/app.c
out/myprog: $(SRC) $(RO_CC) | riscos-toolchain-present
	@mkdir -p out
	$(RO_CC) $(RISCOS_CFLAGS) -Wall $(RISCOS_LDFLAGS) -o $@ $(SRC)
	$(CHECK_ALL) $@
```

- **`RISCOS_CFLAGS`** is `-O2 -mfpu=vfpv3 -mfloat-abi=hard
  -fstack-clash-protection`. Add your own flags after it; don't take any
  of these out. `-fstack-clash-protection` is what stops large stack frames
  aborting on RISC OS, and `-mfpu` decides which machines can run the
  program (vfpv3: every ARMv7 machine; `FPU=vfpv4` for Cortex-A7 and later
  only).
- **`RISCOS_LDFLAGS`** is `-static`. Every program is static: there are no
  RISC OS shared libraries here.
- **Make `$(RO_CC)` a prerequisite** of the program (and, as the examples
  do, `$(RISCOS_TOOLCHAIN)/$(RISCOS_HOST)/lib/libunixlib.a`). Then a new
  toolchain relinks it, instead of leaving a program built against the old
  UnixLib, which `check-unixlib.sh` would reject.
- **`riscos-toolchain-present`** as an order-only prerequisite gives a
  clear message when the toolchain isn't installed.

For a library, compile with `$(RO_CC) $(RISCOS_CFLAGS) -c` and archive with
`$(RO_AR) rcs`. Run `$(CHECK_ALL) program lib1.a lib2.a` to check the
libraries' FPU level too.

## 5. Build with CMake

Use the toolchain file:

```sh
cmake -B build-riscos -DCMAKE_TOOLCHAIN_FILE=$RCD_DIR/cmake/riscos.cmake -DCMAKE_BUILD_TYPE=Release
cmake --build build-riscos
```

It sets the compiler, the RISC OS flags and `-static` (optimisation comes
from the build type: Release unless you give another), and makes
`find_package`, `find_library`, `find_path` and `pkg_check_modules` search
the toolchain and the devkit, never the host. CMake sees the system as
`RISCOS`, with `UNIX` set too, so:

```cmake
if(RISCOS)
  include(RiscOS)                                   # from cmake/RiscOS.cmake
  riscos_checks(myprog)                             # check-all after each link
  riscos_aif(myprog "${CMAKE_BINARY_DIR}/!MyProg/!RunImage,ff8")
endif()
```

`riscos_checks` makes the build fail if a check fails. `riscos_aif` adds a
target that strips the program and makes the Absolute file.

`cmake/linux-arm-aligntrap.cmake` builds the same project as ARM Linux
code, and makes ctest run each test under `qemu-arm-aligntrap`:

```sh
cmake -B build-qemu -DCMAKE_TOOLCHAIN_FILE=$RCD_DIR/cmake/linux-arm-aligntrap.cmake
cmake --build build-qemu && ctest --test-dir build-qemu
```

`examples/cmake` does all three builds from one `CMakeLists.txt`.

## 6. Build with configure (autotools)

```sh
. $RCD_DIR/env.sh                     # PATH, RISCOS_CFLAGS, RISCOS_DEVKIT (bash, zsh, or sh with RCD_DIR set)
PKG_CONFIG_LIBDIR=$RISCOS_DEVKIT/lib/pkgconfig PKG_CONFIG_PATH= \
./configure --host=arm-riscos-gnueabihf --disable-shared \
    CFLAGS="$RISCOS_CFLAGS" CXXFLAGS="$RISCOS_CFLAGS" \
    CPPFLAGS="-I$RISCOS_DEVKIT/include" LDFLAGS="-static -L$RISCOS_DEVKIT/lib"
make
$RCD_DIR/checks/check-all.sh src/myprog
```

- `--host=arm-riscos-gnueabihf` makes it a cross build: configure doesn't
  try to run what it compiles. (`--disable-shared` is for packages that
  use libtool; others warn that they don't know it, which is harmless.)
- `PKG_CONFIG_LIBDIR` makes `pkg-config` read the devkit's `.pc` files and
  never your Linux system's. The devkit's `.pc` files work out their own
  paths, and list every library a static link needs.
- `config.sub` from before about 2018 doesn't know `riscos`: copy in
  current `config.sub` and `config.guess` (from
  `/usr/share/automake-*/`).
- Keep paths free of spaces: autoconf and libtool can't cope with them.
- A configure check that needs to run a program (`AC_RUN_IFELSE`) can't;
  answer it with a cache variable (`ac_cv_...=yes`) on the command line.
- Programs the build runs on the build machine (code generators) must be
  built with the host compiler: pass `CC_FOR_BUILD=gcc` if the package
  uses it.

## 7. Libraries: the devkit and your own

The riscos-mesa devkit (`make devkit`) has static OpenGL (OSMesa), EGL,
OpenGL ES 1 and 2, GLU, SDL2, freeglut, OpenAL and zlib, built for this
toolchain. With Make:

```make
SDL_CFLAGS := $(shell $(RISCOS_PKG_CONFIG) --cflags sdl2)
SDL_LIBS := $(shell $(RISCOS_PKG_CONFIG) --libs --static sdl2)
out/game: $(SRC) $(RO_CC) | riscos-toolchain-present
	$(RO_CC) $(RISCOS_CFLAGS) $(SDL_CFLAGS) $(RISCOS_LDFLAGS) -o $@ $(SRC) $(SDL_LIBS)
```

(`$(DEVKIT_CFLAGS)` and `$(DEVKIT_LDFLAGS)` are the plain `-I` and `-L` for
the devkit, if you'd rather name the libraries yourself.)

`RISCOS_PKG_CONFIG` is `pkg-config` reading only the devkit's `.pc` files.
Its `README.md` (in `devkit/env`) says which libraries each part needs, in
link order.

For any other library, build it yourself with the same compiler and flags
(sections 4 to 6), as a static `.a`, into a staging directory of your
project, and check it: `checks/check-fpu.sh lib.a`. Build it with
`-fstack-clash-protection` too: a library compiled without it can still
make a large frame that `check-stack-probes.py` finds in your program.
The ports at [github.com/adyoull](https://github.com/adyoull) build many
(libpng, freetype, ogg, vorbis, expat, fontconfig, PhysicsFS, ...): their
build scripts are a good start.

## 8. C++

Use `$(RO_CXX)` (`arm-riscos-gnueabihf-g++`) with the same flags. libstdc++
is linked statically like everything else, and exceptions link. Never pass
GCC a `-specs` file: with one, this GCC leaves out `-lgcc_eh`, and C++
programs no longer link. A program that mixes C and C++ objects
must be linked with `g++`, or with `gcc ... -lstdc++`.

## 9. Make the application: !App, !Run, !Sprites, the zip

A RISC OS application is a directory whose name starts with `!`:

| File | Filetype | What |
|---|---|---|
| `!RunImage,ff8` (or any name) | Absolute (&FF8) | Your program: the ELF stripped, then `elf2aif`'d |
| `!Run,feb` | Obey (&FEB) | Run on double-click: sets `<App$Dir>`, loads the modules the program needs, sets the WimpSlot, runs it |
| `!Boot,feb` | Obey | Run when the Filer first sees the app: `IconSprites`, `<App$Dir>` |
| `!Sprites,ff9` | Sprite (&FF9) | The app's icon: sprites `!myapp` (34 x 34) and `sm!myapp` (17 x 17) |
| `!Help,fff` | Text (&FFF) | Shown by Help in the Filer menu |

The `,xxx` suffix is the RISC OS filetype in hex. Keep it in the file names
in your repository: `package/rozip.py` stores it in the zip, and the
unzipper on RISC OS sets the filetype from it.

```make
out/!MyApp/!RunImage,ff8: out/myprog
	@mkdir -p $(dir $@)
	$(RO_STRIP) -o out/myprog.stripped out/myprog
	$(ELF2AIF) -e out/myprog.stripped $@
out/!MyApp/!Sprites,ff9: icon.png icon-small.png
	@mkdir -p $(dir $@)
	$(PNG2SPRITE) $@ '!myapp=icon.png' 'sm!myapp=icon-small.png'
out/MyApp.zip: out/!MyApp/!RunImage,ff8 out/!MyApp/!Sprites,ff9
	cp app/!Run,feb app/!Boot,feb app/!Help,fff out/!MyApp/
	$(ROZIP) $@ -C out !MyApp
```

- **Why AIF:** an ELF program needs the `!SharedLibs` ELF loader; an
  Absolute file runs on any RISC OS 5 with just two modules.
- **`!Run` must load those modules,** SharedUnixLibrary 1.16 or later and
  ARMEABISupport, with `RMEnsure` (copy the lines from
  `examples/wimp/app/!Run,feb`). Threaded programs also need the
  PThreadTicker module (`toolchain/env/riscos/PThrTicker,ffa`): ship it in
  your app and `RMEnsure PThreadTicker 0.03` it the same way.
- **The WimpSlot** is the memory the program starts with. UnixLib puts a
  large heap in a dynamic area, so the slot mostly has to hold the program
  itself: `WimpSlot -min 1024K -max 1024K` is enough for a small one, and a
  big program or a large static array needs more
  ([RISCOS-RULES.md](RISCOS-RULES.md) section 7).
- **A command-line program** can run in a task window from `!Run`, as
  `examples/hello` does, or be set up as a command with
  `Set Alias$MyProg Run <MyProg$Dir>.myprog %%*0` in `!Run`, as
  `examples/cmake` does (`%%` because `!Run` is an Obey file).
- **Sprites:** `package/png2sprite.py` turns PNGs into a sprite file.
  Sprite names are lower case, up to 12 characters, and the app sprite is
  the app's name in lower case with the `!`.

## 10. Test it on Linux

Split your code in two before you test it:

- **Code that calls SWIs** (screen, Wimp, files by RISC OS name, modules):
  keep it in a few files, behind functions of your own. Test it against the
  Fake RISC OS: built with `$(FAKE_CC) $(FAKE_CFLAGS)` and `$(FAKE_SRC)`,
  your test installs a C function for each SWI the code calls
  (`fake_swi`), then calls your code and checks what happened.
  `examples/wimp/tests/test_fake.c` fakes ten Wimp SWIs and plays a user's
  clicks; `examples/hello/tests/test_fake.c` is smaller.
- **Everything else:** test it as ARM code under `qemu-arm-aligntrap`, which
  stops the program at the first unaligned access, as RISC OS would, and on
  any VFPv4 instruction. With Make: `$(LINUXARM_CC) $(LINUXARM_CFLAGS)`, run
  through `$(ALIGNTRAP)` (see `examples/hello`); with CMake: the
  `linux-arm-aligntrap.cmake` toolchain file and ctest.
- **Modules and assembler** routines: `emu/rcd_emu.py` runs them in the
  Unicorn emulator with SWIs faked in Python (`emu/example`).

Before writing a fake of a module or of the desktop, look in `fake/ports/`:
the ports' fakes of SharedSoundBuffer, DigitalRenderer, VideoOverlay,
AcornSSL, VCHIQ, a scripted Wimp desktop with a screen in memory and more
are there, with where each came from ([TESTING.md](TESTING.md)).

## 11. Test it on the Pi

[PI-TESTING.md](PI-TESTING.md): getting the zip across, the modules it
needs, what to try, and what to collect when something goes wrong.

## 12. Moving to a new release

When riscos-crossdev has a new release (new toolchain, UnixLib or devkit):

1. Move your submodule (or checkout) to the new tag; read its
   `CHANGELOG.md` entry.
2. `make prebuilt` into a fresh `RISCOS_TOOLCHAIN`, and `make devkit`.
3. Rebuild everything from clean, including your own libraries: objects
   built against the old UnixLib headers must not be mixed with the new
   ones. `check-unixlib.sh` catches the commonest case.
4. Run your checks and Linux tests, then test on the Pi again.

## 13. Porting an existing program: a checklist

- [ ] Read [RISCOS-RULES.md](RISCOS-RULES.md).
- [ ] Build it for Linux first, with `-Wcast-align=strict`: each warning is
      a possible alignment abort on RISC OS. `checks/check-unaligned.sh`
      does this for you.
- [ ] Build its libraries as static `.a` files with `RISCOS_CFLAGS`.
- [ ] Look for `fork`, `exec*`, `system`, `popen`, `mmap` of files, `dlopen`
      and threads that spin: RISC OS has no `fork`, and its multitasking is
      cooperative.
- [ ] Guard RISC OS code with `#ifdef __riscos__` (the compiler defines
      it), and keep the SWI calls in their own files.
- [ ] Files: UnixLib maps Unix paths to RISC OS ones (`/` and `.` swap),
      and `name.ext` is stored as `name/ext`. Ship data with the names
      UnixLib expects ([RISCOS-RULES.md](RISCOS-RULES.md) section 9).
- [ ] Add the checks to the build, so they run on every link.
- [ ] Write Fake RISC OS tests for the code that calls SWIs, and run the
      portable code's tests under QEMU.
- [ ] Make the app (section 9) and test on the Pi.
