# examples/wimp: a desktop program

Clicks: an icon on the icon bar, a window that counts your clicks, a menu
with Quit. Written in C against the Wimp's SWIs, with the window and menu
built in code (no Templates file).

- **`src/main.c`** is only the `Wimp_Poll` loop. **`src/app.c`** does the
  rest: `app_init` (Wimp_Initialise, the icon bar icon, the window) and
  `app_event`, which acts on one event. Kept apart like this, the event
  handling can be tested without a desktop.
- **`tests/test_fake.c`** fakes the ten Wimp SWIs the program uses on the
  Fake RISC OS: each fake records what the program asked for and answers as
  the Wimp would. The test then plays what a user does (Select on the icon
  bar, clicks in the window, Menu, Quit, the close icon, the desktop
  quitting) and checks each SWI call and its block: 37 checks.
- **`app/clicks.png`, `app/sm-clicks.png`** become `!Sprites` with
  `$(PNG2SPRITE)`.
- `!Run` loads SharedUnixLibrary and ARMEABISupport, sets the WimpSlot, and
  runs `!RunImage`.

```sh
make RCD_DIR=../..          # out/Clicks.zip
make RCD_DIR=../.. check    # the checks and the Fake RISC OS test
```

To start your own desktop program from it, rename `!Clicks` and
`Clicks.zip` in the `Makefile`, `APP_NAME` in `src/app.c`, the sprite
names and `Clicks$Dir`. The window and icon block layouts are
the PRMs' (Wimp_CreateWindow, Wimp_CreateIcon, Wimp_CreateMenu). More in
[docs/USING.md](../../docs/USING.md).
