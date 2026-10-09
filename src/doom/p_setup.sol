// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;

import {
    GameContext,
    GameConst,
    GameSector,
    Mobj,
    Thinker,
    Door,
    FloorMove,
    CeilingMove,
    Plat,
    FireFlicker,
    LightFlash,
    Strobe,
    Glow
} from "./p_game_state.sol";
import {MapData, MapThing, Line, Vertex} from "./r_defs.sol";
import {R_Data} from "./r_data.sol";
import {P_Tick} from "./p_tick.sol";
import {P_Mobj} from "./p_mobj.sol";
import {P_Spec} from "./p_spec.sol";
import {P_Switch} from "./p_switch.sol";
import {M_BBox} from "./m_bbox.sol";
import {P_Zone_Setup} from "./p_zone_setup.sol";

/// @custom:source linuxdoom-1.10/p_setup.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @dev Existing R_Data.R_LoadMap owns the exact original disk-loader adaptations.
/// Gameplay completes BLOCKMAP/REJECT, sector grouping and original ordered spawning here.
library P_Setup {
    error MalformedMap();
    error UnsupportedDeathmatchStartup();

    function signed16(bytes memory data, uint256 offset) private pure returns (int16) {
        if (offset + 2 > data.length) revert MalformedMap();
        return int16(uint16(uint8(data[offset])) | uint16(uint8(data[offset + 1])) << 8);
    }

    function P_LoadBlockMap(GameContext memory c, uint32 lump) internal view {
        bytes memory data = R_Data.W_CacheLumpNum(c.resources.source, lump);
        if (data.length < 8 || data.length % 2 != 0) revert MalformedMap();
        c.state.blockmap.lump = new int16[](data.length / 2);
        for (uint256 i; i < data.length / 2; ++i) {
            c.state.blockmap.lump[i] = signed16(data, i * 2);
        }
        c.state.blockmap.orgx = int32(c.state.blockmap.lump[0]) * 65536;
        c.state.blockmap.orgy = int32(c.state.blockmap.lump[1]) * 65536;
        c.state.blockmap.width = c.state.blockmap.lump[2];
        c.state.blockmap.height = c.state.blockmap.lump[3];
        if (c.state.blockmap.width <= 0 || c.state.blockmap.height <= 0) revert MalformedMap();
        uint256 blocks = uint256(uint32(c.state.blockmap.width)) * uint32(c.state.blockmap.height);
        if (4 + blocks > c.state.blockmap.lump.length) revert MalformedMap();
        c.state.blockmap.heads = new uint32[](blocks);
        for (uint256 i; i < blocks; ++i) {
            c.state.blockmap.heads[i] = GameConst.NULL;
        }
        P_Zone_Setup.blockmap(c, lump);
    }

    /// @dev Original P_LoadSectors fields absent from the renderer's Sector are loaded here.
    function P_LoadSectorRuntime(GameContext memory c, uint32 lump) internal view {
        bytes memory data = R_Data.W_CacheLumpNum(c.resources.source, lump);
        if (data.length != c.map.sectors.length * 26) revert MalformedMap();
        c.state.sectors = new GameSector[](c.map.sectors.length);
        for (uint256 i; i < c.state.sectors.length; ++i) {
            GameSector memory sec = c.state.sectors[i];
            sec.special = signed16(data, i * 26 + 22);
            sec.tag = signed16(data, i * 26 + 24);
            sec.soundtarget = GameConst.NULL;
            sec.thinglist = GameConst.NULL;
            sec.specialdata = GameConst.NULL;
        }
        c.state.lineValidcount = new uint32[](c.map.lines.length);
        c.state.lineSpecialdata = new uint32[](c.map.lines.length);
        for (uint256 i; i < c.state.lineSpecialdata.length; ++i) {
            c.state.lineSpecialdata[i] = GameConst.NULL;
        }
    }

    function P_GroupLines(GameContext memory c) internal pure {
        for (uint256 i; i < c.map.subsectors.length; ++i) {
            c.map.subsectors[i].sector = c.map.sides[c.map.segs[c.map.subsectors[i].firstline].sidedef].sector;
        }
        uint32[] memory counts = new uint32[](c.map.sectors.length);
        uint256 references;
        for (uint256 i; i < c.map.lines.length; ++i) {
            Line memory line = c.map.lines[i];
            ++counts[line.frontsector];
            ++references;
            if (line.backsector != GameConst.NULL && line.backsector != line.frontsector) {
                ++counts[line.backsector];
                ++references;
            }
        }
        P_Zone_Setup.groupLines(c, references);
        for (uint32 i; i < c.state.sectors.length; ++i) {
            GameSector memory sector = c.state.sectors[i];
            sector.lines = new uint32[](counts[i]);
            int32[4] memory box;
            M_BBox.M_ClearBox(box);
            uint32 count;
            for (uint32 j; j < c.map.lines.length; ++j) {
                Line memory line = c.map.lines[j];
                if (line.frontsector == i || line.backsector == i) {
                    sector.lines[count++] = j;
                    Vertex memory v1 = c.map.vertexes[line.v1];
                    Vertex memory v2 = c.map.vertexes[line.v2];
                    M_BBox.M_AddToBox(box, v1.x, v1.y);
                    M_BBox.M_AddToBox(box, v2.x, v2.y);
                }
            }
            if (count != counts[i]) revert MalformedMap();
            unchecked {
                sector.soundorgx = (box[3] + box[2]) / 2;
                sector.soundorgy = (box[0] + box[1]) / 2;
                int32 blockIndex = (box[0] - c.state.blockmap.orgy + GameConst.MAXRADIUS) >> 23;
                sector.blockbox[0] =
                    blockIndex >= c.state.blockmap.height ? c.state.blockmap.height - 1 : blockIndex;
                blockIndex = (box[1] - c.state.blockmap.orgy - GameConst.MAXRADIUS) >> 23;
                sector.blockbox[1] = blockIndex < 0 ? int32(0) : blockIndex;
                blockIndex = (box[3] - c.state.blockmap.orgx + GameConst.MAXRADIUS) >> 23;
                sector.blockbox[3] =
                    blockIndex >= c.state.blockmap.width ? c.state.blockmap.width - 1 : blockIndex;
                blockIndex = (box[2] - c.state.blockmap.orgx - GameConst.MAXRADIUS) >> 23;
                sector.blockbox[2] = blockIndex < 0 ? int32(0) : blockIndex;
            }
        }
    }

    function P_LoadThings(GameContext memory c) internal view {
        for (uint256 i; i < c.map.things.length; ++i) {
            MapThing memory thing = c.map.things[i];
            if (c.state.gamemode != 2) {
                int16 kind = thing.thingType;
                if (
                    kind == 68 || kind == 64 || kind == 88 || kind == 89 || kind == 69 || kind == 67
                        || kind == 71 || kind == 65 || kind == 66 || kind == 84
                ) {
                    // Original breaks the entire THINGS loop here, rather than continuing.
                    break;
                }
            }
            P_Mobj.P_SpawnMapThing(c, thing);
        }
    }

    function mapName(GameContext memory c, int32 episode, int32 map) private pure returns (bytes8 name) {
        if (c.state.gamemode == 2) {
            if (map < 1 || map > 99) revert MalformedMap();
            bytes memory b = abi.encodePacked(
                "MAP", bytes1(uint8(uint32(map / 10) + 48)), bytes1(uint8(uint32(map % 10) + 48))
            );
            for (uint256 i; i < b.length; ++i) {
                name |= bytes8(b[i]) >> (i * 8);
            }
        } else {
            if (episode < 1 || episode > 9 || map < 1 || map > 9) revert MalformedMap();
            name = bytes8(
                abi.encodePacked(
                    "E", bytes1(uint8(uint32(episode) + 48)), "M", bytes1(uint8(uint32(map) + 48))
                )
            );
        }
    }

    function P_SetupLevel(GameContext memory c, int32 episode, int32 map, int32, int32) internal view {
        if (c.state.deathmatch != 0) revert UnsupportedDeathmatchStartup();
        c.state.totalkills = 0;
        c.state.totalitems = 0;
        c.state.totalsecret = 0;
        for (uint32 i; i < 4; ++i) {
            c.state.players[i].killcount = 0;
            c.state.players[i].secretcount = 0;
            c.state.players[i].itemcount = 0;
        }
        c.state.players[uint32(c.state.consoleplayer)].viewz = 1;
        P_Zone_Setup.begin(c);
        // Fresh logical pools retain inventory/player globals; physical FreeTags preserves caches.
        c.state.mobjs = new Mobj[](8);
        c.state.mobjCount = 0;
        c.state.doors = new Door[](0);
        c.state.doorCount = 0;
        c.state.floors = new FloorMove[](0);
        c.state.floorCount = 0;
        c.state.ceilings = new CeilingMove[](0);
        c.state.ceilingCount = 0;
        c.state.plats = new Plat[](0);
        c.state.platCount = 0;
        c.state.fireFlickers = new FireFlicker[](0);
        c.state.fireFlickerCount = 0;
        c.state.lightFlashes = new LightFlash[](0);
        c.state.lightFlashCount = 0;
        c.state.strobes = new Strobe[](0);
        c.state.strobeCount = 0;
        c.state.glows = new Glow[](0);
        c.state.glowCount = 0;
        P_Tick.P_InitThinkers(c.state);
        bytes8 name = mapName(c, episode, map);
        uint32 lump = R_Data.W_GetNumForName(c.resources.source, name);
        c.state.leveltime = 0;
        P_LoadBlockMap(c, lump + 10); // ML_BLOCKMAP
        c.map = R_Data.R_LoadMap(c.resources, name);
        c.state.map = c.map;
        P_Zone_Setup.geometry(c, lump);
        P_LoadSectorRuntime(c, lump + 8); // ML_SECTORS
        c.state.rejectmatrix = R_Data.W_CacheLumpNum(c.resources.source, lump + 9);
        P_Zone_Setup.reject(c, lump + 9);
        P_GroupLines(c);
        c.state.deathmatchStartCount = 0;
        uint32 thingsBlock = P_Zone_Setup.things(c, lump + 1);
        P_LoadThings(c);
        P_Zone_Setup.freeThings(c, thingsBlock);
        c.state.iquehead = 0;
        c.state.iquetail = 0;
        c.hooks.spawnSpecials(c);
        // Immutable resources replace W_Reload/cache purge; host sound/precache/UI have no world effects.
    }

    function P_Init(GameContext memory c) internal pure {
        P_Switch.P_InitSwitchList(c);
        P_Spec.P_InitPicAnims(c);
        // Original R_InitSprites is performed by the renderer adapter against identical sprite names.
    }
}
