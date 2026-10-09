/* SPDX-License-Identifier: GPL-2.0-only. Native clip ABI and observation callbacks. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
_Static_assert(sizeof(int)==4,"DOOM int ABI");
typedef struct { int first,last; } cliprange_t;
#define MAXSEGS 32
static cliprange_t solidsegs[MAXSEGS];
static cliprange_t *newend;
static int viewwidth;
static void R_StoreWallRange(int start,int stop){printf(" %d %d",start,stop);}
