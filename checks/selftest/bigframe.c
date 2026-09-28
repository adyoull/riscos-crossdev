/* checks/selftest: a function with a 16 KB frame. Built without
   -fstack-clash-protection, check-stack-probes.py must report it. */
#include <stdio.h>
#include <string.h>

__attribute__ ((noinline)) static int big (int n)
{
  volatile char buf[16384];
  memset ((char *) buf, n, sizeof buf);
  return buf[n];
}

int main (int argc, char **argv)
{
  (void) argv;
  printf ("%d\n", big (argc));
  return 0;
}
