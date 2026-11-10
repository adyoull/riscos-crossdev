/* libgreet: a shared library for a "mixed" program. It has no UnixLib of
   its own (built -nostdlib): malloc and snprintf are the program's, and
   so is greet_hook, which the library calls back. */
#include <stdio.h>
#include <stdlib.h>
#include "greet.h"

static int calls;                       /* the library's own data */
static int ready;

__attribute__((constructor)) static void greet_init(void) { ready = 1; }

char *greet(const char *who)
{
  char *s = malloc(64);
  if (s)
    snprintf(s, 64, "Hello, %s, from libgreet (%s, call %d)",
             who, ready ? "set up" : "NOT set up", greet_hook(++calls));
  return s;
}
