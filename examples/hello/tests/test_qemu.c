/* hello's portable part (src/greet.c), built for arm-linux and run under
   qemu-arm-aligntrap: the same ARM code, trapping unaligned accesses as
   RISC OS does, on a Cortex-A8 (VFPv3). A fault ends the run with SIGBUS
   (exit status 135) instead of a FAIL line. */
#include <stdio.h>
#include <string.h>
#include "../src/greet.h"

static int checks, fails;
#define CHECK(cond, what) do { checks++; if (!(cond)) { fails++; \
  fprintf (stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, what); } } while (0)

int main (void)
{
  /* 8-byte aligned, so buf + k has a known alignment. */
  static unsigned char buf[40] __attribute__ ((aligned (8)));
  char s[32];
  uint32_t ref;
  int k;

  hello_format_uptime (s, sizeof s, 0);
  CHECK (strcmp (s, "0:00:00") == 0, "zero");
  hello_format_uptime (s, sizeof s, 372399);
  CHECK (strcmp (s, "1:02:03") == 0, "1:02:03");
  hello_format_uptime (s, sizeof s, 100u * 3600 * 1000);
  CHECK (strcmp (s, "1000:00:00") == 0, "1000 hours");

  buf[1] = 0x78; buf[2] = 0x56; buf[3] = 0x34; buf[4] = 0x12;
  CHECK (hello_read_le32 (buf + 1) == 0x12345678, "le32 at an odd address");

  /* The line hello prints (main.c); !Help quotes it. */
  memcpy (buf + 1, "RISC OS reads words aligned!", 28);
  CHECK (hello_checksum (buf + 1, 28) == 0x1653a4a4, "the checksum !Help gives");

  for (k = 0; k < 32; k++)
    buf[k] = (unsigned char) (k * 37 + 1);
  ref = hello_checksum (buf, 32);
  CHECK (ref != 0, "checksum");
  for (k = 1; k < 4; k++)
    {
      memmove (buf + k, buf + k - 1, 32);   /* the same bytes, one further on */
      CHECK (hello_checksum (buf + k, 32) == ref, "same checksum at any alignment");
    }

  printf ("hello (qemu-arm-aligntrap): %d checks, %d failed\n", checks, fails);
  return fails != 0;
}
