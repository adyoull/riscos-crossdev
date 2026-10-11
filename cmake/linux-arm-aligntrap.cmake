# CMake toolchain file for testing portable code as ARM Linux code under
# qemu-arm-aligntrap (RISC OS's alignment rules, a Cortex-A8):
#
#   cmake -B build-qemu -DCMAKE_TOOLCHAIN_FILE=$RCD_DIR/cmake/linux-arm-aligntrap.cmake
#   cmake --build build-qemu && ctest --test-dir build-qemu
#
# ctest runs each test through qemu/aligntrap.sh: an unaligned access stops
# it with SIGBUS, a VFPv4 instruction with SIGILL. The flags match
# LINUXARM_CFLAGS in riscos.mk. Needs gcc-arm-linux-gnueabihf.
get_filename_component(RCD_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
if(NOT DEFINED RISCOS_TOOLCHAIN AND DEFINED ENV{RISCOS_TOOLCHAIN})
  set(RISCOS_TOOLCHAIN "$ENV{RISCOS_TOOLCHAIN}")
endif()
if(NOT DEFINED RISCOS_TOOLCHAIN)
  set(RISCOS_TOOLCHAIN "${RCD_DIR}/toolchain/env")
endif()
set(CMAKE_TRY_COMPILE_PLATFORM_VARIABLES RISCOS_TOOLCHAIN)
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_C_COMPILER arm-linux-gnueabihf-gcc)
set(CMAKE_CXX_COMPILER arm-linux-gnueabihf-g++)
set(CMAKE_C_FLAGS_INIT "-mcpu=cortex-a8 -mfpu=vfpv3 -mfloat-abi=hard -mno-unaligned-access -fstack-clash-protection")
set(CMAKE_CXX_FLAGS_INIT "${CMAKE_C_FLAGS_INIT}")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-no-pie")
set(CMAKE_POSITION_INDEPENDENT_CODE OFF)
set(CMAKE_CROSSCOMPILING_EMULATOR
    env "QEMU=${RISCOS_TOOLCHAIN}/bin/qemu-arm-aligntrap" "${RCD_DIR}/qemu/aligntrap.sh")
set(CMAKE_FIND_ROOT_PATH /usr/arm-linux-gnueabihf)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
