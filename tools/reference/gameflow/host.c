/* SPDX-License-Identifier: GPL-2.0-only
 * Observing boundary doubles only. Algorithms are extracted verbatim below. */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include "doomdef.h"
#include "doomstat.h"
#include "p_local.h"
#include "g_game.h"
#include "m_random.h"
#include "r_main.h"
#include "r_sky.h"
#include "d_net.h"
#include "wi_stuff.h"
#include "info.h"
#include "dstrings.h"
int gametic, leveltime, consoleplayer, displayplayer, levelstarttic, starttime;
int gameepisode,gamemap, totalkills,totalitems,totalsecret, skyflatnum, skytexture;
int rndindex,prndindex, d_episode,d_map,turnheld,ticdup=1;
skill_t gameskill,d_skill; GameMode_t gamemode;
gameaction_t gameaction;gamestate_t gamestate,wipegamestate;
boolean paused,sendpause,sendsave,usergame,viewactive,automapactive,menuactive;
boolean netgame,netdemo,demoplayback,demorecording,deathmatch,respawnparm,respawnmonsters,fastparm,nomonsters,secretexit;
boolean playeringame[4]; player_t players[4]; mobj_t actors[4];
wbstartstruct_t wminfo;void *statcopy;
state_t states[NUMSTATES];mobjinfo_t mobjinfo[NUMMOBJTYPES];
int maxammo[4]={200,50,300,50};
extern int pars[4][10],cpars[32];
#define NUMKEYS 256
#define TURBOTHRESHOLD 0x32
#define MAXBOB 0x100000
#define ANG5 (ANG90/18)
boolean gamekeydown[NUMKEYS];int joyxmove,joyymove,mousex,mousey;
boolean mousearray[4],joyarray[5];boolean *mousebuttons=mousearray+1,*joybuttons=joyarray+1;
short consistancy[4][BACKUPTICS];ticcmd_t netcmds[4][BACKUPTICS];
char savedescription[32];int savegameslot;
char *player_names[4]={HUSTR_PLRGREEN,HUSTR_PLRINDIGO,HUSTR_PLRBROWN,HUSTR_PLRRED};
boolean onground;int observations[1024],tracecount;static void observe(int id){if(tracecount>=1024)abort();observations[tracecount++]=id;}
void I_Error(char *fmt,...){va_list ap;va_start(ap,fmt);vfprintf(stderr,fmt,ap);va_end(ap);exit(2);}
void G_DoLoadLevel(void);void G_DoNewGame(void);void G_DoCompleted(void);void G_DoWorldDone(void);void G_DoReborn(int);
void G_PlayerReborn(int);void G_InitPlayer(int);void G_PlayerFinishLevel(int);
void P_DeathThink(player_t*);void P_CalcHeight(player_t*);void Original_P_Ticker(void);
void S_PauseSound(void){} void S_ResumeSound(void){}
void M_ClearRandom(void){prndindex=rndindex=0;}
int R_FlatNumForName(char *name){if(strcmp(name,"F_SKY1"))abort();observe(20);return 3;}
int R_TextureNumForName(char *name){if(!strcmp(name,"SKY3")){observe(23);return 9;}if(strcmp(name,"SKY1"))abort();observe(21);return 7;}
int W_CheckNumForName(char *name){(void)name;return -1;}
int I_GetTime(void){return 123;}
void Z_CheckHeap(void){observe(3);}
void AM_Stop(void){observe(4);automapactive=false;}
void WI_Start(wbstartstruct_t *w){if(w!=&wminfo)abort();observe(5);}
void F_StartFinale(void){observe(6);gameaction=ga_nothing;gamestate=GS_FINALE;viewactive=automapactive=false;}
void ST_Ticker(void){observe(7);}void AM_Ticker(void){observe(8);}void HU_Ticker(void){observe(9);}
void WI_Ticker(void){observe(10);}void F_Ticker(void){observe(11);}
void P_Ticker(void){observe(1);Original_P_Ticker();}
void P_RunThinkers(void){observe(13);}void P_UpdateSpecials(void){observe(14);}void P_RespawnSpecials(void){observe(15);}
void P_MovePsprites(player_t *p){(void)p;observe(16);}
void P_PlayerThink(player_t *p){observe(12);if(p->playerstate==PST_DEAD)P_DeathThink(p);else if(p->cmd.buttons&BT_SPECIAL)p->cmd.buttons=0;}
angle_t R_PointToAngle2(fixed_t a,fixed_t b,fixed_t c,fixed_t d){(void)a;(void)b;(void)c;(void)d;abort();}
void P_SetupLevel(int ep,int map,int mask,skill_t skill){
 if(ep!=gameepisode||map!=gamemap||mask||skill!=gameskill)abort();observe(2);
 leveltime=totalkills=totalitems=totalsecret=0;
 for(int i=0;i<4;i++){players[i].killcount=players[i].itemcount=players[i].secretcount=0;}
 players[0].viewz=1;
 for(int i=0;i<4;i++)if(playeringame[i]){if(players[i].playerstate==PST_REBORN)G_PlayerReborn(i);players[i].mo=actors+i;players[i].playerstate=PST_LIVE;}
}
/* Excluded network/demo/save paths fail closed if the corpus reaches them. */
void G_DoLoadGame(void){abort();}void G_DoSaveGame(void){abort();}void G_DoPlayDemo(void){abort();}
void G_ReadDemoTiccmd(ticcmd_t *c){(void)c;abort();}void G_WriteDemoTiccmd(ticcmd_t *c){(void)c;abort();}
void D_PageTicker(void){abort();}void M_ScreenShot(void){abort();}
void G_DeathMatchSpawnPlayer(int p){(void)p;abort();}
boolean G_CheckSpot(int p,mapthing_t *m){(void)p;(void)m;abort();}
void P_SpawnPlayer(mapthing_t *m){(void)m;abort();}mapthing_t playerstarts[4];
