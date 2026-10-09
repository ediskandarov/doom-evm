// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

// Copyright (C) 1993-1996 by id Software, Inc.
// Original: linuxdoom-1.10/d_ticcmd.h, ticcmd_t. Preserve original field spelling.
struct Ticcmd {
    int8 forwardmove;
    int8 sidemove;
    int16 angleturn;
    int16 consistancy;
    uint8 chatchar;
    uint8 buttons;
}

// Persistent keyboard turn acceleration from g_game.c. One command = one tic (ticdup = 1).
struct GameInputState {
    int32 turnheld;
}

struct KeyboardInput {
    bool up;
    bool down;
    bool strafeleft;
    bool straferight;
    bool left;
    bool right;
    bool use;
    bool fire;
    bool speed;
    bool strafe;
    // Original digit key: 0 = no key; 1..8 select; original digit 9 has no effect.
    uint8 weaponRequest;
}
