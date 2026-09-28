/* qemu/selftest: a word load from an odd address. Must be stopped with
   SIGBUS under qemu/aligntrap.sh (as RISC OS stops it), unless the
   argument is "aligned". */
#include <stdint.h>
#include <string.h>
#include <stdio.h>

static unsigned char buf[16] __attribute__ ((aligned (4))) = { 1, 2, 3, 4, 5, 6, 7, 8 };

int main (int argc, char **argv)
{
  int off = argc > 1 && strcmp (argv[1], "aligned") == 0 ? 0 : 1;
  volatile uint32_t *p = (volatile uint32_t *) (buf + off);
  printf ("word at +%d: %08x\n", off, (unsigned) *p);
  return 0;
}
