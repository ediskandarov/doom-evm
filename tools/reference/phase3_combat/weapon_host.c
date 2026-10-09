/* SPDX-License-Identifier: GPL-2.0-only */
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "doomdef.h"
#include "d_event.h"
#include "p_local.h"
#include "doomstat.h"
#include "m_random.h"
#include "s_sound.h"
#include "sounds.h"
player_t players[MAXPLAYERS];
GameMode_t gamemode = commercial;
int leveltime;
fixed_t viewx, viewy;
fixed_t *finecosine = &finesine[FINEANGLES / 4];
mobj_t *linetarget;
extern int prndindex;
static mobj_t actor, victim, missile;
static int hit;
static uint32_t shotcount, linehash, aimcount, aimhash, missilecount, missilehash;
static uint32_t noisecount, spawncount, damagecount, damagehash;
static uint32_t mix(uint32_t hash, uint32_t value) { return (hash ^ value) * 16777619u; }
void I_Error(char *error, ...) { (void)error; abort(); }
void S_StartSound(void *origin, int sound) { (void)origin; (void)sound; }
boolean P_SetMobjState(mobj_t *mo, statenum_t state) {
    mo->state = &states[state]; mo->tics = states[state].tics; return state != 0;
}
void P_NoiseAlert(mobj_t *target, mobj_t *emitter) { (void)target; (void)emitter; ++noisecount; }
fixed_t P_AimLineAttack(mobj_t *mo, angle_t angle, fixed_t range) {
    (void)mo; ++aimcount; aimhash = mix(mix(aimhash,angle),range);
    linetarget = hit ? &victim : NULL; return 12345;
}
void P_LineAttack(mobj_t *mo, angle_t angle, fixed_t range, fixed_t slope, int damage) {
    (void)mo; ++shotcount;
    linehash = mix(mix(mix(mix(linehash,angle),range),slope),damage);
    linetarget = hit ? &victim : NULL;
}
void P_SpawnPlayerMissile(mobj_t *mo, mobjtype_t type) {
    (void)mo; ++missilecount; missilehash = mix(missilehash,type);
}
mobj_t *P_SpawnMobj(fixed_t x, fixed_t y, fixed_t z, mobjtype_t type) {
    (void)x; (void)y; (void)z; (void)type; ++spawncount; return &missile;
}
void P_DamageMobj(mobj_t *target, mobj_t *inflictor, mobj_t *source, int damage) {
    (void)target; (void)inflictor; (void)source; ++damagecount; damagehash = mix(damagehash,damage);
}
