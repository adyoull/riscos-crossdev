# Include from a Makefile to build host tests against the fake RISC OS:
#
#   include $(RCD_DIR)/fake/fake.mk
#   out/test_foo: test_foo.c foo.c $(FAKE_SRC)
#   	$(FAKE_CC) $(FAKE_CFLAGS) -o $@ $^
#
# 32-bit (-m32, needs gcc-13-multilib on Ubuntu 24.04) so int and pointers are the same size,
# as on RISC OS. -funsigned-char: char is unsigned on ARM, signed on x86.
# gcc-13-multilib, unlike gcc-multilib, doesn't link /usr/include/asm, so
# with -m32 <errno.h> can't find <asm/errno.h>: take it from the 64-bit
# headers (the asm headers serve both).
FAKE_DIR := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))
FAKE_CC ?= gcc
FAKE_CFLAGS ?= -m32 -g -O1 -Wall -Wextra -funsigned-char -D__riscos -D__FAKE_RISCOS \
  -I$(FAKE_DIR) $(if $(wildcard /usr/include/asm),,$(if $(wildcard /usr/include/x86_64-linux-gnu/asm),-idirafter /usr/include/x86_64-linux-gnu))
FAKE_SRC := $(FAKE_DIR)/riscos.c
