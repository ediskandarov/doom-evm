/* Goal 4.2 oracle: unchanged st_stuff.c included to observe its file globals.
 * Platform/resource functions below are host boundaries, never widget logic. */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include "doomdef.h"
#include "st_stuff.c"

player_t players[MAXPLAYERS];
int consoleplayer, displayplayer;
boolean netgame, automapactive;
boolean deathmatch;
GameMode_t gamemode;
skill_t gameskill;
int gameepisode, gamemap;
static byte palette_rgb[768];
static unsigned palette_revision;
static char resource_dir[4096];
static char names[128][9];
static byte *lumps[128];
static int lump_count;
static mobj_t mo, attacker;
extern int rndindex;

byte *I_AllocLow(int n) { return calloc(1,(size_t)n); }
void *Z_Malloc(int n,int tag,void *user) { (void)tag;(void)user;return calloc(1,(size_t)n); }
void I_Error(char *fmt,...) { va_list args;va_start(args,fmt);vfprintf(stderr,fmt,args);va_end(args);exit(20); }
int W_GetNumForName(char *name) {
    for(int i=0;i<lump_count;i++) if(!strcmp(names[i],name)) return i;
    char path[8192];snprintf(path,sizeof(path),"%s/%s.bin",resource_dir,name);
    FILE *f=fopen(path,"rb");if(!f) I_Error("missing lump %s",name);
    fseek(f,0,SEEK_END);long size=ftell(f);rewind(f);
    byte *data=malloc((size_t)size);if(fread(data,1,(size_t)size,f)!=(size_t)size) exit(21);fclose(f);
    strcpy(names[lump_count],name);lumps[lump_count]=data;return lump_count++;
}
void *W_CacheLumpNum(int id,int tag) { (void)tag;return lumps[id]; }
void *W_CacheLumpName(char *name,int tag) {return W_CacheLumpNum(W_GetNumForName(name),tag);}
void I_SetPalette(byte *p) {for(int i=0;i<768;i++)palette_rgb[i]=gammatable[usegamma][p[i]];palette_revision++;}
void S_ChangeMusic(int music, int looping) { (void)music;(void)looping;abort(); }
void G_DeferedInitNew(skill_t skill,int episode,int map) { (void)skill;(void)episode;(void)map;abort(); }
boolean P_GivePower(player_t *p,int power) { (void)p;(void)power;abort(); }
static uint32_t read32(FILE *f) {byte b[4];if(fread(b,1,4,f)!=4)exit(22);return ((uint32_t)b[0]<<24)|((uint32_t)b[1]<<16)|((uint32_t)b[2]<<8)|b[3];}
static void write32(uint32_t v) {byte b[4]={v>>24,v>>16,v>>8,v};fwrite(b,1,4,stdout);}
static void input(int32_t *a) {
    player_t *p=&players[consoleplayer];
    p->mo=&mo;p->health=a[1];p->armorpoints=a[2];p->readyweapon=a[3];
    for(int i=0;i<4;i++){p->ammo[i]=a[4+i];p->maxammo[i]=a[8+i];p->frags[i]=a[31+i];}
    for(int i=0;i<9;i++)p->weaponowned[i]=(a[12]>>i)&1;
    for(int i=0;i<6;i++)p->cards[i]=(a[13]>>i)&1;
    p->damagecount=a[14];p->bonuscount=a[15];p->powers[pw_strength]=a[16];p->powers[pw_ironfeet]=a[17];
    p->powers[pw_invulnerability]=a[18];p->cheats=a[19];p->attackdown=a[20];
    p->attacker=a[21]==0?NULL:a[21]==1?&mo:&attacker;
    attacker.x=a[22];attacker.y=a[23];mo.angle=(uint32_t)a[24];
    automapactive=a[27];deathmatch=a[28];netgame=a[29];usegamma=a[30];
}
int main(int argc,char **argv) {
    if(argc!=3)return 1;strcpy(resource_dir,argv[2]);
    FILE *f=fopen(argv[1],"rb");if(!f)return 2;
    V_Init();ST_Init();M_ClearRandom();
    for(int i=0;i<64000;i++)screens[0][i]=(byte)(i*13+(i/320)*7+19);
    uint32_t count=read32(f);
    for(uint32_t row=0;row<count;row++) {
        int32_t a[36];for(int i=0;i<36;i++)a[i]=(int32_t)read32(f);
        input(a);if(row==0)ST_Start();
        switch(a[0]) {
            case 0:ST_Ticker();ST_Drawer(a[25],a[26]);break;
            case 1:ST_Ticker();break;
            case 2:ST_Drawer(a[25],a[26]);break;
            case 3:ST_Start();break;
            case 4:ST_Stop();break;
            case 6:st_faceindex=a[35];ST_Drawer(a[25],a[26]);break;
            case 5:{event_t ev={ev_keyup,a[35],0,0};ST_Responder(&ev);break;}
        }
        int values[]={st_clock,st_faceindex,st_facecount,st_oldhealth,st_randomnumber,rndindex,
            st_palette,palette_revision,*w_ready.num,w_ready.data,st_fragscount,keyboxes[0],keyboxes[1],keyboxes[2],
            st_statusbaron,st_firsttime,st_stopped,st_gamestate,st_armson,st_fragson,st_notdeathmatch,
            w_ready.oldnum,w_health.n.oldnum,w_armor.n.oldnum};
        for(int i=0;i<24;i++)write32(values[i]);
        fwrite(screens[0],1,64000,stdout);fwrite(screens[4],1,10240,stdout);fwrite(palette_rgb,1,768,stdout);
    }
    return 0;
}
