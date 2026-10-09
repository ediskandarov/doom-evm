// SPDX-License-Identifier: GPL-2.0-only
// Original lifecycle units with explicit observing boundary doubles.
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdarg.h>
#include "doomdef.h"
#include "doomstat.h"
#include "p_local.h"
#include "r_state.h"
#include "m_random.h"
#include "g_game.h"
#include "s_sound.h"
#include "info.h"
#include "r_main.h"
extern int prndindex;extern boolean onground;
int leveltime,gametic,validcount;GameMode_t gamemode;int gameepisode=1,gamemap=1;skill_t gameskill;
boolean netgame,deathmatch,respawnmonsters,nomonsters,fastparm,secretexit;gameaction_t gameaction;player_t players[4];boolean playeringame[4];thinker_t thinkercap;
mapthing_t playerstarts[4],deathmatchstarts[10];mapthing_t *deathmatch_p=deathmatchstarts;
int maxammo[4]={200,50,300,50},totalkills,totalitems,totalsecret,consoleplayer,displayplayer;
int numsectors,numlines,numsides,numsubsectors;sector_t *sectors;line_t *lines;side_t *sides;subsector_t *subsectors;
int bmapwidth,bmapheight;fixed_t bmaporgx,bmaporgy;mobj_t **blocklinks;line_t *ceilingline;fixed_t attackrange;int skyflatnum=3;
fixed_t viewx,viewy;fixed_t *finecosine=finesine+FINEANGLES/4;mobj_t *linetarget;
static mobj_t *objects[1024];static int objectcount;static uint32_t mode;static int32_t calls[32768];static int callcount,aimcount,actionguard;
void I_Error(char *format,...) {va_list ap;va_start(ap,format);vfprintf(stderr,format,ap);va_end(ap);fputc('\n',stderr);exit(2);}
static int actorid(mobj_t *m) {if(!m) return -1;for(int i=0;i<objectcount;i++) if(objects[i]==m) return i;I_Error("unknown actor");return -1;}
static void observe(int code,int a,int b,int c,int d,int e) {int32_t row[]={code,a,b,c,d,e};if(callcount+6>32768) I_Error("observation capacity");memcpy(calls+callcount,row,sizeof(row));callcount+=6;}
void *Z_Malloc(int size,int tag,void *user) {(void)tag;void *p=malloc(size);if(!p) I_Error("allocate");memset(p,getenv("ALLOCATION_FILL")?0xa5:0,size);if(user) *(void**)user=p;return p;}
void Z_Free(void *p) {(void)p;I_Error("unexpected free before lazy thinker turn");}
void P_AddThinker(thinker_t *t) {if(objectcount==1024) I_Error("actor capacity");objects[objectcount++]=(mobj_t*)t;t->prev=thinkercap.prev;t->next=&thinkercap;thinkercap.prev->next=t;thinkercap.prev=t;}
void P_RemoveThinker(thinker_t *t) {t->function.acv=(actionf_v)-1;}
void S_StartSound(void *origin,int sound) {(void)origin;(void)sound;}void S_StopSound(void *origin){(void)origin;}void ST_Start(void){}void HU_Start(void){}
void P_MovePsprites(player_t *p) {observe(1,p-players,0,0,0,0);}
void P_SetupPsprites(player_t *p) {observe(2,p-players,0,0,0,0);}
void P_UseLines(player_t *p) {observe(3,p-players,0,0,0,0);}
void P_PlayerInSpecialSector(player_t *p) {observe(4,p-players,0,0,0,0);}
boolean P_TryMove(mobj_t *m,fixed_t x,fixed_t y) {observe(5,actorid(m),x,y,0,0);ceilingline=(mode&128)?lines:NULL;if(mode&4) return false;m->x=x;m->y=y;return true;}
boolean P_CheckPosition(mobj_t *m,fixed_t x,fixed_t y) {observe(6,actorid(m),x,y,0,0);return !(mode&2);}
void P_SlideMove(mobj_t *m) {observe(7,actorid(m),0,0,0,0);m->momx/=2;m->momy/=2;}
fixed_t P_AimLineAttack(mobj_t *m,angle_t angle,fixed_t range) {observe(8,actorid(m),angle,range,0,0);aimcount++;linetarget=aimcount>=(int)(1+(mode&3))?objects[1]:NULL;return 123456;}
int W_CheckNumForName(char *name) {(void)name;return (mode&134217728)?0:-1;}
subsector_t *R_PointInSubsector(fixed_t x,fixed_t y) {(void)x;(void)y;return subsectors;}
void ObserveAction(int action,mobj_t *m) {observe(9,action,actorid(m),0,0,0);if(mode&8192) m->tics=7;if((mode&65536) && !actionguard){actionguard=1;P_SetMobjState(m,S_PLAY);}}
static void word(FILE *f,int32_t v) {uint32_t u=(uint32_t)v;unsigned char b[]={u>>24,u>>16,u>>8,u};if(fwrite(b,1,4,f)!=4) I_Error("write");}
static void mapthing(FILE *f,mapthing_t *m) {word(f,m->x);word(f,m->y);word(f,m->angle);word(f,m->type);word(f,m->options);}
static void player(FILE *f,player_t *p) {
 word(f,actorid(p->mo));word(f,p->playerstate);word(f,p->cmd.forwardmove);word(f,p->cmd.sidemove);word(f,p->cmd.angleturn);word(f,p->cmd.consistancy);word(f,p->cmd.chatchar);word(f,p->cmd.buttons);
 int32_t a[]={p->viewz,p->viewheight,p->deltaviewheight,p->bob,p->health,p->armorpoints,p->armortype,p->backpack,p->readyweapon,p->pendingweapon,p->attackdown,p->usedown,p->cheats,p->refire,p->killcount,p->itemcount,p->secretcount,p->damagecount,p->bonuscount,actorid(p->attacker),p->extralight,p->fixedcolormap,p->colormap,p->didsecret,p->message!=NULL};for(unsigned i=0;i<sizeof(a)/sizeof(*a);i++) word(f,a[i]);
 for(int i=0;i<6;i++){word(f,p->powers[i]);word(f,p->cards[i]);}for(int i=0;i<4;i++){word(f,p->frags[i]);word(f,p->ammo[i]);word(f,p->maxammo[i]);}for(int i=0;i<9;i++) word(f,p->weaponowned[i]);for(int i=0;i<2;i++){pspdef_t *p2=p->psprites+i;word(f,p2->state?p2->state-states:-1);word(f,p2->tics);word(f,p2->sx);word(f,p2->sy);}
}
static void snapshot(FILE *f,int result) {
 word(f,result);word(f,prndindex);word(f,leveltime);word(f,gametic);word(f,onground);word(f,gameaction);word(f,secretexit);word(f,totalkills);word(f,totalitems);word(f,totalsecret);
 for(int i=0;i<4;i++) player(f,players+i);
 word(f,objectcount);for(int i=0;i<objectcount;i++){mobj_t *m=objects[i];int32_t a[]={m->type,m->x,m->y,m->z,m->angle,m->sprite,m->frame,m->floorz,m->ceilingz,m->radius,m->height,m->momx,m->momy,m->momz,m->tics,m->state?m->state-states:-1,m->flags,m->health,m->movedir,m->movecount,actorid(m->target),m->reactiontime,m->threshold,m->player?m->player-players:-1,m->lastlook,actorid(m->tracer),actorid(m->snext),actorid(m->sprev),actorid(m->bnext),actorid(m->bprev),m->thinker.function.acv==(actionf_v)-1};for(unsigned j=0;j<sizeof(a)/sizeof(*a);j++)word(f,a[j]);mapthing(f,&m->spawnpoint);}
 word(f,actorid(sectors[0].thinglist));for(int i=0;i<256;i++) word(f,actorid(blocklinks[i]));word(f,deathmatch_p-deathmatchstarts);for(int i=0;i<4;i++) mapthing(f,playerstarts+i);for(int i=0;i<10;i++) mapthing(f,deathmatchstarts+i);
 word(f,iquehead);word(f,iquetail);for(int i=0;i<128;i++){word(f,itemrespawntime[i]);mapthing(f,itemrespawnque+i);}word(f,callcount/6);for(int i=0;i<callcount;i++) word(f,calls[i]);
}
static void setup(int kind,int seed,uint32_t flags,int momx,int momy,int momz,int z,int skill,int gm,int angle,int options) {
 static sector_t s;static line_t l;static subsector_t ss;static mobj_t *heads[256];static state_t saved[3];static int initialized;
 if(!initialized){memcpy(saved,states+900,sizeof(saved));initialized=1;}memcpy(states+900,saved,sizeof(saved));
 // Private, deterministic zero-tic chain exercises the original state walker and callbacks.
 states[900].tics=0;states[900].action.acp1=(actionf_p1)A_Look;states[900].nextstate=901;states[901].tics=0;states[901].action.acp1=(actionf_p1)A_Fall;states[901].nextstate=902;states[902].tics=4;states[902].action.acp1=(actionf_p1)A_Pain;
 memset(&s,0,sizeof(s));memset(&l,0,sizeof(l));memset(&ss,0,sizeof(ss));memset(heads,0,sizeof(heads));memset(players,0,sizeof(players));memset(playeringame,0,sizeof(playeringame));memset(playerstarts,0,sizeof(playerstarts));memset(deathmatchstarts,0,sizeof(deathmatchstarts));memset(itemrespawnque,0,sizeof(itemrespawnque));memset(itemrespawntime,0,sizeof(itemrespawntime));
 mode=flags;objectcount=0;callcount=0;aimcount=actionguard=0;prndindex=seed;rndindex=0;validcount=0;leveltime=(mode&262144)?416:1050;gametic=0;gamemode=gm;gameskill=skill;gameaction=ga_nothing;secretexit=true;deathmatch=(mode&524288)?2:0;netgame=!!(mode&2097152);respawnmonsters=!!(mode&131072);nomonsters=!!(mode&1048576);totalkills=totalitems=totalsecret=0;iquehead=iquetail=0;deathmatch_p=deathmatchstarts;onground=!(mode&536870912);attackrange=(mode&4194304)?MELEERANGE:MISSILERANGE;
 sectors=&s;lines=&l;subsectors=&ss;numsectors=numlines=numsubsectors=1;s.floorheight=0;s.ceilingheight=(mode&1073741824)?64*FRACUNIT:128*FRACUNIT;s.ceilingpic=(mode&128)?3:0;s.special=(mode&16384)?5:0;ss.sector=&s;l.backsector=&s;ceilingline=NULL;linetarget=NULL;
 bmapwidth=bmapheight=16;bmaporgx=bmaporgy=-1024*FRACUNIT;blocklinks=heads;thinkercap.next=thinkercap.prev=&thinkercap;
 mobj_t *mo=P_SpawnMobj(-16*FRACUNIT,8*FRACUNIT,z,kind);P_SpawnMobj(128*FRACUNIT,64*FRACUNIT,8*FRACUNIT,MT_POSSESSED);mobj_t *item=P_SpawnMobj(-64*FRACUNIT,16*FRACUNIT,ONFLOORZ,MT_CLIP);item->spawnpoint=(mapthing_t){-64,16,270,2007,7};
 if(mode&2)mo->reactiontime=2;if(mode&4)mo->reactiontime=0;mo->player=(mode&1)?NULL:players;mo->target=objects[1];mo->tracer=objects[1];mo->momx=momx;mo->momy=momy;mo->momz=momz;mo->angle=(uint32_t)angle;mo->spawnpoint=(mapthing_t){-64,16,angle,3004,options};
 if(mode&8)mo->flags|=MF_SKULLFLY;if(mode&16)mo->flags|=MF_FLOAT;if(mode&32)mo->flags|=MF_MISSILE;if(mode&64)mo->flags|=MF_CORPSE;if(mode&4096)mo->flags|=MF_DROPPED;if(mode&33554432)mo->flags|=MF_NOGRAVITY;if(mode&67108864)objects[1]->flags|=MF_SHADOW;if(mode&2147483648U)mo->flags|=MF_JUSTATTACKED;
 if(mode&131072){mo->tics=-1;mo->movecount=419;mo->flags|=MF_COUNTKILL;}
 playeringame[0]=true;playeringame[1]=!!(mode&2097152);players[1].health=77;
 player_t *p=players;p->mo=mo;p->attacker=objects[1];p->viewheight=41*FRACUNIT;p->deltaviewheight=-FRACUNIT/4;p->health=97;p->armorpoints=25;p->armortype=1;p->readyweapon=1;p->pendingweapon=wp_nochange;p->damagecount=7;p->bonuscount=3;p->usedown=!!(mode&16777216);p->attackdown=1;p->killcount=5;p->itemcount=6;p->secretcount=7;p->message="test";p->backpack=true;p->extralight=2;p->fixedcolormap=1;p->colormap=2;p->didsecret=true;
 p->playerstate=(mode&1024)?PST_DEAD:((mode&2048)?PST_REBORN:PST_LIVE);p->cheats=((mode&256)?CF_NOMOMENTUM:0)|((mode&512)?CF_NOCLIP:0);
 p->cmd=(ticcmd_t){.forwardmove=(int8_t)(momx/2048),.sidemove=(int8_t)(momy/2048),.angleturn=(int16_t)momz,.consistancy=42,.chatchar=65,.buttons=(uint8_t)options};
 for(int i=0;i<4;i++){p->frags[i]=13*(i+1);p->ammo[i]=20+i;p->maxammo[i]=100+i;}for(int i=0;i<9;i++)p->weaponowned[i]=!!(mode&8388608)||(i<=1);for(int i=0;i<6;i++){p->powers[i]=(mode&268435456)?1:((mode&4194304)?129:0);p->cards[i]=(i&1);}
 p->psprites[0]=(pspdef_t){states+S_PISTOL,4,1234,5678};p->psprites[1]=(pspdef_t){states+S_PISTOLFLASH,3,2345,6789};
 if(mode&32768){iquehead=127;iquetail=0;for(int i=0;i<128;i++){itemrespawnque[i]=item->spawnpoint;itemrespawntime[i]=0;}}
}
