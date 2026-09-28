/* Fake RISC OS: the test-side interface.
   Code under test includes the fake kernel.h/swis.h as if they were the
   real ones; tests include this header to set up and inspect the fake. */
#ifndef FAKE_FAKE_H
#define FAKE_FAKE_H
#include "kernel.h"

/* A SWI handler: r[0..9] in, changed in place for the outputs. Return NULL
   for success, or an error (the caller sees it as the SWI's error). */
typedef const _kernel_oserror *fake_swi_fn (int swi, int r[10]);

/* Back to the start state: no handlers, clock at 0, no output, no
   variables. Call it at the start of each test. */
void fake_reset (void);

/* Handle SWI number swi (without the X bit) with fn; replaces a built-in.
   Name it too, for OS_SWINumberFromString (NULL: no name). */
void fake_swi (int swi, const char *name, fake_swi_fn *fn);

/* Built in (until replaced):
   OS_WriteC, OS_Write0, OS_NewLine   append to the output buffer
   OS_ReadMonotonicTime               the fake clock (centiseconds)
   OS_ReadVarVal (string reads)       the fake system variables
   OS_SWINumberFromString             the names given to fake_swi
   OS_GenerateError                   returns its R0
   Any other SWI prints its number and aborts the test. */

/* Everything written with OS_WriteC/OS_Write0/OS_NewLine since the last
   fake_reset (OS_NewLine writes "\r\n", as RISC OS does). */
const char *fake_output (void);

/* The monotonic clock, in centiseconds. */
void fake_set_time (unsigned cs);
void fake_advance (unsigned cs);

/* System variables, read by OS_ReadVarVal. value NULL unsets. */
void fake_setvar (const char *name, const char *value);

/* How many times SWI swi has been called since fake_reset. */
int fake_calls (int swi);

/* A tiny test harness: CHECK(cond, "what") counts and reports. */
extern int fake_checks, fake_fails;
#define CHECK(cond, what) do { fake_checks++; if (!(cond)) { fake_fails++; \
  fprintf (stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, what); } } while (0)
/* Prints the totals; returns the exit status for main. */
int fake_done (const char *name);

#endif
