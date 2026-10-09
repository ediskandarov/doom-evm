// SPDX-License-Identifier: GPL-2.0-only
// Additional original special-dispatch globals for the independent world mover fixture host.
#include "g_game.h"
#include "m_argv.h"
#include "sounds.h"
typedef struct {boolean istexture;int picnum,basepic,numpics,speed;} anim_t;
anim_t anims[32],*lastanim=anims;
int texturetranslations[3],flattranslations[8];
int *texturetranslation=texturetranslations,*flattranslation=flattranslations;
int switchlist[MAXSWITCHES*2],numswitches;
button_t buttonlist[MAXBUTTONS];
#define MAXLINEANIMS 64
short numlinespecials;line_t *linespeciallist[MAXLINEANIMS];
boolean levelTimer;int levelTimeCount,totalsecret;
GameMode_t gamemode=shareware;gameaction_t gameaction;boolean secretexit;
boolean deathmatch=false;int myargc=1;static char *argv_data[]={"world-specials",NULL};char **myargv=argv_data;
fixed_t *finecosine=&finesine[FINEANGLES/4];
int M_CheckParm(char *name){(void)name;return 0;}
int W_CheckNumForName(char *name){(void)name;return -1;}
void G_ExitLevel(void){secretexit=false;gameaction=ga_completed;}
void G_SecretExitLevel(void){secretexit=gamemode!=commercial;gameaction=ga_completed;}
void P_MobjThinker(mobj_t *m){(void)m;}
mobj_t *P_SpawnMobj(fixed_t x,fixed_t y,fixed_t z,mobjtype_t type){(void)x;(void)y;(void)z;(void)type;I_Error("Unexpected teleport marker in dispatch fixture");return NULL;}
boolean P_TeleportMove(mobj_t *m,fixed_t x,fixed_t y){(void)m;(void)x;(void)y;I_Error("Unexpected teleport move in dispatch fixture");return false;}
void P_DamageMobj(mobj_t *m,mobj_t *inflictor,mobj_t *source,int damage){(void)inflictor;(void)source;m->health-=damage;if(m->player)m->player->health-=damage;}
static int _overlay_line(line_t *line){return line?(int)(line-lines):-1;}
static int _overlay_sector(void *soundorg){return soundorg?(int)(((sector_t*)((char*)soundorg - offsetof(sector_t,soundorg)))-sectors):-1;}
static void overlay(void){
    snapshot_size=0;append(gameaction);append(secretexit);append(totalsecret);append(levelTimer);append(levelTimeCount);append(numswitches);
    for(int i=0;i<numswitches*2+1;i++)append(switchlist[i]);
    for(int i=0;i<6;i++){append(sides[i].textureoffset);append(sides[i].rowoffset);append(sides[i].toptexture);append(sides[i].midtexture);append(sides[i].bottomtexture);}
    for(int i=0;i<16;i++){button_t *b=buttonlist+i;append(b->btimer);append(_overlay_line(b->line));append(b->where);append(b->btexture);append(_overlay_sector(b->soundorg));}
    append(numlinespecials);for(int i=0;i<numlinespecials;i++)append(linespeciallist[i]-lines);
    outputword(snapshot_size);for(unsigned i=0;i<snapshot_size;i++)outputword(snapshot_words[i]);
}
