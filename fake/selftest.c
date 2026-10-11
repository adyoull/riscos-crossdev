/* fake/selftest.c: the fake RISC OS itself. The masks pass registers the
   way UnixLib's _swix does (inputs, outputs in order, _OUT(_FLAGS) last),
   _swi returns what _RETURN names, errors leave outputs alone, and the SWI
   numbers come from UnixLib's swis.h. Run by make check. */
#include <stdio.h>
#include <string.h>
#include "fake.h"
#include "swis.h"

static int seen[10];
static const _kernel_oserror boom = { 99, "Boom" };

static const _kernel_oserror *echo (int swi, int r[10])
{
  int i;
  (void) swi;
  for (i = 0; i < 10; i++) { seen[i] = r[i]; r[i] = r[i] * 2 + i; }
  return NULL;
}

static const _kernel_oserror *fail (int swi, int r[10])
{
  (void) swi; r[0] = 12345;
  return &boom;
}

int main (void)
{
  int a = -1, b = -1, c = -1, f = -1, v;
  _kernel_swi_regs in, out;
  const _kernel_oserror *e;

  CHECK (_INR (0, 2) == 7 && _INR (3, 4) == 0x18, "_INR");
  CHECK (_OUTR (0, 1) == (_OUT (0) | _OUT (1)), "_OUTR");
  CHECK (_OUT (_FLAGS) == 1U << 21, "_OUT(_FLAGS) is bit 21");
  CHECK (OS_WriteC == 0 && OS_ReadMonotonicTime == 0x42 && Wimp_Poll == 0x400c7
         && Wimp_CreateWindow == 0x400c1, "SWI numbers from UnixLib's swis.h");

  fake_reset ();
  fake_swi (0x4f000, "Test_Echo", echo);
  e = _swix (0x4f000, _INR (0, 2) | _IN (5) | _OUT (0) | _OUT (2) | _OUT (5) | _OUT (_FLAGS),
             10, 20, 30, 50, &a, &b, &c, &f);
  CHECK (!e && seen[0] == 10 && seen[1] == 20 && seen[2] == 30 && seen[5] == 50, "inputs in order");
  CHECK (a == 20 && b == 62 && c == 105 && f == 0, "outputs in register order, then the flags");

  v = _swi (0x4f000, _IN (1) | _RETURN (1), 7);
  CHECK (v == 15, "_swi returns the register _RETURN names");
  v = _swi (0x4f000, _IN (0) | _RETURN (_FLAGS), 7);
  CHECK (v == 0, "_RETURN(_FLAGS) returns the flags");

  fake_swi (0x4f001, "Test_Fail", fail);
  a = -1;
  e = _swix (0x4f001, _OUT (0), &a);
  CHECK (e && e->errnum == 99 && a == -1, "an error leaves the outputs alone");

  memset (&in, 0, sizeof in); in.r[3] = 4;
  CHECK (!_kernel_swi (0x4f000, &in, &out) && out.r[3] == 11, "_kernel_swi");
  CHECK (_kernel_swi (0x4f001, &in, &out) && _kernel_last_oserror ()->errnum == 99,
         "_kernel_swi errors, and _kernel_last_oserror");

  return fake_done ("fake RISC OS selftest");
}
