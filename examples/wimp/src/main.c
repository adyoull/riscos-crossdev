/* Clicks: the poll loop. Everything it calls is in app.c. */
#include <kernel.h>
#include <swis.h>
#include "app.h"

int main (void)
{
  static int block[64];
  int reason, quit = 0;

  if (app_init ())
    return 1;
  while (!quit)
    {
      /* Mask bit 0: no null events, so the program sleeps until something
         happens and other tasks get the time. */
      _kernel_oserror *e = _swix (Wimp_Poll, _INR (0, 1) | _OUT (0), 1, block, &reason);
      if (e)
        {
          app_report (e->errmess);
          break;
        }
      quit = app_event (reason, block);
    }
  app_close ();
  return 0;
}
