/* Test-only observation host. Original allocator body is included unchanged
   except the already declared align4 -> align8 LP64 adaptation. */
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include "r_local.h"
static byte *allocation, *arena;
static unsigned placement;
static void *external_owner;
byte *I_ZoneBase(int *size) {
    *size = 8192;
    allocation = calloc(1, *size + 8192);
    if (!allocation) abort();
    arena = allocation + placement;
    return arena;
}
void I_Error(char *fmt, ...) { (void)fmt; abort(); }
#include "zone.c"
static void pointer(const char *stage, memblock_t *b, const char *field,
                    void *p, const void *storage) {
    printf("{\"stage\":\"%s\",\"blockOffset\":%td,\"field\":\"%s\","
           "\"value\":\"0x%llx\",\"bytes\":\"", stage, (byte*)b-arena,
           field, (unsigned long long)(uintptr_t)p);
    for (unsigned i=0; i<8; ++i) printf("%02x", ((const byte*)storage)[i]);
    puts("\"}");
}
static void snapshot(const char *stage) {
    memblock_t *b = &mainzone->blocklist;
    do {
        pointer(stage,b,"next",b->next,&b->next);
        pointer(stage,b,"prev",b->prev,&b->prev);
        pointer(stage,b,"user",b->user,&b->user);
        b=b->next;
    } while(b!=&mainzone->blocklist);
    pointer(stage,&mainzone->blocklist,"rover",mainzone->rover,&mainzone->rover);
}
int main(int argc, char **argv) {
    _Static_assert(sizeof(void*)==8 && sizeof(memblock_t)==40,"LP64");
    _Static_assert(sizeof(memzone_t)==56 && _Alignof(memblock_t)==8,"align8");
    uint32_t endian=1; if(*(byte*)&endian!=1) return 2;
    placement=argc>1 ? (unsigned)atoi(argv[1]) : 0;
    if(placement>4096 || placement%8) return 3;
    Z_Init();
    printf("{\"base\":\"0x%llx\",\"allocationBase\":\"0x%llx\",\"placement\":%u}\n",
           (unsigned long long)(uintptr_t)arena,
           (unsigned long long)(uintptr_t)allocation,placement);
    snapshot("init");
    byte *a=Z_Malloc(17,PU_STATIC,NULL);
    byte *b=Z_Malloc(238,PU_CACHE,&external_owner);
    /* Owner-slot address inside the zone, rather than a global/stack slot. */
    void **inside_owner=Z_Malloc(sizeof(void*),PU_STATIC,NULL);
    Z_Malloc(340,PU_CACHE,inside_owner);
    snapshot("allocated");
    Z_Free(b); snapshot("free");
    Z_Free(a); snapshot("coalesced");
    Z_Malloc(7,PU_STATIC,NULL); snapshot("reuse");
    Z_ClearZone(mainzone); snapshot("clear");
    free(allocation); return 0;
}
