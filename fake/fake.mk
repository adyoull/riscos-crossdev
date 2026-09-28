# Include from a Makefile to build host tests against the fake RISC OS:
#
#   include $(RCD_DIR)/fake/fake.mk
#   out/test_foo: test_foo.c foo.c $(FAKE_SRC)
#   	$(FAKE_CC) $(FAKE_CFLAGS) -o $@ $^
#
# 32-bit (-m32, needs gcc-multilib) so int and pointers are the same size,
# as on RISC OS. -funsigned-char: char is unsigned on ARM, signed on x86.
FAKE_DIR := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))
FAKE_CC ?= gcc
FAKE_CFLAGS ?= -m32 -g -O1 -Wall -Wextra -funsigned-char -D__riscos -D__FAKE_RISCOS \
  -I$(FAKE_DIR)
FAKE_SRC := $(FAKE_DIR)/riscos.c
