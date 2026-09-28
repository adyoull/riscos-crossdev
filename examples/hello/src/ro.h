/* hello: the RISC OS part (SWI calls). Tested on Linux against the fake
   RISC OS (tests/test_fake.c) as well as on RISC OS. */
#ifndef HELLO_RO_H
#define HELLO_RO_H
#include <stddef.h>

/* Time since the machine started, in centiseconds (OS_ReadMonotonicTime). */
unsigned hello_uptime (void);

/* The name to greet: the system variable Hello$Name, or "world" if it's
   unset, empty or too long for buf. */
const char *hello_name (char *buf, size_t len);

/* Write s and a newline with OS_Write0/OS_NewLine. 0 on success, -1 if a
   SWI returned an error (its message is written to stderr). */
int hello_say (const char *s);

#endif
