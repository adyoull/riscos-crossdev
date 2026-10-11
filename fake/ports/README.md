# The ports' fakes

Every RISC OS port at [github.com/adyoull](https://github.com/adyoull) tests
its RISC OS code on Linux against fakes: of SWIs, modules, the Wimp, the
screen, hardware. They are collected here, unchanged, so that a new port can
start from what already exists instead of writing its own. Each one is
still owned by the port it came from, and is kept up to date from there.

## Where each came from, and keeping them current

| Here | Port (repository) | Copied from | Licence |
|---|---|---|---|
| `unixlib/` | [riscos-unixlib](https://github.com/adyoull/riscos-unixlib) | `tests/host/*/fake/`, `tests/emu/` | UnixLib's licences (`libunixlib/COPYING` there); `host/eventfd/fake/sys/eventfd.h` is FreeBSD's (BSD 2-clause, in the file) |
| `mesa/` | [riscos-mesa](https://github.com/adyoull/riscos-mesa) | `tests/host-harness/` | MIT |
| `gtk/` | [riscos-gtk](https://github.com/adyoull/riscos-gtk) | `tests/fake/` | MIT |
| `ffmpeg/` | [riscos-ffmpeg](https://github.com/adyoull/riscos-ffmpeg) | `tests/host/` | GPL version 2 or later |
| `midisynth/` | [riscos-midisynth](https://github.com/adyoull/riscos-midisynth) | `tests/` | MIT |
| `matinee/` | [riscos-matinee](https://github.com/adyoull/riscos-matinee) | `tests/host/` | GPL version 2 or later |
| `reelhwaccel/` | [riscos-reelhwaccel](https://github.com/adyoull/riscos-reelhwaccel) | `tests/host/` | GPL version 2 |
| `ysflight/` | [riscos-ysflight](https://github.com/adyoull/riscos-ysflight) | `tests/` | BSD 3-clause (its `LICENSE`) |

- **`FILES`** lists what is copied: port, repository, the path prefix
  dropped here, and the path in the repository. To take another fake, or
  stop taking one, edit it.
- **`MANIFEST`** records, for each file here, its sha256, the repository,
  the commit it was copied at and its path there. It's generated: don't edit
  it.
- **`update.sh`** clones each repository's latest commit from GitHub, copies
  the files again and lists what changed (old commit → new commit). Review
  with `git diff fake/ports`, run `make check`, commit.
  `update.sh CHECKOUTS` does the same from checkouts you already have.
- **`check.sh`** (part of `make check`) fails if a file here no longer
  matches `MANIFEST`. Don't fix a fake here: fix it in its port, then run
  `update.sh`, so the two never drift apart. It also compiles the fakes
  that stand on their own.

## What each fakes

| Fake | What it stands in for | Used by (in its port) |
|---|---|---|
| `unixlib/host/fake/` (`riscos.c`, `swis.h`, `kernel.h`, `DRender.h`, `sys/soundcard.h`, `internal/`, `prelude.h`) | SharedSoundBuffer and StreamManager playing in simulated time, DigitalRenderer, OS_SWINumberFromString, the clock, `pthread_yield`, `getenv`; the few UnixLib internals `sound/dsp.c` uses | `tests/host/dsp` (/dev/dsp), `tests/host/midi` |
| `unixlib/host/ticker/fake/` | UnixLib's internal `<pthread.h>` and `os.h` for the pthread ticker: PThreadTicker module lookup, Wimp filters, OS_CallEvery | `tests/host/ticker` |
| `unixlib/host/{eventfd,getserv,heldwait,services}/fake/` | The UnixLib internals each of those files needs: fd table, thread-switching hold and `__pthread_held_wait`, the services database reader | `tests/host/eventfd`, `getserv`, `heldwait`, `services` |
| `unixlib/emu/` (`swi_stub.c`, `heap_stub.c`, `swi_test.py`, `heap_test.py`, `ticker_test.py`) | SWIs faked in Python for the real library code running in the Unicorn ARM emulator: OS_DynamicArea/ChangeDynamicArea (the heap), Territory and OS_GBPB (time, `read`), the PThreadTicker module and its RMA copy | `tests/emu` (needs a UnixLib build) |
| `mesa/egl/fake_riscos.c`, `.h`, `fake/` | A scripted Wimp task: Wimp_Initialise, Create/Open/Close/DeleteWindow, Poll/PollIdle with redraws, null events, keys, clicks, resizes, menus; Redraw/Update/GetRectangle; a 32bpp screen in memory; OS_SpriteOp create/plot; mode and VDU variables; screen banks; thread-safe | The EGL harness, dEQP-EGL, the SDL GL driver tests |
| `mesa/egl/portrun.c` | A runner that drives a whole ported program on the fake desktop from a script of events (`FRAMES`, `KEYS`, `PPM` pictures) | Ports' smoke tests on Linux |
| `mesa/ovl/fake_ovl.c`, `fake/` | The VideoOverlay module as the ROOL wiki describes it, checking the program keeps to the rules (mode selectors, IDs, mapping, buffers, cleanup) | `ovltest`, EGL overlays |
| `mesa/sdl-wimp/` | Wimp_Poll blocks fed to SDL's event code, with the SWIs and SDL events recorded: Message_PreQuit/Quit, the close icon, the icon bar menu, a fake keyboard (OS_Byte 121/129/196) with auto-repeat | SDL's Wimp event handling |
| `mesa/fake/` | The minimal `kernel.h`/`swis.h` for the SDL GL harness | — |
| `gtk/mesa-egl/` | riscos-mesa's fake desktop, extended for GTK: more Wimp (menus, messages, drags), pictures through cairo, AcornSSL over real sockets | riscos-gtk's programs on the fake desktop (`tests/gtk/*-fake.c`) |
| `gtk/sdl-wimp/` | As `mesa/sdl-wimp/`, the model for GTK's event source | — |
| `ffmpeg/fake_riscos.c`, `.h`, `fake/` | TaskWindow detection, the screen and mode variables, riscos-mesa's EGL calls (window surfaces kept as memory, the last frame kept for the test) | `libavdevice/riscos_egl.c` (`ffmpeg -f egl`) |
| `ffmpeg/fake_acornssl.c` | The AcornSSL module: handshake steps inside Recv/Send (ENOTCONN until done), FIONBIO, MSG_PEEK, SO_ACORNSSL_HOSTNAME, Close leaving a handed-over socket open; bytes pass through unencrypted | FFmpeg's AcornSSL TLS backend |
| `ffmpeg/fake_sdl_gl.c`, `.h` | SDL audio and the OpenGL calls ffegl uses, with a fake clock and a sound device that plays queued bytes in real time | `ffegl` |
| `ffmpeg/ffplay-kernel-stub.h` | Leaving a TaskWindow: OS_GetEnv, Wimp_StartTask (written to a file) | `ffplay-direct.sh` |
| `midisynth/fake_swi.c`, `.h`, `fake/` | SharedSoundBuffer, StreamManager and DigitalRenderer for MIDISynth's output: everything played is kept, and played only when the test says time has passed | `tests/test_output.c` |
| `matinee/fake_reelcore.c`, `.h`, `fake/` | riscos-ffmpeg's reelcore player library: a "video" that opens, moves with the fake Wimp's clock and gives a new picture every 4 cs | `tests/host/ui_test.c` |
| `matinee/fakeplex.py` | plex.tv and a Plex Media Server: fixed JSON answers, every request recorded, Range requests on a 5 MB part file, Plex Home users and PINs | Matinee's host tests |
| `reelhwaccel/fake_hevc.c`, `.h`, `ffmpeg/hevc_fake_env.c` | The Pi 4's HEVC decoder block (registers, the two phases, command lists, interrupts, memory), checking the commands and writing the picture FFmpeg decoded | `hevcdec`, FFmpeg's hevc hwaccel |
| `reelhwaccel/fake_vc.c`, `.h`, `mmaldecode_test.c` | The VCHIQ module and the MMAL H.264 video decoder as the Pi behaves (bulk transfers, format changes, the Pi's quirks: swallowed buffer 0, a disable that never answers) | `mmaldecode`, `vcdec`, FFmpeg's `h264_vchiq` |
| `ysflight/` | riscos-crossdev's own fake (`fake/` at the top of this repo) with the extra SWI numbers and a joystick `kernel.h` | YS Flight's window and joystick code |

## Fakes not copied

Some ports fake RISC OS inside a test file rather than in a file of its
own. They are part of that test, so they stay in the port; look there when
you need the same SWIs:

- riscos-unixlib `tests/host/midi/test_midi.c`: the MIDISynth and MIDI
  modules (Tx/Rx bytes, a full buffer, sharing between programs).
- riscos-unixlib `tests/host/ticker/test_ticker.c`: OS_CallEvery,
  OS_RemoveTickerEvent, Filter_* and OS_Module 18 for PThreadTicker.
- riscos-ffmpeg `tests/host/convert_test.c`, `reel_test.c`,
  `fffront_test.c`, `convert_cmds.c`: Wimp windows, drags and text
  (Wimp_PollIdle, Wimp_DragBox, Wimp_TextOp, Wimp_SetExtent) for !FFmpeg's
  front end and Reel.
- riscos-ffmpeg `tests/host/mesa/riscos_shim.c` and riscos-mesa
  `tests/host-harness/mesa/arm/shim.c`: SWI shims for Mesa built for ARM
  Linux under QEMU.
- riscos-matinee `tests/host/ui_test.c`: a Wimp desktop for Matinee's
  windows (Poll, windows, icons, menus, drags, messages, Wimp_StartTask).
- riscos-gtk `tests/gtk/*-fake.c`: programs driven on `gtk/mesa-egl`
  (these are tests, the fake itself is copied).
- riscos-ysflight `tests/host-joystick/test_joystick.cpp`: the joystick
  SWI (Joystick_Read).

Not on GitHub, so not copied (yet): riscos-ytdl (a fake YouTube and its
player script, `tests/host/fake_youtube.py`, `tests/data/fake_player.js`)
and riscos-mesa-v3d (`tests/host-*`: the V3D module's memory, display and
EGL calls).
