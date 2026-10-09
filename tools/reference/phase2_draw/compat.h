/* Host types/globals for mechanically extracted original r_draw.c bodies. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
typedef unsigned char byte;
typedef byte lighttable_t;
typedef int32_t fixed_t;
#define SCREENWIDTH 320
#define SCREENHEIGHT 200
#define SBARHEIGHT 32
#define FRACBITS 16
#define FUZZTABLE 50
#define FUZZOFF 320
#define PU_STATIC 1
static byte screen0[64000], screen1[64000], source[8192], colors[34*256];
static byte *screens[2] = {screen0,screen1};
static byte *ylookup[832];
static int columnofs[1120], viewheight, viewwindowx, viewwindowy, centery;
static int dc_x, dc_yl, dc_yh, ds_y, ds_x1, ds_x2, fuzzpos;
static fixed_t dc_iscale, dc_texturemid, ds_xfrac, ds_yfrac, ds_xstep, ds_ystep;
static byte *dc_source,*dc_colormap,*dc_translation,*translationtables,*ds_source,*ds_colormap;
static byte *colormaps=colors;
static void *Z_Malloc(int n,int tag,void *user) { (void)tag; (void)user; return malloc(n); }
static void I_Error(const char *msg, ...) { fprintf(stderr,"%s\n",msg); exit(2); }
