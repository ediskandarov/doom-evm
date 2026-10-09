// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {GameContext, GameConst as C, Animation, ButtonWhere} from "./p_game_state.sol";
import {Line} from "./r_defs.sol";
import {R_Data} from "./r_data.sol";
import {
    GameSector,
    Mobj,
    Player,
    FloorMove,
    FloorType,
    ThinkerKind,
    DoorType,
    CeilingType,
    PlatType,
    Button
} from "./p_game_state.sol";
import {P_Heap} from "./p_heap.sol";
import {P_Tick} from "./p_tick.sol";
import {M_Random} from "./m_random.sol";
import {G_Game} from "./g_game.sol";
import {P_Info} from "./p_info.sol";
import {P_Doors} from "./p_doors.sol";
import {P_Floor, StairType} from "./p_floor.sol";
import {P_Ceilng} from "./p_ceilng.sol";
import {P_Plats} from "./p_plats.sol";
import {P_Lights} from "./p_lights.sol";
import {P_Telept} from "./p_telept.sol";
import {P_Switch} from "./p_switch.sol";

struct PicAnimationDef {
    bool istexture;
    bytes8 endname;
    bytes8 startname;
    int32 speed;
}

/// @custom:source linuxdoom-1.10/p_spec.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
library P_Spec {
    error BadAnimation(bytes8 startname, bytes8 endname);
    error UnknownSectorSpecial(int16 special);
    error TooManyScrollingLines();
    error InvalidDonutGeometry();

    function getSide(GameContext memory c, uint32 currentSector, uint32 line, uint32 side)
        internal
        pure
        returns (uint32)
    {
        return c.map.lines[c.state.sectors[currentSector].lines[line]].sidenum[side];
    }

    function getSector(GameContext memory c, uint32 currentSector, uint32 line, uint32 side)
        internal
        pure
        returns (uint32)
    {
        return c.map.sides[getSide(c, currentSector, line, side)].sector;
    }

    function twoSided(GameContext memory c, uint32 sector, uint32 line) internal pure returns (int32) {
        return int32(uint32(c.map.lines[c.state.sectors[sector].lines[line]].flags & 4));
    }

    function getNextSector(GameContext memory c, uint32 line, uint32 sector) internal pure returns (uint32) {
        Line memory l = c.map.lines[line];
        if (l.flags & 4 == 0) return C.NULL;
        return l.frontsector == sector ? l.backsector : l.frontsector;
    }

    function P_FindLowestFloorSurrounding(GameContext memory c, uint32 sec)
        internal
        pure
        returns (int32 floor)
    {
        floor = c.map.sectors[sec].floorheight;
        for (uint256 i; i < c.state.sectors[sec].lines.length; i++) {
            uint32 other = getNextSector(c, c.state.sectors[sec].lines[i], sec);
            if (other == C.NULL) continue;
            if (c.map.sectors[other].floorheight < floor) floor = c.map.sectors[other].floorheight;
        }
    }

    function P_FindHighestFloorSurrounding(GameContext memory c, uint32 sec)
        internal
        pure
        returns (int32 floor)
    {
        floor = -500 * 65536;
        for (uint256 i; i < c.state.sectors[sec].lines.length; i++) {
            uint32 other = getNextSector(c, c.state.sectors[sec].lines[i], sec);
            if (other == C.NULL) continue;
            if (c.map.sectors[other].floorheight > floor) floor = c.map.sectors[other].floorheight;
        }
    }

    function P_FindNextHighestFloor(GameContext memory c, uint32 sec, int32 currentheight)
        internal
        pure
        returns (int32)
    {
        int32[20] memory heights;
        uint32 h;
        for (uint256 i; i < c.state.sectors[sec].lines.length; i++) {
            uint32 other = getNextSector(c, c.state.sectors[sec].lines[i], sec);
            if (other == C.NULL) continue;
            if (c.map.sectors[other].floorheight > currentheight) {
                heights[h++] = c.map.sectors[other].floorheight;
            }
            if (h >= 20) break; // Original prints a warning and stops after first 20 eligible entries.
        }
        if (h == 0) return currentheight;
        int32 min = heights[0];
        for (uint32 i = 1; i < h; i++) {
            if (heights[i] < min) min = heights[i];
        }
        return min;
    }

    function P_FindLowestCeilingSurrounding(GameContext memory c, uint32 sec)
        internal
        pure
        returns (int32 height)
    {
        height = type(int32).max;
        for (uint256 i; i < c.state.sectors[sec].lines.length; i++) {
            uint32 other = getNextSector(c, c.state.sectors[sec].lines[i], sec);
            if (other == C.NULL) continue;
            if (c.map.sectors[other].ceilingheight < height) height = c.map.sectors[other].ceilingheight;
        }
    }

    function P_FindHighestCeilingSurrounding(GameContext memory c, uint32 sec)
        internal
        pure
        returns (int32 height)
    {
        height = 0;
        for (uint256 i; i < c.state.sectors[sec].lines.length; i++) {
            uint32 other = getNextSector(c, c.state.sectors[sec].lines[i], sec);
            if (other == C.NULL) continue;
            if (c.map.sectors[other].ceilingheight > height) height = c.map.sectors[other].ceilingheight;
        }
    }

    function P_FindSectorFromLineTag(GameContext memory c, uint32 line, int32 start)
        internal
        pure
        returns (int32)
    {
        return P_FindSectorFromTag(c, c.map.lines[line].tag, start);
    }

    /// @dev Adapter for original boss EV_DoFloor/EV_DoDoor synthetic line objects, used only for their tag.
    function P_FindSectorFromTag(GameContext memory c, int32 tag, int32 start) internal pure returns (int32) {
        for (int32 i = start + 1; i < int32(uint32(c.state.sectors.length)); i++) {
            if (c.state.sectors[uint32(i)].tag == tag) return i;
        }
        return -1;
    }

    function P_FindMinSurroundingLight(GameContext memory c, uint32 sec, int32 max)
        internal
        pure
        returns (int32 min)
    {
        min = max;
        for (uint256 i; i < c.state.sectors[sec].lines.length; i++) {
            uint32 other = getNextSector(c, c.state.sectors[sec].lines[i], sec);
            if (other == C.NULL) continue;
            if (c.map.sectors[other].lightlevel < min) min = c.map.sectors[other].lightlevel;
        }
    }

    function animationDefs() internal pure returns (PicAnimationDef[22] memory defs) {
        defs[0] = PicAnimationDef(false, "NUKAGE3", "NUKAGE1", 8);
        defs[1] = PicAnimationDef(false, "FWATER4", "FWATER1", 8);
        defs[2] = PicAnimationDef(false, "SWATER4", "SWATER1", 8);
        defs[3] = PicAnimationDef(false, "LAVA4", "LAVA1", 8);
        defs[4] = PicAnimationDef(false, "BLOOD3", "BLOOD1", 8);
        defs[5] = PicAnimationDef(false, "RROCK08", "RROCK05", 8);
        defs[6] = PicAnimationDef(false, "SLIME04", "SLIME01", 8);
        defs[7] = PicAnimationDef(false, "SLIME08", "SLIME05", 8);
        defs[8] = PicAnimationDef(false, "SLIME12", "SLIME09", 8);
        defs[9] = PicAnimationDef(true, "BLODGR4", "BLODGR1", 8);
        defs[10] = PicAnimationDef(true, "SLADRIP3", "SLADRIP1", 8);
        defs[11] = PicAnimationDef(true, "BLODRIP4", "BLODRIP1", 8);
        defs[12] = PicAnimationDef(true, "FIREWALL", "FIREWALA", 8);
        defs[13] = PicAnimationDef(true, "GSTFONT3", "GSTFONT1", 8);
        defs[14] = PicAnimationDef(true, "FIRELAVA", "FIRELAV3", 8);
        defs[15] = PicAnimationDef(true, "FIREMAG3", "FIREMAG1", 8);
        defs[16] = PicAnimationDef(true, "FIREBLU2", "FIREBLU1", 8);
        defs[17] = PicAnimationDef(true, "ROCKRED3", "ROCKRED1", 8);
        defs[18] = PicAnimationDef(true, "BFALL4", "BFALL1", 8);
        defs[19] = PicAnimationDef(true, "SFALL4", "SFALL1", 8);
        defs[20] = PicAnimationDef(true, "WFALL4", "WFALL1", 8);
        defs[21] = PicAnimationDef(true, "DBRAIN4", "DBRAIN1", 8);
    }

    function animationPresent(GameContext memory c, PicAnimationDef memory a) private pure returns (bool) {
        return a.istexture
            ? R_Data.R_CheckTextureNumForName(c.resources, a.startname) != -1
            : R_Data.W_CheckNumForName(c.resources.source, a.startname) != -1;
    }

    function P_InitPicAnims(GameContext memory c) internal pure {
        PicAnimationDef[22] memory defs = animationDefs();
        uint256 count;
        for (uint256 i; i < defs.length; i++) {
            if (animationPresent(c, defs[i])) count++;
        }
        c.state.animations = new Animation[](count);
        c.state.texturetranslation = c.resources.texturetranslation;
        c.state.flattranslation = c.resources.flattranslation;
        uint256 at;
        for (uint256 i; i < defs.length; i++) {
            PicAnimationDef memory d = defs[i];
            if (!animationPresent(c, d)) continue;
            Animation memory a = c.state.animations[at++];
            a.picnum = int32(
                d.istexture
                    ? R_Data.R_TextureNumForName(c.resources, d.endname)
                    : R_Data.R_FlatNumForName(c.resources, d.endname)
            );
            a.basepic = int32(
                d.istexture
                    ? R_Data.R_TextureNumForName(c.resources, d.startname)
                    : R_Data.R_FlatNumForName(c.resources, d.startname)
            );
            a.istexture = d.istexture;
            a.numpics = a.picnum - a.basepic + 1;
            if (a.numpics < 2) revert BadAnimation(d.startname, d.endname);
            a.speed = d.speed;
        }
    }

    function P_PlayerInSpecialSector(GameContext memory c, uint32 playerId) internal view {
        unchecked {
            Player memory player = c.state.players[playerId];
            Mobj memory mo = c.state.mobjs[player.mo];
            uint32 sector = c.map.subsectors[mo.subsector].sector;
            if (mo.z != c.map.sectors[sector].floorheight) return;
            int16 special = c.state.sectors[sector].special;
            if (special == 5) {
                if (player.powers[3] == 0 && c.state.leveltime & 31 == 0) {
                    c.hooks.damageMobj(c, player.mo, C.NULL, C.NULL, 10);
                }
            } else if (special == 7) {
                if (player.powers[3] == 0 && c.state.leveltime & 31 == 0) {
                    c.hooks.damageMobj(c, player.mo, C.NULL, C.NULL, 5);
                }
            } else if (special == 16 || special == 4) {
                if (player.powers[3] == 0 || M_Random.P_Random(c.state) < 5) {
                    if (c.state.leveltime & 31 == 0) c.hooks.damageMobj(c, player.mo, C.NULL, C.NULL, 20);
                }
            } else if (special == 9) {
                player.secretcount++;
                c.state.sectors[sector].special = 0;
            } else if (special == 11) {
                player.cheats &= ~C.CF_GODMODE;
                if (c.state.leveltime & 31 == 0) c.hooks.damageMobj(c, player.mo, C.NULL, C.NULL, 20);
                if (player.health <= 10) G_Game.G_ExitLevel(c.state);
            } else {
                revert UnknownSectorSpecial(special);
            }
        }
    }

    function P_UpdateSpecials(GameContext memory c) internal pure {
        unchecked {
            if (c.state.levelTimer) {
                c.state.levelTimeCount--;
                if (c.state.levelTimeCount == 0) G_Game.G_ExitLevel(c.state);
            }
            for (uint256 j; j < c.state.animations.length; j++) {
                Animation memory a = c.state.animations[j];
                for (int32 i = a.basepic; i < a.basepic + a.numpics; i++) {
                    int32 pic = a.basepic + ((c.state.leveltime / a.speed + i) % a.numpics);
                    if (a.istexture) c.state.texturetranslation[uint32(i)] = uint32(pic);
                    else c.state.flattranslation[uint32(i)] = uint32(pic);
                }
            }
            for (uint256 i; i < c.state.scrollingLines.length; i++) {
                uint32 line = c.state.scrollingLines[i];
                if (c.map.lines[line].special == 48) {
                    c.map.sides[c.map.lines[line].sidenum[0]].textureoffset += 65536;
                }
            }
            for (uint256 i; i < 16; i++) {
                Button memory b = c.state.buttons[i];
                if (b.btimer == 0) continue;
                b.btimer--;
                if (b.btimer != 0) continue;
                uint32 side = c.map.lines[b.line].sidenum[0];
                if (b.where == ButtonWhere.top) c.map.sides[side].toptexture = uint32(b.btexture);
                else if (b.where == ButtonWhere.middle) c.map.sides[side].midtexture = uint32(b.btexture);
                else if (b.where == ButtonWhere.bottom) c.map.sides[side].bottomtexture = uint32(b.btexture);
                c.state.buttons[i] = Button(C.NULL, ButtonWhere.top, 0, 0, C.NULL);
            }
        }
    }

    function EV_DoDonut(GameContext memory c, uint32 line) internal pure returns (int32 rtn) {
        int32 secnum = -1;
        while ((secnum = P_FindSectorFromLineTag(c, line, secnum)) >= 0) {
            uint32 s1 = uint32(secnum);
            if (c.state.sectors[s1].specialdata != C.NULL) continue;
            rtn = 1;
            if (c.state.sectors[s1].lines.length == 0) revert InvalidDonutGeometry();
            uint32 s2 = getNextSector(c, c.state.sectors[s1].lines[0], s1);
            if (s2 == C.NULL) revert InvalidDonutGeometry();
            for (uint256 i; i < c.state.sectors[s2].lines.length; i++) {
                uint32 ringline = c.state.sectors[s2].lines[i];
                // Original (!flags & ML_TWOSIDED) is always false, not !(flags & ML_TWOSIDED).
                if (c.map.lines[ringline].backsector == s1) continue;
                uint32 s3 = c.map.lines[ringline].backsector;
                if (s3 == C.NULL) revert InvalidDonutGeometry();
                uint32 id = P_Heap.allocateFloorMove(c.state);
                FloorMove memory floor = c.state.floors[id];
                floor.thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.floor, id);
                c.state.sectors[s2].specialdata = floor.thinker;
                floor.floorType = FloorType.donutRaise;
                floor.crush = false;
                floor.direction = 1;
                floor.sector = s2;
                floor.speed = 65536 / 2;
                floor.texture = int16(uint16(c.map.sectors[s3].floorpic));
                floor.newspecial = 0;
                floor.floordestheight = c.map.sectors[s3].floorheight;
                id = P_Heap.allocateFloorMove(c.state);
                floor = c.state.floors[id];
                floor.thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.floor, id);
                c.state.sectors[s1].specialdata = floor.thinker;
                floor.floorType = FloorType.lowerFloor;
                floor.crush = false;
                floor.direction = -1;
                floor.sector = s1;
                floor.speed = 65536 / 2;
                floor.floordestheight = c.map.sectors[s3].floorheight;
                break;
            }
        }
    }

    function P_SpawnSpecials(GameContext memory c) internal view {
        // Declared CLI profile has no -avg/-timer host arguments. Timed update semantics remain original.
        c.state.levelTimer = false;
        for (uint32 i; i < c.state.sectors.length; i++) {
            int16 special = c.state.sectors[i].special;
            if (special == 0) continue;
            if (special == 1) {
                P_Lights.P_SpawnLightFlash(c, i);
            } else if (special == 2) {
                P_Lights.P_SpawnStrobeFlash(c, i, 15, 0);
            } else if (special == 3) {
                P_Lights.P_SpawnStrobeFlash(c, i, 35, 0);
            } else if (special == 4) {
                P_Lights.P_SpawnStrobeFlash(c, i, 15, 0);
                c.state.sectors[i].special = 4;
            } else if (special == 8) {
                P_Lights.P_SpawnGlowingLight(c, i);
            } else if (special == 9) {
                c.state.totalsecret++;
            } else if (special == 10) {
                P_Doors.P_SpawnDoorCloseIn30(c, i);
            } else if (special == 12) {
                P_Lights.P_SpawnStrobeFlash(c, i, 35, 1);
            } else if (special == 13) {
                P_Lights.P_SpawnStrobeFlash(c, i, 15, 1);
            } else if (special == 14) {
                P_Doors.P_SpawnDoorRaiseIn5Mins(c, i, int32(i));
            } else if (special == 17) {
                P_Lights.P_SpawnFireFlicker(c, i);
            }
        }
        uint256 count;
        for (uint256 i; i < c.map.lines.length; i++) {
            if (c.map.lines[i].special == 48) count++;
        }
        if (count > 64) revert TooManyScrollingLines();
        c.state.scrollingLines = new uint32[](count);
        uint256 at;
        for (uint32 i; i < c.map.lines.length; i++) {
            if (c.map.lines[i].special == 48) c.state.scrollingLines[at++] = i;
        }
        for (uint256 i; i < 30; i++) {
            c.state.activeceilings[i] = C.NULL;
            c.state.activeplats[i] = C.NULL;
        }
        for (uint256 i; i < 16; i++) {
            c.state.buttons[i] = Button(C.NULL, ButtonWhere.top, 0, 0, C.NULL);
        }
    }

    function P_CrossSpecialLine(GameContext memory c, uint32 line, int32 side, uint32 thing) internal view {
        if (c.state.mobjs[thing].player == C.NULL) {
            uint32 kind = c.state.mobjs[thing].mobjType;
            if (
                kind == P_Info.MT_ROCKET || kind == P_Info.MT_PLASMA || kind == P_Info.MT_BFG
                    || kind == P_Info.MT_TROOPSHOT || kind == P_Info.MT_HEADSHOT
                    || kind == P_Info.MT_BRUISERSHOT
            ) return;
            int16 special = c.map.lines[line].special;
            if (!(special == 39 || special == 97 || special == 125 || special == 126 || special == 4
                        || special == 10 || special == 88)) return;
        }
        if (c.map.lines[line].special == 2) {
            P_Doors.EV_DoDoor(c, line, DoorType.open);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 3) {
            P_Doors.EV_DoDoor(c, line, DoorType.close);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 4) {
            P_Doors.EV_DoDoor(c, line, DoorType.normal);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 5) {
            P_Floor.EV_DoFloor(c, line, FloorType.raiseFloor);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 6) {
            P_Ceilng.EV_DoCeiling(c, line, CeilingType.fastCrushAndRaise);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 8) {
            P_Floor.EV_BuildStairs(c, line, StairType.build8);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 10) {
            P_Plats.EV_DoPlat(c, line, PlatType.downWaitUpStay, 0);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 12) {
            P_Lights.EV_LightTurnOn(c, line, 0);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 13) {
            P_Lights.EV_LightTurnOn(c, line, 255);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 16) {
            P_Doors.EV_DoDoor(c, line, DoorType.close30ThenOpen);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 17) {
            P_Lights.EV_StartLightStrobing(c, line);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 19) {
            P_Floor.EV_DoFloor(c, line, FloorType.lowerFloor);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 22) {
            P_Plats.EV_DoPlat(c, line, PlatType.raiseToNearestAndChange, 0);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 25) {
            P_Ceilng.EV_DoCeiling(c, line, CeilingType.crushAndRaise);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 30) {
            P_Floor.EV_DoFloor(c, line, FloorType.raiseToTexture);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 35) {
            P_Lights.EV_LightTurnOn(c, line, 35);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 36) {
            P_Floor.EV_DoFloor(c, line, FloorType.turboLower);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 37) {
            P_Floor.EV_DoFloor(c, line, FloorType.lowerAndChange);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 38) {
            P_Floor.EV_DoFloor(c, line, FloorType.lowerFloorToLowest);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 39) {
            P_Telept.EV_Teleport(c, line, side, thing);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 40) {
            P_Ceilng.EV_DoCeiling(c, line, CeilingType.raiseToHighest);
            P_Floor.EV_DoFloor(c, line, FloorType.lowerFloorToLowest);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 44) {
            P_Ceilng.EV_DoCeiling(c, line, CeilingType.lowerAndCrush);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 52) {
            G_Game.G_ExitLevel(c.state);
        } else if (c.map.lines[line].special == 53) {
            P_Plats.EV_DoPlat(c, line, PlatType.perpetualRaise, 0);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 54) {
            P_Plats.EV_StopPlat(c, line);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 56) {
            P_Floor.EV_DoFloor(c, line, FloorType.raiseFloorCrush);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 57) {
            P_Ceilng.EV_CeilingCrushStop(c, line);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 58) {
            P_Floor.EV_DoFloor(c, line, FloorType.raiseFloor24);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 59) {
            P_Floor.EV_DoFloor(c, line, FloorType.raiseFloor24AndChange);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 104) {
            P_Lights.EV_TurnTagLightsOff(c, line);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 108) {
            P_Doors.EV_DoDoor(c, line, DoorType.blazeRaise);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 109) {
            P_Doors.EV_DoDoor(c, line, DoorType.blazeOpen);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 100) {
            P_Floor.EV_BuildStairs(c, line, StairType.turbo16);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 110) {
            P_Doors.EV_DoDoor(c, line, DoorType.blazeClose);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 119) {
            P_Floor.EV_DoFloor(c, line, FloorType.raiseFloorToNearest);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 121) {
            P_Plats.EV_DoPlat(c, line, PlatType.blazeDWUS, 0);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 124) {
            G_Game.G_SecretExitLevel(c);
        } else if (c.map.lines[line].special == 125) {
            if (c.state.mobjs[thing].player == C.NULL) {
                P_Telept.EV_Teleport(c, line, side, thing);
                c.map.lines[line].special = 0;
            }
        } else if (c.map.lines[line].special == 130) {
            P_Floor.EV_DoFloor(c, line, FloorType.raiseFloorTurbo);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 141) {
            P_Ceilng.EV_DoCeiling(c, line, CeilingType.silentCrushAndRaise);
            c.map.lines[line].special = 0;
        } else if (c.map.lines[line].special == 72) {
            P_Ceilng.EV_DoCeiling(c, line, CeilingType.lowerAndCrush);
        } else if (c.map.lines[line].special == 73) {
            P_Ceilng.EV_DoCeiling(c, line, CeilingType.crushAndRaise);
        } else if (c.map.lines[line].special == 74) {
            P_Ceilng.EV_CeilingCrushStop(c, line);
        } else if (c.map.lines[line].special == 75) {
            P_Doors.EV_DoDoor(c, line, DoorType.close);
        } else if (c.map.lines[line].special == 76) {
            P_Doors.EV_DoDoor(c, line, DoorType.close30ThenOpen);
        } else if (c.map.lines[line].special == 77) {
            P_Ceilng.EV_DoCeiling(c, line, CeilingType.fastCrushAndRaise);
        } else if (c.map.lines[line].special == 79) {
            P_Lights.EV_LightTurnOn(c, line, 35);
        } else if (c.map.lines[line].special == 80) {
            P_Lights.EV_LightTurnOn(c, line, 0);
        } else if (c.map.lines[line].special == 81) {
            P_Lights.EV_LightTurnOn(c, line, 255);
        } else if (c.map.lines[line].special == 82) {
            P_Floor.EV_DoFloor(c, line, FloorType.lowerFloorToLowest);
        } else if (c.map.lines[line].special == 83) {
            P_Floor.EV_DoFloor(c, line, FloorType.lowerFloor);
        } else if (c.map.lines[line].special == 84) {
            P_Floor.EV_DoFloor(c, line, FloorType.lowerAndChange);
        } else if (c.map.lines[line].special == 86) {
            P_Doors.EV_DoDoor(c, line, DoorType.open);
        } else if (c.map.lines[line].special == 87) {
            P_Plats.EV_DoPlat(c, line, PlatType.perpetualRaise, 0);
        } else if (c.map.lines[line].special == 88) {
            P_Plats.EV_DoPlat(c, line, PlatType.downWaitUpStay, 0);
        } else if (c.map.lines[line].special == 89) {
            P_Plats.EV_StopPlat(c, line);
        } else if (c.map.lines[line].special == 90) {
            P_Doors.EV_DoDoor(c, line, DoorType.normal);
        } else if (c.map.lines[line].special == 91) {
            P_Floor.EV_DoFloor(c, line, FloorType.raiseFloor);
        } else if (c.map.lines[line].special == 92) {
            P_Floor.EV_DoFloor(c, line, FloorType.raiseFloor24);
        } else if (c.map.lines[line].special == 93) {
            P_Floor.EV_DoFloor(c, line, FloorType.raiseFloor24AndChange);
        } else if (c.map.lines[line].special == 94) {
            P_Floor.EV_DoFloor(c, line, FloorType.raiseFloorCrush);
        } else if (c.map.lines[line].special == 95) {
            P_Plats.EV_DoPlat(c, line, PlatType.raiseToNearestAndChange, 0);
        } else if (c.map.lines[line].special == 96) {
            P_Floor.EV_DoFloor(c, line, FloorType.raiseToTexture);
        } else if (c.map.lines[line].special == 97) {
            P_Telept.EV_Teleport(c, line, side, thing);
        } else if (c.map.lines[line].special == 98) {
            P_Floor.EV_DoFloor(c, line, FloorType.turboLower);
        } else if (c.map.lines[line].special == 105) {
            P_Doors.EV_DoDoor(c, line, DoorType.blazeRaise);
        } else if (c.map.lines[line].special == 106) {
            P_Doors.EV_DoDoor(c, line, DoorType.blazeOpen);
        } else if (c.map.lines[line].special == 107) {
            P_Doors.EV_DoDoor(c, line, DoorType.blazeClose);
        } else if (c.map.lines[line].special == 120) {
            P_Plats.EV_DoPlat(c, line, PlatType.blazeDWUS, 0);
        } else if (c.map.lines[line].special == 126) {
            if (c.state.mobjs[thing].player == C.NULL) {
                P_Telept.EV_Teleport(c, line, side, thing);
            }
        } else if (c.map.lines[line].special == 128) {
            P_Floor.EV_DoFloor(c, line, FloorType.raiseFloorToNearest);
        } else if (c.map.lines[line].special == 129) {
            P_Floor.EV_DoFloor(c, line, FloorType.raiseFloorTurbo);
        }
    }

    function P_ShootSpecialLine(GameContext memory c, uint32 thing, uint32 line) internal view {
        if (c.state.mobjs[thing].player == C.NULL && c.map.lines[line].special != 46) return;
        if (c.map.lines[line].special == 24) {
            P_Floor.EV_DoFloor(c, line, FloorType.raiseFloor);
            P_Switch.P_ChangeSwitchTexture(c, line, 0);
        } else if (c.map.lines[line].special == 46) {
            P_Doors.EV_DoDoor(c, line, DoorType.open);
            P_Switch.P_ChangeSwitchTexture(c, line, 1);
        } else if (c.map.lines[line].special == 47) {
            P_Plats.EV_DoPlat(c, line, PlatType.raiseToNearestAndChange, 0);
            P_Switch.P_ChangeSwitchTexture(c, line, 0);
        }
    }
}
