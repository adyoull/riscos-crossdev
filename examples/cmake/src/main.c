/* tally FILE [N]: the N (default 10) most frequent words in FILE.
   With zlib (the riscos-mesa devkit has it), FILE may be gzipped. */
#include <stdio.h>
#include <stdlib.h>
#include "tally.h"
#ifdef HAVE_ZLIB
#include <zlib.h>
#endif

int main (int argc, char **argv)
{
  char buf[4096];
  int n, len;
  size_t i, got;
  tally *t;
  tally_entry *top;
#ifdef HAVE_ZLIB
  gzFile f;
#else
  FILE *f;
#endif

  if (argc < 2 || argc > 3)
    {
      fprintf (stderr, "usage: tally FILE [N]\n");
      return 2;
    }
  n = argc == 3 ? atoi (argv[2]) : 10;
#ifdef HAVE_ZLIB
  f = gzopen (argv[1], "rb");             /* reads plain files too */
#else
  f = fopen (argv[1], "rb");
#endif
  if (!f || !(t = tally_new ()) || n < 1 || !(top = malloc (n * sizeof *top)))
    {
      perror (argv[1]);
      return 1;
    }
#ifdef HAVE_ZLIB
  while ((len = gzread (f, buf, sizeof buf)) > 0)
#else
  while ((len = (int) fread (buf, 1, sizeof buf, f)) > 0)
#endif
    if (tally_add (t, buf, (size_t) len))
      {
        fprintf (stderr, "tally: out of memory\n");
        return 1;
      }
  tally_end (t);
  printf ("%lu words, %lu different\n",
          (unsigned long) tally_words (t), (unsigned long) tally_distinct (t));
  got = tally_top (t, top, (size_t) n);
  for (i = 0; i < got; i++)
    printf ("%7u  %s\n", top[i].count, top[i].word);
  return 0;
}
