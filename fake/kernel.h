/* Fake RISC OS: kernel.h for host (Linux) builds.
   The types and calls of the real kernel.h that SWI-calling code uses.
   Build 32-bit (-m32, see fake/fake.mk) so that int and pointers are the
   same size, as on RISC OS: code stores pointers in _kernel_swi_regs. */
#ifndef FAKE_KERNEL_H
#define FAKE_KERNEL_H

typedef struct
{
  int errnum;
  char errmess[252];
} _kernel_oserror;

typedef struct
{
  int r[10];
} _kernel_swi_regs;

_kernel_oserror *_kernel_swi (int no, _kernel_swi_regs *in, _kernel_swi_regs *out);
_kernel_oserror *_kernel_last_oserror (void);

#endif
