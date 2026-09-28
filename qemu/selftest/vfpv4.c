/* qemu/selftest: a fused multiply-add (VFPv4). Must be stopped with
   SIGILL on the Cortex-A8 that qemu/aligntrap.sh emulates (as a VFPv3
   machine would stop it). */
#include <stdio.h>

int main (int argc, char **argv)
{
  volatile float a = argc, b = 2.5f, c = 1.0f;
  float r;
  __asm__ volatile ("vfma.f32 %0, %1, %2" : "=t" (r) : "t" (a), "t" (b), "0" (c));
  printf ("%f\n", r);
  return 0;
}
