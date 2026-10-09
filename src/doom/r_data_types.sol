// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {ResourceIdentity, LumpDescriptor} from "../evm/ResourceTypes.sol";

/// @notice EVM placement adapter; concatenated STOP-prefixed immutable 16 KiB code chunks.
struct ResourceView {
    ResourceIdentity identity;
    address[] chunks;
    uint32 byteLength;
    LumpDescriptor[] lumps;
}

/// @custom:source linuxdoom-1.10/r_data.c texpatch_t
struct TexPatch {
    int32 originx;
    int32 originy;
    uint32 patch;
}

/// @custom:source linuxdoom-1.10/r_data.c texture_t and texturecolumn* arrays
struct Texture {
    bytes8 name;
    uint16 width;
    uint16 height;
    uint32 widthmask;
    TexPatch[] patches;
    int32[] columnlump;
    uint32[] columnofs;
    uint32 compositesize;
    bytes composite;
    bool compositeReady;
}

struct RenderResources {
    ResourceView source;
    bytes[] lumpcache; // per-frame W_CacheLumpNum reuse; empty means not loaded
    Texture[] textures;
    uint32[] texturetranslation;
    uint32[] flattranslation;
    uint32 firstflat;
    uint32 numflats;
    uint32 firstspritelump;
    uint32 numspritelumps;
    bytes colormaps;
    bytes[] colormapcache; // bounded memory slices replacing reusable lighttable_t pointers
    int32[] spritewidth;
    int32[] spriteoffset;
    int32[] spritetopoffset;
}

/// @notice Pointer replacement. data[offset] is the returned C byte pointer.
/// @dev Keeping the prefix permits masked callers to inspect column posts at offset - 3.
struct ColumnView {
    bytes data;
    uint32 offset;
}
