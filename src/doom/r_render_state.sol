// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;

import {RenderState, DrawColumn, DrawSpan} from "./r_state.sol";
import {MapData} from "./r_defs.sol";
import {RenderResources} from "./r_data_types.sol";

/// @custom:source linuxdoom-1.10/r_bsp.c cliprange_t
struct ClipRange {
    int32 first;
    int32 last;
}

/// @custom:source linuxdoom-1.10/r_defs.h drawseg_t
struct DrawSeg {
    uint32 curline;
    int32 x1;
    int32 x2;
    int32 scale1;
    int32 scale2;
    int32 scalestep;
    uint8 silhouette;
    int32 bsilheight;
    int32 tsilheight;
    int32[] sprtopclip;
    int32[] sprbottomclip;
    int32[] maskedtexturecol;
}

/// @custom:source linuxdoom-1.10/r_defs.h visplane_t
/// @dev top/bottom have 322 bytes: logical x is stored at x+1, including -1/320 sentinels.
struct Visplane {
    int32 height;
    uint32 picnum;
    int16 lightlevel;
    int32 minx;
    int32 maxx;
    bytes top;
    bytes bottom;
}

/// @custom:source linuxdoom-1.10/r_segs.c globals
struct WallState {
    bool segtextured;
    bool markfloor;
    bool markceiling;
    bool maskedtexture;
    uint32 toptexture;
    uint32 bottomtexture;
    uint32 midtexture;
    uint32 rw_normalangle;
    uint32 rw_angle1;
    int32 rw_x;
    int32 rw_stopx;
    uint32 rw_centerangle;
    int32 rw_offset;
    int32 rw_distance;
    int32 rw_scale;
    int32 rw_scalestep;
    int32 rw_midtexturemid;
    int32 rw_toptexturemid;
    int32 rw_bottomtexturemid;
    int32 worldtop;
    int32 worldbottom;
    int32 worldhigh;
    int32 worldlow;
    int32 pixhigh;
    int32 pixlow;
    int32 pixhighstep;
    int32 pixlowstep;
    int32 topfrac;
    int32 topstep;
    int32 bottomfrac;
    int32 bottomstep;
    int32 lightnum; // row into rs.scalelight, or rs.fixedcolormap override
}

/// @custom:source linuxdoom-1.10/r_plane.c globals
struct PlaneState {
    int32 basexscale;
    int32 baseyscale;
    int32[] cachedheight;
    int32[] cacheddistance;
    int32[] cachedxstep;
    int32[] cachedystep;
    int32[] spanstart;
    int32 planeheight;
    int32 light;
}

/// @notice Integrator-owned per-frame globals for the original renderer pipeline.
/// @dev No host-supplied visibility. Index NULL is 0xffffffff; array index zero remains valid.
struct RenderContext {
    RenderState rs;
    MapData map;
    RenderResources resources;
    ClipRange[] solidsegs; // 32 original slots
    uint32 solidsegCount;
    DrawSeg[] drawsegs; // 256 original slots
    uint32 drawsegCount;
    Visplane[] visplanes; // 128 original slots
    uint32 visplaneCount;
    uint32 floorplane;
    uint32 ceilingplane;
    int32[] floorclip;
    int32[] ceilingclip;
    uint32 openingCount; // enforce original 320*64 shorts even with independent memory slices
    uint32 curline;
    uint32 frontsector;
    uint32 backsector;
    uint32 skyflatnum;
    uint32 skytexture;
    int32 skytexturemid;
    uint32[] sectorValidcount;
    WallState wall;
    PlaneState plane;
    DrawColumn dc;
    DrawSpan ds;
}
