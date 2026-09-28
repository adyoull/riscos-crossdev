/* hello: the portable part (no RISC OS calls). Tested on Linux under
   qemu-arm-aligntrap (tests/test_qemu.c) as well as on RISC OS. */
#ifndef HELLO_GREET_H
#define HELLO_GREET_H
#include <stddef.h>
#include <stdint.h>

/* Centiseconds as "H:MM:SS". Returns the length, like snprintf. */
int hello_format_uptime (char *buf, size_t len, unsigned cs);

/* A little-endian 32-bit word at any address. RISC OS traps unaligned word
   loads, so this reads bytes; *(uint32_t *) p would abort when p is odd. */
uint32_t hello_read_le32 (const unsigned char *p);

/* A simple checksum of the little-endian words in p[0..n) (n % 4 == 0),
   wherever p points. */
uint32_t hello_checksum (const unsigned char *p, size_t n);

#endif
