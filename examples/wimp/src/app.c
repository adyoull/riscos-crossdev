/* Clicks: everything but the poll loop. See app.h. The window and menu are
   built in code (no Templates file), with the block layouts from the PRMs
   (Wimp_CreateWindow, Wimp_CreateIcon, Wimp_CreateMenu). */
#include <stdio.h>
#include <string.h>
#include <kernel.h>
#include <swis.h>
#include "app.h"

#define APP_NAME "Clicks"
#define TASK_WORD 0x4B534154          /* "TASK" */
#define WIMP_VERSION 310

static int task, window = -1, clicks;
static char text[32] = "No clicks yet";

/* The menu on the icon bar icon: a title and one item, Quit. */
static struct
{
  char title[12];
  unsigned char colours[4];           /* title fg, bg; work fg, bg */
  int width, height, gap;
  struct { int flags, submenu, icon_flags; char text[12]; } item[1];
} menu = {
  APP_NAME, { 7, 2, 7, 0 }, 4 * 16, 44, 0,
  { { 0x80 /* last item */, -1, 0x07000021 /* text, filled, black on white */, "Quit" } }
};

void app_report (const char *msg)
{
  _kernel_oserror e;
  e.errnum = 0;
  snprintf (e.errmess, sizeof e.errmess, "%s", msg);
  _swix (Wimp_ReportError, _INR (0, 2), &e, 1 /* OK box */, APP_NAME);
}

static int fail (const _kernel_oserror *e)
{
  if (e)
    app_report (e->errmess);
  return e != NULL;
}

/* Window: 400 x 200 OS units, title bar, back and close icons, and one
   icon showing the count (indirected text, so changing text[] and
   asking for a redraw is enough). */
static int create_window (void)
{
  int b[22 + 8];
  memset (b, 0, sizeof b);
  b[0] = 400; b[1] = 600; b[2] = 800; b[3] = 800;   /* visible area on screen */
  b[6] = -1;                                       /* open on top */
  b[7] = (int) 0x87000012;  /* new flags; title, back, close; movable; the Wimp redraws it */
  ((unsigned char *) b)[32] = 7;  ((unsigned char *) b)[33] = 2;   /* title colours */
  ((unsigned char *) b)[34] = 7;  ((unsigned char *) b)[35] = 1;   /* work area colours */
  ((unsigned char *) b)[36] = 3;  ((unsigned char *) b)[37] = 1;   /* scroll bars */
  ((unsigned char *) b)[38] = 12;                                  /* title with the caret */
  b[10] = 0; b[11] = -200; b[12] = 400; b[13] = 0;  /* work area */
  b[14] = 0x3D;             /* title: text, border, centred, filled */
  b[15] = 3 << 12;          /* work area: report clicks */
  b[16] = 1;                /* sprites from the Wimp's pool */
  memcpy (&b[18], APP_NAME, sizeof APP_NAME);
  b[21] = 1;                /* one icon */
  b[22] = 16; b[23] = -140; b[24] = 384; b[25] = -60;              /* its box */
  b[26] = 0x0700013D;       /* text, border, centred, filled, indirected; black */
  b[27] = (int) text; b[28] = -1; b[29] = sizeof text;             /* text, no validation, size */
  return fail (_swix (Wimp_CreateWindow, _IN (1) | _OUT (0), b, &window));
}

static int create_iconbar_icon (void)
{
  int b[9];
  memset (b, 0, sizeof b);
  b[0] = -1;                          /* the right of the icon bar */
  b[1] = 0; b[2] = 0; b[3] = 68; b[4] = 68;
  b[5] = 0x301A;                      /* sprite, centred, report clicks */
  memcpy (&b[6], "!clicks", 8);       /* the sprite in !Sprites */
  return fail (_swix (Wimp_CreateIcon, _INR (0, 1), 0, b));
}

int app_init (void)
{
  static const int messages[] = { 0 };   /* only Message_Quit, always sent */
  if (fail (_swix (Wimp_Initialise, _INR (0, 3) | _OUT (1),
                   WIMP_VERSION, TASK_WORD, APP_NAME, messages, &task)))
    return 1;
  return create_iconbar_icon () || create_window ();
}

static void open_window (void)
{
  int b[9];
  b[0] = window;
  if (fail (_swix (Wimp_GetWindowState, _IN (1), b)))
    return;
  b[7] = -1;                              /* bring it to the front */
  fail (_swix (Wimp_OpenWindow, _IN (1), b));
}

static void show_count (void)
{
  int b[4] = { window, 0, 0, 0 };         /* icon 0, change nothing: redraw it */
  if (clicks == 0)
    snprintf (text, sizeof text, "No clicks yet");
  else
    snprintf (text, sizeof text, "%d click%s", clicks, clicks == 1 ? "" : "s");
  fail (_swix (Wimp_SetIconState, _IN (1), b));
}

int app_clicks (void)
{
  return clicks;
}

int app_event (int reason, int *b)
{
  switch (reason)
    {
    case Open_Window_Request:
      fail (_swix (Wimp_OpenWindow, _IN (1), b));
      break;
    case Close_Window_Request:
      fail (_swix (Wimp_CloseWindow, _IN (1), b));
      break;
    case Mouse_Click:
      if (b[3] == -2)                      /* the icon bar */
        {
          if (b[2] == Button_Select)
            open_window ();
          else if (b[2] == Button_Menu)    /* the menu, above the icon */
            fail (_swix (Wimp_CreateMenu, _INR (1, 3), &menu, b[0] - 64, 96 + 44));
        }
      else if (b[3] == window)
        {
          if (b[2] == Button_Select)
            clicks++;
          else if (b[2] == Button_Adjust)
            clicks = 0;
          show_count ();
        }
      break;
    case Menu_Selection:
      if (b[0] == 0)                       /* Quit */
        return 1;
      break;
    case User_Message:
    case User_Message_Recorded:
      if (b[4] == Message_Quit)
        return 1;
      break;
    }
  return 0;
}

void app_close (void)
{
  _swix (Wimp_CloseDown, _INR (0, 1), task, TASK_WORD);
}
