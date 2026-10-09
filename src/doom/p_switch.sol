// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {GameContext, Button, ButtonWhere} from "./p_game_state.sol";
import {R_Data} from "./r_data.sol";
import {GameConst as C, DoorType, FloorType, CeilingType, PlatType} from "./p_game_state.sol";
import {G_Game} from "./g_game.sol";
import {P_Spec} from "./p_spec.sol";
import {P_Doors} from "./p_doors.sol";
import {P_Floor, StairType} from "./p_floor.sol";
import {P_Ceilng} from "./p_ceilng.sol";
import {P_Plats} from "./p_plats.sol";
import {P_Lights} from "./p_lights.sol";

struct SwitchDef {
    bytes8 name1;
    bytes8 name2;
    int16 episode;
}

/// @custom:source linuxdoom-1.10/p_switch.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
library P_Switch {
    error NoButtonSlots();

    function switchDefs() internal pure returns (SwitchDef[40] memory defs) {
        defs[0] = SwitchDef("SW1BRCOM", "SW2BRCOM", 1);
        defs[1] = SwitchDef("SW1BRN1", "SW2BRN1", 1);
        defs[2] = SwitchDef("SW1BRN2", "SW2BRN2", 1);
        defs[3] = SwitchDef("SW1BRNGN", "SW2BRNGN", 1);
        defs[4] = SwitchDef("SW1BROWN", "SW2BROWN", 1);
        defs[5] = SwitchDef("SW1COMM", "SW2COMM", 1);
        defs[6] = SwitchDef("SW1COMP", "SW2COMP", 1);
        defs[7] = SwitchDef("SW1DIRT", "SW2DIRT", 1);
        defs[8] = SwitchDef("SW1EXIT", "SW2EXIT", 1);
        defs[9] = SwitchDef("SW1GRAY", "SW2GRAY", 1);
        defs[10] = SwitchDef("SW1GRAY1", "SW2GRAY1", 1);
        defs[11] = SwitchDef("SW1METAL", "SW2METAL", 1);
        defs[12] = SwitchDef("SW1PIPE", "SW2PIPE", 1);
        defs[13] = SwitchDef("SW1SLAD", "SW2SLAD", 1);
        defs[14] = SwitchDef("SW1STARG", "SW2STARG", 1);
        defs[15] = SwitchDef("SW1STON1", "SW2STON1", 1);
        defs[16] = SwitchDef("SW1STON2", "SW2STON2", 1);
        defs[17] = SwitchDef("SW1STONE", "SW2STONE", 1);
        defs[18] = SwitchDef("SW1STRTN", "SW2STRTN", 1);
        defs[19] = SwitchDef("SW1BLUE", "SW2BLUE", 2);
        defs[20] = SwitchDef("SW1CMT", "SW2CMT", 2);
        defs[21] = SwitchDef("SW1GARG", "SW2GARG", 2);
        defs[22] = SwitchDef("SW1GSTON", "SW2GSTON", 2);
        defs[23] = SwitchDef("SW1HOT", "SW2HOT", 2);
        defs[24] = SwitchDef("SW1LION", "SW2LION", 2);
        defs[25] = SwitchDef("SW1SATYR", "SW2SATYR", 2);
        defs[26] = SwitchDef("SW1SKIN", "SW2SKIN", 2);
        defs[27] = SwitchDef("SW1VINE", "SW2VINE", 2);
        defs[28] = SwitchDef("SW1WOOD", "SW2WOOD", 2);
        defs[29] = SwitchDef("SW1PANEL", "SW2PANEL", 3);
        defs[30] = SwitchDef("SW1ROCK", "SW2ROCK", 3);
        defs[31] = SwitchDef("SW1MET2", "SW2MET2", 3);
        defs[32] = SwitchDef("SW1WDMET", "SW2WDMET", 3);
        defs[33] = SwitchDef("SW1BRIK", "SW2BRIK", 3);
        defs[34] = SwitchDef("SW1MOD1", "SW2MOD1", 3);
        defs[35] = SwitchDef("SW1ZIM", "SW2ZIM", 3);
        defs[36] = SwitchDef("SW1STON6", "SW2STON6", 3);
        defs[37] = SwitchDef("SW1TEK", "SW2TEK", 3);
        defs[38] = SwitchDef("SW1MARB", "SW2MARB", 3);
        defs[39] = SwitchDef("SW1SKULL", "SW2SKULL", 3);
    }

    function P_InitSwitchList(GameContext memory c) internal pure {
        int16 episode = c.state.gamemode == 1 ? int16(2) : c.state.gamemode == 2 ? int16(3) : int16(1);
        SwitchDef[40] memory defs = switchDefs();
        uint256 count;
        for (uint256 i; i < defs.length; i++) {
            if (defs[i].episode <= episode) count++;
        }
        c.state.switchlist = new int32[](count * 2 + 1);
        uint256 at;
        for (uint256 i; i < defs.length; i++) {
            if (defs[i].episode > episode) continue;
            c.state.switchlist[at++] = int32(R_Data.R_TextureNumForName(c.resources, defs[i].name1));
            c.state.switchlist[at++] = int32(R_Data.R_TextureNumForName(c.resources, defs[i].name2));
        }
        c.state.numswitches = int32(uint32(count));
        c.state.switchlist[at] = -1;
    }

    function P_StartButton(GameContext memory c, uint32 line, ButtonWhere where, int32 texture, int32 time)
        internal
        pure
    {
        for (uint256 i; i < 16; i++) {
            if (c.state.buttons[i].btimer != 0 && c.state.buttons[i].line == line) return;
        }
        for (uint256 i; i < 16; i++) {
            Button memory button = c.state.buttons[i];
            if (button.btimer != 0) continue;
            button.line = line;
            button.where = where;
            button.btexture = texture;
            button.btimer = time;
            button.soundsector = c.map.lines[line].frontsector;
            return;
        }
        revert NoButtonSlots();
    }

    function P_ChangeSwitchTexture(GameContext memory c, uint32 line, int32 useAgain) internal pure {
        if (useAgain == 0) c.map.lines[line].special = 0;
        uint32 side = c.map.lines[line].sidenum[0];
        int32 texTop = int32(c.map.sides[side].toptexture);
        int32 texMid = int32(c.map.sides[side].midtexture);
        int32 texBot = int32(c.map.sides[side].bottomtexture);
        for (uint32 i; i < uint32(c.state.numswitches) * 2; i++) {
            if (c.state.switchlist[i] == texTop) {
                c.map.sides[side].toptexture = uint32(c.state.switchlist[i ^ 1]);
                if (useAgain != 0) P_StartButton(c, line, ButtonWhere.top, c.state.switchlist[i], 35);
                return;
            } else if (c.state.switchlist[i] == texMid) {
                c.map.sides[side].midtexture = uint32(c.state.switchlist[i ^ 1]);
                if (useAgain != 0) P_StartButton(c, line, ButtonWhere.middle, c.state.switchlist[i], 35);
                return;
            } else if (c.state.switchlist[i] == texBot) {
                c.map.sides[side].bottomtexture = uint32(c.state.switchlist[i ^ 1]);
                if (useAgain != 0) P_StartButton(c, line, ButtonWhere.bottom, c.state.switchlist[i], 35);
                return;
            }
        }
    }

    function P_UseSpecialLine(GameContext memory c, uint32 thing, uint32 line, int32 side)
        internal
        view
        returns (bool)
    {
        if (side != 0 && c.map.lines[line].special != 124) return false;
        if (c.state.mobjs[thing].player == C.NULL) {
            if (c.map.lines[line].flags & 32 != 0) return false;
            int16 special = c.map.lines[line].special;
            if (!(special == 1 || special == 32 || special == 33 || special == 34)) return false;
        }
        if (
            c.map.lines[line].special == 1 || c.map.lines[line].special == 26
                || c.map.lines[line].special == 27 || c.map.lines[line].special == 28
                || c.map.lines[line].special == 31 || c.map.lines[line].special == 32
                || c.map.lines[line].special == 33 || c.map.lines[line].special == 34
                || c.map.lines[line].special == 117 || c.map.lines[line].special == 118
        ) {
            P_Doors.EV_VerticalDoor(c, line, thing);
        } else if (c.map.lines[line].special == 7) {
            if (P_Floor.EV_BuildStairs(c, line, StairType.build8) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 9) {
            if (P_Spec.EV_DoDonut(c, line) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 11) {
            P_Switch.P_ChangeSwitchTexture(c, line, 0);
            G_Game.G_ExitLevel(c.state);
        } else if (c.map.lines[line].special == 14) {
            if (P_Plats.EV_DoPlat(c, line, PlatType.raiseAndChange, 32) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 15) {
            if (P_Plats.EV_DoPlat(c, line, PlatType.raiseAndChange, 24) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 18) {
            if (P_Floor.EV_DoFloor(c, line, FloorType.raiseFloorToNearest) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 20) {
            if (P_Plats.EV_DoPlat(c, line, PlatType.raiseToNearestAndChange, 0) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 21) {
            if (P_Plats.EV_DoPlat(c, line, PlatType.downWaitUpStay, 0) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 23) {
            if (P_Floor.EV_DoFloor(c, line, FloorType.lowerFloorToLowest) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 29) {
            if (P_Doors.EV_DoDoor(c, line, DoorType.normal) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 41) {
            if (P_Ceilng.EV_DoCeiling(c, line, CeilingType.lowerToFloor) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 71) {
            if (P_Floor.EV_DoFloor(c, line, FloorType.turboLower) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 49) {
            if (P_Ceilng.EV_DoCeiling(c, line, CeilingType.crushAndRaise) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 50) {
            if (P_Doors.EV_DoDoor(c, line, DoorType.close) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 51) {
            P_Switch.P_ChangeSwitchTexture(c, line, 0);
            G_Game.G_SecretExitLevel(c);
        } else if (c.map.lines[line].special == 55) {
            if (P_Floor.EV_DoFloor(c, line, FloorType.raiseFloorCrush) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 101) {
            if (P_Floor.EV_DoFloor(c, line, FloorType.raiseFloor) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 102) {
            if (P_Floor.EV_DoFloor(c, line, FloorType.lowerFloor) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 103) {
            if (P_Doors.EV_DoDoor(c, line, DoorType.open) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 111) {
            if (P_Doors.EV_DoDoor(c, line, DoorType.blazeRaise) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 112) {
            if (P_Doors.EV_DoDoor(c, line, DoorType.blazeOpen) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 113) {
            if (P_Doors.EV_DoDoor(c, line, DoorType.blazeClose) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 122) {
            if (P_Plats.EV_DoPlat(c, line, PlatType.blazeDWUS, 0) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 127) {
            if (P_Floor.EV_BuildStairs(c, line, StairType.turbo16) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 131) {
            if (P_Floor.EV_DoFloor(c, line, FloorType.raiseFloorTurbo) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (
            c.map.lines[line].special == 133 || c.map.lines[line].special == 135
                || c.map.lines[line].special == 137
        ) {
            if (P_Doors.EV_DoLockedDoor(c, line, DoorType.blazeOpen, thing) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 140) {
            if (P_Floor.EV_DoFloor(c, line, FloorType.raiseFloor512) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 0);
            }
        } else if (c.map.lines[line].special == 42) {
            if (P_Doors.EV_DoDoor(c, line, DoorType.close) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (c.map.lines[line].special == 43) {
            if (P_Ceilng.EV_DoCeiling(c, line, CeilingType.lowerToFloor) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (c.map.lines[line].special == 45) {
            if (P_Floor.EV_DoFloor(c, line, FloorType.lowerFloor) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (c.map.lines[line].special == 60) {
            if (P_Floor.EV_DoFloor(c, line, FloorType.lowerFloorToLowest) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (c.map.lines[line].special == 61) {
            if (P_Doors.EV_DoDoor(c, line, DoorType.open) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (c.map.lines[line].special == 62) {
            if (P_Plats.EV_DoPlat(c, line, PlatType.downWaitUpStay, 1) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (c.map.lines[line].special == 63) {
            if (P_Doors.EV_DoDoor(c, line, DoorType.normal) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (c.map.lines[line].special == 64) {
            if (P_Floor.EV_DoFloor(c, line, FloorType.raiseFloor) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (c.map.lines[line].special == 66) {
            if (P_Plats.EV_DoPlat(c, line, PlatType.raiseAndChange, 24) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (c.map.lines[line].special == 67) {
            if (P_Plats.EV_DoPlat(c, line, PlatType.raiseAndChange, 32) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (c.map.lines[line].special == 65) {
            if (P_Floor.EV_DoFloor(c, line, FloorType.raiseFloorCrush) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (c.map.lines[line].special == 68) {
            if (P_Plats.EV_DoPlat(c, line, PlatType.raiseToNearestAndChange, 0) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (c.map.lines[line].special == 69) {
            if (P_Floor.EV_DoFloor(c, line, FloorType.raiseFloorToNearest) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (c.map.lines[line].special == 70) {
            if (P_Floor.EV_DoFloor(c, line, FloorType.turboLower) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (c.map.lines[line].special == 114) {
            if (P_Doors.EV_DoDoor(c, line, DoorType.blazeRaise) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (c.map.lines[line].special == 115) {
            if (P_Doors.EV_DoDoor(c, line, DoorType.blazeOpen) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (c.map.lines[line].special == 116) {
            if (P_Doors.EV_DoDoor(c, line, DoorType.blazeClose) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (c.map.lines[line].special == 123) {
            if (P_Plats.EV_DoPlat(c, line, PlatType.blazeDWUS, 0) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (c.map.lines[line].special == 132) {
            if (P_Floor.EV_DoFloor(c, line, FloorType.raiseFloorTurbo) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (
            c.map.lines[line].special == 99 || c.map.lines[line].special == 134
                || c.map.lines[line].special == 136
        ) {
            if (P_Doors.EV_DoLockedDoor(c, line, DoorType.blazeOpen, thing) != 0) {
                P_Switch.P_ChangeSwitchTexture(c, line, 1);
            }
        } else if (c.map.lines[line].special == 138) {
            P_Lights.EV_LightTurnOn(c, line, 255);
            P_Switch.P_ChangeSwitchTexture(c, line, 1);
        } else if (c.map.lines[line].special == 139) {
            P_Lights.EV_LightTurnOn(c, line, 35);
            P_Switch.P_ChangeSwitchTexture(c, line, 1);
        }
        return true;
    }
}
