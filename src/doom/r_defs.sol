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
