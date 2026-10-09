/* GPL-2.0-only. Standalone original-C globals and resource-pointer adapters. */
#include "../compat.h"
#include <stddef.h>
#define SCREENWIDTH 320
#define SCREENHEIGHT 200
#define MAXVISPLANES 128
#define LIGHTZSHIFT 20
#define LIGHTSEGSHIFT 4
#define LIGHTLEVELS 16
#define MAXLIGHTZ 128
#define ANGLETOSKYSHIFT 22
#define PU_STATIC 1
#define PU_CACHE 101
typedef unsigned char byte;
typedef byte lighttable_t;
typedef struct {fixed_t height;int picnum,lightlevel,minx,maxx;byte pad1,top[320],pad2,pad3,bottom[320],pad4;} visplane_t;
static visplane_t visplanes[128],*lastvisplane;
static short floorclip[320],ceilingclip[320],openings[320*64],*lastopening;
static int spanstart[200],viewwidth,viewheight,detailshift,centery,extralight;
static int skyflatnum=99,skytexture=0,skytexturemid=100*65536,firstflat,flattranslation[2]={1,0};
static fixed_t planeheight,yslope[200],distscale[320],basexscale,baseyscale,centerxfrac,viewz,pspriteiscale;
static fixed_t cachedheight[200],cacheddistance[200],cachedxstep[200],cachedystep[200];
static angle_t viewangle,xtoviewangle[321];
fixed_t *finecosine=finesine+2048;
static byte colormaps[34*256],*fixedcolormap,**planezlight,*zlight[16][128];
static int ds_y,ds_x1,ds_x2,dc_x,dc_yl,dc_yh;
static fixed_t ds_xfrac,ds_yfrac,ds_xstep,ds_ystep,dc_iscale,dc_texturemid;
static byte *ds_source,*ds_colormap,*dc_source,*dc_colormap;
static byte framebuffer[64000],*ylookup[200];static int columnofs[320];
static byte flats[2][4096],sky[128][128];
static void (*spanfunc)(void),(*colfunc)(void);
static byte *W_CacheLumpNum(int lump,int tag){(void)tag;return flats[lump];}
static void Z_ChangeTag(void *ptr,int tag){(void)ptr;(void)tag;}
static byte *R_GetColumn(int texture,int column){if(texture!=0)abort();return sky[column&127];}
fixed_t FixedMul(fixed_t a,fixed_t b);fixed_t FixedDiv(fixed_t a,fixed_t b);fixed_t FixedDiv2(fixed_t a,fixed_t b);
