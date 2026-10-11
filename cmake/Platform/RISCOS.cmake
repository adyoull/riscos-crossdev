# CMake's platform description for RISC OS (cmake/riscos.cmake selects it).
# UnixLib is a POSIX C library, so code written for Unix mostly builds:
# UNIX is set as well as RISCOS. Static libraries only.
set(RISCOS 1)
set(UNIX 1)
set(CMAKE_EXECUTABLE_SUFFIX "")
set(CMAKE_STATIC_LIBRARY_PREFIX "lib")
set(CMAKE_STATIC_LIBRARY_SUFFIX ".a")
set(CMAKE_FIND_LIBRARY_PREFIXES "lib")
set(CMAKE_FIND_LIBRARY_SUFFIXES ".a")
set_property(GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS FALSE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "RISC OS: static libraries only")
