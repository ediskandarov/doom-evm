#define main zone_sequence_main
#include "../phase3_zone_allocator/host.c"
#undef main
#include "r_local.h"
int dc_x,dc_yl,dc_yh,centery;
fixed_t dc_iscale,dc_texturemid;
byte* dc_source;
lighttable_t* dc_colormap;
byte* ylookup[200];
int columnofs[320];
#include "draw_generated.c"
static int written_integer(memblock_t* b,size_t rel) {
 if(rel<sizeof(b->size))return 1;
 if(rel>=offsetof(memblock_t,tag)&&rel<offsetof(memblock_t,tag)+sizeof(b->tag))return 1;
 if(rel>=offsetof(memblock_t,id)&&rel<offsetof(memblock_t,id)+sizeof(b->id)&&id_known(b))return 1;
 return 0;
}
int main(void){
 static const int lengths[]={1,7,8,9,31,32,33,63,64,65,111,112,113,255,511,1128};
 word(80);
 for(size_t row=0;row<16;row++)for(int kind=0;kind<5;kind++) {
  int len=lengths[row],tag=kind==1?1:(row%3==0?1:row%3==1?50:101);
  free(backing);heap_bytes=kind==4?56+40+((len+7)&~7)+64:8192;memset(owners,0,sizeof(owners));known_count=0;Z_Init();
  byte* source=Z_Malloc(len,PU_CACHE,&owners[0]);for(int i=0;i<len;i++)source[i]=(byte)(i*7+5);
  if(kind<3){byte* body=Z_Malloc(160,tag,kind==1?NULL:&owners[1]);for(int i=0;i<160;i++)body[i]=(byte)(i*29+7);if(kind==2)Z_Free(body);}
  byte values[128]={0},mask[128]={0};
  memblock_t* b=(memblock_t*)(source-sizeof(memblock_t));
  for(size_t i=0;i<128;i++){
   size_t position=(size_t)(source-backing)+(size_t)len+i;if(position>=(size_t)heap_bytes)continue;byte* p=backing+position;
   while(b!=&mainzone->blocklist&&p>=(byte*)b+b->size)b=b->next;
   if(b==&mainzone->blocklist)abort();size_t rel=(size_t)(p-(byte*)b);
   if(rel<sizeof(memblock_t)){if(written_integer(b,rel)){mask[i]=1;values[i]=*p;}}
   else if(kind==0&&b->user==&owners[1]&&rel-sizeof(memblock_t)<160){mask[i]=1;values[i]=*p;}
  }
  uint32_t pixel=UINT32_MAX;
  if(kind<3&&len>=111){
   byte maps[256],screen[64000];memset(screen,0,sizeof(screen));for(int i=0;i<256;i++)maps[i]=(byte)(i*7+3);
   size_t sample=((size_t)((len+7)&~7))+offsetof(memblock_t,id);dc_source=source+sample-127;dc_colormap=maps;
   dc_x=dc_yl=dc_yh=centery=0;dc_iscale=0;dc_texturemid=-1;ylookup[0]=screen;columnofs[0]=0;
   R_DrawColumn();pixel=screen[0];
  }
  word((uint32_t)len);word((uint32_t)kind);word((uint32_t)tag);word((uint32_t)heap_bytes);word(pixel);
  fwrite(values,1,128,stdout);fwrite(mask,1,128,stdout);
 }
 free(backing);return 0;
}
