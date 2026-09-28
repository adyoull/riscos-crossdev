/* Fake RISC OS: swis.h for host (Linux) builds.
   _swix/_swi with the real register masks, and the numbers of the SWIs the
   fake implements (fake/riscos.c) or tests commonly fake themselves. Add
   the numbers your code uses (from the real swis.h or the PRMs). */
#ifndef FAKE_SWIS_H
#define FAKE_SWIS_H
#include "kernel.h"

#define _IN(i)      (1U << (i))
#define _INR(a,b)   ((~0U << (a)) & ~(~0U << ((b) + 1)))
#define _OUT(i)     (1U << (31 - (i)))
#define _OUTR(a,b)  ((((1U << ((b) - (a) + 1)) - 1)) << (31 - (b)))
#define _FLAGS      (1U << 21)   /* output: the PSR flags (V=bit 28 ... N=31) */
#define _RETURN(i)  ((i) << 16)  /* _swi: which register is returned */

#define XOS_Bit                0x20000

#define OS_WriteC              0x00
#define OS_Write0              0x02
#define OS_NewLine             0x03
#define OS_Byte                0x06
#define OS_Exit                0x11
#define OS_EnterOS             0x16
#define OS_SetCallBack         0x1b
#define OS_Module              0x1e
#define OS_ReadVarVal          0x23
#define OS_SetVarVal           0x24
#define OS_SWINumberFromString 0x39
#define OS_CallEvery           0x3c
#define OS_RemoveTickerEvent   0x3d
#define OS_ReadMonotonicTime   0x42
#define OS_GenerateError       0x2b
#define Wimp_Initialise        0x400c0
#define Wimp_CloseDown         0x400dd
#define Wimp_ReportError       0x400df
#define Wimp_Poll              0x400c7

const _kernel_oserror *_swix (int swi, unsigned mask, ...);
int _swi (int swi, unsigned mask, ...);

#endif
