# Include from a port's Makefile for the toolchain, flags and tools:
#
#   RCD_DIR := path/to/riscos-crossdev
#   include $(RCD_DIR)/riscos.mk
#
# Make's version of env.sh. Override any of these on the command line.
# (Immediate assignments: MAKEFILE_LIST changes as more files are included.)
ifndef RCD_DIR
RCD_DIR := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))
endif
ifndef RISCOS_TOOLCHAIN
RISCOS_TOOLCHAIN := $(RCD_DIR)/toolchain/env
endif
ifndef RISCOS_DEVKIT
RISCOS_DEVKIT := $(RCD_DIR)/devkit/env
endif
FPU ?= vfpv3
RISCOS_HOST := arm-riscos-gnueabihf
RO_BIN := $(RISCOS_TOOLCHAIN)/bin
RO_CC := $(RO_BIN)/$(RISCOS_HOST)-gcc
RO_CXX := $(RO_BIN)/$(RISCOS_HOST)-g++
RO_AR := $(RO_BIN)/$(RISCOS_HOST)-ar
RO_STRIP := $(RO_BIN)/$(RISCOS_HOST)-strip
ELF2AIF := $(RO_BIN)/elf2aif
QEMU_ALIGNTRAP := $(RO_BIN)/qemu-arm-aligntrap

# -fstack-clash-protection is required (ARMEABISupport's stack guard page);
# see docs/RISCOS-RULES.md for why each flag is here.
RISCOS_CFLAGS ?= -O2 -mfpu=$(FPU) -mfloat-abi=hard -fstack-clash-protection
RISCOS_LDFLAGS ?= -static

# The riscos-mesa devkit (make devkit): add these to compile and link lines,
# e.g. $(RO_CC) $(RISCOS_CFLAGS) $(DEVKIT_CFLAGS) x.c $(RISCOS_LDFLAGS)
#      $(DEVKIT_LDFLAGS) -lEGL -lOSMesa -lstdc++ -lz -lm   (devkit README)
DEVKIT_CFLAGS := -I$(RISCOS_DEVKIT)/include
DEVKIT_LDFLAGS := -L$(RISCOS_DEVKIT)/lib

ROZIP := python3 $(RCD_DIR)/package/rozip.py
CHECK_ALL := $(RCD_DIR)/checks/check-all.sh
CHECK_UNALIGNED := $(RCD_DIR)/checks/check-unaligned.sh
ALIGNTRAP := $(RCD_DIR)/qemu/aligntrap.sh

# The same code for arm-linux, to run under qemu-arm-aligntrap:
# -mno-unaligned-access makes GCC generate what it would for RISC OS;
# -no-pie keeps the program's code where qemu/aligntrap.sh expects it.
LINUXARM_CC ?= arm-linux-gnueabihf-gcc
LINUXARM_CFLAGS ?= -O2 -g -mcpu=cortex-a8 -mfpu=vfpv3 -mfloat-abi=hard \
  -mno-unaligned-access -fstack-clash-protection -no-pie

include $(RCD_DIR)/fake/fake.mk

# Check that the toolchain is there before using it.
riscos-toolchain-present:
	@test -x $(RO_CC) || { echo "No toolchain in $(RISCOS_TOOLCHAIN): run 'make prebuilt' or 'make toolchain' in $(RCD_DIR)" >&2; exit 1; }
.PHONY: riscos-toolchain-present
