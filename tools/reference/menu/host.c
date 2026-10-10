// SPDX-License-Identifier: GPL-2.0-only
// Comparison-only host, appended after original extracted menu functions.
#include <stdarg.h>
patch_t *hu_font[HU_FONTSIZE];
boolean chat_on, message_dontfuckwithme, sendpause;
boolean automapactive, demoplayback, devparm, netgame;
int consoleplayer;
player_t players[MAXPLAYERS];
int usegamma;
static byte *wad;
static int wadcount, waddir;
static int deferredSkill=-1, deferredEpisode=-1, deferredMap=-1;
static unsigned read32(byte *p) { return p[0]|p[1]<<8|p[2]<<16|p[3]<<24; }
void I_Error(char *fmt,...) { va_list ap;va_start(ap,fmt);vfprintf(stderr,fmt,ap);va_end(ap);abort(); }
byte *I_AllocLow(int length) { return calloc(1,(size_t)length); }
int W_GetNumForName(char *name) { for(int i=wadcount-1;i>=0;--i)if(!strncmp((char*)wad+waddir+i*16+8,name,8))return i; I_Error("Missing %s",name);return -1; }
void *W_CacheLumpNum(int num,int tag) { (void)tag;return wad+read32(wad+waddir+num*16); }
void *W_CacheLumpName(char *name,int tag) {return W_CacheLumpNum(W_GetNumForName(name),tag);}
void S_StartSound(void *origin,int sound) { (void)origin;(void)sound; }
int I_GetTime(void) { return 0; }
void I_SetPalette(byte *palette) { (void)palette; }
void G_ScreenShot(void) { abort(); }
void M_DoSave(int slot) { (void)slot;abort(); }
void G_DeferedInitNew(skill_t skill,int episode,int map) {deferredSkill=skill;deferredEpisode=episode;deferredMap=map;}
static void output(char *dir,char *name,void *bytes,size_t size) {char p[1024];snprintf(p,sizeof(p),"%s/%s",dir,name);FILE*f=fopen(p,"wb");if(!f)abort();fwrite(bytes,1,size,f);fclose(f);}
static void screen(char *dir,char *name) {V_DrawPatchDirect(0,0,0,W_CacheLumpName("TITLEPIC",PU_CACHE));M_Drawer();output(dir,name,screens[0],64000);}
static void word(FILE *f,int value) {byte b[4]={(unsigned)value>>24,(unsigned)value>>16,(unsigned)value>>8,(unsigned)value};fwrite(b,1,4,f);}
static void state(FILE *f,int consumed) {word(f,consumed);word(f,menuactive);word(f,currentMenu==&MainDef?0:currentMenu==&EpiDef?1:2);word(f,itemOn);word(f,whichSkull);word(f,skullAnimCounter);word(f,MainDef.lastOn);word(f,EpiDef.lastOn);word(f,NewDef.lastOn);word(f,messageToPrint);word(f,deferredSkill);word(f,deferredEpisode);word(f,deferredMap);}
int main(int argc,char **argv) {
    if(argc!=3)abort();FILE*f=fopen(argv[1],"rb");fseek(f,0,SEEK_END);long n=ftell(f);rewind(f);wad=malloc(n);fread(wad,1,n,f);fclose(f);
    wadcount=read32(wad+4);waddir=read32(wad+8);gamemode=retail;screenblocks=10;V_Init();
    for(int i=0;i<HU_FONTSIZE;i++){char name[9];snprintf(name,9,"STCFN%03d",33+i);hu_font[i]=W_CacheLumpName(name,PU_STATIC);}
    M_Init();M_StartControlPanel();screen(argv[2],"main-skull0.bin");
    for(int i=0;i<10;i++)M_Ticker();screen(argv[2],"main-skull1.bin");
    for(int i=0;i<8;i++)M_Ticker();currentMenu=&EpiDef;itemOn=0;screen(argv[2],"episode.bin");
    currentMenu=&NewDef;for(int i=0;i<5;i++){itemOn=i;char name[64];snprintf(name,64,"skill-%d.bin",i);screen(argv[2],name);}
    M_ChooseSkill(4);screen(argv[2],"nightmare.bin");
    // Reset source globals to a fresh original menu runtime for responder proof.
    MainDef.lastOn=0;EpiDef.lastOn=0;NewDef.lastOn=2;M_Init();
    char path[1024];snprintf(path,sizeof(path),"%s/responder.bin",argv[2]);FILE*s=fopen(path,"wb");
    int events[][2]={{0,27},{1,27},{0,13},{0,13},{0,175},{0,175},{0,173},{0,172},{0,174},{0,104},{0,104},{0,127},{0,127},{0,27},{0,27},{0,13},{0,13},{0,110},{0,13},{0,13},{0,110},{0,27},{0,27},{0,13},{0,13},{0,110},{0,13},{0,121}};
    for(unsigned i=0;i<sizeof(events)/sizeof(*events);i++){event_t e={events[i][0],events[i][1],0,0};int consumed=M_Responder(&e);M_Ticker();state(s,consumed);}
    fclose(s);return 0;
}
