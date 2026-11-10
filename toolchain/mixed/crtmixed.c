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
