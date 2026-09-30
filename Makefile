# riscos-crossdev: build and test RISC OS software on Linux.
#
#   make toolchain   build the cross toolchain and qemu-arm-aligntrap from
#                    source into toolchain/env (an hour or more)
#   make prebuilt    or: download and unpack the checksummed prebuilt one
#   make devkit      download and unpack the checksummed riscos-mesa devkit
#                    (OpenGL, EGL, SDL2, OpenAL...) into devkit/env
#   make hello       examples/hello -> examples/hello/out/Hello.zip
#   make check       every test that runs on Linux (see docs/TESTING.md)
#   make dist VERSION=x.y   the toolchain tarball for a release
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

hello:
	$(MAKE) -C examples/hello RCD_DIR=$(CURDIR) RISCOS_TOOLCHAIN=$(abspath $(RISCOS_TOOLCHAIN))

EMU_OBJ := emu/example/out/elapsed.o
$(EMU_OBJ): emu/example/elapsed.s | riscos-toolchain-present
	@mkdir -p $(dir $@)
	$(RO_BIN)/$(RISCOS_HOST)-as -o $@ $<

check: riscos-toolchain-present
	@echo "== scripts parse"
	@for s in env.sh toolchain/*.sh qemu/*.sh checks/*.sh devkit/*.sh; do bash -n $$s || exit 1; done
	@python3 -m py_compile checks/*.py package/*.py emu/*.py emu/example/*.py && rm -rf checks/__pycache__ package/__pycache__ emu/__pycache__ emu/example/__pycache__
	@echo "== the checks catch what they look for"
	RISCOS_TOOLCHAIN=$(abspath $(RISCOS_TOOLCHAIN)) checks/selftest.sh
	@echo "== qemu-arm-aligntrap traps like RISC OS"
	RISCOS_TOOLCHAIN=$(abspath $(RISCOS_TOOLCHAIN)) qemu/selftest.sh
	@echo "== examples/hello: build, checks, Fake RISC OS test, QEMU test"
	$(MAKE) -C examples/hello RCD_DIR=$(CURDIR) RISCOS_TOOLCHAIN=$(abspath $(RISCOS_TOOLCHAIN)) all check
	@echo "== Unicorn: an assembler routine with a faked SWI"
	@if python3 -c 'import unicorn' 2>/dev/null; then \
	  $(MAKE) -s $(EMU_OBJ) && RISCOS_TOOLCHAIN=$(abspath $(RISCOS_TOOLCHAIN)) python3 emu/example/test_elapsed.py $(EMU_OBJ); \
	else echo "SKIP (pip install unicorn)"; fi
	@echo "== the riscos-mesa devkit with this toolchain"
	@if [ -f $(RISCOS_DEVKIT)/VERSION ]; then $(MAKE) -s check-devkit; \
	else echo "SKIP (no devkit: make devkit)"; fi
	@echo "== all checks passed"

dist:
	@test -n "$(VERSION)" || { echo "usage: make dist VERSION=x.y" >&2; exit 1; }
	toolchain/package.sh $(VERSION)

clean:
	$(MAKE) -C examples/hello clean
	rm -rf checks/selftest/out qemu/selftest/out emu/example/out devkit/out out

.PHONY: all toolchain prebuilt devkit check-devkit hello check dist clean
