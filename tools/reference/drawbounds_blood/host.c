// SPDX-License-Identifier: GPL-2.0-only
// Actual unchanged draw bodies and pinned allocator, under declared heap seeds.
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <stdio.h>
#include "r_local.h"
static unsigned char *backing;
static int seed;
byte *I_ZoneBase(int *size) {
    *size=8192;
    backing=malloc((size_t)*size);
    if(!backing) abort();
    memset(backing,seed,(size_t)*size); // Explicit tested platform initialization.
    return backing;
}
void I_Error(char *error,...) { va_list v;va_start(v,error);vfprintf(stderr,error,v);va_end(v);exit(42); }
#include "zone_generated.c"
int dc_x,dc_yl,dc_yh,centery;
fixed_t dc_iscale,dc_texturemid;
byte *dc_source;
lighttable_t *dc_colormap;
byte *ylookup[200];
int columnofs[320];
short *mfloorclip,*mceilingclip;
fixed_t spryscale,sprtopscreen;
void (*colfunc)(void);
#include "draw_generated.c"
#include "masked_generated.c"
int main(int argc,char **argv) {
    if(argc!=4) abort();seed=(int)strtoul(argv[3],NULL,0);
    FILE *f=fopen(argv[1],"rb");if(!f) abort();
    Z_Init();void *owner1=NULL,*owner2=NULL;
    byte *source=Z_Malloc(324,PU_CACHE,&owner1);
    if(fread(source,1,324,f)!=324) abort();fclose(f);
    (void)Z_Malloc(196,PU_CACHE,&owner2);
    memblock_t *next=((memblock_t *)(source-sizeof(memblock_t)))->next;
    _Static_assert(sizeof(memblock_t)==40,"accepted LP64 layout");
    _Static_assert(offsetof(memblock_t,user)==8,"header gap4..7");
    int before=((byte *)next)[4];
    byte maps[256],screen[64000];memset(screen,0,sizeof(screen));
    f=fopen(argv[2],"rb");if(!f||fread(maps,1,256,f)!=256) abort();fclose(f);
    for(int y=0;y<200;y++) ylookup[y]=screen+y*320;
    for(int x=0;x<320;x++) columnofs[x]=x;
    short floor[320],ceiling[320];for(int x=0;x<320;x++){floor[x]=200;ceiling[x]=-1;}
    mfloorclip=floor;mceilingclip=ceiling;
    dc_x=123;centery=100;dc_iscale=9472;dc_texturemid=-542247;dc_colormap=maps;
    spryscale=453406;sprtopscreen=10305097;colfunc=R_DrawColumn;
    R_DrawMaskedColumn((column_t *)(source+202));
    printf("{\"seed\":%d,\"paddingBefore\":%d,\"paddingAfter\":%d,\"firstPixel\":%d,\"expectedPixel\":%d,\"relativePhysicalAddress\":%td}\n",seed,before,((byte *)next)[4],screen[178*320+123],maps[seed],(byte *)next+4-source);
    free(backing);return 0;
}
