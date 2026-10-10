#pragma once
/* Host-only declarations for compiling the unchanged original translation units.
 * The patch/post layouts are identical to linuxdoom-1.10 r_defs.h. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <limits.h>
#define __I_SYSTEM__
#define __R_LOCAL__
#define __DOOMDEF__
#define __DOOMDATA__
#define __M_BBOX__
#define __M_SWAP__
#define __V_VIDEO__
#define SCREENWIDTH 320
#define SCREENHEIGHT 200
#define MININT INT_MIN
#define MAXINT INT_MAX
#define SHORT(x) (x)
#define LONG(x) (x)
typedef unsigned char byte;
typedef int fixed_t;
typedef struct { byte topdelta, length; } post_t;
typedef post_t column_t;
typedef struct {
    short width, height, leftoffset, topoffset;
    int columnofs[8];
} patch_t;
enum { BOXTOP, BOXBOTTOM, BOXLEFT, BOXRIGHT };
extern byte *screens[5];
extern int dirtybox[4];
extern byte gammatable[5][256];
extern int usegamma;
byte *I_AllocLow(int);
void I_Error(char *, ...);
void M_ClearBox(fixed_t *);
void M_AddToBox(fixed_t *, fixed_t, fixed_t);
void V_Init(void);
void V_MarkRect(int,int,int,int);
void V_CopyRect(int,int,int,int,int,int,int,int);
void V_DrawPatch(int,int,int,patch_t *);
void V_DrawPatchFlipped(int,int,int,patch_t *);
void V_DrawPatchDirect(int,int,int,patch_t *);
void V_DrawBlock(int,int,int,int,int,byte *);
void V_GetBlock(int,int,int,int,int,byte *);
