/* A stand-in for a shared UnixLib, libstdc++ or libgcc_s, for "mixed"
   programs (riscos-crossdev: UnixLib, libstdc++ and libgcc linked into
   the program). It has the SONAME a library built for fully shared
   programs asks for, and no code: that library's calls go to the
   program's own UnixLib, which the program exports (-rdynamic). It lives
   only in the app's own lib directory, so other programs still get the
   real shared UnixLib from !SharedLibs. crtmixed.o knows it by this
   symbol. Built by install.sh. MIT licence. */
const int __riscos_mixed_stub = 1;
