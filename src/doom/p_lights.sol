// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {GameContext, GameConst, ThinkerKind, FireFlicker, LightFlash, Strobe, Glow} from "./p_game_state.sol";
import {P_Heap} from "./p_heap.sol";
import {P_Tick} from "./p_tick.sol";
import {P_Spec} from "./p_spec.sol";
import {M_Random} from "./m_random.sol";

/// @custom:source linuxdoom-1.10/p_lights.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
library P_Lights {
    function T_FireFlicker(GameContext memory c, uint32 id) internal pure {
        FireFlicker memory flick = c.state.fireFlickers[id];
        unchecked {
            --flick.count;
        }
        if (flick.count != 0) return;
        int32 amount = (M_Random.P_Random(c.state) & 3) * 16;
        unchecked {
            c.map.sectors[flick.sector].lightlevel = int16(
                int32(c.map.sectors[flick.sector].lightlevel) - amount < flick.minlight
                    ? flick.minlight
                    : flick.maxlight - amount
            );
        }
        flick.count = 4;
    }

    function P_SpawnFireFlicker(GameContext memory c, uint32 sector) internal pure {
        c.state.sectors[sector].special = 0;
        uint32 id = P_Heap.allocateFireFlicker(c.state);
        FireFlicker memory flick = c.state.fireFlickers[id];
        flick.thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.fireFlicker, id);
        flick.sector = sector;
        flick.maxlight = c.map.sectors[sector].lightlevel;
        unchecked {
            flick.minlight = P_Spec.P_FindMinSurroundingLight(c, sector, flick.maxlight) + 16;
        }
        flick.count = 4;
    }

    function T_LightFlash(GameContext memory c, uint32 id) internal pure {
        LightFlash memory flash = c.state.lightFlashes[id];
        unchecked {
            --flash.count;
        }
        if (flash.count != 0) return;
        if (c.map.sectors[flash.sector].lightlevel == flash.maxlight) {
            c.map.sectors[flash.sector].lightlevel = int16(flash.minlight);
            flash.count = (M_Random.P_Random(c.state) & flash.mintime) + 1;
        } else {
            c.map.sectors[flash.sector].lightlevel = int16(flash.maxlight);
            flash.count = (M_Random.P_Random(c.state) & flash.maxtime) + 1;
        }
    }

    function P_SpawnLightFlash(GameContext memory c, uint32 sector) internal pure {
        c.state.sectors[sector].special = 0;
        uint32 id = P_Heap.allocateLightFlash(c.state);
        LightFlash memory flash = c.state.lightFlashes[id];
        flash.thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.lightFlash, id);
        flash.sector = sector;
        flash.maxlight = c.map.sectors[sector].lightlevel;
        flash.minlight = P_Spec.P_FindMinSurroundingLight(c, sector, flash.maxlight);
        flash.maxtime = 64;
        flash.mintime = 7;
        flash.count = (M_Random.P_Random(c.state) & flash.maxtime) + 1;
    }

    function T_StrobeFlash(GameContext memory c, uint32 id) internal pure {
        Strobe memory flash = c.state.strobes[id];
        unchecked {
            --flash.count;
        }
        if (flash.count != 0) return;
        if (c.map.sectors[flash.sector].lightlevel == flash.minlight) {
            c.map.sectors[flash.sector].lightlevel = int16(flash.maxlight);
            flash.count = flash.brighttime;
        } else {
            c.map.sectors[flash.sector].lightlevel = int16(flash.minlight);
            flash.count = flash.darktime;
        }
    }

    function P_SpawnStrobeFlash(GameContext memory c, uint32 sector, int32 fastOrSlow, int32 inSync)
        internal
        pure
    {
        uint32 id = P_Heap.allocateStrobe(c.state);
        Strobe memory flash = c.state.strobes[id];
        flash.thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.strobe, id);
        flash.sector = sector;
        flash.darktime = fastOrSlow;
        flash.brighttime = 5;
        flash.maxlight = c.map.sectors[sector].lightlevel;
        flash.minlight = P_Spec.P_FindMinSurroundingLight(c, sector, flash.maxlight);
        if (flash.minlight == flash.maxlight) flash.minlight = 0;
        c.state.sectors[sector].special = 0;
        flash.count = inSync == 0 ? (M_Random.P_Random(c.state) & 7) + 1 : int32(1);
    }

    function EV_StartLightStrobing(GameContext memory c, uint32 line) internal pure {
        int32 secnum = -1;
        while ((secnum = P_Spec.P_FindSectorFromLineTag(c, line, secnum)) >= 0) {
            uint32 sector = uint32(secnum);
            if (c.state.sectors[sector].specialdata != GameConst.NULL) continue;
            P_SpawnStrobeFlash(c, sector, 35, 0);
        }
    }

    function EV_TurnTagLightsOff(GameContext memory c, uint32 line) internal pure {
        for (uint32 j; j < c.state.sectors.length; ++j) {
            if (c.state.sectors[j].tag != c.map.lines[line].tag) continue;
            int32 minimum = c.map.sectors[j].lightlevel;
            for (uint32 i; i < c.state.sectors[j].lines.length; ++i) {
                uint32 next = P_Spec.getNextSector(c, c.state.sectors[j].lines[i], j);
                if (next == GameConst.NULL) continue;
                if (c.map.sectors[next].lightlevel < minimum) minimum = c.map.sectors[next].lightlevel;
            }
            c.map.sectors[j].lightlevel = int16(minimum);
        }
    }

    function EV_LightTurnOn(GameContext memory c, uint32 line, int32 bright) internal pure {
        for (uint32 i; i < c.state.sectors.length; ++i) {
            if (c.state.sectors[i].tag != c.map.lines[line].tag) continue;
            // Original bright is shared across sectors: only search while it remains zero.
            if (bright == 0) {
                for (uint32 j; j < c.state.sectors[i].lines.length; ++j) {
                    uint32 next = P_Spec.getNextSector(c, c.state.sectors[i].lines[j], i);
                    if (next == GameConst.NULL) continue;
                    if (c.map.sectors[next].lightlevel > bright) bright = c.map.sectors[next].lightlevel;
                }
            }
            c.map.sectors[i].lightlevel = int16(bright);
        }
    }

    function T_Glow(GameContext memory c, uint32 id) internal pure {
        Glow memory glow = c.state.glows[id];
        unchecked {
            if (glow.direction == -1) {
                c.map.sectors[glow.sector].lightlevel -= 8;
                if (c.map.sectors[glow.sector].lightlevel <= glow.minlight) {
                    c.map.sectors[glow.sector].lightlevel += 8;
                    glow.direction = 1;
                }
            } else if (glow.direction == 1) {
                c.map.sectors[glow.sector].lightlevel += 8;
                if (c.map.sectors[glow.sector].lightlevel >= glow.maxlight) {
                    c.map.sectors[glow.sector].lightlevel -= 8;
                    glow.direction = -1;
                }
            }
        }
    }

    function P_SpawnGlowingLight(GameContext memory c, uint32 sector) internal pure {
        uint32 id = P_Heap.allocateGlow(c.state);
        Glow memory glow = c.state.glows[id];
        glow.thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.glow, id);
        glow.sector = sector;
        glow.maxlight = c.map.sectors[sector].lightlevel;
        glow.minlight = P_Spec.P_FindMinSurroundingLight(c, sector, glow.maxlight);
        glow.direction = -1;
        c.state.sectors[sector].special = 0;
    }
}
