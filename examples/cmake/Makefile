# examples/cmake: the CMake project here, built and tested three ways.
#   make         build-riscos/Tally.zip (CMake with cmake/riscos.cmake)
#   make check   that, plus ctest under qemu-arm-aligntrap and on the host
#   make clean
RCD_DIR ?= ../..
include $(RCD_DIR)/riscos.mk
.DEFAULT_GOAL := all
CMAKE_ENV := RISCOS_TOOLCHAIN=$(abspath $(RISCOS_TOOLCHAIN)) RISCOS_DEVKIT=$(abspath $(RISCOS_DEVKIT))

all: build-riscos/Tally.zip
check: all test-qemu test-host

build-riscos/Tally.zip: CMakeLists.txt src/*.c src/*.h app/!Run,feb app/!Help,fff | riscos-toolchain-present
	$(CMAKE_ENV) cmake -S . -B build-riscos -DCMAKE_TOOLCHAIN_FILE=$(RCD_DIR)/cmake/riscos.cmake -DCMAKE_BUILD_TYPE=Release
	cmake --build build-riscos
	cp app/!Run,feb app/!Help,fff build-riscos/!Tally/
	$(ROZIP) $@ -C build-riscos !Tally

test-qemu:
	$(CMAKE_ENV) cmake -S . -B build-qemu -DCMAKE_TOOLCHAIN_FILE=$(RCD_DIR)/cmake/linux-arm-aligntrap.cmake
	cmake --build build-qemu
	ctest --test-dir build-qemu --output-on-failure

test-host:
	cmake -S . -B build-host
	cmake --build build-host
	ctest --test-dir build-host --output-on-failure

clean:
	rm -rf build-riscos build-qemu build-host

.PHONY: all check test-qemu test-host clean
