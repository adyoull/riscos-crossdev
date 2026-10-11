# examples/hello: a command-line program

A small C program that greets you and says how long the machine has been
up, run in a task window on RISC OS. It is the whole path in one
`Makefile`:

1. compile and link for RISC OS (`$(RO_CC) $(RISCOS_CFLAGS) ... -static`);
2. run every check on the linked program (`$(CHECK_ALL)`), and the
   unaligned-cast check on the sources;
3. strip, convert to Absolute with `elf2aif`, put it in `!Hello` with
   `!Run`, `!Boot` and `!Help`, and zip it with filetypes (`$(ROZIP)`);
4. test on Linux:
   - `src/ro.c`, which calls SWIs (`OS_ReadMonotonicTime`, `OS_ReadVarVal`,
     `OS_Write0`), against the Fake RISC OS: `tests/test_fake.c`;
   - `src/greet.c`, which is portable, as ARM code under
     `qemu-arm-aligntrap`: `tests/test_qemu.c`.

```sh
make RCD_DIR=../..          # out/Hello.zip
make RCD_DIR=../.. check    # the checks and both tests
```

On the Pi: unzip, double-click `!Hello`. `*Set Hello$Name Andrew` first to
be greeted by name. More in [docs/USING.md](../../docs/USING.md).
