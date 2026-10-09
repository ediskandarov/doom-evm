// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {GameContext, GameConst, ThinkerKind, CeilingMove, CeilingType, PlaneResult} from "./p_game_state.sol";
import {P_Heap} from "./p_heap.sol";
import {P_Tick} from "./p_tick.sol";
import {P_Spec} from "./p_spec.sol";
import {P_Floor} from "./p_floor.sol";

/// @custom:source linuxdoom-1.10/p_ceilng.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
library P_Ceilng {
    function T_MoveCeiling(GameContext memory c, uint32 id) internal view {
        CeilingMove memory ceiling = c.state.ceilings[id];
        PlaneResult res;
        if (ceiling.direction == 1) {
            res = P_Floor.T_MovePlane(c, ceiling.sector, ceiling.speed, ceiling.topheight, false, 1, 1);
            if (res == PlaneResult.pastdest) {
                if (ceiling.ceilingType == CeilingType.raiseToHighest) {
                    P_RemoveActiveCeiling(c, id);
                } else if (
                    ceiling.ceilingType == CeilingType.silentCrushAndRaise
                        || ceiling.ceilingType == CeilingType.fastCrushAndRaise
                        || ceiling.ceilingType == CeilingType.crushAndRaise
                ) {
                    ceiling.direction = -1;
                }
            }
        } else if (ceiling.direction == -1) {
            res = P_Floor.T_MovePlane(
                c, ceiling.sector, ceiling.speed, ceiling.bottomheight, ceiling.crush, 1, -1
            );
            if (res == PlaneResult.pastdest) {
                if (
                    ceiling.ceilingType == CeilingType.silentCrushAndRaise
                        || ceiling.ceilingType == CeilingType.crushAndRaise
                ) {
                    ceiling.speed = 65536;
                    ceiling.direction = 1;
                } else if (ceiling.ceilingType == CeilingType.fastCrushAndRaise) {
                    ceiling.direction = 1;
                } else if (
                    ceiling.ceilingType == CeilingType.lowerAndCrush
                        || ceiling.ceilingType == CeilingType.lowerToFloor
                ) {
                    P_RemoveActiveCeiling(c, id);
                }
            } else if (res == PlaneResult.crushed) {
                if (
                    ceiling.ceilingType == CeilingType.silentCrushAndRaise
                        || ceiling.ceilingType == CeilingType.crushAndRaise
                        || ceiling.ceilingType == CeilingType.lowerAndCrush
                ) ceiling.speed = 65536 / 8;
            }
        }
    }

    function EV_DoCeiling(GameContext memory c, uint32 line, CeilingType kind)
        internal
        pure
        returns (int32 rtn)
    {
        if (
            kind == CeilingType.fastCrushAndRaise || kind == CeilingType.silentCrushAndRaise
                || kind == CeilingType.crushAndRaise
        ) P_ActivateInStasisCeiling(c, line);
        int32 secnum = -1;
        while ((secnum = P_Spec.P_FindSectorFromLineTag(c, line, secnum)) >= 0) {
            uint32 sector = uint32(secnum);
            if (c.state.sectors[sector].specialdata != GameConst.NULL) continue;
            rtn = 1;
            uint32 id = P_Heap.allocateCeilingMove(c.state);
            CeilingMove memory ceiling = c.state.ceilings[id];
            ceiling.thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.ceiling, id);
            c.state.sectors[sector].specialdata = ceiling.thinker;
            ceiling.sector = sector;
            ceiling.crush = false;
            unchecked {
                if (kind == CeilingType.fastCrushAndRaise) {
                    ceiling.crush = true;
                    ceiling.topheight = c.map.sectors[sector].ceilingheight;
                    ceiling.bottomheight = c.map.sectors[sector].floorheight + 8 * 65536;
                    ceiling.direction = -1;
                    ceiling.speed = 2 * 65536;
                } else if (
                    kind == CeilingType.silentCrushAndRaise || kind == CeilingType.crushAndRaise
                        || kind == CeilingType.lowerAndCrush || kind == CeilingType.lowerToFloor
                ) {
                    if (kind == CeilingType.silentCrushAndRaise || kind == CeilingType.crushAndRaise) {
                        ceiling.crush = true;
                        ceiling.topheight = c.map.sectors[sector].ceilingheight;
                    }
                    ceiling.bottomheight = c.map.sectors[sector].floorheight;
                    if (kind != CeilingType.lowerToFloor) ceiling.bottomheight += 8 * 65536;
                    ceiling.direction = -1;
                    ceiling.speed = 65536;
                } else if (kind == CeilingType.raiseToHighest) {
                    ceiling.topheight = P_Spec.P_FindHighestCeilingSurrounding(c, sector);
                    ceiling.direction = 1;
                    ceiling.speed = 65536;
                }
            }
            ceiling.tag = c.state.sectors[sector].tag;
            ceiling.ceilingType = kind;
            P_AddActiveCeiling(c, id);
        }
    }

    function P_AddActiveCeiling(GameContext memory c, uint32 id) internal pure {
        for (uint32 i; i < 30; ++i) {
            if (c.state.activeceilings[i] == GameConst.NULL) {
                c.state.activeceilings[i] = id;
                return;
            }
        }
        // Original silently leaves overflow ceilings running but outside the registry.
    }

    function P_RemoveActiveCeiling(GameContext memory c, uint32 id) internal pure {
        for (uint32 i; i < 30; ++i) {
            if (c.state.activeceilings[i] == id) {
                CeilingMove memory ceiling = c.state.ceilings[id];
                c.state.sectors[ceiling.sector].specialdata = GameConst.NULL;
                P_Tick.P_RemoveThinker(c.state, ceiling.thinker);
                c.state.activeceilings[i] = GameConst.NULL;
                break;
            }
        }
    }

    function P_ActivateInStasisCeiling(GameContext memory c, uint32 line) internal pure {
        for (uint32 i; i < 30; ++i) {
            uint32 id = c.state.activeceilings[i];
            if (id == GameConst.NULL) continue;
            CeilingMove memory ceiling = c.state.ceilings[id];
            if (ceiling.tag == c.map.lines[line].tag && ceiling.direction == 0) {
                ceiling.direction = ceiling.olddirection;
                c.state.thinkers[ceiling.thinker].status = GameConst.THINKER_ACTIVE;
            }
        }
    }

    function EV_CeilingCrushStop(GameContext memory c, uint32 line) internal pure returns (int32 rtn) {
        for (uint32 i; i < 30; ++i) {
            uint32 id = c.state.activeceilings[i];
            if (id == GameConst.NULL) continue;
            CeilingMove memory ceiling = c.state.ceilings[id];
            if (ceiling.tag == c.map.lines[line].tag && ceiling.direction != 0) {
                ceiling.olddirection = ceiling.direction;
                c.state.thinkers[ceiling.thinker].status = GameConst.THINKER_STASIS;
                ceiling.direction = 0;
                rtn = 1;
            }
        }
    }
}
