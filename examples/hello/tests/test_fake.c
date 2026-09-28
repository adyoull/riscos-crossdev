/* hello's RISC OS part (src/ro.c) on Linux, against the fake RISC OS. */
#include <stdio.h>
#include <string.h>
#include "fake.h"
#include "swis.h"
#include "../src/ro.h"

static const _kernel_oserror no_screen = { 1, "No screen" };
static const _kernel_oserror *broken_write0 (int swi, int r[10])
{
  (void) swi; (void) r;
  return &no_screen;
}

int main (void)
{
  char buf[16];

  fake_reset ();
  fake_set_time (123456);
  CHECK (hello_uptime () == 123456, "uptime comes from OS_ReadMonotonicTime");
  fake_advance (100);
  CHECK (hello_uptime () == 123556, "and follows the clock");

  CHECK (strcmp (hello_name (buf, sizeof buf), "world") == 0, "unset Hello$Name: world");
  fake_setvar ("Hello$Name", "");
  CHECK (strcmp (hello_name (buf, sizeof buf), "world") == 0, "empty Hello$Name: world");
  fake_setvar ("Hello$Name", "Acorn");
  CHECK (strcmp (hello_name (buf, sizeof buf), "Acorn") == 0, "Hello$Name is read");
  fake_setvar ("Hello$Name", "fifteen chars!!");
  CHECK (strcmp (hello_name (buf, sizeof buf), "fifteen chars!!") == 0, "a name that just fits");
  fake_setvar ("Hello$Name", "sixteen chars!!!");
  CHECK (strcmp (hello_name (buf, sizeof buf), "world") == 0, "a name too long: world");
  CHECK (strcmp (hello_name (buf, 1), "world") == 0, "no room at all: world");

  CHECK (hello_say ("Hi") == 0 && strcmp (fake_output (), "Hi\r\n") == 0,
         "hello_say writes the text and a newline");
  CHECK (fake_calls (OS_Write0) == 1 && fake_calls (OS_NewLine) == 1, "one SWI each");

  fake_reset ();
  fake_swi (OS_Write0, "OS_Write0", broken_write0);
  CHECK (hello_say ("Hi") == -1, "an error from OS_Write0 is returned");
  CHECK (fake_calls (OS_NewLine) == 0, "and nothing more is written");

  return fake_done ("hello (fake RISC OS)");
}
