/* hello: the RISC OS part. See ro.h. */
#include <stdio.h>
#include <string.h>
#include <kernel.h>
#include <swis.h>
#include "ro.h"

unsigned hello_uptime (void)
{
  int t = 0;
  if (_swix (OS_ReadMonotonicTime, _OUT (0), &t))
    return 0;
  return (unsigned) t;
}

const char *hello_name (char *buf, size_t len)
{
  int n = 0;
  /* R2 = buffer size - 1 leaves room for the terminator; R3 = 0: first
     match; R4 = 3: expand to a string. */
  if (len < 2
      || _swix (OS_ReadVarVal, _INR (0, 4) | _OUT (2),
                "Hello$Name", buf, (int) len - 1, 0, 3, &n)
      || n <= 0)
    return "world";
  buf[n] = 0;
  return buf;
}

int hello_say (const char *s)
{
  const _kernel_oserror *e = _swix (OS_Write0, _IN (0), s);
  if (!e)
    e = _swix (OS_NewLine, 0);
  if (e)
    {
      fprintf (stderr, "hello: %s\n", e->errmess);
      return -1;
    }
  return 0;
}
