/* tally's library, as ARM code under qemu-arm-aligntrap (ctest in a build
   made with cmake/linux-arm-aligntrap.cmake), or as host code. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tally.h"

static int fails, checks;
#define CHECK(c, what) do { checks++; if (!(c)) { fails++; fprintf (stderr, "FAIL %d: %s\n", __LINE__, what); } } while (0)

int main (void)
{
  tally_entry top[4];
  tally *t = tally_new ();
  const char *text = "The cat and the hat. THE END, and that's that";
  char big[64 * 1024];
  size_t i;

  /* Split anywhere, a word is still counted once. */
  tally_add (t, text, 10);
  tally_add (t, text + 10, strlen (text) - 10);
  tally_end (t);
  CHECK (tally_words (t) == 10, "10 words");
  CHECK (tally_distinct (t) == 7, "7 different");
  CHECK (tally_top (t, top, 4) == 4, "a top 4");
  CHECK (strcmp (top[0].word, "the") == 0 && top[0].count == 3, "\"the\" 3 times, case ignored");
  CHECK (strcmp (top[1].word, "and") == 0 && top[1].count == 2, "then \"and\" (ties alphabetical)");
  CHECK (strcmp (top[2].word, "cat") == 0, "then \"cat\"");
  tally_free (t);

  /* Enough different words to make the table grow several times. */
  t = tally_new ();
  for (i = 0; i < 5000; i++)
    {
      char w[16];
      int n = sprintf (w, "w%lu ", (unsigned long) (i % 1000));
      tally_add (t, w, (size_t) n);
    }
  CHECK (tally_distinct (t) == 1000 && tally_words (t) == 5000, "1000 words, 5 times each");
  tally_free (t);

  /* A long run of text with no word breaks: cut at 63 characters. */
  t = tally_new ();
  memset (big, 'a', sizeof big);
  tally_add (t, big, sizeof big);
  tally_end (t);
  CHECK (tally_words (t) == 1 && tally_top (t, top, 1) == 1 && strlen (top[0].word) == 63,
         "a very long word is one word, cut short");
  tally_free (t);

  t = tally_new ();
  CHECK (tally_top (t, top, 4) == 0, "nothing counted, no top");
  tally_free (t);

  printf ("tally: %d checks, %d failed\n", checks, fails);
  return fails != 0;
}
