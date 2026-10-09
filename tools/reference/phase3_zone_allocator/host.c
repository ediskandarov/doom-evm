#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <stdio.h>
#include "z_zone.h"
static void* owners[16];
static uint32_t known_offsets[8192];
static unsigned char known[8192];
static size_t known_count;
static int heap_bytes;
static unsigned char* backing;
static void note(void* address,int is_known);
#include "zone_generated.c"
_Static_assert(sizeof(memblock_t)==40,"pinned LP64 memblock");
_Static_assert(sizeof(memzone_t)==56,"pinned LP64 memzone");
_Static_assert(_Alignof(memblock_t)==8,"pinned pointer alignment");
_Static_assert(offsetof(memblock_t,id)==20,"pinned ID offset");
_Static_assert(offsetof(memzone_t,blocklist)==8,"pinned sentinel offset");
static void note(void* address,int is_known) {
 uint32_t off=(uint32_t)((unsigned char*)address-backing);
 for(size_t i=0;i<known_count;i++)if(known_offsets[i]==off){known[i]=(unsigned char)is_known;return;}
 if(known_count==8192)abort();known_offsets[known_count]=off;known[known_count++]=(unsigned char)is_known;
}
static int id_known(memblock_t* b){uint32_t off=(uint32_t)((unsigned char*)b-backing);for(size_t i=0;i<known_count;i++)if(known_offsets[i]==off)return known[i];return 0;}
byte* I_ZoneBase(int* bytes){*bytes=heap_bytes;backing=calloc(1,(size_t)heap_bytes);if(!backing)abort();return backing;}
void I_Error(char* error,...){va_list v;va_start(v,error);vfprintf(stderr,error,v);va_end(v);exit(42);}
static uint32_t offset(void* p){return p?(uint32_t)((unsigned char*)p-backing):UINT32_MAX;}
static uint32_t owner(memblock_t* b){for(uint32_t i=0;i<16;i++)if(b->user==&owners[i])return i;return UINT32_MAX;}
static void word(uint32_t n){putchar((n>>24)&255);putchar((n>>16)&255);putchar((n>>8)&255);putchar(n&255);}
static void snapshot(void){
 Z_CheckHeap();word((uint32_t)mainzone->size);word(offset(mainzone->rover));word(offset(mainzone->blocklist.prev));word(offset(mainzone->blocklist.next));word((uint32_t)Z_FreeMemory());
 uint32_t count=0;for(memblock_t* b=mainzone->blocklist.next;b!=&mainzone->blocklist;b=b->next)count++;word(count);
 for(memblock_t* b=mainzone->blocklist.next;b!=&mainzone->blocklist;b=b->next){word(offset(b));word((uint32_t)b->size);word(b->user!=NULL);word(owner(b));word((uint32_t)b->tag);word(id_known(b));word(id_known(b)?(uint32_t)b->id:0);word(offset(b->prev));word(offset(b->next));}
 for(size_t i=0;i<16;i++)word(offset(owners[i]));
}
int main(void){int op,a,b,c;while(scanf("%d %d %d %d",&op,&a,&b,&c)==4){
 if(op==0){free(backing);heap_bytes=a;memset(owners,0,sizeof(owners));known_count=0;Z_Init();}
 else if(op==1)Z_Malloc(a,b,c<0?NULL:&owners[c]);
 else if(op==2)Z_Free(owners[a]);
 else if(op==3)Z_FreeTags(a,b);
 else if(op==4)Z_ChangeTag2(owners[a],b);
 else if(op==5)Z_ClearZone(mainzone);
 else if(op==6)Z_CheckHeap();
 else if(op==7)Z_Free(backing+a+sizeof(memblock_t));
 else if(op==8)Z_ChangeTag2(backing+a+sizeof(memblock_t),b);
 else if(op==9){mainzone->blocklist.next->next->prev=&mainzone->blocklist;Z_CheckHeap();}
 else abort();
 snapshot();
 }free(backing);return 0;}
