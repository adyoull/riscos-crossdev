/* checks/selftest: built with -D_FILE_OFFSET_BITS=64, this must use
   UnixLib 5.0.2's 64-bit calls (__unixlib_fstat64, lseek64), which reach
   files up to 4GB-1. A toolchain with an older UnixLib links the 32-bit
   ones instead. */
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>

int main (int argc, char **argv)
{
  struct stat st;
  (void) argc;
  if (fstat (0, &st) == 0)
    printf ("%lld %lld\n", (long long) st.st_size, (long long) lseek (0, 0, SEEK_END));
  return sizeof st.st_size == 8 && argv[0] ? 0 : 1;
}
