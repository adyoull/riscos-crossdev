# Testing on Linux

`make check` runs everything below that runs on Linux. Each layer catches
something the one before can't; none of them replaces a run on RISC OS
(PI-TESTING.md).

```
make check
== scripts parse
== the checks catch what they look for       checks/selftest.sh
== qemu-arm-aligntrap traps like RISC OS     qemu/selftest.sh
== examples/hello: build, checks, Fake RISC OS test, QEMU test
== Unicorn: an assembler routine with a faked SWI
== all checks passed
```

The two self-tests break things on purpose (an unprobed 16 KB frame, a
VFPv4 instruction, an unaligned load) and check that they're caught. If a
self-test fails, don't trust the layer it tests.

## The checks (layer 2)

Run on every build. `examples/hello/Makefile` runs them before it will zip.

| Command | Input | Fails when |
|---|---|---|
| `checks/check-all.sh PROGRAM.elf [LIB.a...]` | the linked, unstripped ELF | any of the next three fails |
| `checks/check-stack-probes.py PROGRAM.elf` | | a frame of 4 KB or more doesn't probe |
| `checks/check-fpu.sh FILE...` | programs, `.a`, `.o` | a VFPv4-only instruction is used |
| `checks/check-unixlib.sh PROGRAM.elf` | | UnixLib's ticker block sizes disagree |
| `checks/check-unaligned.sh [-s SAFE] [CFLAGS] FILE.c...` | sources | a cast raises the required alignment |
| `checks/neon-align.py --check FILE.S...` | NEON assembly | a NEON access needs more alignment than it's sure to have |

`check-unaligned.sh` is noisy on big code bases. Check each warning by
hand; put the ones that are safe (for example, a cast of a `malloc`ed
buffer plus a multiple of 4) in a file of regular expressions and pass it
with `-s`. The ports keep that file in the repo.

Why each check exists: RISCOS-RULES.md.

## The Fake RISC OS (layer 3)

Your RISC OS-specific C (the code that calls SWIs) compiled for Linux, with
`fake/` providing `kernel.h`, `swis.h` and the SWIs themselves. Tests run in
a fraction of a second, under gdb or valgrind if you like.

```make
include $(RCD_DIR)/riscos.mk         # includes fake/fake.mk
out/test_fake: tests/test_fake.c src/ro.c $(FAKE_SRC)
	$(FAKE_CC) $(FAKE_CFLAGS) -o $@ $^
```

In the test:

```c
#include "fake.h"
#include "swis.h"

static const _kernel_oserror *my_swi (int swi, int r[10])
{
  r[0] = 42;                  /* outputs: change r in place */
  return NULL;                /* or an error block */
}

fake_reset ();                               /* at the start of each test */
fake_swi (0x4E380, "MyModule_Thing", my_swi);  /* your module's SWI */
fake_set_time (100);                         /* OS_ReadMonotonicTime */
fake_setvar ("MyApp$Option", "1");           /* OS_ReadVarVal */
/* ... call your code ... */
CHECK (strcmp (fake_output (), "Hello\r\n") == 0, "what OS_Write0 wrote");
CHECK (fake_calls (0x4E380) == 1, "called once");
return fake_done ("my test");
```

Built in: `OS_WriteC`, `OS_Write0`, `OS_NewLine`, `OS_ReadMonotonicTime`,
`OS_ReadVarVal` (strings), `OS_SWINumberFromString` (names given to
`fake_swi`) and `OS_GenerateError`. Any other SWI stops the test with its
number, so you know what to fake next. Calls without the X bit (`_swi`)
that return an error stop the test too, as RISC OS would raise it.

Things to know:

- It's built 32-bit (`-m32`): RISC OS code stores pointers in `int`
  registers, which only works when they're the same size.
- `-funsigned-char`: `char` is unsigned on ARM and signed on x86.
- `swis.h` has only a few SWI numbers. Add the ones you use.
- A fake is only as right as your reading of the PRMs. When the Pi
  disagrees with a fake, fix the fake first, then the code.

`examples/hello/tests/test_fake.c` is a complete example.
riscos-unixlib's `tests/host` shows fakes of whole modules
(SharedSoundBuffer, StreamManager, DigitalRenderer, MIDISynth), and
riscos-mesa's `tests/host-harness` runs its OpenGL, EGL, SDL and OpenAL code
against its own fakes.

## QEMU user mode (layer 4)

Your portable code (anything without SWI calls) built for ARM Linux with
the same compiler settings that matter, and run by `qemu-arm-aligntrap`:

- alignment checking on, for your code only (`qemu/aligntrap.sh` exempts
  glibc and ld.so). An unaligned access stops the program with SIGBUS,
  exit status 135;
- a Cortex-A8 CPU: a VFPv4 instruction stops it with SIGILL, exit status
  132 (`QEMU_CPU=cortex-a7` to allow VFPv4).

```make
out/test_qemu: tests/test_qemu.c src/greet.c
	$(LINUXARM_CC) $(LINUXARM_CFLAGS) -o $@ $^
test-qemu: out/test_qemu
	QEMU=$(QEMU_ALIGNTRAP) $(ALIGNTRAP) out/test_qemu
```

`LINUXARM_CFLAGS` has `-mno-unaligned-access` (so GCC generates what it
does for RISC OS) and `-no-pie` (`aligntrap.sh` needs the program's code at
a fixed address).

To see where a fault is: `QEMU_ARGS="-g 1234" qemu/aligntrap.sh out/test_qemu`
in one terminal, then `gdb-multiarch out/test_qemu -ex "target remote :1234" -ex c`
in another.

This is ARM code, but from `arm-linux-gnueabihf-gcc`, not the RISC OS
compiler, and with glibc instead of UnixLib. It finds the faults in your
code's logic and data layout, not bugs in the RISC OS toolchain or UnixLib.
For big programs, the ports build their whole library stack this way
(riscos-ffmpeg's `tests/qemu`: FFmpeg's checkasm suites and decode,
encode and conversion jobs, NEON compared with C).

## Unicorn: module and assembler code (layer 4)

`emu/rcd_emu.py` loads the `.text` of an object file into the Unicorn ARM
emulator and calls routines in it with the registers you give, faking
the SWIs in Python. Use it for module entry points, interrupt handlers,
Wimp filters and hand-written assembler: code QEMU user mode can't run.

```python
from rcd_emu import Machine, Checks, load_object, VFLAG
code, syms = load_object("out/routine.o")
m = Machine(); m.load(0x8000, code)
m.on_swi(0x42, lambda m, r: r.__setitem__(0, 5000))   # OS_ReadMonotonicTime
regs, cpsr = m.call(0x8000 + syms["elapsed"], r0=1200)
```

`call` fails if the routine doesn't return or leaves the stack unbalanced;
`m.called(swi)` lists the registers of each call to a SWI;
`m.error(num, "text")` makes an error block for a fake SWI to return (the
V flag is set for you). `emu/example/test_elapsed.py` is a complete example.
riscos-unixlib's `tests/emu/ticker_test.py` tests a whole module this way
(header, workspace, and the ticker handler with another task paged in).

Needs `pip install unicorn`; `make check` says SKIP without it.
