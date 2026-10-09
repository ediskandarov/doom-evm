// SPDX-License-Identifier: GPL-2.0-only
// Native host for the unchanged original renderer. Platform and static scene setup only.
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "doomdef.h"
#include "doomstat.h"
#include "r_local.h"
#include "r_sky.h"
#include "w_wad.h"
#include "z_zone.h"
#include "p_local.h"
#include "info.h"

static FILE *tracefile;
void OracleTrace(const char *function,int a,int b) { if(tracefile) fprintf(tracefile,"%s %d %d\n",function,a,b); }
byte *screens[5];
int detailLevel=0, screenblocks=11;
int consoleplayer=0, displayplayer=0;

boolean demoplayback=false;
player_t players[MAXPLAYERS];

void I_Error(char *format,...) { va_list ap; va_start(ap,format); vfprintf(stderr,format,ap); va_end(ap); fputc('\n',stderr); exit(2); }

byte *I_ZoneBase(int *size) { *size=64*1024*1024;byte *p=calloc(1,(size_t)*size);if(!p) I_Error("zone allocation");return p; }
void OracleAllocation(void *p,int size) { const char *fill=getenv("DOOM_ORACLE_ALLOCATION_FILL");if(fill) memset(p,(unsigned char)strtoul(fill,NULL,0),(size_t)size); }
#include "p_tick.h"
#include "p_setup.h"
#include "g_game.h"
#include "m_random.h"
#include "s_sound.h"
#include "st_stuff.h"
#include "hu_stuff.h"
#include "am_map.h"
#include "i_system.h"
_Static_assert(sizeof(int)==4 && sizeof(short)==2 && (char)255==-1,"native integer profile");
boolean netgame=false, deathmatch=false, paused=false, menuactive=false;
boolean playeringame[MAXPLAYERS]={true,false,false,false};
boolean respawnmonsters=false, respawnparm=false, fastparm=false, nomonsters=false;
boolean precache=false, secretexit=false, automapactive=false;
int gametic=0, gameepisode=1, gamemap=1, totalkills=0,totalitems=0,totalsecret=0,bodyqueslot=0;
skill_t gameskill=sk_medium;
gameaction_t gameaction=ga_nothing;
gamestate_t gamestate=GS_LEVEL;
wbstartstruct_t wminfo;
int myargc=1; char *hostargv[]={"gameplay",NULL}; char **myargv=hostargv;
void NetUpdate(void) {}
void I_BeginRead(void) {}
void I_EndRead(void) {}
void V_MarkRect(int x,int y,int width,int height) { (void)x;(void)y;(void)width;(void)height; }
void V_DrawPatch(int x,int y,int screen,patch_t *patch) { I_Error("Unexpected border draw"); }
void S_Start(void) {}
void S_StartSound(void *origin,int sound_id) { (void)origin;(void)sound_id; }
void S_StopSound(void *origin) { (void)origin; }
void ST_Start(void) {}
void HU_Start(void) {}
void AM_Stop(void) { automapactive=false; }
void I_Tactile(int on,int off,int total) { (void)on;(void)off;(void)total; }
int M_CheckParm(char *name) { (void)name; return 0; }
void G_DeathMatchSpawnPlayer(int player) { (void)player; I_Error("Deathmatch outside native profile"); }
extern char *sprnames[];
extern int prndindex, rndindex;
static void word(FILE *file,int32_t value) { uint32_t u=(uint32_t)value; unsigned char bytes[4]={u>>24,u>>16,u>>8,u}; if(fwrite(bytes,1,4,file)!=4) I_Error("state write"); }
static const char *event_names[256];static unsigned long event_counts[256];static int event_count;
void OracleEvent(const char *name) { for(int i=0;i<event_count;i++) if(!strcmp(event_names[i],name)) {event_counts[i]++;return;} if(event_count==256) I_Error("event capacity");event_names[event_count]=name;event_counts[event_count++]=1;}
#include "observe.h"
#include "diagnostics.h"
static void snapshot(FILE *file) {
    player_t *p=players; mobj_t *m=p->mo;
    word(file,leveltime);word(file,gametic);word(file,prndindex);word(file,rndindex);
    word(file,m->x);word(file,m->y);word(file,m->z);word(file,m->angle);
    word(file,m->momx);word(file,m->momy);word(file,m->momz);
    word(file,p->viewz);word(file,p->viewheight);word(file,p->deltaviewheight);word(file,p->bob);
    word(file,m->floorz);word(file,m->ceilingz);word(file,m->subsector-subsectors);
    word(file,p->health);word(file,m->health);word(file,p->armorpoints);word(file,p->armortype);
    word(file,p->readyweapon);word(file,p->pendingweapon);word(file,p->usedown);word(file,p->attackdown);word(file,p->refire);
    word(file,m->state ? m->state-states : -1);word(file,m->tics);word(file,m->flags);
    for(int i=0;i<NUMAMMO;i++) word(file,p->ammo[i]);
    for(int i=0;i<NUMPSPRITES;i++) { pspdef_t *ps=p->psprites+i;word(file,ps->state ? ps->state-states:-1);word(file,ps->tics);word(file,ps->sx);word(file,ps->sy); }
    int count=0;for(thinker_t *t=thinkercap.next;t!=&thinkercap;t=t->next) count++;word(file,count);
    word(file,totalkills);word(file,totalitems);word(file,totalsecret);word(file,p->killcount);word(file,p->itemcount);word(file,p->secretcount);
    word(file,p->damagecount);word(file,p->bonuscount);word(file,p->extralight);word(file,p->fixedcolormap);
}
static void world_record(FILE *f) {
    long start=ftell(f);word(f,0);long payload=ftell(f);observe_world(f);long end=ftell(f);fseek(f,start,SEEK_SET);word(f,(int32_t)(end-payload));fseek(f,end,SEEK_SET);
}
static void writefile(const char *directory,const char *name,const void *data,size_t size) {
    char path[4096];snprintf(path,sizeof(path),"%s/%s",directory,name);FILE *f=fopen(path,"wb"); if(!f || fwrite(data,1,size,f)!=size) I_Error("write %s",path);fclose(f);
}
int main(int argc,char **argv) {
    if(argc!=4 && argc!=5) I_Error("gameplay WAD output-directory commands-file [ordinary|combat-arena|damage-arena|death-arena|door-use]");
    Z_Init();char *files[]={argv[1],NULL};W_InitMultipleFiles(files);gamemode=retail;gamemission=doom;
    screens[0]=calloc(1,320*200);screens[1]=calloc(1,320*200);
    char *sprite_names[NUMSPRITES+1];memcpy(sprite_names,sprnames,NUMSPRITES*sizeof(*sprite_names));sprite_names[NUMSPRITES]=NULL;
    R_Init();R_InitSprites(sprite_names);R_ExecuteSetViewSize();skyflatnum=R_FlatNumForName("F_SKY1");skytexture=R_TextureNumForName("SKY1");
    P_InitSwitchList();P_InitPicAnims();M_ClearRandom();players[0].playerstate=PST_REBORN;
    if(argc==5 && !strcmp(argv[4],"door-use")) nomonsters=true;
    P_SetupLevel(1,1,1,sk_medium);
    if(argc==5 && (!strcmp(argv[4],"door-use") || !strcmp(argv[4],"door-obstructed"))) {
        mobj_t *m=players[0].mo;if(!P_TeleportMove(m,832*FRACUNIT,576*FRACUNIT)) I_Error("Door setup blocked");m->z=m->floorz;m->angle=ANG270;
    } else if(argc==5 && strcmp(argv[4],"ordinary")) {
        if(strcmp(argv[4],"combat-arena") && strcmp(argv[4],"damage-arena") && strcmp(argv[4],"death-arena")) I_Error("Unknown scenario setup");
        // Controlled original-object spawn in actual E1M1 geometry, not a synthetic map or alternate AI.
        mobj_t *player=players[0].mo;
        mobj_t *enemy=P_SpawnMobj(player->x+64*FRACUNIT,player->y,ONFLOORZ,MT_POSSESSED);
        if(!P_CheckPosition(enemy,enemy->x,enemy->y)) I_Error("Arena enemy overlaps geometry/object");
        enemy->angle=ANG180;enemy->target=player;
        P_SetMobjState(enemy,enemy->info->seestate);
        if(!strcmp(argv[4],"damage-arena")) {players[0].armorpoints=100;players[0].armortype=1;}
        if(!strcmp(argv[4],"death-arena")) {players[0].health=3;player->health=3;}
    }
    char path[4096];snprintf(path,sizeof(path),"%s/ticks.bin",argv[2]);FILE *ticks=fopen(path,"wb");if(!ticks) I_Error("open ticks");snapshot(ticks);
    snprintf(path,sizeof(path),"%s/states.bin",argv[2]);FILE *world=fopen(path,"wb");if(!world) I_Error("open states");world_record(world);
    snprintf(path,sizeof(path),"%s/diagnostics.bin",argv[2]);FILE *diagnostics=fopen(path,"wb");if(!diagnostics) I_Error("open diagnostics");diagnostic_record(diagnostics);
    FILE *commands=fopen(argv[3],"r");if(!commands) I_Error("open commands");
    sector_t *monitor=argc==5 && (!strcmp(argv[4],"door-use") || !strcmp(argv[4],"door-obstructed")) ? lines[55].backsector:NULL;int initialDoor=monitor ? monitor->ceilingheight:-1,maxDoor=initialDoor,lastDoor=initialDoor,lastDirection=0,doorReversals=0,doorRiseTicks=0,doorFallTicks=0;
    int forward,side,angle,buttons,render;
    while(fscanf(commands,"%d %d %d %d %d",&forward,&side,&angle,&buttons,&render)==5) {
        if(forward<-50||forward>50||side<-50||side>50||angle<-32768||angle>32767||buttons<0||buttons>255) I_Error("command range");
        players[0].cmd=(ticcmd_t){.forwardmove=forward,.sidemove=side,.angleturn=angle,.buttons=buttons};
        P_Ticker();gametic++;if(monitor) { int current=monitor->ceilingheight,dir=current>lastDoor?1:(current<lastDoor?-1:0);if(dir>0) doorRiseTicks++;if(dir<0) doorFallTicks++;if(dir && lastDirection && dir!=lastDirection) doorReversals++;if(dir) lastDirection=dir;if(current>maxDoor) maxDoor=current;lastDoor=current;}snapshot(ticks);world_record(world);diagnostic_record(diagnostics);
        if(render) { R_RenderPlayerView(players);char name[80];snprintf(name,sizeof(name),"frame-%06d.bin",gametic);writefile(argv[2],name,screens[0],64000); }
    }
    if(!feof(commands)) I_Error("malformed commands");fclose(commands);fclose(ticks);fclose(world);fclose(diagnostics);
    char summary[1024];int len=snprintf(summary,sizeof(summary),"{\"tics\":%d,\"leveltime\":%d,\"prndindex\":%d,\"x\":%d,\"y\":%d,\"health\":%d,\"totalKills\":%d,\"totalItems\":%d,\"sectors\":%d,\"blockWidth\":%d,\"blockHeight\":%d,\"doorSector\":%d,\"initialDoorCeiling\":%d,\"maxDoorCeiling\":%d,\"finalDoorCeiling\":%d,\"doorRiseTicks\":%d,\"doorFallTicks\":%d,\"doorReversals\":%d}\n",gametic,leveltime,prndindex,players[0].mo->x,players[0].mo->y,players[0].health,totalkills,totalitems,numsectors,bmapwidth,bmapheight,monitor ? (int)(monitor-sectors):-1,initialDoor,maxDoor,monitor ? monitor->ceilingheight:-1,doorRiseTicks,doorFallTicks,doorReversals);writefile(argv[2],"summary.json",summary,len);
    snprintf(path,sizeof(path),"%s/events.json",argv[2]);FILE *events=fopen(path,"w");if(!events) I_Error("open events");fputs("{",events);for(int i=0;i<event_count;i++) fprintf(events,"%s\"%s\":%lu",i ? ",":"",event_names[i],event_counts[i]);fputs("}\n",events);fclose(events);
    return 0;
}
