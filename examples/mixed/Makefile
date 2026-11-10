# examples/mixed: a "mixed" RISC OS program (test, riscos-crossdev 1.11):
# UnixLib is linked into the program as usual, and the program's own
# library, libgreet, is a shared library loaded by !SharedLibs (SOManager
# and ld-riscos/so/2). See docs/MIXED.md.
#
#   make            out/libgreet.so, out/mixhello (ELF), the checks, out/MixHello.zip
#   make check      the checks
#   make clean
RCD_DIR ?= ../..
include $(RCD_DIR)/riscos.mk
.DEFAULT_GOAL := all
OUT := out

all: $(OUT)/MixHello.zip
check: checks

# The library: position-independent, with no UnixLib of its own.
$(OUT)/greet.o: src/greet.c src/greet.h $(RO_CC) | riscos-toolchain-present
	@mkdir -p $(OUT)
	$(RO_CC) $(RISCOS_SO_CFLAGS) -Wall -Wextra -c -o $@ src/greet.c
$(OUT)/libgreet.so: $(OUT)/greet.o
	$(RO_CC) $(RISCOS_SO_LDFLAGS) -Wl,-soname,libgreet.so.1 -o $@ $< $(RISCOS_SO_LIBS)

# The program: -rdynamic instead of -static. UnixLib is still linked in.
$(OUT)/mixhello: src/main.c src/greet.h $(OUT)/libgreet.so $(RISCOS_TOOLCHAIN)/$(RISCOS_HOST)/lib/libunixlib.a
	$(RO_CC) $(RISCOS_CFLAGS) -Wall -Wextra -o $@ src/main.c $(RISCOS_MIXED_LDFLAGS) -L$(OUT) -lgreet

checks: $(OUT)/mixhello $(OUT)/libgreet.so
	$(CHECK_ALL) $(OUT)/mixhello
	$(RCD_DIR)/checks/check-shared-lib.sh $(OUT)/libgreet.so

# The app: the program stays an ELF file (&E1F, run by !SharedLibs), and
# the library goes in its lib directory as libgreet/so/1.
$(OUT)/MixHello.zip: $(OUT)/mixhello $(OUT)/libgreet.so app/!Run,feb | checks
	rm -rf $(OUT)/!MixHello && mkdir -p $(OUT)/!MixHello/lib
	$(RO_STRIP) -o $(OUT)/!MixHello/mixhello,e1f $(OUT)/mixhello
	$(RO_STRIP) --strip-unneeded -o $(OUT)/!MixHello/lib/libgreet.so.1,e1f $(OUT)/libgreet.so
	cp app/!Run,feb $(OUT)/!MixHello/
	$(RCD_DIR)/checks/check-mixed-package.sh $(OUT)/!MixHello/mixhello,e1f $(OUT)/!MixHello/lib
	$(ROZIP) $@ -C $(OUT) !MixHello
	@echo "$@: unzip it on RISC OS and run !MixHello (needs !SharedLibs with ld-riscos/so/2)"

clean:
	rm -rf $(OUT)
.PHONY: all check checks clean
