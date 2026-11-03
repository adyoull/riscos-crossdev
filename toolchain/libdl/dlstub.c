/* libdl for RISC OS programs built with riscos-crossdev: a stub.
 *
 * The toolchain links every program statically, and RISC OS has no
 * dynamic loader for them, so nothing can be loaded at run time. The
 * toolchain has <dlfcn.h> but no libdl, so a build that links -ldl (CMake's
 * CMAKE_DL_LIBS, many configure scripts) failed with "cannot find -ldl".
 * With this, such programs link; dlopen() fails and dlerror() says why,
 * which is how they behave when a plugin is missing.
 *
 * Installed as libdl.a by toolchain/libdl/install.sh (run by make prebuilt
 * and make toolchain). The prototypes follow the toolchain's dlfcn.h.
 * Written for riscos-crossdev, after riscos-openttd's stub. MIT licence.
 */
#include <dlfcn.h>
#include <stddef.h>

static const char *dl_error;

static void *fail(const char *why)
{
  dl_error = why;
  return NULL;
}

void *dlopen(const char *filename, int flag)
{
  (void)flag;
  if (filename == NULL)
    return fail("dlopen: no symbol table: RISC OS programs are linked statically");
  return fail("dlopen: RISC OS programs are linked statically; no library can be loaded at run time");
}

void *dlsym(void *handle, const char *symbol)
{
  (void)handle; (void)symbol;
  return fail("dlsym: RISC OS programs are linked statically; no symbols can be looked up");
}

int dlclose(void *handle)
{
  (void)handle;
  dl_error = "dlclose: nothing was opened";
  return -1;
}

const char *dlerror(void)
{
  const char *e = dl_error;
  dl_error = NULL;
  return e;
}

int dladdr(void *address, Dl_info *info)
{
  (void)address; (void)info;
  return 0;
}
