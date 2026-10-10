// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

/// @custom:source linuxdoom-1.10/d_player.h wbplayerstruct_t, wbstartstruct_t
struct WiPlayerStats {
    bool inGame;
    int32 skills;
    int32 sitems;
    int32 ssecret;
    int32 stime;
    int32[4] frags;
    int32 score;
}

struct WiStart {
    int32 epsd;
    bool didsecret;
    int32 last;
    int32 next;
    int32 maxkills;
    int32 maxitems;
    int32 maxsecret;
    int32 maxfrags;
    int32 partime;
    int32 pnum;
    WiPlayerStats[4] plyr;
}

/// @dev Explicit original player/global boundary; caller commits latches and rndindex.
/// gamemode: shareware=0, registered=1, retail=3. Only player 0 is active.
struct WiInput {
    int32 gamemode;
    bool[4] playeringame;
    uint8[4] buttons;
    int32[4] attackdown;
    int32[4] usedown;
    uint32 rndindex;
}

/// @custom:source linuxdoom-1.10/wi_stuff.c mutable globals and anim_t fields
/// @dev No asset bytes or callbacks. Keep this state and WiInput across calls/draws.
struct WiState {
    WiStart wbs;
    int32 state; // NoState=-1, StatCount=0, ShowNextLoc=1
    int32 acceleratestage;
    int32 me;
    int32 cnt;
    int32 bcnt;
    int32 firstrefresh;
    int32[4] cnt_kills;
    int32[4] cnt_items;
    int32[4] cnt_secret;
    int32 cnt_time;
    int32 cnt_par;
    int32 cnt_pause;
    int32 sp_state;
    bool snl_pointeron;
    int32[10] animNexttic;
    int32[10] animCtr;
    bool started; // adapter lifecycle guard
    bool worldDoneRequested; // original WI_End -> G_WorldDone boundary, no progression here
}

/// @dev Borrow original authenticated patch bytes per memory context; never persist them.
struct WiGraphics {
    bytes bg;
    bytes[9] lnames;
    bytes[2] yah;
    bytes splat;
    bytes[30] anims;
    bytes wiminus;
    bytes[10] num;
    bytes percent;
    bytes finished;
    bytes entering;
    bytes kills;
    bytes secret;
    bytes sp_secret;
    bytes items;
    bytes frags;
    bytes colon;
    bytes time;
    bytes sucks;
    bytes par;
    bytes killers;
    bytes victims;
    bytes total;
    bytes star;
    bytes bstar;
    bytes[4] p;
    bytes[4] bp;
}
