#pragma once
#include "../video/compat.h"
#undef MININT
#undef MAXINT
#define TICRATE 35
#include "../../../original/DOOM/linuxdoom-1.10/doomtype.h"
#define __R_DEFS__
#define __R_DRAW__
#define KEY_BACKSPACE 127
#define KEY_ENTER 13
extern int viewwindowx, viewwindowy, viewwidth, viewheight;
void R_VideoErase(unsigned ofs, int count);
