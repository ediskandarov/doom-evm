// SPDX-License-Identifier: GPL-2.0-only
// Original p_enemy unit oracle; neighboring subsystems are explicit observing test doubles.
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
extern int prndindex;
int validcount,leveltime,gametic;GameMode_t gamemode;GameMission_t gamemission=doom;Language_t language=english;
int gameepisode,gamemap;skill_t gameskill;boolean netgame,fastparm,playeringame[4];player_t players[4];thinker_t thinkercap;
int numsectors,numlines,numsides,numsubsectors;sector_t *sectors;line_t *lines;side_t *sides;subsector_t *subsectors;
int bmapwidth,bmapheight;fixed_t bmaporgx,bmaporgy;mobj_t **blocklinks;
fixed_t opentop,openbottom,openrange,lowfloor,tmfloorz;boolean floatok;line_t *spechit[8];int numspechit;
fixed_t viewx,viewy;
fixed_t *finecosine=finesine+FINEANGLES/4;
static mobj_t objects[512];static int objectcount;static uint32_t mode;static int32_t calls[16384];static int callcount,easyShadow;
void I_Error(char *format,...) {va_list ap;va_start(ap,format);vfprintf(stderr,format,ap);va_end(ap);fputc('\n',stderr);exit(2);}
static int actorid(mobj_t *m) {return m ? (int)(m-objects):-1;}
static void observe(int code,int a,int b,int c,int d,int e) {int32_t row[]={code,a,b,c,d,e};if(callcount+6>16384) I_Error("observation capacity");memcpy(calls+callcount,row,sizeof(row));callcount+=6;}
void S_StartSound(void *origin,int sound) {(void)origin;(void)sound;}
void P_MobjThinker(mobj_t *mo) {(void)mo;I_Error("unexpected thinker call");}
boolean P_CheckSight(mobj_t *a,mobj_t *b) {observe(9,actorid(a),actorid(b),0,0,0);return !(mode&2);}
boolean P_TryMove(mobj_t *m,fixed_t x,fixed_t y) {observe(8,actorid(m),x,y,0,0);floatok=!!(mode&1024);tmfloorz=16*FRACUNIT;numspechit=(mode&2048)?2:0;spechit[0]=lines;spechit[1]=lines+1;if(mode&4) return false;m->x=x;m->y=y;return true;}
boolean P_UseSpecialLine(mobj_t *m,line_t *line,int side) {observe(10,actorid(m),(int)(line-lines),side,0,0);return (line-lines)==1;}
boolean P_CheckPosition(mobj_t *m,fixed_t x,fixed_t y) {observe(11,actorid(m),x,y,0,0);return !(mode&32);}
boolean P_TeleportMove(mobj_t *m,fixed_t x,fixed_t y) {observe(12,actorid(m),x,y,0,0);m->x=x;m->y=y;return true;}
void P_RemoveMobj(mobj_t *m) {observe(13,actorid(m),0,0,0,0);m->thinker.function.acv=(actionf_v)-1;}
boolean P_SetMobjState(mobj_t *m,statenum_t st) {observe(1,actorid(m),st,0,0,0);m->state=states+st;m->tics=m->state->tics;m->sprite=m->state->sprite;m->frame=m->state->frame;return true;}
static mobj_t *newobject(int type,int x,int y,int z) {
 if(objectcount==512) I_Error("actor capacity");mobj_t *m=objects+objectcount++;memset(m,0,sizeof(*m));m->type=type;m->info=mobjinfo+type;m->x=x;m->y=y;m->z=z;m->state=states+m->info->spawnstate;m->tics=m->state->tics;m->sprite=m->state->sprite;m->frame=m->state->frame;m->flags=m->info->flags;m->health=m->info->spawnhealth;m->radius=m->info->radius;m->height=m->info->height;m->subsector=subsectors;
 m->thinker.function.acp1=(actionf_p1)P_MobjThinker;m->thinker.prev=thinkercap.prev;m->thinker.next=&thinkercap;thinkercap.prev->next=&m->thinker;thinkercap.prev=&m->thinker;
 return m;
}
mobj_t *P_SpawnMobj(fixed_t x,fixed_t y,fixed_t z,mobjtype_t type) {mobj_t *m=newobject(type,x,y,z);observe(2,actorid(m),x,y,z,type);return m;}
mobj_t *P_SpawnMissile(mobj_t *a,mobj_t *b,mobjtype_t type) {mobj_t *m=newobject(type,a->x,a->y,a->z+32*FRACUNIT);m->angle=R_PointToAngle2(a->x,a->y,b->x,b->y);m->momx=100000;m->momy=200000;m->momz=300000;observe(3,actorid(a),actorid(b),type,actorid(m),0);return m;}
void P_SpawnPuff(fixed_t x,fixed_t y,fixed_t z) {observe(4,x,y,z,0,0);}
void P_DamageMobj(mobj_t *target,mobj_t *inflictor,mobj_t *source,int damage) {observe(5,actorid(target),actorid(inflictor),actorid(source),damage,0);target->health-=damage;}
void P_RadiusAttack(mobj_t *spot,mobj_t *source,int damage) {observe(6,actorid(spot),actorid(source),damage,0,0);}
fixed_t P_AimLineAttack(mobj_t *m,angle_t angle,fixed_t distance) {observe(7,actorid(m),angle,distance,0,0);return 123456;}
void P_LineAttack(mobj_t *m,angle_t angle,fixed_t distance,fixed_t slope,int damage) {observe(14,actorid(m),angle,distance,slope,damage);}
int EV_DoFloor(line_t *line,floor_e type) {observe(15,line->tag,type,0,0,0);return 1;}
int EV_DoDoor(line_t *line,vldoor_e type) {observe(16,line->tag,type,0,0,0);return 1;}
void G_ExitLevel(void) {observe(17,0,0,0,0,0);}
void A_ReFire(player_t *p,pspdef_t *psp) {observe(18,p-players,psp-p->psprites,0,0,0);}
subsector_t *R_PointInSubsector(fixed_t x,fixed_t y) {(void)x;(void)y;return subsectors;}
void P_UnsetThingPosition(mobj_t *m) {(void)m;}
void P_SetThingPosition(mobj_t *m) {(void)m;}
boolean P_BlockThingsIterator(int x,int y,boolean(*func)(mobj_t*)) {if(x<0||y<0||x>=bmapwidth||y>=bmapheight) return true;for(mobj_t *m=blocklinks[y*bmapwidth+x];m;m=m->bnext) if(!func(m)) return false;return true;}
static void word(FILE *f,int32_t v) {uint32_t u=(uint32_t)v;unsigned char b[]={u>>24,u>>16,u>>8,u};if(fwrite(b,1,4,f)!=4) I_Error("write");}
static void setup(int type,int seed,uint32_t flags,int dx,int dy,int gm,int episode,int map,int skill) {
 static sector_t sectors_store[3];static line_t lines_store[3];static side_t sides_store[6];static subsector_t sub_store[1];static mobj_t *heads[256];static line_t *sectorlines[3][2];
 memset(objects,0,sizeof(objects));objectcount=0;callcount=0;mode=flags;prndindex=seed;rndindex=0;validcount=1;leveltime=0;gametic=(mode&4096)?1:0;gamemode=gm;gameepisode=episode;gamemap=map;gameskill=skill;netgame=!!(mode&8192);fastparm=!!(mode&16384);
 sectors=sectors_store;lines=lines_store;sides=sides_store;subsectors=sub_store;memset(sectors,0,sizeof(sectors_store));memset(lines,0,sizeof(lines_store));memset(sides,0,sizeof(sides_store));memset(heads,0,sizeof(heads));numsectors=3;numlines=3;numsides=6;numsubsectors=1;subsectors[0].sector=sectors;
 for(int i=0;i<3;i++) {sectors[i].floorheight=0;sectors[i].ceilingheight=128*FRACUNIT;sectors[i].linecount=2;sectors[i].lines=sectorlines[i];lines[i].flags=ML_TWOSIDED|(i?ML_SOUNDBLOCK:0);lines[i].sidenum[0]=2*i;lines[i].sidenum[1]=2*i+1;sides[2*i].sector=sectors+i;sides[2*i+1].sector=sectors+(i+1)%3;lines[i].frontsector=sides[2*i].sector;lines[i].backsector=sides[2*i+1].sector;sectorlines[i][0]=lines+i;sectorlines[i][1]=lines+(i+2)%3;}
 if(mode&32768) sectors[1].ceilingheight=0;
 bmapwidth=bmapheight=16;bmaporgx=bmaporgy=-128*FRACUNIT;blocklinks=heads;thinkercap.next=thinkercap.prev=&thinkercap;
 mobj_t *actor=newobject(type,-16*FRACUNIT,8*FRACUNIT,0);mobj_t *target=newobject(MT_PLAYER,dx*FRACUNIT,dy*FRACUNIT,8*FRACUNIT);mobj_t *corpse=newobject(MT_POSSESSED,-8*FRACUNIT,8*FRACUNIT,0);mobj_t *spot=newobject(MT_BOSSTARGET,0,256*FRACUNIT,0);
 actor->target=(mode&16)?NULL:target;actor->tracer=target;actor->angle=0x18000000;actor->movedir=(mode&65536)?DI_NODIR:DI_EAST;actor->movecount=(mode&131072)?3:0;actor->lastlook=seed&3;actor->reactiontime=(mode&8)?2:0;actor->threshold=3;
 if(mode&1) target->flags|=MF_SHADOW;if(mode&262144) actor->flags|=MF_JUSTHIT;if(mode&524288) actor->flags|=MF_JUSTATTACKED;if(mode&1048576) actor->flags|=MF_AMBUSH;
 target->health=(mode&256)?0:100;corpse->health=0;corpse->flags=MF_CORPSE;corpse->tics=-1;corpse->height=corpse->info->height/4;corpse->target=target;corpse->momx=123;corpse->momy=456;
 heads[16]=corpse;corpse->bnext=actor;actor->bnext=NULL;
 if(mode&64) {mobj_t *other=newobject(type,256*FRACUNIT,256*FRACUNIT,0);other->health=100;}
 if(mode&2097152) for(int i=0;i<21;i++) newobject(MT_SKULL,i*FRACUNIT,0,0);
 memset(players,0,sizeof(players));memset(playeringame,0,sizeof(playeringame));playeringame[0]=true;players[0].mo=target;players[0].health=target->health;target->player=players;
 soundtarget=target;numspechit=0;floatok=false;tmfloorz=0;corpsehit=NULL;vileobj=NULL;viletryx=-8*FRACUNIT;viletryy=8*FRACUNIT;
 numbraintargets=1;braintargets[0]=spot;braintargeton=0;
}
static void snapshot(FILE *f,int result) {
 word(f,result);word(f,prndindex);word(f,validcount);word(f,numspechit);word(f,braintargeton);word(f,numbraintargets);word(f,easyShadow);
 word(f,objectcount);for(int i=0;i<objectcount;i++) {mobj_t *m=objects+i;int32_t row[]={m->type,m->x,m->y,m->z,m->angle,m->momx,m->momy,m->momz,m->flags,m->health,m->height,m->tics,m->state?m->state-states:-1,actorid(m->target),actorid(m->tracer),m->reactiontime,m->threshold,m->movedir,m->movecount,m->lastlook,m->thinker.function.acv==(actionf_v)-1};for(int j=0;j<21;j++) word(f,row[j]);}
 for(int i=0;i<3;i++) {word(f,sectors[i].validcount);word(f,sectors[i].soundtraversed);word(f,actorid(sectors[i].soundtarget));}
 word(f,callcount/6);for(int i=0;i<callcount;i++) word(f,calls[i]);
}
