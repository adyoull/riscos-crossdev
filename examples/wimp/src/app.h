/* Clicks: a small desktop (Wimp) program. An icon on the icon bar; click
   it to open a window that counts your clicks (Select adds one, Adjust
   starts again); Menu on the icon gives Quit.

   The program is split so that every part can be tested on Linux against
   the Fake RISC OS: app.c does everything, main.c only polls. */
#ifndef CLICKS_APP_H
#define CLICKS_APP_H

/* Wimp_Poll reason codes and mouse buttons this program uses. */
enum { Open_Window_Request = 2, Close_Window_Request = 3, Mouse_Click = 6,
       Menu_Selection = 9, User_Message = 17, User_Message_Recorded = 18 };
enum { Button_Adjust = 1, Button_Menu = 2, Button_Select = 4 };
#define Message_Quit 0

/* Start: Wimp_Initialise, the icon bar icon, the window. 0 if all went well. */
int app_init (void);

/* Act on one event from Wimp_Poll (block is Wimp_Poll's 256-byte block).
   Returns 1 when the program should end. */
int app_event (int reason, int *block);

/* The number on the window now. */
int app_clicks (void);

/* Wimp_CloseDown. */
void app_close (void);

/* Show an error in a box (Wimp_ReportError). */
void app_report (const char *text);

#endif
