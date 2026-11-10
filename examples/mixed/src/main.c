/* mixhello: a "mixed" RISC OS program. UnixLib is linked in, as in any
   crossdev program; libgreet is a shared library that SOManager loads. */
#include <stdio.h>
#include <stdlib.h>
#include "greet.h"

int greet_hook(int n) { return n; }

int main(void)
{
  for (int i = 0; i < 2; i++) {
    char *s = greet("RISC OS");
    puts(s ? s : "out of memory");
    free(s);
  }
  return 0;
}
