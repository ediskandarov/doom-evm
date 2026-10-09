// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {RenderContext} from "./r_render_state.sol";
import {RenderThing} from "./r_sprite_state.sol";
import {MapThing} from "./r_defs.sol";
import {Info, InfoData} from "./info.sol";
import {R_Main} from "./r_main.sol";
import {Tables} from "./tables.sol";

/// @notice Static medium-skill single-player spawn-state adapter, without actions or ticks.
/// @custom:source p_setup.c P_LoadThings; p_mobj.c P_SpawnMapThing/P_SpawnMobj; p_maputl.c P_SetThingPosition
library P_SetupStatic {
    error UnknownThing(int16 doomednum);

    function load(RenderContext memory c, InfoData memory info) internal pure {
        c.sprite.sectorHeads = new uint32[](c.map.sectors.length);
        for (uint256 i; i < c.sprite.sectorHeads.length; ++i) {
            c.sprite.sectorHeads[i] = type(uint32).max;
        }
        uint256 count;
        for (uint256 i; i < c.map.things.length; ++i) {
            if (selected(c.map.things[i])) ++count;
        }
        c.sprite.things = new RenderThing[](count);
        uint32 cursor;
        for (uint256 i; i < c.map.things.length; ++i) {
            MapThing memory t = c.map.things[i];
            if (t.thingType == 1) {
                c.sprite.playerSector =
                c.map
                .subsectors[R_Main.R_PointInSubsector(int32(t.x) * 65536, int32(t.y) * 65536, c.map)].sector;
            }
            if (!selected(t)) continue;
            uint256 kind;
            for (; kind < Info.NUMMOBJTYPES; ++kind) {
                if (int32(Info.word(info.mobjInfo, kind * 20)) == t.thingType) break;
            }
            if (kind == Info.NUMMOBJTYPES) revert UnknownThing(t.thingType);
            uint256 p = kind * 20;
            RenderThing memory thing = c.sprite.things[cursor];
            thing.x = int32(t.x) * 65536;
            thing.y = int32(t.y) * 65536;
            unchecked {
                thing.angle = uint32(int32(t.angle) / 45) * Tables.ANG45;
            }
            thing.flags = Info.word(info.mobjInfo, p + 8);
            if (t.options & 8 != 0) thing.flags |= 32;
            uint256 state = Info.word(info.mobjInfo, p + 4) * 8;
            thing.sprite = Info.word(info.states, state);
            thing.frame = Info.word(info.states, state + 4);
            thing.sector = c.map.subsectors[R_Main.R_PointInSubsector(thing.x, thing.y, c.map)].sector;
            unchecked {
                thing.z = thing.flags & 256 != 0
                    ? c.map.sectors[thing.sector].ceilingheight - int32(Info.word(info.mobjInfo, p + 16))
                    : c.map.sectors[thing.sector].floorheight;
            }
            thing.next = type(uint32).max;
            if (thing.flags & 8 == 0) {
                thing.next = c.sprite.sectorHeads[thing.sector];
                c.sprite.sectorHeads[thing.sector] = cursor;
            }
            ++cursor;
        }
    }

    function selected(MapThing memory t) private pure returns (bool) {
        return t.thingType > 4 && t.thingType != 11 && t.options & 16 == 0 && t.options & 2 != 0;
    }
}
