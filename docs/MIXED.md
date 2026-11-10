# Mixed programs: UnixLib linked in, other libraries shared

New in 1.11, with UnixLib 5.0.3.7. Ordinary static programs are built
exactly as before.

A crossdev program is normally static: UnixLib, libstdc++ and every other
library are linked into it. A *mixed* program still has UnixLib, libstdc++
and libgcc linked in. Its other libraries, though, are shared libraries
(`.so`), which RISC OS loads when the program starts, using !SharedLibs
(SOManager and `ld-riscos/so/2`). Programs that use the same library then
share one copy of its code in memory.

**Tested:**

- on RISC OS on Linux (in QEMU, and on the owner's own machine) with
  `MixTest`: C and C++, threads, signals, and exceptions between a
  program and a library;
- on RISC OS 5 directly, on a Raspberry Pi 4, with riscos-gtk's mixed
  Geany and L3afpad. Both used one copy of GTK's 26 libraries (20 MB), the
  same as Geany alone, and ran alongside Iris, which uses !SharedLibs
  too.

## Building

With `riscos.mk`:

```make
# A library: position-independent, and with no UnixLib of its own.
$(RO_CC) $(RISCOS_SO_CFLAGS) -c -o greet.o greet.c
$(RO_CC) $(RISCOS_SO_LDFLAGS) -Wl,-soname,libgreet.so.1 -o libgreet.so greet.o $(RISCOS_SO_LIBS)

# The program: -rdynamic instead of -static.
$(RO_CC) $(RISCOS_CFLAGS) -o prog main.c $(RISCOS_MIXED_LDFLAGS) -L. -lgreet

# A library from a static archive built with -fPIC (no libtool needed):
# the .so, its SONAME, the archive, and the libraries it uses.
$(call RISCOS_SO_FROM_A,libx.so,libx.so.1,libx.a,-L. -lgreet)
```

| Variable | Value | What it does |
|---|---|---|
| `RISCOS_SO_CFLAGS` | `$(RISCOS_CFLAGS) -fPIC` | Library code that every program can share |
| `RISCOS_SO_LDFLAGS` | `-shared -nodefaultlibs` | A shared library, with no UnixLib, libstdc++ or libgcc of its own (1.11 had `-nostdlib`) |
| `RISCOS_SO_LIBS` | `-lgcc` | libgcc's helpers, private to the library (C++ libraries need its unwinder) |
| `RISCOS_MIXED_LDFLAGS` | `-rdynamic -Wl,-rpath-link=$(RISCOS_MIXED_STUBS)` | Link the program dynamically, with UnixLib still linked in |
| `RISCOS_MIXED_STUBS` | the toolchain's `mixed-stubs` | Stand-ins for GCCSDK-built libraries (below) |
| `RISCOS_SO_FROM_A` | a `$(call …)` | A shared library from a static archive: `--whole-archive`, and `--as-needed` for the libraries it uses |

- **What `-rdynamic` does:** with this toolchain it leaves the link
  dynamic (every other link gets `-static`).
  - UnixLib, libstdc++ and libgcc still come from the static libraries;
    there are no shared ones.
  - The program exports their functions, so its libraries use the
    program's malloc, printf and so on: one UnixLib, one heap.
  - `ld-riscos/so/2` becomes the program's interpreter.
  - `crtmixed.o` is linked in, so C++ exceptions can pass between a
    library and the program.
  - libstdc++ is linked in too, even into a C program, as `g++` does: a
    library may be C++ (riscos-gtk's harfbuzz is). Only what the libraries
    use is linked in.
- **`-pthread` works** as on Linux (`_REENTRANT`, and an empty
  `libpthread`: UnixLib has the threads). Threaded programs ship the
  PThreadTicker module, static or mixed.
- **A `-rdynamic` link needs at least one shared library on the line.**
  Without one, binutils 2.30's ld crashes ("ld terminated with signal 11").
- **Watch for builds that already pass `-rdynamic`** (some configure
  scripts and CMake's `ENABLE_EXPORTS` do). They now make a dynamic
  program. `checks/check-static.sh` says so: "dynamically linked but needs
  no shared library: drop -rdynamic".
- **Don't link a library with `libunixlib.a`.** `-nodefaultlibs` keeps UnixLib
  out of it; with two copies there would be two heaps.
  `checks/check-shared-lib.sh` catches this, and libraries that aren't
  position-independent.
- **`-nodefaultlibs`, not `-nostdlib`.** Both leave out UnixLib, libstdc++
  and libgcc. `-nostdlib` also leaves out the start files
  (`crtbeginS.o` and the rest), and with them `__dso_handle`: a C++
  library with static objects then fails to link ("undefined reference to
  `__dso_handle`"). With `-nodefaultlibs` each library's static objects
  are built when it loads and destroyed, in order, when the program exits
  (tested on RISC OS on Linux). Found by riscos-mesa.
- **Libraries from big archives:**
  - `--whole-archive` (in `RISCOS_SO_FROM_A`) fails with "multiple
    definition" if the archive holds the same object twice, as meson's
    overlapping internal libraries can make it. A static link never
    notices. Extract each distinct member once and link the objects
    (riscos-mesa's `tools/ar-unique.py` does this).
  - Code compiled with `-ffunction-sections -fdata-sections` that exports
    only its API shrinks a lot with `-Wl,--gc-sections` (riscos-mesa's
    libOSMesa: 17 MB to 7.6 MB unstripped).
  - A shared SDL holds all of SDL, including `SDL_LoadObject`'s `dlopen`,
    which a static link only pulled in when used. Link the program with
    `-ldl` (the toolchain's stub) to satisfy it.
- **Strip the libraries you ship** with `--strip-unneeded`. Unstripped,
  their symbol tables name the build machine's directories. Stripped ones
  still link.

## Checking

- `checks/check-all.sh PROGRAM` (the unstripped ELF) accepts a mixed
  program: "OK: … is mixed: UnixLib linked in; shared: libgreet.so.1".
- `checks/check-shared-lib.sh LIBRARY.so` checks each library:
  - it has a SONAME;
  - it doesn't need a shared UnixLib, libstdc++, libgcc_s or libm;
  - it has no text relocations;
  - it doesn't define UnixLib's own functions.

- `checks/check-mixed-package.sh PROGRAM LIBDIR` checks a package: every
  library the program needs, directly or through another library, is in
  LIBDIR (as `libX.so.N` or `libX.so.N,e1f`) and passes
  `check-shared-lib.sh` (or is a stand-in, below), and every name the
  libraries need is defined. `examples/mixed` runs it before zipping.

### One UnixLib, always

A mixed program's UnixLib is the one linked into it. Its libraries must
not bring their own: a second UnixLib would have its own heap, file table
and signal handlers.

**Libraries built for fully shared programs** (GCCSDK's, as in
!SharedLibs) need `libunixlib.so.5`, and C++ ones `libstdc++.so.6`,
`libgcc_s.so.1` and `libm.so.1`. A mixed program can still use them, with its own UnixLib:

- The toolchain has **stand-ins** under those names, in
  `$(RISCOS_MIXED_STUBS)` (`arm-riscos-gnueabihf/lib/mixed-stubs`). They
  are empty libraries.
- Put the ones needed in the app's `lib` directory, like its other
  libraries (`lib.libunixlib/so/5`). The loader looks there first, so it
  loads the stand-in, and the library's calls go to the program's UnixLib,
  which the program exports. `-rdynamic` links in whatever UnixLib
  functions the libraries use, as well as the program's own.
- **C++ libraries** ask for libstdc++'s names with versions
  (`operator new@GLIBCXX_3.4`). Link the program with
  `$(shell riscos-mixed-exports LIBS)` (the toolchain's `bin`): it lists
  every name those libraries need, so the static libstdc++, libgcc and
  UnixLib parts they use are linked in and exported. The loader matches
  them by name.

  ```make
  $(RO_CXX) $(RISCOS_CFLAGS) -o prog main.o $(RISCOS_MIXED_LDFLAGS) \
      $(shell riscos-mixed-exports libfoo.so) -L. -lfoo
  ```
- They're used only by the programs whose `LD_LIBRARY_PATH` has them.
  Other programs, fully shared ones
  included, still get the real shared UnixLib from !SharedLibs: SOManager
  tells libraries apart by their full path, not their name.
- Nothing needs renaming: the program's UnixLib is linked in, so it has no
  file or SONAME of its own.

Three checks keep it to one UnixLib:

1. **Building a library:** `check-shared-lib.sh` refuses one that needs a
   shared UnixLib or defines UnixLib's functions. With `--stand-ins` it
   accepts one that needs only the four above.
2. **Packaging:** `check-mixed-package.sh` follows every library the
   program needs, says which stand-ins to copy in, and checks that the
   program or a library defines every name the libraries need.
3. **Running:** `crtmixed.o` looks at every library the loader has loaded.
   If one is a real shared UnixLib, libstdc++ or libgcc_s (a stand-in was
   missing, so the one in !SharedLibs was found), the program stops before
   `main` with a message naming it.

Keep every library the program needs in the directories on its
`LD_LIBRARY_PATH` (below): a library missing there would be looked for in
!SharedLibs.

Tested on RISC OS on Linux (QEMU, NativeSupport 0.33):

- a C library linked against `libunixlib.so.5` runs in a mixed program
  with the stand-in, using the program's `qsort`, `strtol`, `getpid`,
  `malloc` and `snprintf`; with a real `libunixlib.so.5` in its place, the
  program stops with the message;
- a C++ library built as GCCSDK builds them (shared libstdc++, UnixLib,
  libgcc_s, libm) runs in a mixed program with the stand-ins and
  `riscos-mixed-exports`: strings, vectors, sorting, an exception caught
  inside it, and exceptions it throws caught by the program;
- **all at once**, each in its own task window: a static program, a mixed
  one, a fully shared one (the real `libunixlib.so.5` from
  !SharedLibs.lib.armeabihf) and the mixed C++ one, all with a thread, for
  40 seconds. All finished correctly.

**Hidden symbols:** a library built with `-fvisibility=hidden` (GLib is)
exports only what is marked for export. A variable the program sets in a
library, such as GLib's `g_riscos_spawn_hooks`, needs
`__attribute__((visibility("default")))`.

## Packaging

`examples/mixed` builds `!MixHello`; copy it to start.

- **The program:** it stays an ELF file (filetype &E1F), stripped. It isn't
  converted with `elf2aif`. !SharedLibs runs it (`Alias$@RunType_E1F`).
- **The libraries** go under their SONAME, such as `lib.libgreet/so/1`
  (`libgreet.so.1,e1f` on Linux), in one of two places:
  - **in the app's own directory,** for libraries only it uses
    (`!MixHello.lib`);
  - **in a library pack in `!Boot.Resources`,** for libraries several apps
    share, as riscos-gtk's `!GTKLibs` holds GTK's 26. Its `!Boot` sets
    `GTKLibs$Path`; each app's `!Run` boots it if it hasn't been.
- **Only one copy of each file is shared.** SOManager loads each library
  file once and shares it between every program that uses that file. Two
  apps each with their own copy of a library load it twice. So libraries
  meant to be shared go in one pack, used by every app.
- **Not in !SharedLibs.lib.** GCCSDK's own packages there use the same
  SONAMEs (`libz.so.1`, `libpng16.so.16`, `libglib-2.0.so.0`…) for
  programs built against the shared UnixLib.
- **`!Run` tells the loader where they are.** The variable is named after
  the program's leaf name, or after the app (without the `!`) when the
  program is `!RunImage`. A pack's directory goes after the app's own:

  ```
  Set MixHelloLibs$Path <MixHello$Dir>.lib.
  Set mixhello$LD$Env "LD_LIBRARY_PATH=/MixHelloLibs:"
  Run <MixHello$Dir>.mixhello
  ```

  riscos-gtk's `!Geany` uses its pack like this (from its `!Run`, which
  runs on RISC OS 5 and RISC OS on Linux):

  ```
  If "<SharedLibs$Dir>" = "" Then IfThere Boot:Resources.!SharedLibs.!Boot Then Run Boot:Resources.!SharedLibs.!Boot
  If "<GTKLibs$Dir>" = "" Then IfThere Boot:Resources.!GTKLibs.!Boot Then Run Boot:Resources.!GTKLibs.!Boot
  Unset Geany$SO2
  IfThere SharedLibs:lib.ld-riscos-eabihf/so Then Set Geany$SO2 1
  If "<Geany$SO2>" = "" Then Error The !SharedLibs booted has no ld-riscos/so/2: Geany needs a newer one (GCCSDK 8 or later) in !Boot.Resources.
  If "<GTKLibs$Dir>" = "" Then Error Geany needs !GTKLibs in !Boot.Resources
  Set geany$LD$Env "LD_LIBRARY_PATH=/GTKLibs:"
  Run <Geany$Dir>.geany %*0
  ```
- **Check the package** with every directory, in order:
  `checks/check-mixed-package.sh PROGRAM APPLIBDIR PACKDIR`.

- **What users need:**
  - SharedUnixLibrary 1.16 or later;
  - ARMEABISupport (1.05 and 1.08 both tested);
  - a **!SharedLibs that has `ld-riscos/so/2`** (GCCSDK 8 or later; Iris
    ships one), in `!Boot.Resources`. riscos.info's SharedLibs 4.0 package
    has only the older `ld-riscos/so/1` and won't run these programs.
    `!Run` can check for it, as `!Geany`'s does above;
  - any library pack the app uses.
- **On RISC OS on Linux,** use NativeSupport 0.33 or later. Older versions
  abort after any program removes a dynamic area.

## Not done yet

- **CMake:** `cmake/riscos.cmake` links every program `-static`, so mixed
  programs need Make (or configure) for now.
- **`-Wl,--as-needed` for the program** isn't in `RISCOS_MIXED_LDFLAGS`. A
  program then names only the libraries it calls itself, and the loader
  finds the rest through them. It hasn't been tried with SOManager, and
  ld 2.30 crashes on an `-rdynamic` link left with no shared library. Add
  it yourself if you need it, and test.

## The devkit

The riscos-mesa devkit's libraries in `lib/` are static (`.a`): a mixed
program can link them in, as a static one does.

riscos-mesa is adding shared builds of them, from its test build
20.3.5-19c: libOSMesa, libEGL, libGLU, libglut, libSDL2 and libopenal as
`.so` files in the devkit's `lib/shared`, and as `!MesaLibs`, a library
pack for `!Boot.Resources`. They haven't run on RISC OS yet; until a
release has them, link the devkit's libraries in.
