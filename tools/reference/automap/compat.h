#pragma once
#include "../video/compat.h"
#undef MININT
#undef MAXINT
#include "../../../original/DOOM/linuxdoom-1.10/doomtype.h"
#include "../../../original/DOOM/linuxdoom-1.10/tables.h"
#include "../../../original/DOOM/linuxdoom-1.10/m_cheat.h"
#include "../../../original/DOOM/linuxdoom-1.10/d_englsh.h"
#define PLAYERRADIUS (16*FRACUNIT)
#define MAPBLOCKUNITS 128
#define ML_SECRET 32
#define ML_DONTDRAW 128
#define ML_MAPPED 256
#define KEY_DOWNARROW 0xaf
#define KEY_UPARROW 0xad
#define KEY_RIGHTARROW 0xae
#define KEY_LEFTARROW 0xac
#define KEY_TAB 9
#define MAXPLAYERS 4
#define PU_STATIC 1
#define PU_CACHE 2
enum { ev_keydown, ev_keyup, ev_mouse, ev_joystick };
enum { pw_allmap, pw_invisibility };
typedef struct {int type,data1,data2,data3;} event_t;
#include "../../../original/DOOM/linuxdoom-1.10/am_map.h"
typedef struct {fixed_t x,y;} vertex_t;
typedef struct mobj_s {fixed_t x,y; angle_t angle; struct mobj_s *snext;} mobj_t;
typedef struct {fixed_t floorheight,ceilingheight; mobj_t *thinglist;} sector_t;
typedef struct {vertex_t *v1,*v2; int flags,special; sector_t *frontsector,*backsector;} line_t;
typedef struct {mobj_t *mo; int powers[2]; char *message;} player_t;
extern vertex_t *vertexes;
extern line_t *lines;
extern sector_t *sectors;
extern int numvertexes,numlines,numsectors,consoleplayer,gamemap,gameepisode;
extern int playeringame[4],netgame,deathmatch,singledemo;
extern player_t players[4];
extern fixed_t bmaporgx,bmaporgy;
void *W_CacheLumpName(char*,int);
void Z_ChangeTag(void*,int);
int ST_Responder(event_t*);
