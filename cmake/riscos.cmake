# CMake toolchain file for RISC OS, with the riscos-crossdev toolchain:
#
#   cmake -B build-riscos -DCMAKE_TOOLCHAIN_FILE=$RCD_DIR/cmake/riscos.cmake \
#         -DCMAKE_BUILD_TYPE=Release
#
# Settings (cmake -D..., or the environment, as env.sh):
#   RISCOS_TOOLCHAIN  the installed toolchain (default: toolchain/env here)
#   RISCOS_DEVKIT     the riscos-mesa devkit (default: devkit/env here);
#                     its include/ and lib/ are searched by find_package,
#                     find_library and find_path, after the toolchain's own
#   FPU               vfpv3 (default) or vfpv4
#
# Programs are static (RISC OS has no shared libraries for these), with the
# flags every RISC OS build needs (docs/RISCOS-RULES.md). CMake sees the
# system as RISCOS, with UNIX set too (UnixLib is a POSIX C library), so
# `if(RISCOS)` picks out RISC OS. include(RiscOSBuild) adds riscos_checks() and
# riscos_aif() (cmake/RiscOSBuild.cmake).
get_filename_component(RCD_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
foreach(v RISCOS_TOOLCHAIN RISCOS_DEVKIT FPU)
  if(NOT DEFINED ${v} AND DEFINED ENV{${v}})
    set(${v} "$ENV{${v}}")
  endif()
endforeach()
if(NOT DEFINED RISCOS_TOOLCHAIN)
  set(RISCOS_TOOLCHAIN "${RCD_DIR}/toolchain/env")
endif()
if(NOT DEFINED RISCOS_DEVKIT)
  set(RISCOS_DEVKIT "${RCD_DIR}/devkit/env")
endif()
if(NOT DEFINED FPU)
  set(FPU vfpv3)
endif()
# try_compile projects get the same settings.
set(CMAKE_TRY_COMPILE_PLATFORM_VARIABLES RISCOS_TOOLCHAIN RISCOS_DEVKIT FPU)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}")
set(CMAKE_SYSTEM_NAME RISCOS)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(_ro "${RISCOS_TOOLCHAIN}/bin/arm-riscos-gnueabihf-")
if(NOT EXISTS "${_ro}gcc")
  message(FATAL_ERROR "No toolchain in ${RISCOS_TOOLCHAIN}: run 'make prebuilt' in ${RCD_DIR}, or set RISCOS_TOOLCHAIN")
endif()
set(CMAKE_C_COMPILER "${_ro}gcc")
set(CMAKE_CXX_COMPILER "${_ro}g++")
set(CMAKE_ASM_COMPILER "${_ro}gcc")
set(CMAKE_AR "${_ro}ar" CACHE FILEPATH "")
set(CMAKE_RANLIB "${_ro}ranlib" CACHE FILEPATH "")
set(CMAKE_STRIP "${_ro}strip" CACHE FILEPATH "")
set(RISCOS_ELF2AIF "${RISCOS_TOOLCHAIN}/bin/elf2aif" CACHE FILEPATH "elf2aif")

set(CMAKE_C_FLAGS_INIT "-mfpu=${FPU} -mfloat-abi=hard -fstack-clash-protection")
set(CMAKE_CXX_FLAGS_INIT "${CMAKE_C_FLAGS_INIT}")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-static")
# Optimisation comes from the build type: Release unless one is given.
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Release unless given (cmake/riscos.cmake)")
endif()

set(CMAKE_FIND_ROOT_PATH "${RISCOS_TOOLCHAIN}/arm-riscos-gnueabihf" "${RISCOS_DEVKIT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
# The devkit has no usr/: search its include/ and lib/ directly.
list(APPEND CMAKE_SYSTEM_PREFIX_PATH "/")
# pkg_check_modules() (FindPkgConfig) reads the devkit's .pc files, and
# never the host's.
set(ENV{PKG_CONFIG_LIBDIR} "${RISCOS_DEVKIT}/lib/pkgconfig")
set(ENV{PKG_CONFIG_PATH} "")
