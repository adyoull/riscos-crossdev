/* tally: count the words in some text. Portable C (no SWIs), so it is
   tested on Linux as ARM code under qemu-arm-aligntrap, and as host code. */
#ifndef TALLY_H
#define TALLY_H
#include <stddef.h>

typedef struct tally tally;
typedef struct { const char *word; unsigned count; } tally_entry;

tally *tally_new (void);
void tally_free (tally *t);
/* Count the words in text (letters, digits and apostrophes; case ignored).
   Can be called many times, with text split anywhere: a word cut in two by
   the split is counted once. */
int tally_add (tally *t, const char *text, size_t len);
/* Finish a word left open by the last tally_add. */
void tally_end (tally *t);
size_t tally_words (const tally *t);     /* all words */
size_t tally_distinct (const tally *t);  /* different words */
/* The n most frequent words, most first (ties in alphabetical order).
   Returns how many were written to out. */
size_t tally_top (const tally *t, tally_entry *out, size_t n);
#endif
