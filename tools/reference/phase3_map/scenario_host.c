// SPDX-License-Identifier: GPL-2.0-only
// Synthetic map fixture host, using unchanged original p_map/p_maputl/p_sight units.
// Higher gameplay modules are recorded mock callbacks; full integration uses gameplay oracle.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include "doomdef.h"
#include "doomstat.h"
#include "p_local.h"
#include "r_sky.h"
#include "m_random.h"
#include "m_bbox.h"

int numvertexes,numsectors,numlines,numsubsectors,numnodes,numsegs;
vertex_t *vertexes;sector_t *sectors;line_t *lines;subsector_t *subsectors;node_t *nodes;seg_t *segs;
side_t *sides;
int validcount,bmapwidth,bmapheight;fixed_t bmaporgx,bmaporgy;
short *blockmaplump,*blockmap;mobj_t **blocklinks;byte *rejectmatrix;
fixed_t viewx,viewy;fixed_t *finecosine=&finesine[FINEANGLES/4];
int gamemap=1,leveltime;boolean netgame=false;player_t players[4];
int skyflatnum=17;state_t states[NUMSTATES];mobjinfo_t mobjinfo[NUMMOBJTYPES];
static mobj_t actors[8];static int actor_count;
static int calls[256],call_count;
static int nested_mutation;
extern mobj_t *tmthing;
extern fixed_t attackrange;
static void logcall(int op,int a,int b,int d,int e) { if(call_count+5>256)exit(3);calls[call_count++]=op;calls[call_count++]=a;calls[call_count++]=b;calls[call_count++]=d;calls[call_count++]=e; }
static int actorid(mobj_t *t) { return t?(int)(t-actors):-1; }
void I_Error(char *format,...) { va_list args;va_start(args,format);vfprintf(stderr,format,args);va_end(args);exit(2); }
void S_StartSound(void *origin,int sound) {(void)origin;(void)sound;}
void P_DamageMobj(mobj_t *t,mobj_t *inflictor,mobj_t *source,int damage) {logcall(1,actorid(t),actorid(inflictor),actorid(source),damage);t->health-=damage;if(nested_mutation==1)tmthing=actors+1;}
void P_TouchSpecialThing(mobj_t *special,mobj_t *toucher) {logcall(2,actorid(special),actorid(toucher),0,0);}
boolean P_SetMobjState(mobj_t *t,statenum_t state) {logcall(3,actorid(t),state,0,0);t->state=states+state;return true;}
void P_RemoveMobj(mobj_t *t) {logcall(4,actorid(t),0,0,0);}
void P_CrossSpecialLine(int line,int side,mobj_t *t) {logcall(5,line,side,actorid(t),0);}
void P_ShootSpecialLine(mobj_t *t,line_t *line) {logcall(6,actorid(t),(int)(line-lines),0,0);if(nested_mutation==2)attackrange=64*FRACUNIT;}
boolean P_UseSpecialLine(mobj_t *t,line_t *line,int side) {logcall(7,actorid(t),(int)(line-lines),side,0);return true;}
void P_SpawnPuff(fixed_t x,fixed_t y,fixed_t z) {logcall(8,x,y,z,0);}
void P_SpawnBlood(fixed_t x,fixed_t y,fixed_t z,int damage) {logcall(9,x,y,z,damage);}
mobj_t *P_SpawnMobj(fixed_t x,fixed_t y,fixed_t z,mobjtype_t type) {if(actor_count==8)exit(3);mobj_t *t=actors+actor_count++;memset(t,0,sizeof(*t));t->x=x;t->y=y;t->z=z;t->type=type;logcall(10,x,y,z,type);return t;}
extern fixed_t tmbbox[4],tmx,tmy,tmfloorz,tmceilingz,tmdropoffz,opentop,openbottom,openrange,lowfloor;
extern boolean floatok,nofit,crushchange;extern mobj_t *tmthing,*slidemo,*shootthing,*linetarget,*usething,*bombspot,*bombsource;
extern line_t *ceilingline,*spechit[8],*bestslideline,*secondslideline;
extern int numspechit,la_damage,bombdamage;
extern fixed_t bestslidefrac,secondslidefrac,tmxmove,tmymove,shootz,attackrange,aimslope,sightzstart,topslope,bottomslope,t2x,t2y;
extern intercept_t intercepts[128],*intercept_p;extern divline_t trace,strace;extern boolean earlyout;extern int prndindex,rndindex,sightcounts[2];
extern void P_SlideMove(mobj_t *);extern boolean P_ChangeSector(sector_t *,boolean);
static vertex_t vs[4];static sector_t ss[2];static line_t ls[2];static subsector_t subs[1];static seg_t sg[2];static short bm[23];static mobj_t *heads[16];static byte reject[1];
static void wall(int id,int x,boolean two) {
    vertex_t *v=vs+2*id;v[0].x=v[1].x=x*FRACUNIT;v[0].y=128*FRACUNIT;v[1].y=-128*FRACUNIT;
    line_t *l=ls+id;memset(l,0,sizeof(*l));l->v1=v;l->v2=v+1;l->dy=-256*FRACUNIT;l->slopetype=ST_VERTICAL;l->frontsector=ss;l->backsector=two?ss+1:NULL;l->flags=two?ML_TWOSIDED:0;l->sidenum[1]=two?0:-1;
    l->bbox[BOXLEFT]=l->bbox[BOXRIGHT]=x*FRACUNIT;l->bbox[BOXTOP]=128*FRACUNIT;l->bbox[BOXBOTTOM]=-128*FRACUNIT;
    sg[id].linedef=l;sg[id].frontsector=ss;sg[id].backsector=l->backsector;
}
static void setup(int op,int variant) {
    memset(actors,0,sizeof(actors));memset(players,0,sizeof(players));memset(ss,0,sizeof(ss));memset(heads,0,sizeof(heads));memset(reject,0,sizeof(reject));memset(sg,0,sizeof(sg));
    actor_count=2;call_count=0;nested_mutation=0;validcount=0;leveltime=0;gamemap=1;M_ClearRandom();
    vertexes=vs;numvertexes=4;sectors=ss;numsectors=2;lines=ls;numlines=2;subsectors=subs;numsubsectors=1;nodes=NULL;numnodes=0;segs=sg;numsegs=2;
    ss[0].ceilingheight=ss[1].ceilingheight=128*FRACUNIT;ss[0].ceilingpic=ss[1].ceilingpic=0;
    ss[0].blockbox[BOXLEFT]=0;ss[0].blockbox[BOXRIGHT]=3;ss[0].blockbox[BOXBOTTOM]=0;ss[0].blockbox[BOXTOP]=3;
    wall(0,64,false);wall(1,-64,true);subs[0]=(subsector_t){.sector=ss,.numlines=2,.firstline=0};
    bmapwidth=bmapheight=4;bmaporgx=bmaporgy=-256*FRACUNIT;blockmaplump=bm;blockmap=bm+4;blocklinks=heads;rejectmatrix=reject;
    bm[0]=-256;bm[1]=-256;bm[2]=bm[3]=4;for(int i=4;i<20;i++)bm[i]=20;bm[20]=0;bm[21]=1;bm[22]=-1;
    for(int i=0;i<2;i++){mobj_t *t=actors+i;t->radius=16*FRACUNIT;t->height=56*FRACUNIT;t->health=100;t->flags=MF_SOLID|MF_SHOOTABLE;t->type=i?MT_POSSESSED:MT_PLAYER;t->info=mobjinfo+t->type;t->floorz=0;t->ceilingz=128*FRACUNIT;t->state=states+S_PLAY;t->target=NULL;}
    actors[0].flags|=MF_PICKUP;actors[0].player=players;players[0].mo=actors;actors[1].x=32*FRACUNIT;
    mobjinfo[MT_PLAYER].damage=3;mobjinfo[MT_PLAYER].spawnstate=S_PLAY;
    tmbbox[0]=tmbbox[1]=tmbbox[2]=tmbbox[3]=0;tmthing=slidemo=shootthing=linetarget=usething=bombspot=bombsource=NULL;
    tmx=tmy=tmfloorz=tmceilingz=tmdropoffz=opentop=openbottom=openrange=lowfloor=0;floatok=nofit=crushchange=0;
    ceilingline=bestslideline=secondslideline=NULL;numspechit=la_damage=bombdamage=0;memset(spechit,0,sizeof(spechit));
    bestslidefrac=secondslidefrac=tmxmove=tmymove=shootz=attackrange=aimslope=sightzstart=topslope=bottomslope=t2x=t2y=0;
    intercept_p=intercepts;memset(intercepts,0,sizeof(intercepts));memset(&trace,0,sizeof(trace));memset(&strace,0,sizeof(strace));earlyout=0;sightcounts[0]=sightcounts[1]=0;
    if(op<=1){
        if(variant>=2&&variant<=9)actors[1].flags=0;
        if(variant>=3&&variant<=8)wall(0,64,true);
        if(variant==3)ls[0].flags|=ML_BLOCKING;
        if(variant==4)ss[1].floorheight=24*FRACUNIT;
        if(variant==5)ss[1].floorheight=25*FRACUNIT;
        if(variant==6)ss[1].ceilingheight=55*FRACUNIT;
        if(variant==7)actors[0].flags|=MF_NOCLIP;
        if(variant==8){ss[1].floorheight=-25*FRACUNIT;actors[0].flags|=MF_FLOAT;}
        if(variant==10||variant==11){actors[0].flags=MF_MISSILE;actors[0].radius=6*FRACUNIT;actors[0].target=variant==11?actors+1:actors;}
        if(variant==12)actors[0].flags|=MF_SKULLFLY;
        if(variant==13||variant==14){actors[1].x=24*FRACUNIT;actors[1].flags=MF_SPECIAL|(variant==14?MF_SOLID:0);}
        if(variant==15){actors[1].flags=0;wall(0,40,true);wall(1,48,true);ls[0].special=7;ls[1].special=9;}
        if(variant==16){actors[0].flags|=MF_SKULLFLY;nested_mutation=1;}
    } else if(op==2){if(variant==1)actors[0].player=NULL;if(variant==2){actors[0].player=NULL;gamemap=30;}if(variant==3)actors[1].flags=MF_SOLID;}
    else if(op==3){actors[1].flags=0;actors[0].momx=80*FRACUNIT;actors[0].momy=(variant?16:0)*FRACUNIT;}
    else if(op==4||op==5){if(variant==1)actors[1].z=80*FRACUNIT;if(variant==2)actors[1].flags=0;if(variant==3)actors[1].flags|=MF_NOBLOOD;if(variant==4){actors[1].flags=0;ss[0].ceilingpic=17;ss[0].ceilingheight=16*FRACUNIT;}if(variant==5)ls[0].special=46;if(variant==6){actors[1].flags=0;wall(0,64,true);ls[0].special=46;ss[1].ceilingheight=48*FRACUNIT;nested_mutation=2;}}
    else if(op==6){actors[1].flags=0;if(variant)ls[0].special=1;}
    else if(op==7){if(variant==1)actors[1].type=MT_CYBORG;if(variant==2)actors[1].x=200*FRACUNIT;if(variant==3)reject[0]=1;}
    else if(op==8){ss[0].ceilingheight=48*FRACUNIT;if(variant==1)actors[1].health=0;if(variant==2)actors[1].flags|=MF_DROPPED;if(variant==3)actors[1].flags=0;}
    else if(op==9){if(variant==2)actors[0].flags|=MF_NOSECTOR|MF_NOBLOCKMAP;if(variant==3)actors[0].flags|=MF_NOSECTOR;}
    else if(op==10){actors[1].flags=0;if(variant==1)wall(1,64,true);}
    for(int i=0;i<2;i++)P_SetThingPosition(actors+i);
}
static void word(int32_t value) {uint32_t u=(uint32_t)value;unsigned char b[4]={u>>24,u>>16,u>>8,u};if(fwrite(b,1,4,stdout)!=4)exit(3);}
static void record(int result) {
    word(result);word(floatok);word(tmfloorz);word(tmceilingz);word(tmdropoffz);word(ceilingline?(int)(ceilingline-lines):-1);word(numspechit);word(prndindex);word(validcount);word(actor_count);
    for(int i=0;i<actor_count;i++){mobj_t *t=actors+i;word(t->x);word(t->y);word(t->z);word(t->momx);word(t->momy);word(t->momz);word(t->floorz);word(t->ceilingz);word(t->flags);word(t->health);word(t->radius);word(t->height);word(t->state?(int)(t->state-states):-1);word(actorid(t->snext));word(actorid(t->sprev));word(actorid(t->bnext));word(actorid(t->bprev));}
    word(linetarget?actorid(linetarget):-1);word(aimslope);word((int)(intercept_p-intercepts));word(nofit);word(sightcounts[0]);word(sightcounts[1]);word(actorid(ss[0].thinglist));word(actorid(ss[1].thinglist));
    for(int i=0;i<16;i++)word(actorid(heads[i]));word(call_count);for(int i=0;i<call_count;i++)word(calls[i]);
}
static boolean path_callback(intercept_t *hit) {logcall(11,hit->d.line-lines,hit->frac,hit->isaline,0);return true;}
int main(void) {int op,variant;while(scanf("%d %d",&op,&variant)==2){setup(op,variant);int result=0;
    if(op<=1){int x=variant==0?0:variant==1||variant==13||variant==14?8:variant>=10&&variant<=12||variant==16?32:variant==15?60:50;result=op?P_TryMove(actors,x*FRACUNIT,0):P_CheckPosition(actors,x*FRACUNIT,0);}
    else if(op==2)result=P_TeleportMove(actors,32*FRACUNIT,0);
    else if(op==3)P_SlideMove(actors);
    else if(op==4)result=P_AimLineAttack(actors,0,128*FRACUNIT);
    else if(op==5){fixed_t slope=P_AimLineAttack(actors,0,128*FRACUNIT);P_LineAttack(actors,0,128*FRACUNIT,variant==6?FRACUNIT/4:slope,7);}
    else if(op==6)P_UseLines(players);
    else if(op==7)P_RadiusAttack(actors,NULL,64);
    else if(op==8)result=P_ChangeSector(ss,variant!=4);
    else if(op==9){if(variant==0)P_UnsetThingPosition(actors+1);else{P_UnsetThingPosition(actors);actors[0].x=1000*FRACUNIT;P_SetThingPosition(actors);}}
    else if(op==10)result=P_PathTraverse(-128*FRACUNIT,0,variant==3?10000*FRACUNIT:128*FRACUNIT,0,variant==2?PT_ADDLINES|PT_EARLYOUT:PT_ADDLINES,path_callback);
    else exit(3);record(result);
}return 0;}
