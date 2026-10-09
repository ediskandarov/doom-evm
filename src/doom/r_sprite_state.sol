// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;

/// @custom:source linuxdoom-1.10/r_defs.h spriteframe_t, spritedef_t
struct SpriteFrame {
    int32 rotate; // -1 is the original uninitialized-frame sentinel.
    int16[8] lump;
    uint8[8] flip;
}

struct SpriteDef {
    SpriteFrame[] frames;
}

/// @custom:source linuxdoom-1.10/p_mobj.h mobj_t renderer fields
/// @dev Index links preserve original sector thinglist order; 0xffffffff is NULL.
struct RenderThing {
    int32 x;
    int32 y;
    int32 z;
    uint32 angle;
    uint32 sprite;
    uint32 frame;
    uint32 flags;
    uint32 sector;
    uint32 next;
}

/// @custom:source linuxdoom-1.10/r_defs.h vissprite_t
struct VisSprite {
    int32 x1;
    int32 x2;
    int32 gx;
    int32 gy;
    int32 gz;
    int32 gzt;
    int32 startfrac;
    int32 scale;
    int32 xiscale;
    int32 texturemid;
    int32 patch;
    int32 colormap; // -1 is original NULL/shadow, zero is full-bright.
    uint32 mobjflags;
}

/// @custom:source linuxdoom-1.10/p_pspr.h pspdef_t renderer fields
struct PSprite {
    bool active; // false replaces a NULL state pointer.
    uint32 sprite;
    uint32 frame;
    int32 sx;
    int32 sy;
}

/// @custom:source linuxdoom-1.10/r_things.c initialization scratch
struct SpriteBuild {
    SpriteFrame[29] temp;
    int32 maxframe;
    bytes4 name;
}

/// @custom:source linuxdoom-1.10/r_things.c renderer globals
struct SpriteState {
    SpriteDef[] definitions;
    RenderThing[] things;
    uint32[] sectorHeads;
    VisSprite[] vissprites; // 128 original slots.
    VisSprite overflowSprite;
    uint32 visspriteCount;
    uint32[] sortedOrder; // stable ascending-scale selection replaces pointer links.
    int32 light;
    int32 spryscale;
    int32 sprtopscreen;
    int32[] mfloorclip;
    int32[] mceilingclip;
    uint8 columnMode; // 0=base/detail-specific, 1=fuzz, 2=translated.
    bytes translationtables;
    PSprite[2] psprites;
    uint32 playerSector;
    int32 invisibility;
    int32 viewangleoffset;
    bool modifiedgame;
}
