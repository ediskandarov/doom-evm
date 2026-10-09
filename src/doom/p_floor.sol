// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {GameContext, GameConst, ThinkerKind, FloorMove, FloorType, PlaneResult} from "./p_game_state.sol";
import {P_Heap} from "./p_heap.sol";
import {P_Tick} from "./p_tick.sol";
import {P_Spec} from "./p_spec.sol";

enum StairType {
    build8,
    turbo16
}

/// @custom:source linuxdoom-1.10/p_floor.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
library P_Floor {
    error SyntheticFloorNeedsFrontSector();
    error UninitializedFloorType(FloorType kind);

    function T_MovePlane(
        GameContext memory c,
        uint32 sector,
        int32 speed,
        int32 dest,
        bool crush,
        int32 floorOrCeiling,
        int32 direction
    ) internal view returns (PlaneResult) {
        int32 lastpos;
        bool flag;
        unchecked {
            if (floorOrCeiling == 0) {
                if (direction == -1) {
                    if (c.map.sectors[sector].floorheight - speed < dest) {
                        lastpos = c.map.sectors[sector].floorheight;
                        c.map.sectors[sector].floorheight = dest;
                        flag = c.hooks.changeSector(c, sector, crush);
                        if (flag) {
                            c.map.sectors[sector].floorheight = lastpos;
                            c.hooks.changeSector(c, sector, crush);
                        }
                        return PlaneResult.pastdest;
                    }
                    lastpos = c.map.sectors[sector].floorheight;
                    c.map.sectors[sector].floorheight -= speed;
                    flag = c.hooks.changeSector(c, sector, crush);
                    if (flag) {
                        c.map.sectors[sector].floorheight = lastpos;
                        c.hooks.changeSector(c, sector, crush);
                        return PlaneResult.crushed;
                    }
                } else if (direction == 1) {
                    if (c.map.sectors[sector].floorheight + speed > dest) {
                        lastpos = c.map.sectors[sector].floorheight;
                        c.map.sectors[sector].floorheight = dest;
                        flag = c.hooks.changeSector(c, sector, crush);
                        if (flag) {
                            c.map.sectors[sector].floorheight = lastpos;
                            c.hooks.changeSector(c, sector, crush);
                        }
                        return PlaneResult.pastdest;
                    }
                    lastpos = c.map.sectors[sector].floorheight;
                    c.map.sectors[sector].floorheight += speed;
                    flag = c.hooks.changeSector(c, sector, crush);
                    if (flag) {
                        if (crush) return PlaneResult.crushed;
                        c.map.sectors[sector].floorheight = lastpos;
                        c.hooks.changeSector(c, sector, crush);
                        return PlaneResult.crushed;
                    }
                }
            } else if (floorOrCeiling == 1) {
                if (direction == -1) {
                    if (c.map.sectors[sector].ceilingheight - speed < dest) {
                        lastpos = c.map.sectors[sector].ceilingheight;
                        c.map.sectors[sector].ceilingheight = dest;
                        flag = c.hooks.changeSector(c, sector, crush);
                        if (flag) {
                            c.map.sectors[sector].ceilingheight = lastpos;
                            c.hooks.changeSector(c, sector, crush);
                        }
                        return PlaneResult.pastdest;
                    }
                    lastpos = c.map.sectors[sector].ceilingheight;
                    c.map.sectors[sector].ceilingheight -= speed;
                    flag = c.hooks.changeSector(c, sector, crush);
                    if (flag) {
                        if (crush) return PlaneResult.crushed;
                        c.map.sectors[sector].ceilingheight = lastpos;
                        c.hooks.changeSector(c, sector, crush);
                        return PlaneResult.crushed;
                    }
                } else if (direction == 1) {
                    if (c.map.sectors[sector].ceilingheight + speed > dest) {
                        lastpos = c.map.sectors[sector].ceilingheight;
                        c.map.sectors[sector].ceilingheight = dest;
                        flag = c.hooks.changeSector(c, sector, crush);
                        if (flag) {
                            c.map.sectors[sector].ceilingheight = lastpos;
                            c.hooks.changeSector(c, sector, crush);
                        }
                        return PlaneResult.pastdest;
                    }
                    c.map.sectors[sector].ceilingheight += speed;
                    c.hooks.changeSector(c, sector, crush);
                    // Original upward ceiling obstruction rollback is compiled out (#if 0).
                }
            }
        }
        return PlaneResult.ok;
    }

    function T_MoveFloor(GameContext memory c, uint32 id) internal view {
        FloorMove memory floor = c.state.floors[id];
        PlaneResult res =
            T_MovePlane(c, floor.sector, floor.speed, floor.floordestheight, floor.crush, 0, floor.direction);
        if (res == PlaneResult.pastdest) {
            c.state.sectors[floor.sector].specialdata = GameConst.NULL;
            if (
                (floor.direction == 1 && floor.floorType == FloorType.donutRaise)
                    || (floor.direction == -1 && floor.floorType == FloorType.lowerAndChange)
            ) {
                c.state.sectors[floor.sector].special = int16(floor.newspecial);
                c.map.sectors[floor.sector].floorpic = uint32(int32(floor.texture));
            }
            P_Tick.P_RemoveThinker(c.state, floor.thinker);
        }
    }

    function EV_DoFloor(GameContext memory c, uint32 line, FloorType kind) internal pure returns (int32) {
        return _doFloor(c, c.map.lines[line].tag, c.map.lines[line].frontsector, kind);
    }

    function EV_DoFloorTag(GameContext memory c, int32 tag, FloorType kind) internal pure returns (int32) {
        return _doFloor(c, tag, GameConst.NULL, kind);
    }

    function _doFloor(GameContext memory c, int32 tag, uint32 frontsector, FloorType kind)
        private
        pure
        returns (int32 rtn)
    {
        int32 secnum = -1;
        while ((secnum = P_Spec.P_FindSectorFromTag(c, tag, secnum)) >= 0) {
            uint32 sector = uint32(secnum);
            if (c.state.sectors[sector].specialdata != GameConst.NULL) continue;
            // Original generic donutRaise has no initializer (including its sector pointer).
            // Preserve the defined empty/busy-tag return before rejecting an allocating call.
            if (kind == FloorType.donutRaise) revert UninitializedFloorType(kind);
            if (kind == FloorType.raiseFloor24AndChange && frontsector == GameConst.NULL) {
                revert SyntheticFloorNeedsFrontSector();
            }
            rtn = 1;
            uint32 id = P_Heap.allocateFloorMove(c.state);
            FloorMove memory floor = c.state.floors[id];
            floor.thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.floor, id);
            c.state.sectors[sector].specialdata = floor.thinker;
            floor.floorType = kind;
            floor.crush = false;
            unchecked {
                if (
                    kind == FloorType.lowerFloor || kind == FloorType.lowerFloorToLowest
                        || kind == FloorType.turboLower
                ) {
                    floor.direction = -1;
                    floor.sector = sector;
                    floor.speed = kind == FloorType.turboLower ? int32(4 * 65536) : int32(65536);
                    floor.floordestheight = kind == FloorType.lowerFloorToLowest
                        ? P_Spec.P_FindLowestFloorSurrounding(c, sector)
                        : P_Spec.P_FindHighestFloorSurrounding(c, sector);
                    if (
                        kind == FloorType.turboLower
                            && floor.floordestheight != c.map.sectors[sector].floorheight
                    ) floor.floordestheight += 8 * 65536;
                } else if (kind == FloorType.raiseFloorCrush || kind == FloorType.raiseFloor) {
                    floor.crush = kind == FloorType.raiseFloorCrush;
                    floor.direction = 1;
                    floor.sector = sector;
                    floor.speed = 65536;
                    floor.floordestheight = P_Spec.P_FindLowestCeilingSurrounding(c, sector);
                    if (floor.floordestheight > c.map.sectors[sector].ceilingheight) {
                        floor.floordestheight = c.map.sectors[sector].ceilingheight;
                    }
                    if (kind == FloorType.raiseFloorCrush) floor.floordestheight -= 8 * 65536;
                } else if (kind == FloorType.raiseFloorTurbo || kind == FloorType.raiseFloorToNearest) {
                    floor.direction = 1;
                    floor.sector = sector;
                    floor.speed = kind == FloorType.raiseFloorTurbo ? int32(4 * 65536) : int32(65536);
                    floor.floordestheight =
                        P_Spec.P_FindNextHighestFloor(c, sector, c.map.sectors[sector].floorheight);
                } else if (
                    kind == FloorType.raiseFloor24 || kind == FloorType.raiseFloor512
                        || kind == FloorType.raiseFloor24AndChange
                ) {
                    floor.direction = 1;
                    floor.sector = sector;
                    floor.speed = 65536;
                    floor.floordestheight = c.map.sectors[sector].floorheight
                        + (kind == FloorType.raiseFloor512 ? int32(512 * 65536) : int32(24 * 65536));
                    if (kind == FloorType.raiseFloor24AndChange) {
                        c.map.sectors[sector].floorpic = c.map.sectors[frontsector].floorpic;
                        c.state.sectors[sector].special = c.state.sectors[frontsector].special;
                    }
                } else if (kind == FloorType.raiseToTexture) {
                    int32 minsize = type(int32).max;
                    floor.direction = 1;
                    floor.sector = sector;
                    floor.speed = 65536;
                    for (uint32 i; i < c.state.sectors[sector].lines.length; ++i) {
                        if (P_Spec.twoSided(c, sector, i) == 0) continue;
                        for (uint32 side; side < 2; ++side) {
                            uint32 texture = c.map.sides[P_Spec.getSide(c, sector, i, side)].bottomtexture;
                            if (int32(texture) >= 0) {
                                int32 height = int32(uint32(c.resources.textures[texture].height) << 16);
                                if (height < minsize) minsize = height;
                            }
                        }
                    }
                    floor.floordestheight = c.map.sectors[sector].floorheight + minsize;
                } else if (kind == FloorType.lowerAndChange) {
                    floor.direction = -1;
                    floor.sector = sector;
                    floor.speed = 65536;
                    floor.floordestheight = P_Spec.P_FindLowestFloorSurrounding(c, sector);
                    floor.texture = int16(uint16(c.map.sectors[sector].floorpic));
                    uint32 sec = sector;
                    // Original mutates sec inside the loop, so subsequent linecount uses that sector.
                    for (uint32 i; i < c.state.sectors[sec].lines.length; ++i) {
                        if (P_Spec.twoSided(c, sector, i) == 0) continue;
                        sec = P_Spec.getSector(
                            c,
                            sector,
                            i,
                            c.map.sides[P_Spec.getSide(c, sector, i, 0)].sector == sector ? 1 : 0
                        );
                        if (c.map.sectors[sec].floorheight == floor.floordestheight) {
                            floor.texture = int16(uint16(c.map.sectors[sec].floorpic));
                            floor.newspecial = c.state.sectors[sec].special;
                            break;
                        }
                    }
                }
            }
        }
    }

    function EV_BuildStairs(GameContext memory c, uint32 line, StairType kind)
        internal
        pure
        returns (int32 rtn)
    {
        int32 secnum = -1;
        while ((secnum = P_Spec.P_FindSectorFromLineTag(c, line, secnum)) >= 0) {
            uint32 sec = uint32(secnum);
            if (c.state.sectors[sec].specialdata != GameConst.NULL) continue;
            rtn = 1;
            int32 speed = kind == StairType.build8 ? int32(65536 / 4) : int32(65536 * 4);
            int32 stairsize = kind == StairType.build8 ? int32(8 * 65536) : int32(16 * 65536);
            int32 height;
            unchecked {
                height = c.map.sectors[sec].floorheight + stairsize;
            }
            _stair(c, sec, speed, height);
            uint32 texture = c.map.sectors[sec].floorpic;
            bool ok;
            do {
                ok = false;
                for (uint32 i; i < c.state.sectors[sec].lines.length; ++i) {
                    uint32 lineId = c.state.sectors[sec].lines[i];
                    if (c.map.lines[lineId].flags & 4 == 0) continue;
                    if (sec != c.map.lines[lineId].frontsector) continue;
                    uint32 next = c.map.lines[lineId].backsector;
                    if (c.map.sectors[next].floorpic != texture) continue;
                    unchecked {
                        height += stairsize;
                    }
                    if (c.state.sectors[next].specialdata != GameConst.NULL) continue;
                    sec = next;
                    secnum = int32(sec);
                    _stair(c, sec, speed, height);
                    ok = true;
                    break;
                }
            } while (ok);
        }
    }

    function _stair(GameContext memory c, uint32 sector, int32 speed, int32 height) private pure {
        uint32 id = P_Heap.allocateFloorMove(c.state);
        FloorMove memory floor = c.state.floors[id];
        floor.thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.floor, id);
        c.state.sectors[sector].specialdata = floor.thinker;
        floor.direction = 1;
        floor.sector = sector;
        floor.speed = speed;
        floor.floordestheight = height;
    }
}
