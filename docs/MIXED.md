# Mixed programs: UnixLib linked in, other libraries shared (test)

**This is a test build** (`v1.11-test1`, branch `mixed-link-test`). It
needs UnixLib 5.0.3.7, which is still a release candidate (rc4). Ordinary
static programs are built exactly as before.

A crossdev program is normally static: UnixLib, libstdc++ and every other
library are linked into it. A *mixed* program still has UnixLib, libstdc++
and libgcc linked in. Its other libraries, though, are shared libraries
(`.so`), which RISC OS loads when the program starts, using !SharedLibs
(SOManager and `ld-riscos/so/2`). Programs that use the same library then
share one copy of its code in memory.

It has been tested on RISC OS on Linux (in QEMU, and on the owner's own
machine) with `MixTest`: C and C++, threads, signals, and exceptions
between a program and a library. It hasn't yet been run on RISC OS 5
directly on a Pi.

## Building

With `riscos.mk`:

```make
# A library: position-independent, and with no UnixLib of its own.
$(RO_CC) $(RISCOS_SO_CFLAGS) -c -o greet.o greet.c
$(RO_CC) $(RISCOS_SO_LDFLAGS) -Wl,-soname,libgreet.so.1 -o libgreet.so greet.o $(RISCOS_SO_LIBS)

# The program: -rdynamic instead of -static.
$(RO_CC) $(RISCOS_CFLAGS) -o prog main.c $(RISCOS_MIXED_LDFLAGS) -L. -lgreet
```

| Variable | Value | What it does |
|---|---|---|
| `RISCOS_SO_CFLAGS` | `$(RISCOS_CFLAGS) -fPIC` | Library code that every program can share |
| `RISCOS_SO_LDFLAGS` | `-shared -nostdlib` | A shared library, with no UnixLib, libstdc++ or libgcc of its own |
| `RISCOS_SO_LIBS` | `-lgcc` | libgcc's helpers, private to the library (C++ libraries need its unwinder) |
| `RISCOS_MIXED_LDFLAGS` | `-rdynamic -Wl,-rpath-link=$(RISCOS_MIXED_STUBS)` | Link the program dynamically, with UnixLib still linked in |
| `RISCOS_MIXED_STUBS` | the toolchain's `mixed-stubs` | Stand-ins for GCCSDK-built libraries (below) |

- **What `-rdynamic` does:** with this toolchain it leaves the link
  dynamic (every other link gets `-static`).
  - UnixLib, libstdc++ and libgcc still come from the static libraries;
    there are no shared ones.
  - The program exports their functions, so its libraries use the
    program's malloc, printf and so on: one UnixLib, one heap.
  - `ld-riscos/so/2` becomes the program's interpreter.
  - `crtmixed.o` is linked in, so C++ exceptions can pass between a
    library and the program.
- **A `-rdynamic` link needs at least one shared library on the line.**
  Without one, binutils 2.30's ld crashes ("ld terminated with signal 11").
- **Watch for builds that already pass `-rdynamic`** (some configure
  scripts and CMake's `ENABLE_EXPORTS` do). They now make a dynamic
  program. `checks/check-static.sh` says so: "dynamically linked but needs
  no shared library: drop -rdynamic".
- **Don't link a library with `libunixlib.a`.** `-nostdlib` keeps UnixLib
  out of it; with two copies there would be two heaps.
  `checks/check-shared-lib.sh` catches this, and libraries that aren't
  position-independent.

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
  `check-shared-lib.sh`, and none is a shared UnixLib, libstdc++ or
  libgcc_s. `examples/mixed` runs it before zipping.

### One UnixLib, always

A mixed program's UnixLib is the one linked into it. Its libraries must
not bring their own: a second UnixLib would have its own heap, file table
and signal handlers.

**Libraries built for fully shared programs** (GCCSDK's, as in
!SharedLibs) need `libunixlib.so.5`, and C++ ones `libstdc++.so.6` and
`libgcc_s.so.1`. A mixed program can still use them, with its own UnixLib:

- The toolchain has **stand-ins** under those names, in
  `$(RISCOS_MIXED_STUBS)` (`arm-riscos-gnueabihf/lib/mixed-stubs`). They
  are empty libraries.
- Put the ones needed in the app's `lib` directory, like its other
  libraries (`lib.libunixlib/so/5`). The loader looks there first, so it
  loads the stand-in, and the library's calls go to the program's UnixLib,
  which the program exports. `-rdynamic` links in whatever UnixLib
  functions the libraries use, as well as the program's own.
- They're used only by this app. Other programs, fully shared ones
  included, still get the real shared UnixLib from !SharedLibs: SOManager
  tells libraries apart by their full path, not their name.
- Nothing needs renaming: the program's UnixLib is linked in, so it has no
  file or SONAME of its own.

Three checks keep it to one UnixLib:

1. **Building a library:** `check-shared-lib.sh` refuses one that needs a
   shared UnixLib or defines UnixLib's functions. With `--stand-ins` it
   accepts one that needs only the three above.
2. **Packaging:** `check-mixed-package.sh` follows every library the
   program needs, and says which stand-ins to copy in.
3. **Running:** `crtmixed.o` looks at every library the loader has loaded.
   If one is a real shared UnixLib, libstdc++ or libgcc_s (a stand-in was
   missing, so the one in !SharedLibs was found), the program stops before
   `main` with a message naming it.

Keep all the app's libraries in its own `lib` directory: a library missing
there would be looked for in !SharedLibs.

Tested on RISC OS on Linux (QEMU): a library linked against
`libunixlib.so.5` runs in a mixed program with the stand-in, using the
program's `qsort`, `strtol`, `getpid`, `malloc` and `snprintf`. With a
real `libunixlib.so.5` in its place, the program stops with the message.
Not tested yet: a real GCCSDK C++ library (libstdc++'s symbol versions).

**Hidden symbols:** a library built with `-fvisibility=hidden` (GLib is)
exports only what is marked for export. A variable the program sets in a
library, such as GLib's `g_riscos_spawn_hooks`, needs
`__attribute__((visibility("default")))`.

## Packaging

`examples/mixed` builds `!MixHello`; copy it to start.

- **The program:** it stays an ELF file (filetype &E1F), stripped. It isn't
  converted with `elf2aif`. !SharedLibs runs it (`Alias$@RunType_E1F`).
- **The libraries:** put them in a directory of the app's own, under their
  SONAME, such as `lib.libgreet/so/1` (`libgreet.so.1,e1f` on Linux).
- **`!Run` tells the loader where they are.** The variable is named after
  the program's leaf name, or after the app (without the `!`) when the
  program is `!RunImage`:

  ```
  Set MixHelloLibs$Path <MixHello$Dir>.lib.
  Set mixhello$LD$Env "LD_LIBRARY_PATH=/MixHelloLibs:"
  Run <MixHello$Dir>.mixhello
  ```

- **What users need:**
  - SharedUnixLibrary 1.16 or later;
  - ARMEABISupport (1.05 and 1.08 both tested);
  - a **!SharedLibs that has `ld-riscos/so/2`** (GCCSDK 8 or later; Iris
    ships one). riscos.info's SharedLibs 4.0 package has only the older
    `ld-riscos/so/1` and won't run these programs.
- **On RISC OS on Linux,** use NativeSupport 0.33 or later. Older versions
  abort after any program removes a dynamic area.

## The devkit

The riscos-mesa devkit's libraries are static (`.a`). Until riscos-mesa
publishes shared builds of them, a mixed program links the devkit's
libraries in, as before. Only libraries you build yourself with the
settings above are shared.
