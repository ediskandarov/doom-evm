/* macOS replacement for obsolete libc header. */
#include <limits.h>
#ifndef MININT
#define MININT INT_MIN
#endif
#ifndef MAXINT
#define MAXINT INT_MAX
#endif
