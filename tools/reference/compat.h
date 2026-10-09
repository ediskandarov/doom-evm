/* GPL-2.0-only. Standalone ABI/host shim, not a renderer implementation. */
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>
#include <float.h>
#include <setjmp.h>
#include <math.h>
#include "tables.h"
_Static_assert(sizeof(int)==4 && sizeof(unsigned)==4 && sizeof(long long)==8,"DOOM integer ABI");
_Static_assert(sizeof(double)==8 && DBL_MANT_DIG==53 && DBL_MAX_EXP==1024 && FLT_RADIX==2,"IEEE binary64");
_Static_assert((-1 >> 1)==-1,"arithmetic right shift");
#define MININT INT_MIN
#define MAXINT INT_MAX
#define NF_SUBSECTOR 0x8000
/* Only fields read by extracted functions. No binary struct serialization. */
typedef struct { fixed_t x,y,dx,dy; unsigned short children[2]; } node_t;
typedef struct { int unused; } subsector_t;
static fixed_t viewx,viewy;
static node_t *nodes;
static subsector_t *subsectors;
static int numnodes;
static int trace[32769], trace_count;
static jmp_buf failure;
static void I_Error(const char *message, ...) { (void)message; longjmp(failure,1); }
