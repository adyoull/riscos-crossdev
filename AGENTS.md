# AGENTS.md: notes for AI coding assistants

riscos-crossdev builds and tests RISC OS programs on Linux. It doesn't
emulate RISC OS. A C/C++ program is cross-compiled with GCCSDK GCC 10
(`arm-riscos-gnueabihf`, UnixLib, static only), checked, and tested in
layers on Linux. A human tests the result on a Raspberry Pi. People read
`README.md` and `docs/`; this page is the short version for an assistant
working in this repo, or porting a program with it.

## Setting up

Needs x86-64 Linux (the prebuilt toolchain needs glibc 2.39, as on Ubuntu
24.04), and network access to github.com for the downloads.

```sh
# Packages: the list in docs/SETUP.md. Install gcc-13-multilib, NOT
# gcc-multilib: on Ubuntu 24.04 gcc-multilib conflicts with
# gcc-arm-linux-gnueabihf (apt exit 100).
git clone -b <latest tag> https://github.com/adyoull/riscos-crossdev   # a tag, never main
cd riscos-crossdev
make prebuilt      # the checksummed toolchain -> toolchain/env
make devkit        # optional: OpenGL/EGL/SDL2/OpenAL/zlib -> devkit/env
make check         # must end with "== all checks passed"
```

- On an ARM64 machine there is no prebuilt toolchain: run `make toolchain`
  instead (an hour or more).
- With Docker, skip all of this: `ghcr.io/adyoull/riscos-crossdev:<version>`
  has a release installed (`docs/CI.md`). Run builds in it with
  `docker run --rm -v "$PWD":/src <image> make check all`.
- To use a toolchain installed somewhere else, set `RISCOS_TOOLCHAIN` and
  `RISCOS_DEVKIT`. `env.sh`, `riscos.mk`, `cmake/riscos.cmake` and every
  script read them.

## Porting a program with it

Read `docs/USING.md` (the guide) and `docs/RISCOS-RULES.md` (what aborts
on RISC OS) first. Start from the closest example in `examples/`: `hello`
(command line), `wimp` (desktop) or `cmake`.

- **Build:**
  - Make: `include $(RCD_DIR)/riscos.mk`, then
    `$(RO_CC) $(RISCOS_CFLAGS) ... $(RISCOS_LDFLAGS)`.
  - CMake: `-DCMAKE_TOOLCHAIN_FILE=$RCD_DIR/cmake/riscos.cmake`.
  - configure: `--host=arm-riscos-gnueabihf`, with the flags in USING.md
    section 6.
- **Never drop a flag from `RISCOS_CFLAGS`.** You can add flags after it.
  - `-fstack-clash-protection` stops large stack frames aborting.
  - `-mfpu=vfpv3 -mfloat-abi=hard` keeps the program running on every
    ARMv7 machine.
  - Libraries the program links must be built with the same flags.
- **Run `checks/check-all.sh PROGRAM` on the unstripped ELF after every
  link.** A failure there means the program will abort or hang on RISC OS,
  even though it built: fix the cause, never silence the check. Also run
  `checks/check-unaligned.sh` on the sources; look at each warning.
- **Package:** strip, then `elf2aif -e` to an Absolute file (`,ff8`); put it
  in an `!App` with `!Run`, `!Boot` and `!Sprites`; then
  `package/rozip.py`. Files carry their RISC OS type as a `,xxx` suffix in
  their names: keep it.
- **Test on Linux, in layers** (`docs/TESTING.md`):
  - code that calls SWIs: against the Fake RISC OS (`fake/`, `fake.h`'s
    `fake_swi()`), built with `$(FAKE_CC) $(FAKE_CFLAGS)` (32-bit, `-m32`);
  - portable code: as ARM Linux code under `qemu/aligntrap.sh`.
    Exit status **135** = an unaligned access (it would abort on RISC OS);
    **132** = a VFPv4 instruction. Both are real bugs to fix;
  - module and assembler routines: in Unicorn (`emu/rcd_emu.py`);
  - a test that aborts with "fake RISC OS: unexpected SWI &xxx" has called
    a SWI nobody faked: fake it in the test.
- **Facts that often surprise:**
  - RISC OS has no `fork` and no `dlopen`, and multitasks cooperatively.
  - UnixLib maps Unix paths to RISC OS ones: `name.ext` is stored as
    `name/ext`.
- **Check SWIs, block layouts and Wimp messages against the PRMs.** Don't
  write them from memory.
- **CI:** `ci/riscos-build.yml` and `ci/riscos-crossdev-update.yml` build
  a port on GitHub in the image, pinned by a `.riscos-crossdev` file. The
  update workflow only opens pull requests; never make it merge or
  release.
- **Claim only what you ran.** Say what passed on Linux, and say plainly
  that it hasn't run on RISC OS until a person has tested it there.

## Working on riscos-crossdev itself

- `make check` must pass before a commit. It runs every self-test (each
  check is shown catching its fault), the Fake RISC OS and the ports' fakes,
  QEMU, all three examples, Unicorn, and the devkit's examples.
- **Never edit anything in `fake/ports/`.** These are copies of the ports'
  own fakes, checked by sha256 against `fake/fake_origin.md`.
  - A fix goes to the port it came from.
  - `fake/ports/update.sh` takes the ports' latest fakes. A weekly GitHub
    workflow runs it and opens a pull request.
- **Generated files: regenerate, don't edit.**
  - `fake/swinames.h` and `fake/fake_origin.md`: `fake/gen-swinames.sh`,
    `fake/ports/sync.sh`.
  - A changed toolchain needs `make dist`, and the tarball's sha256 goes in
    `toolchain/PREBUILT`.
- **A release:**
  - Every change is a new version: a `CHANGELOG.md` entry, the version in
    `README.md`, `docs/SETUP.md` and `docs/USING.md`, and an annotated tag.
  - A release that doesn't change the toolchain keeps the previous
    release's tarball in `toolchain/PREBUILT`.
  - Check from a clean clone of the tag: `make prebuilt devkit check`.
- **Files written here are MIT.** Copied files keep their licence: record
  each in `LICENCES.md`.
- **Keep working notes out of the repo:** `.gitignore` excludes handoffs,
  `*START-HERE*.md` and `CLAUDE.md`.
- **Docs:** short sentences, plain words, British spelling. Every command in
  a doc should have been run.
