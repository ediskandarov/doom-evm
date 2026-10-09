// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

// Copyright (C) 1993-1996 by id Software, Inc. Original definitions retained in upstream.
// Modified 2026-10-09: minimal Solidity header adaptation; pointers become indexes.
/// @custom:source linuxdoom-1.10/r_defs.h at a77dfb96cb91780ca334d0d4cfd86957558007e0
struct Vertex {
    int32 x;
    int32 y;
}

/// @custom:source linuxdoom-1.10/r_defs.h (sector_t subset)
struct Sector {
    int32 floorheight;
    int32 ceilingheight;
    uint32 floorpic;
    uint32 ceilingpic;
    int16 lightlevel;
}

struct Node {
    int32 x;
    int32 y;
    int32 dx;
    int32 dy;
    int32[4][2] bbox; // [child][BOXTOP, BOXBOTTOM, BOXLEFT, BOXRIGHT]
    uint16[2] children; // original raw NF_SUBSECTOR encoding
}

struct Side {
    int32 textureoffset;
    int32 rowoffset;
    uint32 toptexture;
    uint32 bottomtexture;
    uint32 midtexture;
    uint32 sector;
}

struct Line {
    uint32 v1;
    uint32 v2;
    int32 dx;
    int32 dy;
    uint16 flags;
    int16 special;
    int16 tag;
    uint32[2] sidenum;
    int32[4] bbox;
    uint8 slopetype;
    uint32 frontsector;
    uint32 backsector;
}

struct Seg {
    uint32 v1;
    uint32 v2;
    int32 offset;
    uint32 angle;
    uint32 sidedef;
    uint32 linedef;
    uint32 frontsector;
    uint32 backsector;
}

struct Subsector {
    uint32 sector;
    uint32 numlines;
    uint32 firstline;
}

/// @dev Original mapthing_t disk fields; spawning is a separate, later integration gate.
struct MapThing {
    int16 x;
    int16 y;
    int16 angle;
    int16 thingType;
    int16 options;
}

struct MapData {
    Vertex[] vertexes;
    Sector[] sectors;
    Side[] sides;
    Line[] lines;
    Seg[] segs;
    Subsector[] subsectors;
    Node[] nodes;
    MapThing[] things;
}
