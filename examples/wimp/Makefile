# examples/wimp: Clicks, a small desktop (Wimp) program: an icon bar icon, a
# window, a menu. Built, checked, tested against the Fake RISC OS with every
# Wimp SWI it uses faked, and zipped with its !Sprites. Copy it to start a
# desktop program; examples/hello shows a command-line one and QEMU tests.
#
#   make            out/clicks (ELF), the checks, out/!Clicks, out/Clicks.zip
#   make check      the checks and the Fake RISC OS test
#   make clean
RCD_DIR ?= ../..
include $(RCD_DIR)/riscos.mk
.DEFAULT_GOAL := all

SRC := src/main.c src/app.c
OUT := out

all: $(OUT)/Clicks.zip
check: checks test-fake

# --- RISC OS build ---------------------------------------------------------
$(OUT)/clicks: $(SRC) src/app.h $(RO_CC) $(RISCOS_TOOLCHAIN)/$(RISCOS_HOST)/lib/libunixlib.a | riscos-toolchain-present
	@mkdir -p $(OUT)
	$(RO_CC) $(RISCOS_CFLAGS) -Wall -Wextra $(RISCOS_LDFLAGS) -o $@ $(SRC)

checks: $(OUT)/clicks
	$(CHECK_ALL) $(OUT)/clicks
	$(CHECK_UNALIGNED) -Isrc $(SRC)

# The icons: PNGs made into a sprite file (&FF9) by package/png2sprite.py.
$(OUT)/!Sprites,ff9: app/clicks.png app/sm-clicks.png
	@mkdir -p $(OUT)
	$(PNG2SPRITE) $@ '!clicks=app/clicks.png' 'sm!clicks=app/sm-clicks.png'

APPFILES := app/!Run,feb app/!Boot,feb app/!Help,fff
$(OUT)/Clicks.zip: $(OUT)/clicks $(OUT)/!Sprites,ff9 $(APPFILES) | checks
	rm -rf $(OUT)/!Clicks && mkdir -p $(OUT)/!Clicks
	$(RO_STRIP) -o $(OUT)/clicks.stripped $(OUT)/clicks
	$(ELF2AIF) -e $(OUT)/clicks.stripped $(OUT)/!Clicks/!RunImage,ff8 >/dev/null
	cp $(APPFILES) $(OUT)/!Sprites,ff9 $(OUT)/!Clicks/
	$(ROZIP) $@ -C $(OUT) !Clicks
	@echo "$@: unzip it on RISC OS (SparkFS or InfoZip) and run !Clicks"

# --- Linux test --------------------------------------------------------------
test-fake: $(OUT)/test_fake
	$(OUT)/test_fake
$(OUT)/test_fake: tests/test_fake.c src/app.c src/app.h $(FAKE_SRC)
	@mkdir -p $(OUT)
	$(FAKE_CC) $(FAKE_CFLAGS) -o $@ tests/test_fake.c src/app.c $(FAKE_SRC)

clean:
	rm -rf $(OUT)

.PHONY: all check checks test-fake clean
