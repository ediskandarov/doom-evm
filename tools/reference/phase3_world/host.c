/* SPDX-License-Identifier: GPL-2.0-only
 * Original world algorithms run unchanged. Synthetic topology and a declared
 * changeSector hook isolate mover logic; full-world collision remains separate. */
#include <limits.h>
#include <stdint.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <setjmp.h>
#include "doomdef.h"
#include "p_local.h"
#include "doomstat.h"
#include "m_random.h"
#include "s_sound.h"
#include "z_zone.h"
#include "i_system.h"
static sector_t sector_data[4];
static side_t side_data[6];
static line_t line_data[3];
sector_t *sectors=sector_data;
side_t *sides=side_data;
line_t *lines=line_data;
void T_FireFlicker(fireflicker_t*);
int numsectors = 4, numsides = 6, numlines = 3;
int leveltime;
player_t players[MAXPLAYERS];
thinker_t thinkercap;
fixed_t heights[3] = {32*FRACUNIT,64*FRACUNIT,24*FRACUNIT};
fixed_t *textureheight = heights;
extern int prndindex;
extern ceiling_t *activeceilings[MAXCEILINGS];
extern plat_t *activeplats[MAXPLATS];
static line_t *sectorlines[4][2];
static mobj_t actor;
static int obstruction, change_calls, return_value;
static int constructor_op, constructor_kind;
static uint32_t change_hash;
typedef struct {void *pointer;int size;int kind;int freed;} block_t;
static block_t blocks[128];
static int blockcount;
static int allocation_fill, expect_error;
static jmp_buf error_escape;
static const char *last_error;
static uint32_t snapshot_words[2048];
static unsigned snapshot_size;
static uint32_t mix(uint32_t h,uint32_t v){return(h^v)*16777619u;}
void I_Error(char *error,...){if(expect_error){last_error=error;longjmp(error_escape,1);}fprintf(stderr,"native I_Error: %s\n",error);abort();}
void S_StartSound(void *origin,int sound){(void)origin;(void)sound;}
void *Z_Malloc(int size,int tag,void *user){
    (void)tag;(void)user;if(blockcount>=128)abort();
    void *p=malloc(size);if(!p)abort();memset(p,allocation_fill,size);blocks[blockcount++]=(block_t){p,size,-1,0};return p;
}
void Z_Free(void *pointer){
    for(int i=0;i<blockcount;++i)if(blocks[i].pointer==pointer){blocks[i].freed=1;return;}
    abort();
}
boolean P_ChangeSector(sector_t *sector,boolean crush){
    ++change_calls;
    change_hash=mix(mix(mix(mix(change_hash,sector-sectors),sector->floorheight),sector->ceilingheight),crush!=0);
    if(obstruction==0)return false;
    if(obstruction==1)return true;
    if(obstruction==2)return(change_calls&1)!=0;
    return leveltime>=10&&leveltime<30;
}
static void outputword(uint32_t u){for(int s=24;s>=0;s-=8)putchar((u>>s)&255);}
static void append(int32_t v){if(snapshot_size>=2048)abort();snapshot_words[snapshot_size++]=(uint32_t)v;}
static int identity(void *pointer){
    if(!pointer)return -1;if(pointer==&thinkercap)return 0;
    for(int i=0;i<blockcount;++i)if(pointer==blocks[i].pointer)return i+1;
    abort();
}
static void classify(void){
    for(int i=0;i<blockcount;++i){
        if(blocks[i].kind!=-1)continue;
        actionf_p1 f=((thinker_t*)blocks[i].pointer)->function.acp1;
        if(f==(actionf_p1)T_VerticalDoor)blocks[i].kind=2;
        else if(f==(actionf_p1)T_MoveFloor)blocks[i].kind=3;
        else if(f==(actionf_p1)T_MoveCeiling)blocks[i].kind=4;
        else if(f==(actionf_p1)T_PlatRaise)blocks[i].kind=5;
        else if(f==(actionf_p1)T_FireFlicker)blocks[i].kind=6;
        else if(f==(actionf_p1)T_LightFlash)blocks[i].kind=7;
        else if(f==(actionf_p1)T_StrobeFlash)blocks[i].kind=8;
        else if(f==(actionf_p1)T_Glow)blocks[i].kind=9;
        else abort();
    }
}
static void snapshot(void){
    classify();snapshot_size=0;
    append(return_value);append(prndindex);append(change_calls);append(change_hash);append(leveltime);append(blockcount+1);
    for(int i=0;i<4;++i){
        sector_t*s=&sectors[i];append(s->floorheight);append(s->ceilingheight);append(s->lightlevel);append(s->floorpic);
        append(s->special);append(s->tag);append(identity(s->specialdata));
    }
    for(int i=0;i<3;++i)append(lines[i].special);
    int live=0;for(thinker_t*t=thinkercap.next;t!=&thinkercap;t=t->next)++live;
    append(live);
    for(thinker_t*t=thinkercap.next;t!=&thinkercap;t=t->next){
        int id=identity(t),kind=blocks[id-1].kind;
        int status=t->function.acp1==(actionf_p1)-1?2:t->function.acp1?0:1;
        append(id);append(kind);append(status);append(identity(t->prev));append(identity(t->next));
        switch(kind){
          case 2:{vldoor_t*p=(vldoor_t*)t;int uninitialized=constructor_op==3&&constructor_kind==0;append(p->sector-sectors);append(p->type);append(uninitialized?0:p->topheight);append(p->speed);append(p->direction);append(uninitialized?0:p->topwait);append(p->topcountdown);break;}
          case 3:{floormove_t*p=(floormove_t*)t;int uninitialized=constructor_op==8;append(p->sector-sectors);append(uninitialized?0:p->type);append(uninitialized?0:p->crush);append(p->direction);append(p->newspecial);append(p->texture);append(p->floordestheight);append(p->speed);break;}
          case 4:{ceiling_t*p=(ceiling_t*)t;append(p->sector-sectors);append(p->type);append(p->bottomheight);append(p->topheight);append(p->speed);append(p->crush);append(p->direction);append(p->tag);append(p->olddirection);break;}
          case 5:{plat_t*p=(plat_t*)t;append(p->sector-sectors);append(p->speed);append(p->low);append(p->high);append(p->wait);append(p->count);append(p->status);append(p->oldstatus);append(p->crush);append(p->tag);append(p->type);break;}
          case 6:{fireflicker_t*p=(fireflicker_t*)t;append(p->sector-sectors);append(p->count);append(p->maxlight);append(p->minlight);break;}
          case 7:{lightflash_t*p=(lightflash_t*)t;append(p->sector-sectors);append(p->count);append(p->maxlight);append(p->minlight);append(p->maxtime);append(p->mintime);break;}
          case 8:{strobe_t*p=(strobe_t*)t;append(p->sector-sectors);append(p->count);append(p->minlight);append(p->maxlight);append(p->darktime);append(p->brighttime);break;}
          case 9:{glow_t*p=(glow_t*)t;append(p->sector-sectors);append(p->minlight);append(p->maxlight);append(p->direction);break;}
          default:abort();
        }
    }
    for(int i=0;i<MAXCEILINGS;++i)append(identity(activeceilings[i]));
    for(int i=0;i<MAXPLATS;++i)append(identity(activeplats[i]));
    // Pickup/door lock messages are hashed as bytes with original default English strings.
    uint32_t h=0;if(players[0].message){h=2166136261u;for(const unsigned char*p=(void*)players[0].message;*p;++p)h=mix(h,*p);}
    append(h);
    outputword(snapshot_size);for(unsigned i=0;i<snapshot_size;++i)outputword(snapshot_words[i]);
}
static void setup(int32_t a[8]){
    for(int i=0;i<blockcount;++i)free(blocks[i].pointer);blockcount=0;
    memset(sectors,0,sizeof(sector_data));memset(sides,0,sizeof(side_data));memset(lines,0,sizeof(line_data));
    memset(players,0,sizeof(players));memset(&actor,0,sizeof(actor));
    memset(activeceilings,0,sizeof(ceiling_t*)*MAXCEILINGS);memset(activeplats,0,sizeof(plat_t*)*MAXPLATS);
    const int floor[4]={0,16,-16,32},ceil[4]={64,128,96,160},light[4]={160,128,64,192},pic[4]={3,3,5,7};
    for(int i=0;i<4;++i){sectors[i].floorheight=floor[i]*FRACUNIT;sectors[i].ceilingheight=ceil[i]*FRACUNIT;
        sectors[i].lightlevel=a[7]?160:light[i];sectors[i].floorpic=pic[i];sectors[i].special=i?9:5;sectors[i].tag=i<2?7:0;}
    const int front[3]={2,0,1},back[3]={0,1,3};
    for(int i=0;i<3;++i){line_t*l=&lines[i];l->flags=ML_TWOSIDED;l->frontsector=&sectors[front[i]];l->backsector=&sectors[back[i]];
        l->sidenum[0]=i*2;l->sidenum[1]=i*2+1;sides[i*2].sector=l->frontsector;sides[i*2+1].sector=l->backsector;
        sides[i*2].bottomtexture=0;sides[i*2+1].bottomtexture=i%3;}
    sectorlines[0][0]=&lines[0];sectorlines[0][1]=&lines[1];sectors[0].lines=sectorlines[0];sectors[0].linecount=2;
    sectorlines[1][0]=&lines[1];sectorlines[1][1]=&lines[2];sectors[1].lines=sectorlines[1];sectors[1].linecount=2;
    sectorlines[2][0]=&lines[0];sectors[2].lines=sectorlines[2];sectors[2].linecount=1;
    sectorlines[3][0]=&lines[2];sectors[3].lines=sectorlines[3];sectors[3].linecount=1;
    lines[0].tag=7;lines[0].special=a[1];
    actor.player=a[3]?NULL:&players[0];players[0].mo=&actor;
    for(int i=0;i<NUMCARDS;++i)players[0].cards[i]=(a[4]>>i)&1;
    obstruction=a[2];change_calls=0;change_hash=2166136261u;return_value=0;leveltime=0;prndindex=a[5];
    constructor_op=a[0];constructor_kind=a[1];
    P_InitThinkers();
    if(a[0]==8&&a[7]==2){
        lines[0].frontsector=&sectors[0];lines[0].backsector=&sectors[2];sides[0].sector=&sectors[0];sides[1].sector=&sectors[2];
        sectors[2].floorpic=3;sectorlines[0][0]=&lines[1];sectorlines[0][1]=&lines[0];
        floormove_t*f=Z_Malloc(sizeof(*f),PU_LEVSPEC,0);P_AddThinker(&f->thinker);f->thinker.function.acp1=NULL;f->sector=&sectors[1];sectors[1].specialdata=f;blocks[0].kind=3;
    }
}
