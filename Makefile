# riscos-crossdev: build and test RISC OS software on Linux.
#
#   make toolchain   build the cross toolchain and qemu-arm-aligntrap from
#                    source into toolchain/env (an hour or more)
#   make prebuilt    or: download and unpack the checksummed prebuilt one
#   make devkit      download and unpack the checksummed riscos-mesa devkit
#                    (OpenGL, EGL, SDL2, OpenAL...) into devkit/env
#   make hello       examples/hello -> examples/hello/out/Hello.zip
#   make examples    every example: hello, wimp (a desktop program), cmake
#   make check       every test that runs on Linux (see docs/TESTING.md)
#   make dist VERSION=x.y   the toolchain tarball for a release
#   make image       the container image (docker/Dockerfile), as riscos-crossdev
#
# Settings: see env.sh (RISCOS_TOOLCHAIN, FPU, JOBS).
include riscos.mk
.DEFAULT_GOAL := all

all: hello

toolchain:
	toolchain/build.sh all
	qemu/build.sh

prebuilt:
	toolchain/install-prebuilt.sh

devkit:
	devkit/install.sh

check-devkit: riscos-toolchain-present
	RISCOS_TOOLCHAIN=$(abspath $(RISCOS_TOOLCHAIN)) RISCOS_DEVKIT=$(abspath $(RISCOS_DEVKIT)) devkit/check.sh

EX_ARGS = RCD_DIR=$(CURDIR) RISCOS_TOOLCHAIN=$(abspath $(RISCOS_TOOLCHAIN)) RISCOS_DEVKIT=$(abspath $(RISCOS_DEVKIT))
hello:
	$(MAKE) -C examples/hello $(EX_ARGS)

examples: hello
	$(MAKE) -C examples/wimp $(EX_ARGS)
	@if command -v cmake >/dev/null; then $(MAKE) -C examples/cmake $(EX_ARGS); \
	else echo "SKIP examples/cmake (no cmake)"; fi

EMU_OBJ := emu/example/out/elapsed.o
$(EMU_OBJ): emu/example/elapsed.s | riscos-toolchain-present
	@mkdir -p $(dir $@)
	$(RO_BIN)/$(RISCOS_HOST)-as -o $@ $<

check: riscos-toolchain-present
	@echo "== scripts parse"
	@for s in env.sh toolchain/*.sh qemu/*.sh checks/*.sh devkit/*.sh fake/*.sh fake/ports/*.sh; do bash -n $$s || exit 1; done
	@python3 -m py_compile checks/*.py package/*.py emu/*.py emu/example/*.py && rm -rf checks/__pycache__ package/__pycache__ emu/__pycache__ emu/example/__pycache__
	@echo "== png2sprite makes sprites RISC OS can read"
	@python3 -B package/selftest.py
	@echo "== the checks catch what they look for"
	RISCOS_TOOLCHAIN=$(abspath $(RISCOS_TOOLCHAIN)) checks/selftest.sh
	@echo "== the Fake RISC OS: itself, its SWI numbers, the ports' fakes"
	@mkdir -p out && $(FAKE_CC) $(FAKE_CFLAGS) -o out/fake-selftest fake/selftest.c $(FAKE_SRC) && out/fake-selftest
	RISCOS_TOOLCHAIN=$(abspath $(RISCOS_TOOLCHAIN)) fake/gen-swinames.sh --check
	RISCOS_TOOLCHAIN=$(abspath $(RISCOS_TOOLCHAIN)) RISCOS_DEVKIT=$(abspath $(RISCOS_DEVKIT)) fake/ports/check.sh
	RISCOS_TOOLCHAIN=$(abspath $(RISCOS_TOOLCHAIN)) fake/ports/check-headers.sh
	@echo "== qemu-arm-aligntrap traps like RISC OS"
	RISCOS_TOOLCHAIN=$(abspath $(RISCOS_TOOLCHAIN)) qemu/selftest.sh
	@echo "== examples/hello: build, checks, Fake RISC OS test, QEMU test"
	$(MAKE) -C examples/hello $(EX_ARGS) all check
	@echo "== examples/wimp: a desktop program, its Wimp SWIs faked"
	$(MAKE) -C examples/wimp $(EX_ARGS) all check
	@echo "== examples/cmake: built for RISC OS with CMake, tested under QEMU and on Linux"
	@if command -v cmake >/dev/null; then $(MAKE) -C examples/cmake $(EX_ARGS) check; \
	else echo "SKIP (no cmake: apt-get install cmake)"; fi
	@echo "== Unicorn: an assembler routine with a faked SWI"
	@if python3 -c 'import unicorn' 2>/dev/null; then \
	  $(MAKE) -s $(EMU_OBJ) && RISCOS_TOOLCHAIN=$(abspath $(RISCOS_TOOLCHAIN)) python3 emu/example/test_elapsed.py $(EMU_OBJ); \
	else echo "SKIP (pip install unicorn)"; fi
	@echo "== the riscos-mesa devkit with this toolchain"
	@if [ -f $(RISCOS_DEVKIT)/VERSION ]; then $(MAKE) -s check-devkit; \
	else echo "SKIP (no devkit: make devkit)"; fi
	@echo "== all checks passed"

image:
	docker build -f docker/Dockerfile -t riscos-crossdev .

dist:
	@test -n "$(VERSION)" || { echo "usage: make dist VERSION=x.y" >&2; exit 1; }
	toolchain/package.sh $(VERSION)

clean:
	$(MAKE) -C examples/hello clean
	$(MAKE) -C examples/wimp clean
	$(MAKE) -C examples/cmake clean
	rm -rf checks/selftest/out qemu/selftest/out emu/example/out devkit/out out

.PHONY: all toolchain prebuilt devkit check-devkit hello examples check image dist clean
