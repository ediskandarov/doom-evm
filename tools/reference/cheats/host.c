/* SPDX-License-Identifier: GPL-2.0-only
 * Original function bodies are appended verbatim by reference.py. */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "doomdef.h"
#include "doomstat.h"
#include "p_local.h"
#include "p_inter.h"
#include "g_game.h"
#include "d_event.h"
#include "m_cheat.h"
#include "dstrings.h"
#include "am_map.h"
#include "st_stuff.h"
boolean netgame, deathmatch;
int consoleplayer, god_health=100, maxammo[4]={200,50,300,50};
skill_t gameskill; GameMode_t gamemode;
player_t players[4], *plyr; mobj_t actors[4];
int d_skill,d_episode,d_map;gameaction_t gameaction;
int st_gamestate,st_firsttime;
#define ST_MSGWIDTH 52
void G_DeferedInitNew(skill_t skill,int episode,int map){d_skill=skill;d_episode=episode;d_map=map;gameaction=2;}
