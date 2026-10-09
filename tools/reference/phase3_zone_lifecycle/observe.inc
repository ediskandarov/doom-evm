// SPDX-License-Identifier: GPL-2.0-only
// Appended to the adapted ORIGINAL z_zone.c TU: access original private mainzone type.
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
extern FILE *zone_events,*zone_stages,*zone_sprites;
extern int gametic,numlumps,numtextures,firstspritelump,numspritelumps;
extern void **lumpcache;
extern byte **texturecomposite;
static unsigned char zone_id_known[67108864/8],zone_tag_known[67108864/8];
static unsigned long zone_sequence,zone_mallocs,zone_frees,zone_tags,zone_purges;
static long zone_live,zone_peak;
static int zone_depth;
static const char *zone_phase="initial";
int ZoneOffset(void *p) {return p ? (int)((uintptr_t)p-(uintptr_t)mainzone):-1;}
static int known(memblock_t *b){return zone_id_known[ZoneOffset(b)/8];}
static int owner(void *user) {
    if(!user || (uintptr_t)user<=0x100) return -1;
    uintptr_t a=(uintptr_t)user,l=(uintptr_t)lumpcache;
    if(lumpcache && a>=l && a<l+(uintptr_t)numlumps*sizeof(void*))return (int)((a-l)/sizeof(void*));
    uintptr_t t=(uintptr_t)texturecomposite;
    if(texturecomposite && a>=t && a<t+(uintptr_t)numtextures*sizeof(void*))return numlumps+(int)((a-t)/sizeof(void*));
    I_Error("Unknown zone owner namespace");return -2;
}
void ZoneFragmentObserved(void *p) {int i=ZoneOffset(p)/8;zone_id_known[i]=0;zone_tag_known[i]=1;}
void ZoneFreedObserved(void *p) {int i=ZoneOffset(p)/8;zone_id_known[i]=1;zone_tag_known[i]=1;}
static void blockrow(FILE *f,memblock_t *b) {
    int offset=ZoneOffset(b),allocated=b->user!=NULL,ik=known(b),tk=zone_tag_known[offset/8];
    fprintf(f,"{\"offset\":%d,\"size\":%d,\"allocated\":%d,\"owner\":%d,\"tagKnown\":%d,\"tag\":",offset,b->size,allocated,owner(b->user),tk);
    if(tk)fprintf(f,"%d",b->tag);else fputs("null",f);
    fprintf(f,",\"idKnown\":%d,\"id\":",ik);if(ik)fprintf(f,"%d",b->id);else fputs("null",f);
    fprintf(f,",\"prev\":%d,\"next\":%d}",ZoneOffset(b->prev),ZoneOffset(b->next));
}
static void eventprefix(const char *op,const char *file,const char *caller,int line) {
    fprintf(zone_events,"{\"sequence\":%lu,\"tic\":%d,\"phase\":\"%s\",\"op\":\"%s\",\"outer\":%d,\"file\":\"%s\",\"caller\":\"%s\",\"line\":%d",++zone_sequence,gametic,zone_phase,op,zone_depth==1,file,caller,line);
}
void *ZoneMallocObserved(const char *file,const char *caller,int line,int request,int tag,void *user) {
    ++zone_depth;int key=owner(user);void *p=Z_Malloc(request,tag,user);memblock_t *b=(memblock_t*)((byte*)p-sizeof(memblock_t));
    zone_id_known[ZoneOffset(b)/8]=1;zone_tag_known[ZoneOffset(b)/8]=1;++zone_mallocs;zone_live+=b->size;if(zone_live>zone_peak)zone_peak=zone_live;
    eventprefix("malloc",file,caller,line);fprintf(zone_events,",\"request\":%d,\"requestedTag\":%d,\"owner\":%d,\"header\":%d,\"size\":%d,\"rover\":%d,\"block\":",request,tag,key,ZoneOffset(b),b->size,ZoneOffset(mainzone->rover));blockrow(zone_events,b);fputs("}\n",zone_events);--zone_depth;return p;
}
void ZoneFreeObserved(const char *file,const char *caller,int line,void *p) {
    ++zone_depth;memblock_t *b=(memblock_t*)((byte*)p-sizeof(memblock_t));int off=ZoneOffset(b),size=b->size,key=owner(b->user);
    ++zone_frees;if(!strcmp(caller,"Z_Malloc"))++zone_purges;zone_live-=size;
    Z_Free(p);memblock_t *survivor=mainzone->blocklist.next;
    while(survivor!=&mainzone->blocklist && !(ZoneOffset(survivor)<=off && off<ZoneOffset(survivor)+survivor->size))survivor=survivor->next;
    if(survivor==&mainzone->blocklist)I_Error("Freed block not in zone");
    eventprefix("free",file,caller,line);fprintf(zone_events,",\"request\":0,\"requestedTag\":0,\"owner\":%d,\"header\":%d,\"size\":%d,\"rover\":%d,\"survivor\":",key,off,size,ZoneOffset(mainzone->rover));blockrow(zone_events,survivor);fputs("}\n",zone_events);--zone_depth;
}
void ZoneTagObserved(const char *file,const char *caller,int line,void *p,int tag) {
    ++zone_depth;memblock_t *b=(memblock_t*)((byte*)p-sizeof(memblock_t));int old=b->tag;if(b->id!=ZONEID)I_Error("Z_CT at %s:%i",file,line);Z_ChangeTag2(p,tag);zone_tag_known[ZoneOffset(b)/8]=1;++zone_tags;
    eventprefix("tag",file,caller,line);fprintf(zone_events,",\"request\":0,\"requestedTag\":%d,\"oldTag\":%d,\"owner\":%d,\"header\":%d,\"size\":%d,\"rover\":%d}\n",tag,old,owner(b->user),ZoneOffset(b),b->size,ZoneOffset(mainzone->rover));--zone_depth;
}
void ZoneTagsObserved(const char *file,const char *caller,int line,int low,int high) {
    ++zone_depth;eventprefix("freeTagsBegin",file,caller,line);fprintf(zone_events,",\"low\":%d,\"high\":%d,\"rover\":%d}\n",low,high,ZoneOffset(mainzone->rover));
    Z_FreeTags(low,high);eventprefix("freeTagsEnd",file,caller,line);fprintf(zone_events,",\"low\":%d,\"high\":%d,\"rover\":%d}\n",low,high,ZoneOffset(mainzone->rover));--zone_depth;
}
void ZoneStage(const char *name) {
    fprintf(zone_stages,"{\"stage\":\"%s\",\"tic\":%d,\"eventCount\":%lu,\"byteLength\":%d,\"zoneBytes\":%zu,\"headerBytes\":%zu,\"rover\":%d,\"capPrev\":%d,\"capNext\":%d,\"liveBytes\":%ld,\"peakLiveBytes\":%ld,\"mallocs\":%lu,\"frees\":%lu,\"tags\":%lu,\"purges\":%lu,\"blocks\":[",name,gametic,zone_sequence,mainzone->size,sizeof(memzone_t),sizeof(memblock_t),ZoneOffset(mainzone->rover),ZoneOffset(mainzone->blocklist.prev),ZoneOffset(mainzone->blocklist.next),zone_live,zone_peak,zone_mallocs,zone_frees,zone_tags,zone_purges);
    int comma=0;for(memblock_t *b=mainzone->blocklist.next;b!=&mainzone->blocklist;b=b->next){if(comma++)fputc(',',zone_stages);blockrow(zone_stages,b);}fputs("],\"owners\":[",zone_stages);
    for(int i=0;i<numlumps+numtextures;i++){if(i)fputc(',',zone_stages);void *p=i<numlumps?lumpcache[i]:texturecomposite[i-numlumps];fprintf(zone_stages,"%d",ZoneOffset(p));}fputs("]}\n",zone_stages);
    fprintf(zone_sprites,"{\"stage\":\"%s\",\"tic\":%d,\"sprites\":[",name,gametic);comma=0;
    for(int i=0;i<numspritelumps;i++) {int lump=firstspritelump+i;if(!lumpcache[lump])continue;memblock_t *b=(memblock_t*)((byte*)lumpcache[lump]-sizeof(memblock_t));memblock_t *n=b->next;if(comma++)fputc(',',zone_sprites);fprintf(zone_sprites,"{\"lump\":%d,\"header\":%d,\"payload\":%d,\"blockSize\":%d,\"next\":",lump,ZoneOffset(b),ZoneOffset(lumpcache[lump]),b->size);if(n==&mainzone->blocklist)fputs("null",zone_sprites);else blockrow(zone_sprites,n);fputc('}',zone_sprites);}fputs("]}\n",zone_sprites);
    zone_phase=name;
}
