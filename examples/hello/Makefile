# examples/hello: a small RISC OS program, from source to a zip for the Pi,
# with every check and both kinds of Linux test. Copy it to start a port.
#
#   make            out/hello (ELF), the checks, out/!Hello, out/Hello.zip
#   make check      the checks, the fake RISC OS test and the QEMU test
#   make clean
RCD_DIR ?= ../..
include $(RCD_DIR)/riscos.mk
.DEFAULT_GOAL := all

VERSION := 1.0
SRC := src/main.c src/greet.c src/ro.c
OUT := out

all: $(OUT)/Hello.zip
check: checks test-fake test-qemu

# --- RISC OS build ---------------------------------------------------------
$(OUT)/hello: $(SRC) src/greet.h src/ro.h | riscos-toolchain-present
	@mkdir -p $(OUT)
	$(RO_CC) $(RISCOS_CFLAGS) -Wall -Wextra $(RISCOS_LDFLAGS) -o $@ $(SRC)

# Every check on the linked program (stack probes, FPU level, UnixLib), and
# the unaligned-cast check on the sources.
checks: $(OUT)/hello
	$(CHECK_ALL) $(OUT)/hello
	$(CHECK_UNALIGNED) -Isrc $(SRC)

# The app: the program stripped and converted to Absolute (AIF, &FF8), so
# it doesn't need !SharedLibs' ELF loader; then zipped with filetypes.
$(OUT)/Hello.zip: $(OUT)/hello app/!Run,feb app/!Help,fff app/!Boot,feb | checks
	rm -rf $(OUT)/!Hello && mkdir -p $(OUT)/!Hello
	$(RO_STRIP) -o $(OUT)/hello.stripped $(OUT)/hello
	$(ELF2AIF) -e $(OUT)/hello.stripped $(OUT)/!Hello/hello,ff8 >/dev/null
	cp app/!Run,feb app/!Help,fff app/!Boot,feb $(OUT)/!Hello/
	$(ROZIP) $@ -C $(OUT) !Hello
	@echo "$@: unzip it on RISC OS (SparkFS or InfoZip) and run !Hello"

# --- Linux tests -------------------------------------------------------------
# The RISC OS part (SWI calls) against the fake RISC OS.
test-fake: $(OUT)/test_fake
	$(OUT)/test_fake
$(OUT)/test_fake: tests/test_fake.c src/ro.c src/ro.h $(FAKE_SRC)
	@mkdir -p $(OUT)
	$(FAKE_CC) $(FAKE_CFLAGS) -o $@ tests/test_fake.c src/ro.c $(FAKE_SRC)

# The portable part as ARM code under qemu-arm-aligntrap (RISC OS alignment
# rules, Cortex-A8).
test-qemu: $(OUT)/test_qemu
	QEMU=$(QEMU_ALIGNTRAP) $(ALIGNTRAP) $(OUT)/test_qemu
$(OUT)/test_qemu: tests/test_qemu.c src/greet.c src/greet.h
	@mkdir -p $(OUT)
	$(LINUXARM_CC) $(LINUXARM_CFLAGS) -Wall -o $@ tests/test_qemu.c src/greet.c

clean:
	rm -rf $(OUT)

.PHONY: all check checks test-fake test-qemu clean
