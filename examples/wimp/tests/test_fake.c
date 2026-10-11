/* Clicks (src/app.c) on Linux, against the Fake RISC OS. Each Wimp SWI it
   uses is faked here: the fakes record what the program asked for and
   answer as the Wimp would, and the test plays the events a user would
   cause (clicks, the window's close icon, the menu, the desktop quitting). */
#include <stdio.h>
#include <string.h>
#include "fake.h"
#include "swis.h"
#include "../src/app.h"

#define WINDOW 0x2a000
static const _kernel_oserror no_memory = { 0x286, "Not enough memory" };

static int fail_create;                 /* make Wimp_CreateWindow fail */
static char task_name[32];
static int icon_block[9], window_block[30];
static char window_text[32];
static const char *icon_text;           /* the count icon's text buffer */
static int opened[8], open_calls, closed;
static int redrawn_icon = -1;
static const char *menu_title, *menu_item;
static int menu_x, menu_y;
static char reported[256];

static const _kernel_oserror *wimp (int swi, int r[10])
{
  int *b = (int *) r[1];
  switch (swi)
    {
    case Wimp_Initialise:
      snprintf (task_name, sizeof task_name, "%s", (const char *) r[2]);
      CHECK (r[1] == 0x4B534154, "Wimp_Initialise: R1 is \"TASK\"");
      CHECK (r[0] >= 310, "Wimp_Initialise: a version that takes a message list");
      r[0] = 380; r[1] = 0x1234;        /* the Wimp's version, the task handle */
      return NULL;
    case Wimp_CreateIcon:
      memcpy (icon_block, b, sizeof icon_block);
      r[0] = 1;
      return NULL;
    case Wimp_CreateWindow:
      if (fail_create)
        return &no_memory;
      memcpy (window_block, b, sizeof window_block);
      icon_text = (const char *) b[27];
      r[0] = WINDOW;
      return NULL;
    case Wimp_GetWindowState:
      CHECK (b[0] == WINDOW, "Wimp_GetWindowState: our window");
      memcpy (&b[1], window_block, 7 * sizeof (int));   /* visible, scroll, behind */
      b[8] = window_block[7];                           /* flags */
      return NULL;
    case Wimp_OpenWindow:
      memcpy (opened, b, sizeof opened);
      open_calls++;
      return NULL;
    case Wimp_CloseWindow:
      closed = b[0];
      return NULL;
    case Wimp_SetIconState:
      CHECK (b[0] == WINDOW && b[2] == 0 && b[3] == 0, "Wimp_SetIconState: our window, no flags changed");
      redrawn_icon = b[1];
      snprintf (window_text, sizeof window_text, "%s", icon_text);
      return NULL;
    case Wimp_CreateMenu:
      menu_title = (const char *) b;
      menu_item = (const char *) b + 28 + 12;   /* header, then flags, submenu, icon flags */
      menu_x = r[2]; menu_y = r[3];
      return NULL;
    case Wimp_ReportError:
      snprintf (reported, sizeof reported, "%s", ((const _kernel_oserror *) r[0])->errmess);
      return NULL;
    case Wimp_CloseDown:
      CHECK (r[0] == 0x1234 && r[1] == 0x4B534154, "Wimp_CloseDown: our task handle and \"TASK\"");
      return NULL;
    }
  return NULL;
}

static void fake_wimp (void)
{
  static const struct { int swi; const char *name; } list[] = {
    { Wimp_Initialise, "Wimp_Initialise" }, { Wimp_CreateIcon, "Wimp_CreateIcon" },
    { Wimp_CreateWindow, "Wimp_CreateWindow" }, { Wimp_GetWindowState, "Wimp_GetWindowState" },
    { Wimp_OpenWindow, "Wimp_OpenWindow" }, { Wimp_CloseWindow, "Wimp_CloseWindow" },
    { Wimp_SetIconState, "Wimp_SetIconState" }, { Wimp_CreateMenu, "Wimp_CreateMenu" },
    { Wimp_ReportError, "Wimp_ReportError" }, { Wimp_CloseDown, "Wimp_CloseDown" } };
  size_t i;
  fake_reset ();
  for (i = 0; i < sizeof list / sizeof list[0]; i++)
    fake_swi (list[i].swi, list[i].name, wimp);
}

/* A click: Wimp_Poll's block for Mouse_Click. */
static int click (int window, int buttons)
{
  int b[64] = { 0 };
  b[0] = 1000; b[1] = 20; b[2] = buttons; b[3] = window; b[4] = 0;
  return app_event (Mouse_Click, b);
}

int main (void)
{
  int b[64] = { 0 };

  fake_wimp ();
  CHECK (app_init () == 0, "app_init succeeds");
  CHECK (strcmp (task_name, "Clicks") == 0, "the task is called Clicks");
  CHECK (icon_block[0] == -1, "the icon goes on the right of the icon bar");
  CHECK (strcmp ((const char *) &icon_block[6], "!clicks") == 0, "it shows the !clicks sprite");
  CHECK ((icon_block[5] & 0x2) && ((icon_block[5] >> 12) & 15) == 3, "a sprite icon that reports clicks");
  CHECK (strcmp ((const char *) &window_block[18], "Clicks") == 0, "the window's title");
  CHECK (window_block[21] == 1 && (window_block[26] & 0x100), "one indirected icon in it");
  CHECK (icon_text && strcmp (icon_text, "No clicks yet") == 0, "which starts with no clicks");
  CHECK (open_calls == 0, "nothing opens until the icon is clicked");

  CHECK (click (-2, 4) == 0 && open_calls == 1, "Select on the icon bar opens the window");
  CHECK (opened[0] == WINDOW && opened[7] == -1, "our window, on top");
  CHECK (opened[1] == window_block[0] && opened[4] == window_block[3], "where Wimp_CreateWindow put it");

  click (WINDOW, 4);
  CHECK (app_clicks () == 1 && redrawn_icon == 0, "Select in the window counts, and redraws the icon");
  CHECK (strcmp (window_text, "1 click") == 0, "\"1 click\"");
  click (WINDOW, 4); click (WINDOW, 4);
  CHECK (strcmp (window_text, "3 clicks") == 0, "\"3 clicks\"");
  click (WINDOW, 1);
  CHECK (app_clicks () == 0 && strcmp (window_text, "No clicks yet") == 0, "Adjust starts again");

  b[0] = WINDOW; b[1] = 10; b[2] = 20; b[3] = 410; b[4] = 220; b[7] = -1;
  CHECK (app_event (Open_Window_Request, b) == 0 && opened[1] == 10 && open_calls == 2,
         "Open_Window_Request (dragged, say) is passed to Wimp_OpenWindow");
  CHECK (app_event (Close_Window_Request, b) == 0 && closed == WINDOW, "the close icon closes it");

  CHECK (click (-2, 2) == 0 && menu_title && strcmp (menu_title, "Clicks") == 0,
         "Menu on the icon bar opens the menu");
  CHECK (menu_item && strcmp (menu_item, "Quit") == 0, "with Quit in it");
  CHECK (menu_x == 1000 - 64 && menu_y == 96 + 44, "above the icon, as the Style Guide says");
  memset (b, 0, sizeof b); b[0] = 0; b[1] = -1;
  CHECK (app_event (Menu_Selection, b) == 1, "choosing Quit ends the program");

  memset (b, 0, sizeof b); b[0] = 20; b[4] = 0;    /* Message_Quit */
  CHECK (app_event (User_Message, b) == 1, "Message_Quit ends it too");
  b[4] = 0x502;                                    /* Message_HelpRequest: not ours */
  CHECK (app_event (User_Message_Recorded, b) == 0, "other messages don't");
  app_close ();
  CHECK (fake_calls (Wimp_CloseDown) == 1, "Wimp_CloseDown at the end");

  fake_wimp ();
  fail_create = 1;
  CHECK (app_init () != 0, "if the window can't be made, app_init fails");
  CHECK (strcmp (reported, "Not enough memory") == 0, "and the error is shown in a box");
  fail_create = 0;

  return fake_done ("Clicks (fake RISC OS)");
}
