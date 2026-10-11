/* Fake RISC OS for host (Linux) builds: _swix, _swi and _kernel_swi,
   dispatched to handlers the tests install (fake.h), plus a few built-in
   SWIs. Build 32-bit (-m32; fake/fake.mk) so pointers fit in registers.
   Based on the fake in riscos-unixlib's tests/host/fake. */
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "swis.h"
#include "fake.h"

#if defined(__SIZEOF_POINTER__) && __SIZEOF_POINTER__ != 4
#error "Build the fake RISC OS 32-bit (-m32): code puts pointers in int registers"
#endif

#define MAXSWI 64
#define MAXVAR 32
static struct { int swi; const char *name; fake_swi_fn *fn; int calls; } swis[MAXSWI];
static int nswis;
static struct { char *name, *value; } vars[MAXVAR];
static unsigned now_cs;
static char out[1 << 16];
static size_t outlen;
static _kernel_oserror last_error;
int fake_checks, fake_fails;

static const _kernel_oserror err_noswi = { 0x1e6, "SWI name not known" };
static const _kernel_oserror err_novar = { 0x124, "System variable not found" };
static const _kernel_oserror err_overflow = { 0x1e4, "Buffer overflow" };

static void put (const char *s, size_t n)
{
  if (outlen + n >= sizeof out)
    n = sizeof out - 1 - outlen;
  memcpy (out + outlen, s, n);
  outlen += n;
  out[outlen] = 0;
}

static const _kernel_oserror *builtin (int swi, int r[10])
{
  switch (swi)
    {
    case OS_WriteC: { char c = (char) r[0]; put (&c, 1); return NULL; }
    case OS_Write0:
      {
        const char *s = (const char *) r[0];
        put (s, strlen (s));
        r[0] = (int) (s + strlen (s) + 1);
        return NULL;
      }
    case OS_NewLine: put ("\r\n", 2); return NULL;
    case OS_ReadMonotonicTime: r[0] = (int) now_cs; return NULL;
    case OS_GenerateError: return (const _kernel_oserror *) r[0];
    case OS_ReadVarVal:
      {
        const char *name = (const char *) r[0];
        int i;
        for (i = 0; i < MAXVAR; i++)
          if (vars[i].name && strcmp (vars[i].name, name) == 0)
            {
              int len = (int) strlen (vars[i].value);
              if (r[2] < 0)          /* asking for the length */
                { r[2] = ~len; return &err_novar; }
              if (len > r[2])        /* RISC OS: an error, not a partial read */
                return &err_overflow;
              memcpy ((char *) r[1], vars[i].value, len);
              r[2] = len; r[4] = 0;  /* string */
              return NULL;
            }
        r[2] = 0;
        return &err_novar;
      }
    case OS_SWINumberFromString:
      {
        const char *name = (const char *) r[1];
        size_t n = strcspn (name, " \t\r\n");
        int i;
        for (i = 0; i < nswis; i++)
          if (swis[i].name && strlen (swis[i].name) == n
              && strncmp (swis[i].name, name, n) == 0)
            { r[0] = swis[i].swi; return NULL; }
        return &err_noswi;
      }
    }
  fprintf (stderr, "fake RISC OS: unexpected SWI &%x\n", swi);
  abort ();
}

static int find (int swi)
{
  int i;
  for (i = 0; i < nswis; i++)
    if (swis[i].swi == swi)
      return i;
  return -1;
}

static const _kernel_oserror *call (int swi, int r[10])
{
  int i = find (swi & ~XOS_Bit);
  const _kernel_oserror *e;
  if (i < 0)
    {
      if (nswis == MAXSWI) abort ();
      i = nswis++;
      swis[i].swi = swi & ~XOS_Bit;
    }
  swis[i].calls++;
  e = swis[i].fn ? swis[i].fn (swi & ~XOS_Bit, r) : builtin (swi & ~XOS_Bit, r);
  if (e)
    last_error = *e;
  return e;
}

/* The masks are UnixLib's (swis.h): inputs _IN(0..9) in bits 0-9, outputs
   _OUT(0..9) in bits 31-22 in register order, then _OUT(_FLAGS) (bit 21),
   whose pointer gets the PSR flags (always 0 here: no N, Z, C or V).
   _swi returns the register _RETURN(n) names, or the flags for
   _RETURN(_FLAGS). _BLOCK isn't faked: a test using it stops. */
static void unpack (unsigned mask, va_list ap, int r[10], int *outp[10], int **flagsp)
{
  int i;
  if (mask & _BLOCK (0))
    {
      fprintf (stderr, "fake RISC OS: _BLOCK in a SWI mask isn't faked\n");
      abort ();
    }
  for (i = 0; i < 10; i++) if (mask & _IN (i)) r[i] = va_arg (ap, int);
  for (i = 0; i < 10; i++) if (mask & _OUT (i)) outp[i] = va_arg (ap, int *);
  if (mask & _OUT (_FLAGS)) *flagsp = va_arg (ap, int *);
}

_kernel_oserror *_swix (int swi, unsigned mask, ...)
{
  int r[10] = {0}, *outp[10] = {0}, *flagsp = NULL, i;
  const _kernel_oserror *e;
  va_list ap;
  va_start (ap, mask);
  unpack (mask, ap, r, outp, &flagsp);
  va_end (ap);
  e = call (swi | XOS_Bit, r);
  if (e)
    return (_kernel_oserror *) e;  /* outputs are not written on an error */
  for (i = 0; i < 10; i++) if (outp[i]) *outp[i] = r[i];
  if (flagsp) *flagsp = 0;
  return NULL;
}

int _swi (int swi, unsigned mask, ...)
{
  int r[10] = {0}, *outp[10] = {0}, *flagsp = NULL, i;
  unsigned ret = (mask >> 16) & 0xf;
  const _kernel_oserror *e;
  va_list ap;
  va_start (ap, mask);
  unpack (mask, ap, r, outp, &flagsp);
  va_end (ap);
  e = call (swi & ~XOS_Bit, r);
  if (e)
    {
      /* Without the X bit RISC OS would raise the error. */
      fprintf (stderr, "fake RISC OS: error from SWI &%x: %s\n", swi, e->errmess);
      abort ();
    }
  for (i = 0; i < 10; i++) if (outp[i]) *outp[i] = r[i];
  if (flagsp) *flagsp = 0;
  return ret == 0xf ? 0 : r[ret];
}

_kernel_oserror *_kernel_swi (int no, _kernel_swi_regs *in, _kernel_swi_regs *outr)
{
  _kernel_swi_regs r = *in;
  const _kernel_oserror *e = call (no, r.r);
  if (e)
    return &last_error;
  *outr = r;
  return NULL;
}

_kernel_oserror *_kernel_last_oserror (void)
{
  return last_error.errnum || last_error.errmess[0] ? &last_error : NULL;
}

void fake_reset (void)
{
  int i;
  memset (swis, 0, sizeof swis);
  nswis = 0;
  for (i = 0; i < MAXVAR; i++)
    { free (vars[i].name); free (vars[i].value); vars[i].name = vars[i].value = NULL; }
  now_cs = 0;
  outlen = 0; out[0] = 0;
  memset (&last_error, 0, sizeof last_error);
}

void fake_swi (int swi, const char *name, fake_swi_fn *fn)
{
  int i = find (swi & ~XOS_Bit);
  if (i < 0)
    {
      if (nswis == MAXSWI) abort ();
      i = nswis++;
      swis[i].swi = swi & ~XOS_Bit;
    }
  swis[i].name = name;
  swis[i].fn = fn;
}

const char *fake_output (void) { return out; }
void fake_set_time (unsigned cs) { now_cs = cs; }
void fake_advance (unsigned cs) { now_cs += cs; }

int fake_calls (int swi)
{
  int i = find (swi & ~XOS_Bit);
  return i < 0 ? 0 : swis[i].calls;
}

void fake_setvar (const char *name, const char *value)
{
  int i, free_slot = -1;
  for (i = 0; i < MAXVAR; i++)
    {
      if (vars[i].name && strcmp (vars[i].name, name) == 0)
        {
          free (vars[i].name); free (vars[i].value);
          vars[i].name = vars[i].value = NULL;
        }
      if (!vars[i].name && free_slot < 0)
        free_slot = i;
    }
  if (value && free_slot >= 0)
    {
      vars[free_slot].name = strdup (name);
      vars[free_slot].value = strdup (value);
    }
}

int fake_done (const char *name)
{
  printf ("%s: %d checks, %d failed\n", name, fake_checks, fake_fails);
  return fake_fails ? 1 : 0;
}
