/* GPL-2.0-only. Host ABI definitions for mechanically extracted original functions. */
#include "../compat.h"
#define SCREENWIDTH 320
#define SCREENHEIGHT 200
#define SBARHEIGHT 32
#define LIGHTLEVELS 16
#define MAXLIGHTSCALE 48
#define MAXLIGHTZ 128
#define NUMCOLORMAPS 32
#define LIGHTZSHIFT 20
#define LIGHTSCALESHIFT 12
#define FIELDOFVIEW 2048
#define DISTMAP 2
#define false 0
static int scaledviewwidth,viewwidth,viewheight,centerx,centery,detailshift;
static fixed_t centerxfrac,centeryfrac,projection,viewz,viewsin,viewcos;
static angle_t viewangle,clipangle;
static int viewangleoffset,extralight,framecount,validcount,sscount;
static int viewangletox[4096];
static angle_t xtoviewangle[321];
static fixed_t yslope[200],distscale[320],pspritescale,pspriteiscale;
static short screenheightarray[320];
typedef unsigned char lighttable_t;
static lighttable_t colormaps[34*256];
static lighttable_t *scalelight[16][48], *zlight[16][128], *scalelightfixed[48],*fixedcolormap,**walllights;
fixed_t *finecosine = finesine+2048;
static angle_t rw_normalangle;
static fixed_t rw_distance;
static int setsizeneeded,setblocks,setdetail;
static unsigned char framebuffer[64000], *screens[1]={framebuffer}, *ylookup[200];
static int columnofs[320],viewwindowx,viewwindowy;
static void noop(void){}
#define R_DrawColumn noop
#define R_DrawFuzzColumn noop
#define R_DrawTranslatedColumn noop
#define R_DrawSpan noop
#define R_DrawColumnLow noop
#define R_DrawSpanLow noop
static void (*colfunc)(void),(*basecolfunc)(void),(*fuzzcolfunc)(void),(*transcolfunc)(void),(*spanfunc)(void);
typedef struct { fixed_t x,y; } vertex_t;
typedef struct { vertex_t *v1,*v2; } seg_t;
typedef struct { fixed_t x,y; angle_t angle; } mobj_t;
typedef struct { mobj_t *mo; int extralight; fixed_t viewz; int fixedcolormap; } player_t;
static player_t *viewplayer;
