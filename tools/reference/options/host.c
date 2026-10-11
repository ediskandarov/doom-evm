// SPDX-License-Identifier: GPL-2.0-only
// Comparison-only host, appended after original extracted menu functions.
#include <stdarg.h>
patch_t *hu_font[HU_FONTSIZE];
boolean chat_on, message_dontfuckwithme, sendpause;
boolean usergame;
boolean automapactive, demoplayback, devparm, netgame;
int consoleplayer;
player_t players[MAXPLAYERS];
int usegamma;
static byte *wad;
static int wadcount, waddir;
static int titleCalls, viewBlocks, viewDetail;
void D_StartTitle(void) { ++titleCalls; }
void R_SetViewSize(int blocks,int detail) { viewBlocks=blocks;viewDetail=detail; }
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
    wadcount=read32(wad+4);waddir=read32(wad+8);gamemode=retail;screenblocks=10;mouseSensitivity=5;showMessages=1;V_Init();
    for(int i=0;i<HU_FONTSIZE;i++){char name[9];snprintf(name,9,"STCFN%03d",33+i);hu_font[i]=W_CacheLumpName(name,PU_STATIC);}
    M_Init();M_StartControlPanel();currentMenu=&OptionsDef;
    for(int size=0;size<=8;size++)for(int msg=0;msg<=1;msg++)for(int item=0;item<8;item++){
        screenSize=size;showMessages=msg;itemOn=item;char name[64];snprintf(name,64,"options-%d-%d-%d.bin",size,msg,item);screen(argv[2],name);
    }
    usergame=true;M_EndGame(0);screen(argv[2],"endgame.bin");M_StopMessage();
    screenblocks=10;showMessages=1;OptionsDef.lastOn=0;MainDef.lastOn=0;M_Init();M_StartControlPanel();M_Options(0);
    char path[1024];snprintf(path,sizeof(path),"%s/options-responder.bin",argv[2]);FILE*s=fopen(path,"wb");
    // Supported hotkeys avoid unavailable detail/mouse/sound routines.
    int keys[]={109,13,13,115,174,174,172,172,174,13,127,111,13,101,13,119,110,27,111,13,101,13,27,27,111,13,101,13,121};
    for(unsigned i=0;i<sizeof(keys)/sizeof(*keys);i++){
        event_t e={ev_keydown,keys[i],0,0};int consumed=M_Responder(&e);M_Ticker();
        word(s,consumed);word(s,menuactive);word(s,currentMenu==&MainDef?0:4);word(s,itemOn);word(s,whichSkull);word(s,skullAnimCounter);
        word(s,OptionsDef.lastOn);word(s,showMessages);word(s,screenSize);word(s,messageToPrint);word(s,titleCalls);
    }
    fclose(s);return 0;
}
