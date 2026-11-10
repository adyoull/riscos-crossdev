/* crtmixed.o: linked into a "mixed" RISC OS program (riscos-crossdev:
   gcc -rdynamic), whose UnixLib, libstdc++ and libgcc are linked in from
   the static libraries while its other libraries are shared objects
   loaded by SOManager and ld-riscos/so/2.

   It lets the program's unwinder (libgcc, linked statically) find the
   exception tables of the shared libraries ld-riscos loaded. libgcc asks
   __gnu_Unwind_Find_exidx, which ld-riscos defines for fully shared
   programs; a program with static UnixLib has none, so this walks
   ld-riscos's list of loaded objects (from the r_debug its DT_DEBUG
   entry points to), as ld-riscos's own dl_unwind.c does. The structure
   is ld-riscos/so/2's struct elf_resolve, up to the fields used here.

   It also makes sure the program's own UnixLib is the only one: if any
   library brought in a shared UnixLib, libstdc++ or libgcc_s (from
   !SharedLibs, built for fully shared programs), the program stops at
   once with a message naming it, instead of running with two C libraries.

   Installed by toolchain/mixed/install.sh. MIT licence. */
typedef struct { int d_tag; union { unsigned d_val, d_ptr; } d_un; } Elf32_Dyn;
#define DT_NULL 0
#define DT_DEBUG 21

typedef unsigned _Unwind_Ptr;
struct elf_resolve {
  char *loadaddr; char *libname; unsigned dynamic_addr;
  struct elf_resolve *next, *prev;
  int libtype; void *symbol_scope;
  unsigned short usage_count, init_flag;
  unsigned nbucket; unsigned *elf_buckets; unsigned nchain; unsigned *chains;
  unsigned dynamic_info[29]; unsigned dynamic_size; unsigned n_phent; void *ppnt;
  char *endaddr; _Unwind_Ptr exidx; int exidx_size;
};
struct r_debug { int r_version; struct elf_resolve *r_map; };

extern Elf32_Dyn _DYNAMIC[] __attribute__((weak));
extern char __exidx_start[] __attribute__((weak)), __exidx_end[] __attribute__((weak));
extern char __executable_start[], etext[];

_Unwind_Ptr __gnu_Unwind_Find_exidx(_Unwind_Ptr addr, int *nrec)
{
  if (addr >= (_Unwind_Ptr) __executable_start && addr < (_Unwind_Ptr) etext) {
    *nrec = (__exidx_end - __exidx_start) / 8;
    return (_Unwind_Ptr) __exidx_start;
  }
  if (_DYNAMIC)
    for (Elf32_Dyn *d = _DYNAMIC; d->d_tag != DT_NULL; d++)
      if (d->d_tag == DT_DEBUG && d->d_un.d_ptr) {
        struct r_debug *r = (struct r_debug *) d->d_un.d_ptr;
        for (struct elf_resolve *t = r->r_map; t; t = t->next)
          if (addr >= (_Unwind_Ptr) t->loadaddr && addr < (_Unwind_Ptr) t->endaddr) {
            *nrec = t->exidx_size / 8;
            return t->exidx;
          }
      }
  *nrec = 0;
  return 0;
}

/* Runs before main (the libraries' constructors have run; this is the
   program's first). Every object ld-riscos loaded is on its list. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *system_lib(const char *name)
{
  /* ld-riscos keeps the name it opened: a Unix-style path such as
     /SharedLibs:/lib/armeabihf/libunixlib.so.5, or a RISC OS one. */
  static const char *const libs[] = { "libunixlib", "libstdc++", "libgcc_s" };
  for (unsigned i = 0; i < sizeof libs / sizeof libs[0]; i++)
    if (strstr(name, libs[i]))
      return libs[i];
  return NULL;
}

__attribute__((constructor(101))) static void crtmixed_one_unixlib(void)
{
  if (!_DYNAMIC)
    return;
  for (Elf32_Dyn *d = _DYNAMIC; d->d_tag != DT_NULL; d++)
    if (d->d_tag == DT_DEBUG && d->d_un.d_ptr) {
      struct r_debug *r = (struct r_debug *) d->d_un.d_ptr;
      for (struct elf_resolve *t = r->r_map; t; t = t->next) {
        const char *what = t->libname ? system_lib(t->libname) : NULL;
        if (what) {
          fprintf(stderr, "This program has its own UnixLib, libstdc++ and libgcc, but one of its "
                  "libraries also loaded a shared %s (%s). Every library it uses must be built "
                  "for mixed programs (riscos-crossdev docs/MIXED.md) and be in its own lib "
                  "directory.\n", what, t->libname);
          exit(1);
        }
      }
    }
}
