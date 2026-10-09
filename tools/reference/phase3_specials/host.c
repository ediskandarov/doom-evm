// SPDX-License-Identifier: GPL-2.0-only
// Logical resource/geometry fixture host; all tested functions are unchanged original C.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <stddef.h>
#include "doomdef.h"
#include "doomstat.h"
#include "p_local.h"
#include "g_game.h"
#include "m_random.h"
#include "sounds.h"
#include "names.h"
typedef struct {boolean istexture;int picnum,basepic,numpics,speed;} anim_t;
typedef struct {boolean istexture;char endname[9],startname[9];int speed;} animdef_t;
#define MAXANIMS 32
#define MAXLINEANIMS 64
#define MAX_ADJOINING_SECTORS 20
anim_t anims[MAXANIMS],*lastanim;
int switchlist[MAXSWITCHES*2],numswitches;button_t buttonlist[MAXBUTTONS];
int numsectors,numlines;sector_t *sectors;line_t *lines;side_t *sides;subsector_t *subsectors;
int leveltime;boolean levelTimer;int levelTimeCount;short numlinespecials;line_t *linespeciallist[MAXLINEANIMS];
int *texturetranslation,*flattranslation;thinker_t thinkercap;
GameMode_t gamemode;gameaction_t gameaction;boolean secretexit;
int totalsecret;
static sector_t ss[32];static line_t ls[32];static side_t sd[64];static subsector_t subs[2];static line_t *sector_lines[32][32];
static mobj_t actors[8];static player_t player;static int actor_count;
static int textrans[256],flattrans[256];static int calls[128],call_count;static int resource_mask,teleport_fail;
extern int prndindex,rndindex;
fixed_t *finecosine=&finesine[FINEANGLES/4];
void I_Error(char *format,...) {va_list ap;va_start(ap,format);vfprintf(stderr,format,ap);va_end(ap);exit(2);}
void S_StartSound(void *origin,int sound){(void)origin;(void)sound;}
static void logcall(int op,int a,int b,int c,int d){if(call_count+5>128)exit(3);calls[call_count++]=op;calls[call_count++]=a;calls[call_count++]=b;calls[call_count++]=c;calls[call_count++]=d;}
static int actorid(mobj_t *t){return t?(int)(t-actors):-1;}
static int lineid(line_t *l){return l?(int)(l-lines):-1;}
static int sectorid(sector_t *s){return s?(int)(s-sectors):-1;}
int R_CheckTextureNumForName(char *name){for(unsigned i=0;i<sizeof(texnames)/sizeof(*texnames);i++){if(resource_mask==1&&!strcmp(texnames[i],"BLODGR1"))continue;if(!strncmp(name,texnames[i],8))return i;}return -1;}
int R_TextureNumForName(char *name){int n=R_CheckTextureNumForName(name);if(n<0)I_Error("missing texture");return n;}
int W_CheckNumForName(char *name){for(unsigned i=0;i<sizeof(flatnames)/sizeof(*flatnames);i++){if(resource_mask==2&&!strcmp(flatnames[i],"NUKAGE1"))continue;if(!strncmp(name,flatnames[i],8))return i;}return -1;}
int R_FlatNumForName(char *name){int n=W_CheckNumForName(name);if(n<0)I_Error("missing flat");return n;}
void G_ExitLevel(void){secretexit=false;gameaction=ga_completed;}
void P_DamageMobj(mobj_t *target,mobj_t *inflictor,mobj_t *source,int damage){logcall(1,actorid(target),actorid(inflictor),actorid(source),damage);target->health-=damage;if(target->player)target->player->health-=damage;}
void P_MobjThinker(mobj_t *m){(void)m;}
boolean P_TeleportMove(mobj_t *m,fixed_t x,fixed_t y){logcall(2,actorid(m),x,y,0);if(teleport_fail)return false;m->x=x;m->y=y;m->floorz=ss[1].floorheight;m->subsector=subs+1;return true;}
mobj_t *P_SpawnMobj(fixed_t x,fixed_t y,fixed_t z,mobjtype_t type){if(actor_count==8)exit(3);mobj_t *m=actors+actor_count++;memset(m,0,sizeof(*m));m->x=x;m->y=y;m->z=z;m->type=type;logcall(3,x,y,z,type);return m;}
static void setup(void){
    memset(ss,0,sizeof(ss));memset(ls,0,sizeof(ls));memset(sd,0,sizeof(sd));memset(subs,0,sizeof(subs));memset(sector_lines,0,sizeof(sector_lines));memset(actors,0,sizeof(actors));memset(&player,0,sizeof(player));memset(anims,0,sizeof(anims));memset(buttonlist,0,sizeof(buttonlist));memset(switchlist,0,sizeof(switchlist));memset(linespeciallist,0,sizeof(linespeciallist));
    sectors=ss;lines=ls;sides=sd;subsectors=subs;numsectors=4;numlines=3;leveltime=0;levelTimer=false;levelTimeCount=0;numlinespecials=0;gamemode=shareware;gameaction=ga_nothing;secretexit=false;totalsecret=0;lastanim=anims;call_count=0;actor_count=4;resource_mask=teleport_fail=0;M_ClearRandom();
    texturetranslation=textrans;flattranslation=flattrans;for(int i=0;i<256;i++){textrans[i]=i;flattrans[i]=i;}
    for(int i=0;i<4;i++){ss[i].lines=sector_lines[i];ss[i].floorheight=i*16*FRACUNIT;ss[i].ceilingheight=(128+i*16)*FRACUNIT;ss[i].lightlevel=128+i*16;}
    ss[0].tag=7;ss[1].tag=-2;ss[2].tag=7;
    for(int i=0;i<3;i++){ls[i].frontsector=ss+i;ls[i].backsector=ss+i+1;ls[i].flags=ML_TWOSIDED;ls[i].sidenum[0]=i*2;ls[i].sidenum[1]=i*2+1;sd[i*2].sector=ss+i;sd[i*2+1].sector=ss+i+1;sector_lines[i][ss[i].linecount++]=ls+i;sector_lines[i+1][ss[i+1].linecount++]=ls+i;}
    ls[0].tag=7;subs[0].sector=ss;subs[1].sector=ss+1;
    actors[0].player=&player;actors[0].subsector=subs;actors[0].health=player.health=100;player.mo=actors;player.viewheight=41*FRACUNIT;thinkercap.next=thinkercap.prev=&thinkercap;
}
static void word(int32_t value){uint32_t u=(uint32_t)value;unsigned char b[4]={u>>24,u>>16,u>>8,u};if(fwrite(b,1,4,stdout)!=4)exit(3);}
static int answer[2048],answer_count;
static void out(int value){if(answer_count==2048)exit(3);answer[answer_count++]=value;}
static void buttons(void){for(int i=0;i<16;i++){button_t *b=buttonlist+i;out(b->btimer);out(lineid(b->line));out(b->where);out(b->btexture);out(b->soundorg?sectorid((sector_t*)((char*)b->soundorg - offsetof(sector_t,soundorg))):-1);}}
