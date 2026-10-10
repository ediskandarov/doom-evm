/* SPDX-License-Identifier: GPL-2.0-only
 * Original WI observes explicit scenarios; no WI algorithm is reproduced here. */
#include "compat.h"
static const char *asset_directory;
static int asset_profile,world_done,placement_failures;
static void *video_allocation;
static char resource_names[80][9];
static void *resource_bytes[80];
static int resource_count;
int gamemode,netgame,deathmatch,french;
boolean playeringame[4];player_t players[4];
void I_Error(char *fmt,...){va_list ap;va_start(ap,fmt);vfprintf(stderr,fmt,ap);va_end(ap);exit(2);}
byte *I_AllocLow(int n){video_allocation=calloc(1,(size_t)n);if(!video_allocation)abort();return video_allocation;}
void *Z_Malloc(int n,int tag,void *owner){(void)tag;(void)owner;void *p=calloc(1,(size_t)n);if(!p)abort();return p;}
void Z_Free(void *p){free(p);}
void Z_ChangeTag(void *p,int tag){(void)p;(void)tag;}
void S_StartSound(void *p,int sound){(void)p;(void)sound;}
void S_ChangeMusic(int music,boolean loop){(void)music;(void)loop;}
void G_WorldDone(void){world_done++;}
int host_printf(const char *fmt,...){(void)fmt;placement_failures++;return 0;}
void *W_CacheLumpName(char *name,int tag){
 (void)tag;for(int i=0;i<resource_count;i++)if(!strcmp(name,resource_names[i]))return resource_bytes[i];
 if(resource_count==80)abort();char path[4096];
 const char *prefix=(asset_profile && (!strcmp(name,"WIURH0")||!strcmp(name,"WIURH1")||!strcmp(name,"WISPLAT")||!strcmp(name,"WIA00000")))?"synthetic/":"";
 snprintf(path,sizeof(path),"%s/%s%s.bin",asset_directory,prefix,name);
 /* Profile 2/3 use oversized pointer candidates; the splat remains well formed/fitting. */
 if(asset_profile>=2&&!strcmp(name,"WIURH0"))snprintf(path,sizeof(path),"%s/synthetic/HUGE.bin",asset_directory);
 if(asset_profile==3&&!strcmp(name,"WIURH1"))snprintf(path,sizeof(path),"%s/synthetic/HUGE.bin",asset_directory);
 FILE *f=fopen(path,"rb");if(!f){perror(path);exit(3);}fseek(f,0,SEEK_END);long n=ftell(f);rewind(f);
 void *p=malloc((size_t)n);if(!p||fread(p,1,(size_t)n,f)!=(size_t)n)abort();fclose(f);
 strcpy(resource_names[resource_count],name);resource_bytes[resource_count++]=p;return p;
}
/* printf is a host diagnostics boundary; no original source text is changed. */
#define printf host_printf
#include "wi_stuff.c"
#undef printf
extern int rndindex,prndindex;
static uint32_t read32(FILE *f){byte b[4];if(fread(b,1,4,f)!=4)abort();return ((uint32_t)b[0]<<24)|((uint32_t)b[1]<<16)|((uint32_t)b[2]<<8)|b[3];}
static void out(int n){uint32_t u=(uint32_t)n;byte b[4]={u>>24,u>>16,u>>8,u};if(fwrite(b,1,4,stdout)!=4)abort();}
static void snapshot(wbstartstruct_t *w){
 out(w->epsd);out(w->didsecret);out(w->last);out(w->next);out(w->maxkills);out(w->maxitems);out(w->maxsecret);out(w->maxfrags);out(w->partime);out(w->pnum);
 for(int i=0;i<4;i++){wbplayerstruct_t *p=&w->plyr[i];out(p->in);out(p->skills);out(p->sitems);out(p->ssecret);out(p->stime);for(int j=0;j<4;j++)out(p->frags[j]);out(p->score);}
 out(state);out(acceleratestage);out(me);out(cnt);out(bcnt);out(firstrefresh);
 for(int i=0;i<4;i++)out(cnt_kills[i]);for(int i=0;i<4;i++)out(cnt_items[i]);for(int i=0;i<4;i++)out(cnt_secret[i]);
 out(cnt_time);out(cnt_par);out(cnt_pause);out(sp_state);out(snl_pointeron);
 for(int i=0;i<10;i++)out(anims[0][i].nexttic);for(int i=0;i<10;i++)out(anims[0][i].ctr);
 out(1);out(world_done!=0);out(gamemode);
 for(int i=0;i<4;i++)out(playeringame[i]);for(int i=0;i<4;i++)out(players[i].cmd.buttons);
 for(int i=0;i<4;i++)out(players[i].attackdown);for(int i=0;i<4;i++)out(players[i].usedown);
 out(rndindex);
 for(int i=0;i<4;i++)out(dirtybox[i]);
 fwrite(screens[0],1,64000,stdout);fwrite(screens[1],1,64000,stdout);
}
int main(int argc,char **argv){
 if(argc!=3||sizeof(int)!=4||sizeof(short)!=2) return 1;asset_directory=argv[2];
 FILE *f=fopen(argv[1],"rb");if(!f)return 2;
 int h[16];for(int i=0;i<16;i++)h[i]=(int32_t)read32(f);
 gamemode=h[0];asset_profile=h[15];playeringame[0]=true;players[0].attackdown=h[12];players[0].usedown=h[13];rndindex=h[14];
 wbstartstruct_t w={0};w.last=h[1];w.next=h[2];w.didsecret=h[3];w.maxkills=h[4];w.maxitems=h[5];w.maxsecret=h[6];w.partime=h[11];
 for(int i=0;i<4;i++){w.plyr[i].in=i==0;w.plyr[i].score=100+i;for(int j=0;j<4;j++)w.plyr[i].frags[j]=i*4+j-5;}
 w.plyr[0].skills=h[7];w.plyr[0].sitems=h[8];w.plyr[0].ssecret=h[9];w.plyr[0].stime=h[10];
 V_Init();M_ClearBox(dirtybox);WI_Start(&w);snapshot(&w);
 uint32_t count=read32(f);
 for(uint32_t i=0;i<count;i++){
  int a[5];for(int j=0;j<5;j++)a[j]=(int32_t)read32(f);
  switch(a[0]){
   case 0:players[0].cmd.buttons=(unsigned char)a[2];for(int j=0;j<a[1];j++)WI_Ticker();if(a[3])WI_Drawer();break;
   case 1:WI_Drawer();break;
   case 2:if(!world_done)WI_End();world_done=0;w.last=a[1];w.next=a[2];w.didsecret=a[3];WI_Start(&w);break;
   case 3:WI_drawNum(a[1],a[2],a[3],a[4]);break;
   case 4:WI_drawPercent(a[1],a[2],a[3]);break;
   case 5:WI_drawTime(a[1],a[2],a[3]);break;
   case 6:{patch_t *c[2]={yah[0],yah[1]};WI_drawOnLnode(a[1],c);break;}
   case 7:WI_drawAnimatedBack();break;
   default:abort();
  }
  snapshot(&w);
 }
 if(!world_done)WI_End();for(int i=0;i<resource_count;i++)free(resource_bytes[i]);free(video_allocation);fclose(f);return 0;
}
