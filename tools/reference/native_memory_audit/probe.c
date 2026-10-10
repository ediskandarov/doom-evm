/* Test-only byte observations. Original function bodies are extracted by run.py. */
#include <stdint.h>
#include <stddef.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include "r_local.h"
static byte *arena;
static const char *policy;
static void *global_owner;
byte *I_ZoneBase(int *size) {
    *size=8192;
    arena=!strcmp(policy,"calloc") ? calloc(1,*size) : malloc(*size);
    if (!arena) abort();
    if (!strcmp(policy,"a5")) memset(arena,0xa5,*size);
    if (!strcmp(policy,"malloc-zero")) memset(arena,0,*size);
    return arena;
}
void I_Error(char *fmt,...) { (void)fmt; abort(); }
#include "zone.c"
int dc_x,dc_yl,dc_yh,centery;
fixed_t dc_iscale,dc_texturemid;
byte *dc_source;lighttable_t *dc_colormap;byte *ylookup[200];int columnofs[320];
#include "draw.c"
#include "cache.c"
static void hex(const byte *p,size_t n) { putchar('"');for(size_t i=0;i<n;i++)printf("%02x",p[i]);putchar('"'); }
static void snapshot(const char *name) {
    printf("{\"kind\":\"zone\",\"stage\":\"%s\",\"base\":\"%p\",\"rover\":%td,\"blocks\":[",name,(void*)arena,(byte*)mainzone->rover-arena);
    int first=1;
    for(memblock_t *b=mainzone->blocklist.next;b!=&mainzone->blocklist;b=b->next) {
        if(!first)putchar(',');first=0;
        printf("{\"offset\":%td,\"size\":%d,\"allocated\":%s,\"user\":\"%p\",\"next\":\"%p\",\"prev\":\"%p\",\"allPointersBelow2Pow48\":%s,\"header\":",(byte*)b-arena,b->size,b->user?"true":"false",(void*)b->user,(void*)b->next,(void*)b->prev,(((uintptr_t)b->user|(uintptr_t)b->next|(uintptr_t)b->prev)>>48)?"false":"true");
        hex((byte*)b,sizeof(*b));putchar('}');
    }
    printf("],\"first256Bytes\":");hex(arena,256);puts("}");
}
static unsigned sample(byte *p,unsigned n) {
    byte screen[64000]={0},map[256];for(int i=0;i<256;i++)map[i]=(byte)i;
    for(int y=0;y<200;y++)ylookup[y]=screen+320*y;
    for(int x=0;x<320;x++)columnofs[x]=x;
    dc_x=287;dc_yl=dc_yh=139;centery=84;dc_iscale=9472;
    dc_texturemid=-33-(139-84)*dc_iscale;dc_source=p+n-127;dc_colormap=map;
    R_DrawColumn();return screen[139*320+287];
}
int main(int argc,char **argv) {
    policy=argc>1?argv[1]:"calloc";
    uint32_t endian=1;
    printf("{\"kind\":\"layout\",\"int\":%zu,\"long\":%zu,\"pointer\":%zu,\"boolean\":%zu,\"plainCharSigned\":%s,\"littleEndian\":%s,\"memblock\":%zu,\"memblockAlign\":%zu,\"memzone\":%zu,\"offsets\":[%zu,%zu,%zu,%zu,%zu,%zu],\"policy\":\"%s\"}\n",sizeof(int),sizeof(long),sizeof(void*),sizeof(boolean),(char)255<0?"true":"false",*(byte*)&endian?"true":"false",sizeof(memblock_t),_Alignof(memblock_t),sizeof(memzone_t),offsetof(memblock_t,size),offsetof(memblock_t,user),offsetof(memblock_t,tag),offsetof(memblock_t,id),offsetof(memblock_t,next),offsetof(memblock_t,prev),policy);
    Z_Init();snapshot("init");
    void *owners[3]={0};byte *a=Z_Malloc(1,PU_STATIC,&owners[0]);a[0]=0x11;
    byte *b=Z_Malloc(17,PU_CACHE,&global_owner);memset(b,0x22,17);
    byte *c=Z_Malloc(64,PU_STATIC,NULL);memset(c,0x33,64);
    snapshot("alloc1-17-64");Z_Free(b);snapshot("free17");Z_Free(a);snapshot("coalesce1-17");
    Z_ClearZone(mainzone);snapshot("clear");
    a=Z_Malloc(7,PU_STATIC,NULL);memset(a,0x44,7);snapshot("reuse7");free(arena);
    Z_Init();a=Z_Malloc(512,PU_CACHE,&owners[1]);memset(a,0xa5,512);
    b=Z_Malloc(4096,PU_CACHE,&owners[2]);for(int i=0;i<4096;i++)b[i]=(byte)(i*13+7);
    snapshot("episode512-4096");
    printf("{\"kind\":\"draw\",\"headerByte527\":%u,\"payloadByte559\":%u,\"pixel527\":%u,\"pixel559\":%u,\"tail64\":",arena[(a-arena)+527],arena[(a-arena)+559],sample(a,527),sample(a,559));hex(arena+(a-arena)+512,64);puts("}");
    free(arena);
    /* Original cache copy: negative origin intentionally does not advance source;
       later post overwrites earlier bytes. Unwritten holes retain their input. */
    byte posts[]={0,4,0,10,11,12,13,0,2,3,0,20,21,22,0,255};
    for(int fill=0;fill<2;fill++) {byte cache[16];memset(cache,fill?0xa5:0,16);R_DrawColumnInCache((column_t*)posts,cache,-1,16);printf("{\"kind\":\"composite\",\"initialFill\":%u,\"bytes\":",fill?165:0);hex(cache,16);puts("}");}
    return 0;
}
