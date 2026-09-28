/* hello: the portable part. See greet.h. */
#include <stdio.h>
#include "greet.h"

int hello_format_uptime (char *buf, size_t len, unsigned cs)
{
  unsigned s = cs / 100;
  return snprintf (buf, len, "%u:%02u:%02u", s / 3600, s / 60 % 60, s % 60);
}

uint32_t hello_read_le32 (const unsigned char *p)
{
  return (uint32_t) p[0] | (uint32_t) p[1] << 8 | (uint32_t) p[2] << 16
         | (uint32_t) p[3] << 24;
}

uint32_t hello_checksum (const unsigned char *p, size_t n)
{
  uint32_t sum = 0;
  size_t i;
  for (i = 0; i + 4 <= n; i += 4)
    sum = (sum << 5 | sum >> 27) ^ hello_read_le32 (p + i);
  return sum;
}
