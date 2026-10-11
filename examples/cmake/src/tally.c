/* tally: see tally.h. A hash table of words, grown as it fills. */
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include "tally.h"

#define MAXWORD 64

struct tally
{
  struct slot { char *word; unsigned count; unsigned hash; } *slots;
  size_t size, used, words;
  char cur[MAXWORD];
  size_t curlen;
};

static unsigned hash (const char *s)
{
  unsigned h = 2166136261u;               /* FNV-1a */
  while (*s)
    h = (h ^ (unsigned char) *s++) * 16777619u;
  return h;
}

tally *tally_new (void)
{
  tally *t = calloc (1, sizeof *t);
  if (t && !(t->slots = calloc (t->size = 64, sizeof *t->slots)))
    {
      free (t);
      t = NULL;
    }
  return t;
}

void tally_free (tally *t)
{
  size_t i;
  if (!t)
    return;
  for (i = 0; i < t->size; i++)
    free (t->slots[i].word);
  free (t->slots);
  free (t);
}

static struct slot *find (struct slot *slots, size_t size, const char *w, unsigned h)
{
  size_t i = h & (size - 1);
  while (slots[i].word && (slots[i].hash != h || strcmp (slots[i].word, w) != 0))
    i = (i + 1) & (size - 1);
  return &slots[i];
}

static int grow (tally *t)
{
  size_t i, size = t->size * 2;
  struct slot *s = calloc (size, sizeof *s);
  if (!s)
    return -1;
  for (i = 0; i < t->size; i++)
    if (t->slots[i].word)
      *find (s, size, t->slots[i].word, t->slots[i].hash) = t->slots[i];
  free (t->slots);
  t->slots = s;
  t->size = size;
  return 0;
}

static int count (tally *t)
{
  unsigned h;
  struct slot *s;
  if (t->curlen == 0)
    return 0;
  t->cur[t->curlen] = 0;
  t->curlen = 0;
  h = hash (t->cur);
  s = find (t->slots, t->size, t->cur, h);
  if (!s->word)
    {
      if ((t->used + 1) * 4 > t->size * 3)
        {
          if (grow (t))
            return -1;
          s = find (t->slots, t->size, t->cur, h);
        }
      if (!(s->word = strdup (t->cur)))
        return -1;
      s->hash = h;
      t->used++;
    }
  s->count++;
  t->words++;
  return 0;
}

int tally_add (tally *t, const char *text, size_t len)
{
  size_t i;
  for (i = 0; i < len; i++)
    {
      unsigned char c = (unsigned char) text[i];
      if (isalnum (c) || c == '\'')
        {
          if (t->curlen < MAXWORD - 1)     /* longer words are cut short */
            t->cur[t->curlen++] = (char) tolower (c);
        }
      else if (count (t))
        return -1;
    }
  return 0;
}

void tally_end (tally *t)
{
  count (t);
}

size_t tally_words (const tally *t) { return t->words; }
size_t tally_distinct (const tally *t) { return t->used; }

static int order (const void *a, const void *b)
{
  const tally_entry *x = a, *y = b;
  if (x->count != y->count)
    return x->count > y->count ? -1 : 1;
  return strcmp (x->word, y->word);
}

size_t tally_top (const tally *t, tally_entry *out, size_t n)
{
  tally_entry *all = malloc ((t->used ? t->used : 1) * sizeof *all);
  size_t i, k = 0;
  if (!all)
    return 0;
  for (i = 0; i < t->size; i++)
    if (t->slots[i].word)
      {
        all[k].word = t->slots[i].word;
        all[k++].count = t->slots[i].count;
      }
  qsort (all, k, sizeof *all, order);
  if (n > k)
    n = k;
  memcpy (out, all, n * sizeof *out);
  free (all);
  return n;
}
