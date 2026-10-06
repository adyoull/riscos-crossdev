# Testing on a Raspberry Pi

The last layer, and the only one that sees the Wimp paging other tasks in
and out, other programs running at the same time, real timing, and the
real modules. Everything on Linux passing means the obvious faults are
gone; it doesn't mean the program works.

## Getting the build onto the Pi

The zips `package/rozip.py` makes keep filetypes. Copy one over (network
share, USB stick, or a !Hello-sized file by any route) and open it with
SparkFS or InfoZip's `unzip`; `!Hello` should appear as an application
and `hello` as an Absolute file.

If you copy an unpacked build instead, files arrive as `hello,ff8`: most
RISC OS network filers (and !LanManFS / !Sunfish) turn the `,xxx` suffix
back into a filetype.

## What the program needs

- SharedUnixLibrary 1.16 or later and ARMEABISupport, from PackMan. Every
  UnixLib program needs both; `!Run` should `RMEnsure` them (see
  `examples/hello/app/!Run,feb`).
- Threaded programs: the PThreadTicker module. Programs built with this
  toolchain (UnixLib 5.0.3.1 and later) use version 0.03, which is in
  `toolchain/env/riscos/PThrTicker,ffa` with its ReadMe and Licence (the
  same module as PThreadTicker-0.03.zip on the riscos-unixlib v5.0.3.3
  release, and as the one in the riscos-mesa devkit 20.3.5-11 and later). Ship it in your app and `RMLoad` it from `!Run`, as its ReadMe
  shows. Without it, or with an older version loaded, UnixLib runs its own
  copy, which also works.
- Programs built with the riscos-mesa devkit: whatever its README lists for
  the libraries you use.

## A test run

1. Start from a freshly booted machine, so a crash from an earlier test
   can't be blamed on this one.
2. Run the program as a user would: double-click it from the Filer.
3. Leave other tasks running (a task window, !Edit, !Paint, a clock) and use
   them while the program runs. Crashes in *other* tasks, or when the
   program quits, are what the Wimp paging problems look like.
4. For a threaded program, run it for a long time (the Warzone 2100 test
   builds were played for an hour).
5. Quit it the normal ways (menu, close icon, Escape) and check the machine
   is still fine afterwards: open a few windows, start another program.

## Collecting information when something goes wrong

- UnixLib reports faults as `Fatal signal received: ...` with a backtrace
  of addresses. To turn them into function names, rebuild the matching
  version's unstripped ELF from the same sources and run
  `arm-riscos-gnueabihf-addr2line -f -i -e hello 0x...`. The first `lr` of
  an "EMT trap" trace is often stale (the fault was in a leaf function):
  disassemble around the `pc` too.
- "Abort on data transfer" / "EMT trap": an unaligned access
  (RISCOS-RULES.md, rule 2). Find it with the QEMU tests.
- "Undefined instruction" on a Cortex-A8/A9 machine: a VFPv4 instruction
  (rule 3). `checks/check-fpu.sh` finds it.
- The machine hangs, or other programs crash: rule 5 (code running while
  another task is paged in) or rule 4 (a stale UnixLib).
- `*Set UnixLib$TickerStats <Wimp$ScrapDir>.TickerStats` makes UnixLib (5.0.1 and later)
  write a line of thread switcher counters when a program quits.

## Testing examples/hello

Double-click `!Hello`. A task window opens with:

```
Hello, world! This machine has been up for H:MM:SS.
checksum 1653a4a4
```

(The QEMU test checks the same checksum on Linux.) Then `*Set Hello$Name <your name>`
and run it again: it should greet you by name. It exercises SWI calls,
UnixLib start-up and `printf`, and a read from an odd address.
