#pragma once
/* Declaration-only platform prelude. Original WI/video/RNG bodies are unchanged. */
#include "../video/compat.h"
#undef MININT
#undef MAXINT
#include "doomtype.h"
#define __D_STATE__
#define __G_GAME__
#define __Z_ZONE__
#define __W_WAD__
#define __S_SOUND__
#define __SOUNDS__
#define MAXPLAYERS 4
#define TICRATE 35
#define PU_STATIC 1
#define PU_CACHE 101
enum {shareware,registered,commercial,retail,indetermined};
enum {BT_ATTACK=1,BT_USE=2};
enum {mus_dm2int,mus_inter,sfx_barexp,sfx_pistol,sfx_sgcock,sfx_pldeth,sfx_slop};
typedef struct {int type,data1,data2,data3;} event_t;
typedef struct {unsigned char buttons;} ticcmd_t;
typedef struct {ticcmd_t cmd; int attackdown,usedown;} player_t;
typedef struct {boolean in;int skills,sitems,ssecret,stime,frags[4],score;} wbplayerstruct_t;
typedef struct {int epsd;boolean didsecret;int last,next,maxkills,maxitems,maxsecret,maxfrags,partime,pnum;wbplayerstruct_t plyr[4];} wbstartstruct_t;
extern int gamemode,netgame,deathmatch,french;
extern boolean playeringame[4];
extern player_t players[4];
void *W_CacheLumpName(char*,int);
void *Z_Malloc(int,int,void*);
void Z_Free(void*);
void Z_ChangeTag(void*,int);
void S_StartSound(void*,int);
void S_ChangeMusic(int,boolean);
void G_WorldDone(void);
