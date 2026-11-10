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

   It also makes sure the program's own UnixLib is the only one. A
   library built for fully shared programs (GCCSDK's, in !SharedLibs)
   needs libunixlib.so.5, libstdc++.so.6 or libgcc_s.so.1; the app's lib
   directory holds empty stand-ins under those names (mixed-stubs/,
   marked by __riscos_mixed_stub), so the library uses the program's
   UnixLib. If a real one was loaded instead, the program stops at once
   with a message naming it, rather than run with two C libraries.

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

/* Is T one of the stand-ins (it defines __riscos_mixed_stub)? Its
   dynamic_info holds unrelocated addresses, as in ld-riscos's hash.c. */
typedef struct { unsigned st_name, st_value, st_size; unsigned char st_info, st_other; unsigned short st_shndx; } Elf32_Sym;
#define DT_STRTAB 5
#define DT_SYMTAB 6
static int is_stub(const struct elf_resolve *t)
{
  if (!t->dynamic_info[DT_SYMTAB] || !t->dynamic_info[DT_STRTAB])
    return 0;
  const Elf32_Sym *sym = (const Elf32_Sym *) (t->loadaddr + t->dynamic_info[DT_SYMTAB]);
  const char *str = t->loadaddr + t->dynamic_info[DT_STRTAB];
  for (unsigned i = 1; i < t->nchain; i++)
    if (sym[i].st_shndx && strcmp(str + sym[i].st_name, "__riscos_mixed_stub") == 0)
      return 1;
  return 0;
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
        if (what && is_stub(t))
          continue;
        if (what) {
          fprintf(stderr, "This program has its own UnixLib, libstdc++ and libgcc, but one of its "
                  "libraries also loaded a shared %s (%s). Put riscos-crossdev's stand-ins "
                  "(mixed-stubs) in the program's own lib directory (docs/MIXED.md).\n", what, t->libname);
          exit(1);
        }
      }
    }
}
