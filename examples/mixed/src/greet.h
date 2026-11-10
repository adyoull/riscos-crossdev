#ifndef GREET_H
#define GREET_H
char *greet(const char *who);           /* in libgreet.so; free() the result */
int greet_hook(int n);                  /* in the program; libgreet calls it */
#endif
