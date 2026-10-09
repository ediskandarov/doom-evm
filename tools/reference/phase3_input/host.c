/* SPDX-License-Identifier: GPL-2.0-only
 * Host globals/stubs only. G_BuildTiccmd is extracted verbatim by reference.py. */
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "doomdef.h"
#include "doomtype.h"
#include "d_ticcmd.h"
#include "d_event.h"
#include "m_fixed.h"
_Static_assert(CHAR_MIN == -128 && sizeof(short) == 2 && sizeof(int) == 4,
               "Unreviewed native integer ABI");
int key_up = 1, key_down = 2, key_strafeleft = 3, key_straferight = 4;
int key_left = 5, key_right = 6, key_use = 7, key_fire = 8;
int key_speed = 9, key_strafe = 10;
boolean gamekeydown[256];
boolean mousearray[4], joyarray[5];
boolean *mousebuttons = &mousearray[1], *joybuttons = &joyarray[1];
int mousebfire = -1, mousebstrafe = -1, mousebforward = -1;
int joybfire = -1, joybstrafe = -1, joybuse = -1, joybspeed = -1;
int mousex, mousey, joyxmove, joyymove;
int dclicktime, dclickstate, dclicks, dclicktime2, dclickstate2, dclicks2;
int turnheld, ticdup = 1, consoleplayer, maketic, savegameslot;
boolean sendpause, sendsave;
static ticcmd_t base;
static ticcmd_t *I_BaseTiccmd(void) { return &base; }
static byte HU_dequeueChatChar(void) { return 0; }
