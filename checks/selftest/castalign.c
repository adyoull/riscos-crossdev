/* checks/selftest: a cast check-unaligned.sh must report (and a safe
   version it must not). */
#include <stdint.h>
#include <string.h>
uint32_t bad (const unsigned char *p) { return *(const uint32_t *) (p + 1); }
uint32_t good (const unsigned char *p) { uint32_t v; memcpy (&v, p + 1, 4); return v; }
