// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {
    GameContext,
    GameConst,
    ThinkerKind,
    Plat,
    PlatType,
    PlatStatus,
    PlaneResult
} from "./p_game_state.sol";
import {P_Heap} from "./p_heap.sol";
import {P_Tick} from "./p_tick.sol";
import {P_Spec} from "./p_spec.sol";
import {P_Floor} from "./p_floor.sol";
import {M_Random} from "./m_random.sol";

/// @custom:source linuxdoom-1.10/p_plats.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
library P_Plats {
    error NoMorePlats();
    error ActivePlatNotFound(uint32 id);

    function T_PlatRaise(GameContext memory c, uint32 id) internal view {
        Plat memory plat = c.state.plats[id];
        PlaneResult res;
        if (plat.status == PlatStatus.up) {
            res = P_Floor.T_MovePlane(c, plat.sector, plat.speed, plat.high, plat.crush, 0, 1);
            if (res == PlaneResult.crushed && !plat.crush) {
                plat.count = plat.wait;
                plat.status = PlatStatus.down;
            } else if (res == PlaneResult.pastdest) {
                plat.count = plat.wait;
                plat.status = PlatStatus.waiting;
                if (
                    plat.platType == PlatType.blazeDWUS || plat.platType == PlatType.downWaitUpStay
                        || plat.platType == PlatType.raiseAndChange
                        || plat.platType == PlatType.raiseToNearestAndChange
                ) P_RemoveActivePlat(c, id);
            }
        } else if (plat.status == PlatStatus.down) {
            res = P_Floor.T_MovePlane(c, plat.sector, plat.speed, plat.low, false, 0, -1);
            if (res == PlaneResult.pastdest) {
                plat.count = plat.wait;
                plat.status = PlatStatus.waiting;
            }
        } else if (plat.status == PlatStatus.waiting) {
            unchecked {
                --plat.count;
            }
            if (plat.count == 0) {
                plat.status =
                    c.map.sectors[plat.sector].floorheight == plat.low ? PlatStatus.up : PlatStatus.down;
            }
        }
    }

    function EV_DoPlat(GameContext memory c, uint32 line, PlatType kind, int32 amount)
        internal
        pure
        returns (int32 rtn)
    {
        if (kind == PlatType.perpetualRaise) P_ActivateInStasis(c, c.map.lines[line].tag);
        int32 secnum = -1;
        while ((secnum = P_Spec.P_FindSectorFromLineTag(c, line, secnum)) >= 0) {
            uint32 sector = uint32(secnum);
            if (c.state.sectors[sector].specialdata != GameConst.NULL) continue;
            rtn = 1;
            uint32 id = P_Heap.allocatePlat(c.state);
            Plat memory plat = c.state.plats[id];
            plat.thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.plat, id);
            plat.platType = kind;
            plat.sector = sector;
            c.state.sectors[sector].specialdata = plat.thinker;
            plat.crush = false;
            plat.tag = c.map.lines[line].tag;
            unchecked {
                if (kind == PlatType.raiseToNearestAndChange || kind == PlatType.raiseAndChange) {
                    plat.speed = 65536 / 2;
                    c.map.sectors[sector].floorpic =
                    c.map.sectors[c.map.sides[c.map.lines[line].sidenum[0]].sector].floorpic;
                    plat.high = kind == PlatType.raiseToNearestAndChange
                        ? P_Spec.P_FindNextHighestFloor(c, sector, c.map.sectors[sector].floorheight)
                        : c.map.sectors[sector].floorheight + amount * 65536;
                    plat.wait = 0;
                    plat.status = PlatStatus.up;
                    if (kind == PlatType.raiseToNearestAndChange) c.state.sectors[sector].special = 0;
                } else if (kind == PlatType.downWaitUpStay || kind == PlatType.blazeDWUS) {
                    plat.speed = kind == PlatType.downWaitUpStay ? int32(4 * 65536) : int32(8 * 65536);
                    plat.low = P_Spec.P_FindLowestFloorSurrounding(c, sector);
                    if (plat.low > c.map.sectors[sector].floorheight) {
                        plat.low = c.map.sectors[sector].floorheight;
                    }
                    plat.high = c.map.sectors[sector].floorheight;
                    plat.wait = 35 * 3;
                    plat.status = PlatStatus.down;
                } else if (kind == PlatType.perpetualRaise) {
                    plat.speed = 65536;
                    plat.low = P_Spec.P_FindLowestFloorSurrounding(c, sector);
                    if (plat.low > c.map.sectors[sector].floorheight) {
                        plat.low = c.map.sectors[sector].floorheight;
                    }
                    plat.high = P_Spec.P_FindHighestFloorSurrounding(c, sector);
                    if (plat.high < c.map.sectors[sector].floorheight) {
                        plat.high = c.map.sectors[sector].floorheight;
                    }
                    plat.wait = 35 * 3;
                    plat.status = PlatStatus(uint32(M_Random.P_Random(c.state) & 1));
                }
            }
            P_AddActivePlat(c, id);
        }
    }

    function P_ActivateInStasis(GameContext memory c, int32 tag) internal pure {
        for (uint32 i; i < 30; ++i) {
            uint32 id = c.state.activeplats[i];
            if (id == GameConst.NULL) continue;
            Plat memory plat = c.state.plats[id];
            if (plat.tag == tag && plat.status == PlatStatus.inStasis) {
                plat.status = plat.oldstatus;
                c.state.thinkers[plat.thinker].status = GameConst.THINKER_ACTIVE;
            }
        }
    }

    function EV_StopPlat(GameContext memory c, uint32 line) internal pure {
        for (uint32 i; i < 30; ++i) {
            uint32 id = c.state.activeplats[i];
            if (id == GameConst.NULL) continue;
            Plat memory plat = c.state.plats[id];
            if (plat.status != PlatStatus.inStasis && plat.tag == c.map.lines[line].tag) {
                plat.oldstatus = plat.status;
                plat.status = PlatStatus.inStasis;
                c.state.thinkers[plat.thinker].status = GameConst.THINKER_STASIS;
            }
        }
    }

    function P_AddActivePlat(GameContext memory c, uint32 id) internal pure {
        for (uint32 i; i < 30; ++i) {
            if (c.state.activeplats[i] == GameConst.NULL) {
                c.state.activeplats[i] = id;
                return;
            }
        }
        revert NoMorePlats();
    }

    function P_RemoveActivePlat(GameContext memory c, uint32 id) internal pure {
        for (uint32 i; i < 30; ++i) {
            if (c.state.activeplats[i] == id) {
                c.state.sectors[c.state.plats[id].sector].specialdata = GameConst.NULL;
                P_Tick.P_RemoveThinker(c.state, c.state.plats[id].thinker);
                c.state.activeplats[i] = GameConst.NULL;
                return;
            }
        }
        revert ActivePlatNotFound(id);
    }
}
