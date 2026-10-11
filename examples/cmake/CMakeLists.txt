# examples/cmake: a CMake project built three ways from the same file
# (RCD_DIR: riscos-crossdev, ../.. here).
#
#   For RISC OS (static ELF, checked, then AIF, with the devkit's zlib):
#     cmake -B build-riscos -DCMAKE_TOOLCHAIN_FILE=$RCD_DIR/cmake/riscos.cmake -DCMAKE_BUILD_TYPE=Release
#     cmake --build build-riscos          -> build-riscos/!Tally/tally,ff8
#   As ARM Linux code, tests run under qemu-arm-aligntrap:
#     cmake -B build-qemu -DCMAKE_TOOLCHAIN_FILE=$RCD_DIR/cmake/linux-arm-aligntrap.cmake
#     cmake --build build-qemu && ctest --test-dir build-qemu
#   On the host, to debug:
#     cmake -B build-host && cmake --build build-host && ctest --test-dir build-host
cmake_minimum_required(VERSION 3.13)
project(tally C)

add_library(tally STATIC src/tally.c)
target_include_directories(tally PUBLIC src)
target_compile_options(tally PRIVATE -Wall -Wextra)

add_executable(tally-cli src/main.c)
set_target_properties(tally-cli PROPERTIES OUTPUT_NAME tally)
target_link_libraries(tally-cli PRIVATE tally)

# Optional libraries come from the riscos-mesa devkit on RISC OS (find_package
# searches it: cmake/riscos.cmake), and from the system elsewhere.
find_package(ZLIB)
if(ZLIB_FOUND)
  target_compile_definitions(tally-cli PRIVATE HAVE_ZLIB)
  target_link_libraries(tally-cli PRIVATE ZLIB::ZLIB)
endif()

if(RISCOS)
  include(RiscOS)
  riscos_checks(tally-cli)
  riscos_aif(tally-cli "${CMAKE_BINARY_DIR}/!Tally/tally,ff8")
else()
  enable_testing()
  add_executable(test_tally tests/test_tally.c)
  target_link_libraries(test_tally PRIVATE tally)
  add_test(NAME tally COMMAND test_tally)
endif()
