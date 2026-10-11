/* Observation host only; includes unchanged original allocator with the declared LP64 align8 adaptation. */
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include "r_local.h"
static byte *arena;
byte *I_ZoneBase(int *size) { *size=8192; return arena=calloc(1,*size); }
void I_Error(char *fmt,...) { va_list ap;va_start(ap,fmt);vfprintf(stderr,fmt,ap);va_end(ap);abort(); }
#include "zone.c"
static void sample(const char *stage,void **cache,int k,void *payload) {
 memblock_t *b=(memblock_t*)((byte*)payload-sizeof(memblock_t));
 if(b->user!=&cache[k] || cache[k]!=payload || b->id!=ZONEID)abort();
 printf("{\"stage\":\"%s\",\"index\":%d,\"stride\":%zu,\"relative\":%td,\"headerOffset\":%td,\"slot\":\"0x%llx\",\"payload\":\"0x%llx\",\"bytes\":\"",stage,k,sizeof(*cache),(byte*)&cache[k]-(byte*)cache,(byte*)b-arena,(unsigned long long)(uintptr_t)b->user,(unsigned long long)(uintptr_t)cache[k]);
 for(unsigned i=0;i<8;i++)printf("%02x",((byte*)&b->user)[i]);puts("\"}");
}
int main(void) {
 setbuf(stdout,NULL);
 _Static_assert(sizeof(void*)==8 && sizeof(memblock_t)==40,"LP64");
 uint32_t endian=1;if(*(byte*)&endian!=1)abort();
 void **cache=calloc(8,sizeof(*cache));Z_Init();
 void *a=Z_Malloc(128,PU_STATIC,&cache[3]);sample("allocate",cache,3,a);
 Z_ChangeTag(a,PU_CACHE);sample("cache-hit-retag",cache,3,a);
 Z_Free(a);if(cache[3]!=NULL)abort();
 Z_Malloc(128,PU_STATIC,NULL); /* consume the old block */
 void *b=Z_Malloc(128,PU_CACHE,&cache[3]);sample("recache-different-block",cache,3,b);if(b==a)abort();
 Z_FreeTags(PU_CACHE,PU_CACHE);if(cache[3]!=NULL)abort();
 void *c=Z_Malloc(128,PU_CACHE,&cache[3]);sample("after-tag-purge",cache,3,c);
 Z_Free(c);if(cache[3]!=NULL)abort();
 void *d=Z_Malloc(7000,PU_CACHE,&cache[6]);sample("before-allocation-purge",cache,6,d);
 Z_Malloc(100,PU_CACHE,&cache[7]); /* keep a distinct start block in the original scan */
 Z_Malloc(6000,PU_STATIC,NULL);if(cache[6]!=NULL)abort();
 puts("{\"freeClears\":true,\"tagPurgeClears\":true,\"allocationPurgeClears\":true}");
 free(cache);free(arena);return 0;
}
