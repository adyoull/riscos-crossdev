/* hello: a small RISC OS program built with riscos-crossdev.
   Greets Hello$Name (or "world"), says how long the machine has been up,
   and prints a checksum read from an odd address (safe: see greet.c). */
#include <stdio.h>
#include "greet.h"
#include "ro.h"

int main (void)
{
  static const unsigned char data[] = "xRISC OS reads words aligned!";
  char name[64], up[32], line[160];

  hello_format_uptime (up, sizeof up, hello_uptime ());
  snprintf (line, sizeof line, "Hello, %s! This machine has been up for %s.",
            hello_name (name, sizeof name), up);
  if (hello_say (line))
    return 1;
  /* data + 1 is odd: hello_read_le32 must not do a word load there. */
  printf ("checksum %08lx\n", (unsigned long) hello_checksum (data + 1, 28));
  return 0;
}
