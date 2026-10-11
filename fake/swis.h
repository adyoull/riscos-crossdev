/* Fake RISC OS: swis.h for host (Linux) builds.
   The register masks are UnixLib's own (so _OUT(_FLAGS), _RETURN(_FLAGS),
   _BLOCK work as on RISC OS), and swinames.h has every SWI number in
   UnixLib's swis.h (fake/gen-swinames.sh). fake/riscos.c implements _swix,
   _swi and a few SWIs; tests add the rest with fake_swi() (fake.h). */
#ifndef FAKE_SWIS_H
#define FAKE_SWIS_H
#include "kernel.h"

/* As UnixLib's swis.h (riscos-unixlib, libunixlib/include/swis.h). */
#define _FLAGS     0x10 /* use with _RETURN() or _OUT() */
#define _IN(i)     (1U << (i))
#define _INR(i,j)  (~0U << (i) ^ ~0U << ((j) + 1))
#define _OUT(i)    ((i) != _FLAGS ? (1U << (31 - (i))) : 1U << 21)
#define _OUTR(i,j) (~0U >> (i) ^ ~0U >> ((j) + 1))
#define _BLOCK(i)  (1U << 11 | (unsigned) (i) << 12)
#define _RETURN(i) ((i) != _FLAGS ? (unsigned) (i) << 16 : 0xFU << 16)
#define _C         (1U << 29)
#define _Z         (1U << 30)
#define _N         (1U << 31)

#define XOS_Bit    0x20000

#include "swinames.h"

#ifdef __cplusplus
extern "C" {
#endif
_kernel_oserror *_swix (int swi, unsigned mask, ...);
int _swi (int swi, unsigned mask, ...);
#ifdef __cplusplus
}
#endif

#endif
