// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;

import {GameContext} from "./p_game_state.sol";
import {ZoneState, ZoneConst} from "./z_zone_types.sol";
import {Z_Zone} from "./z_zone.sol";
import {W_ZoneCache} from "./w_zone_cache.sol";
import {NativeZoneLayout as N} from "./native_zone_layout.sol";

struct SetupZoneObservation {
    bool enabled;
    bytes32 digest;
    uint32 operations;
}

/// @custom:source linuxdoom-1.10/p_setup.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @dev Physical allocation chronology only. Logical loaders retain their original adapters.
/// All counts come from the authenticated parsed map, never an observed allocation tape.
library P_Zone_Setup {
    error NativeSetupSize();
    uint32 internal constant BLOCKLINKS = 0;
    uint32 internal constant VERTEXES = 1;
    uint32 internal constant SECTORS = 2;
    uint32 internal constant SIDES = 3;
    uint32 internal constant LINES = 4;
    uint32 internal constant SUBSECTORS = 5;
    uint32 internal constant NODES = 6;
    uint32 internal constant SEGS = 7;
    uint32 internal constant LINEBUFFER = 8;

    function size(uint256 value) private pure returns (uint32) {
        if (value > uint256(uint32(type(int32).max))) revert NativeSetupSize();
        return uint32(value);
    }

    function record(
        SetupZoneObservation memory observation,
        ZoneState memory zone,
        uint32 op,
        uint32 requestedSize,
        uint32 tag,
        uint32 owner,
        uint32 header,
        uint32 blockSize
    ) private pure {
        if (!observation.enabled) return;
        observation.digest = sha256(
            abi.encodePacked(
                observation.digest,
                op,
                requestedSize,
                tag,
                owner,
                header,
                blockSize,
                Z_Zone.Z_BlockOffset(zone, zone.rover)
            )
        );
        ++observation.operations;
    }

    function allocate(
        GameContext memory c,
        uint256 bytes_,
        uint32 slot,
        SetupZoneObservation memory observation
    ) private pure returns (uint32 id) {
        uint32 requested = size(bytes_);
        id = Z_Zone.Z_Malloc(c.state.nativeZone, requested, ZoneConst.PU_LEVEL, ZoneConst.NULL);
        c.state.nativeMapBlocks[slot] = id;
        record(
            observation,
            c.state.nativeZone,
            1,
            requested,
            ZoneConst.PU_LEVEL,
            ZoneConst.NULL,
            c.state.nativeZone.blocks[id].offset,
            c.state.nativeZone.blocks[id].size
        );
    }

    function cache(GameContext memory c, uint32 lump, uint8 tag, SetupZoneObservation memory observation)
        private
        pure
        returns (uint32 id)
    {
        uint32 previous = c.state.nativeZone.ownerBlocks[lump];
        id = W_ZoneCache.cacheLump(c.state.nativeZone, c.resources.source, lump, tag);
        record(
            observation,
            c.state.nativeZone,
            previous == ZoneConst.NULL ? 1 : 3,
            previous == ZoneConst.NULL ? c.resources.source.lumps[lump].length : 0,
            tag,
            lump,
            c.state.nativeZone.blocks[id].offset,
            c.state.nativeZone.blocks[id].size
        );
    }

    function free(GameContext memory c, uint32 id, SetupZoneObservation memory observation) private pure {
        uint32 header = c.state.nativeZone.blocks[id].offset;
        uint32 blockSize = c.state.nativeZone.blocks[id].size;
        uint32 owner = c.state.nativeZone.blocks[id].owner;
        Z_Zone.Z_Free(c.state.nativeZone, id);
        record(observation, c.state.nativeZone, 2, 0, 0, owner, header, blockSize);
    }

    function begin(GameContext memory c) internal pure {
        if (c.state.nativeZone.byteLength == 0) return;
        Z_Zone.Z_FreeTags(c.state.nativeZone, ZoneConst.PU_LEVEL, ZoneConst.PU_PURGELEVEL - 1);
        for (uint256 i; i < 9; ++i) {
            c.state.nativeMapBlocks[i] = 0;
            c.state.nativePayloadBlocks[i] = new uint32[](0);
        }
    }

    function blockmap(GameContext memory c, uint32 lump) internal pure {
        if (c.state.nativeZone.byteLength == 0) return;
        SetupZoneObservation memory observation;
        blockmap_(c, lump, observation);
    }

    function blockmap_(GameContext memory c, uint32 lump, SetupZoneObservation memory observation)
        private
        pure
    {
        cache(c, lump, ZoneConst.PU_LEVEL, observation);
        allocate(c, c.state.blockmap.heads.length * 8, BLOCKLINKS, observation);
    }

    function array_(
        GameContext memory c,
        uint32 lump,
        uint256 count,
        uint32 stride,
        uint32 slot,
        SetupZoneObservation memory observation
    ) private pure {
        allocate(c, count * stride, slot, observation);
        uint32 temporary = cache(c, lump, ZoneConst.PU_STATIC, observation);
        free(c, temporary, observation);
    }

    function geometry(GameContext memory c, uint32 base) internal pure {
        if (c.state.nativeZone.byteLength == 0) return;
        SetupZoneObservation memory observation;
        geometry_(c, base, observation);
    }

    function geometry_(GameContext memory c, uint32 base, SetupZoneObservation memory observation)
        private
        pure
    {
        // Original P_SetupLevel order, including temporary cache allocation/free between arrays.
        array_(c, base + 4, c.map.vertexes.length, N.VERTEX_SIZE, VERTEXES, observation);
        array_(c, base + 8, c.map.sectors.length, N.SECTOR_SIZE, SECTORS, observation);
        array_(c, base + 3, c.map.sides.length, N.SIDE_SIZE, SIDES, observation);
        array_(c, base + 2, c.map.lines.length, N.LINE_SIZE, LINES, observation);
        array_(c, base + 6, c.map.subsectors.length, N.SUBSECTOR_SIZE, SUBSECTORS, observation);
        array_(c, base + 7, c.map.nodes.length, N.NODE_SIZE, NODES, observation);
        array_(c, base + 5, c.map.segs.length, N.SEG_SIZE, SEGS, observation);
    }

    function reject(GameContext memory c, uint32 lump) internal pure {
        if (c.state.nativeZone.byteLength == 0) return;
        SetupZoneObservation memory observation;
        cache(c, lump, ZoneConst.PU_LEVEL, observation);
    }

    function groupLines(GameContext memory c, uint256 references) internal pure {
        if (c.state.nativeZone.byteLength == 0) return;
        SetupZoneObservation memory observation;
        allocate(c, references * 8, LINEBUFFER, observation);
    }

    function things(GameContext memory c, uint32 lump) internal pure returns (uint32 id) {
        if (c.state.nativeZone.byteLength == 0) return 0;
        SetupZoneObservation memory observation;
        return cache(c, lump, ZoneConst.PU_STATIC, observation);
    }

    function freeThings(GameContext memory c, uint32 id) internal pure {
        if (c.state.nativeZone.byteLength == 0) return;
        SetupZoneObservation memory observation;
        free(c, id, observation);
    }

    /// @dev Comparison-only observation of the SAME recipe and primitives used by P_Setup.
    /// Map/blockmap must already be logically parsed; no logical state is changed here.
    function geometryObserved(GameContext memory c, uint32 base)
        internal
        pure
        returns (bytes32 digest, uint32 operations)
    {
        if (c.state.nativeZone.byteLength == 0) return (bytes32(0), 0);
        SetupZoneObservation memory observation;
        observation.enabled = true;
        begin(c);
        blockmap_(c, base + 10, observation);
        geometry_(c, base, observation);
        cache(c, base + 9, ZoneConst.PU_LEVEL, observation);
        uint256 references;
        for (uint256 i; i < c.map.lines.length; ++i) {
            ++references;
            if (
                c.map.lines[i].backsector != type(uint32).max
                    && c.map.lines[i].backsector != c.map.lines[i].frontsector
            ) ++references;
        }
        allocate(c, references * 8, LINEBUFFER, observation);
        return (observation.digest, observation.operations);
    }
}
