#pragma once
#include "../video/compat.h"
#include <ctype.h>
#define HU_FONTSTART 33
#define HU_FONTSIZE 63
#define MAXPLAYERS 4
#define PU_CACHE 101
#define TEXTSPEED 3
#define TEXTWAIT 250
#define true 1
#define false 0
typedef int boolean;
enum {shareware,registered,commercial,retail,indetermined};
enum {ga_nothing,ga_loadlevel,ga_newgame,ga_loadgame,ga_savegame,ga_playdemo,ga_completed,ga_victory,ga_worlddone};
enum {GS_LEVEL,GS_INTERMISSION,GS_FINALE};
enum {mus_victor,mus_read_m,mus_bunny};
struct {struct {unsigned char buttons;} cmd;} players[4];
int gameaction,gamestate,gamemode,gameepisode=1,gamemap=8,viewactive,automapactive,wipegamestate;
int finalestage,finalecount;
char *finaleflat,*finaletext;
patch_t *hu_font[HU_FONTSIZE];
void *W_CacheLumpName(char*,int);
void S_ChangeMusic(int x,int y) {(void)x;(void)y;}
void S_StartMusic(int x) {(void)x;}
void F_StartCast(void) {abort();}
void F_CastTicker(void) {abort();}
void F_CastDrawer(void) {abort();}
void F_BunnyScroll(void) {abort();}
