# Source this: . ./env.sh
# Settings shared by every script in riscos-crossdev. Each can be set in the
# environment first to override it.
#
#   RISCOS_TOOLCHAIN  the installed cross toolchain (bin/arm-riscos-gnueabihf-gcc,
#                     bin/elf2aif). Default: toolchain/env inside this repo,
#                     where `make toolchain` and `make prebuilt` put it.
#   FPU               vfpv3 (default) runs on every ARMv7 RISC OS machine with
#                     VFP: Cortex-A8/A9 boards and the Pi 2 onwards. vfpv4 adds
#                     fused multiply-add, which only Cortex-A7/A15/A53/A72 have.
RCD_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
: "${RISCOS_TOOLCHAIN:=$RCD_DIR/toolchain/env}"
: "${FPU:=vfpv3}"
: "${JOBS:=$(nproc)}"
export RCD_DIR RISCOS_TOOLCHAIN FPU JOBS
export RISCOS_HOST=arm-riscos-gnueabihf
export PATH="$RISCOS_TOOLCHAIN/bin:$PATH"

# The flags every RISC OS build should use.
#  -fstack-clash-protection is REQUIRED: ARMEABISupport maps the stack a page
#   at a time, so a frame over 4 KB must touch each page in turn, or it jumps
#   over the guard page and the program aborts. checks/check-stack-probes.py
#   finds frames that don't.
#  -mfpu=$FPU -mfloat-abi=hard: the toolchain's own libraries are VFPv3;
#   checks/check-fpu.sh finds VFPv4-only instructions.
export RISCOS_CFLAGS="-O2 -mfpu=$FPU -mfloat-abi=hard -fstack-clash-protection"
