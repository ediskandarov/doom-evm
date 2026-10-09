/* SPDX-License-Identifier: GPL-2.0-only
 * Isolated original-function oracle. Cyclic engine hooks are declared test doubles.
 * Full-world differential acceptance lives in tools/reference/gameplay. */
#include <limits.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "doomdef.h"
#include "dstrings.h"
#include "p_local.h"
#include "doomstat.h"
#include "m_random.h"
#include "s_sound.h"
#include "sounds.h"
#include "i_system.h"
#include "am_map.h"
_Static_assert(sizeof(int) == 4 && CHAR_MIN == -128, "native integer ABI");
player_t players[MAXPLAYERS];
GameMode_t gamemode;
skill_t gameskill;
boolean netgame, deathmatch, automapactive;
int consoleplayer;
extern int prndindex;
fixed_t *finecosine = &finesine[FINEANGLES / 4];
static mobj_t actors[16];
static subsector_t subsector;
static sector_t sector;
static int removed, spawnedtype;
void I_Error(char *error, ...) { (void)error; abort(); }
void I_Tactile(int on, int off, int total) { (void)on; (void)off; (void)total; }
void AM_Stop(void) { automapactive = false; }
void S_StartSound(void *origin, int sound) { (void)origin; (void)sound; }
void P_SetPsprite(player_t *player, int slot, statenum_t state) {
    player->psprites[slot].state = state ? &states[state] : NULL;
    if (state) player->psprites[slot].tics = states[state].tics;
}
void P_DropWeapon(player_t *player) { P_SetPsprite(player, 0, weaponinfo[player->readyweapon].downstate); }
boolean P_SetMobjState(mobj_t *actor, statenum_t state) {
    actor->state = state ? &states[state] : NULL;
    actor->tics = states[state].tics;
    return state != 0;
}
void P_RemoveMobj(mobj_t *actor) { (void)actor; removed = 1; }
mobj_t *P_SpawnMobj(fixed_t x, fixed_t y, fixed_t z, mobjtype_t type) {
    mobj_t *actor = &actors[2];
    actor->x = x; actor->y = y; actor->z = z; actor->type = type;
    actor->info = &mobjinfo[type]; actor->flags = mobjinfo[type].flags;
    spawnedtype = type;
    return actor;
}
// No inflictor in the isolated damage fixture; live geometry/thrust proven in full oracle.
angle_t R_PointToAngle2(fixed_t x, fixed_t y, fixed_t xx, fixed_t yy) {
    (void)x; (void)y; (void)xx; (void)yy; abort();
}
