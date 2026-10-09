// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {GameContext, GameConst, ThinkerKind, Door, DoorType, PlaneResult, Player} from "./p_game_state.sol";
import {P_Heap} from "./p_heap.sol";
import {P_Tick} from "./p_tick.sol";
import {P_Spec} from "./p_spec.sol";
import {P_Floor} from "./p_floor.sol";

/// @custom:source linuxdoom-1.10/p_doors.c active vertical doors at a77dfb96cb91780ca334d0d4cfd86957558007e0
library P_Doors {
    error InvalidDoorThinker(uint32 thinker);

    function T_VerticalDoor(GameContext memory c, uint32 id) internal view {
        Door memory door = c.state.doors[id];
        PlaneResult res;
        if (door.direction == 0) {
            unchecked {
                --door.topcountdown;
            }
            if (door.topcountdown == 0) {
                if (door.doorType == DoorType.blazeRaise || door.doorType == DoorType.normal) {
                    door.direction = -1;
                } else if (door.doorType == DoorType.close30ThenOpen) {
                    door.direction = 1;
                }
            }
        } else if (door.direction == 2) {
            unchecked {
                --door.topcountdown;
            }
            if (door.topcountdown == 0 && door.doorType == DoorType.raiseIn5Mins) {
                door.direction = 1;
                door.doorType = DoorType.normal;
            }
        } else if (door.direction == -1) {
            res = P_Floor.T_MovePlane(
                c, door.sector, door.speed, c.map.sectors[door.sector].floorheight, false, 1, -1
            );
            if (res == PlaneResult.pastdest) {
                if (
                    door.doorType == DoorType.blazeRaise || door.doorType == DoorType.blazeClose
                        || door.doorType == DoorType.normal || door.doorType == DoorType.close
                ) {
                    c.state.sectors[door.sector].specialdata = GameConst.NULL;
                    P_Tick.P_RemoveThinker(c.state, door.thinker);
                } else if (door.doorType == DoorType.close30ThenOpen) {
                    door.direction = 0;
                    door.topcountdown = 35 * 30;
                }
            } else if (res == PlaneResult.crushed) {
                if (door.doorType != DoorType.blazeClose && door.doorType != DoorType.close) {
                    door.direction = 1;
                }
            }
        } else if (door.direction == 1) {
            res = P_Floor.T_MovePlane(c, door.sector, door.speed, door.topheight, false, 1, 1);
            if (res == PlaneResult.pastdest) {
                if (door.doorType == DoorType.blazeRaise || door.doorType == DoorType.normal) {
                    door.direction = 0;
                    door.topcountdown = door.topwait;
                } else if (
                    door.doorType == DoorType.close30ThenOpen || door.doorType == DoorType.blazeOpen
                        || door.doorType == DoorType.open
                ) {
                    c.state.sectors[door.sector].specialdata = GameConst.NULL;
                    P_Tick.P_RemoveThinker(c.state, door.thinker);
                }
            }
        }
    }

    function EV_DoLockedDoor(GameContext memory c, uint32 line, DoorType kind, uint32 thing)
        internal
        pure
        returns (int32)
    {
        uint32 player = c.state.mobjs[thing].player;
        if (player == GameConst.NULL) return 0;
        Player memory p = c.state.players[player];
        int16 special = c.map.lines[line].special;
        if ((special == 99 || special == 133) && !p.cards[0] && !p.cards[3]) {
            p.message = "You need a blue key to activate this object";
            return 0;
        }
        if ((special == 134 || special == 135) && !p.cards[2] && !p.cards[5]) {
            p.message = "You need a red key to activate this object";
            return 0;
        }
        if ((special == 136 || special == 137) && !p.cards[1] && !p.cards[4]) {
            p.message = "You need a yellow key to activate this object";
            return 0;
        }
        return EV_DoDoor(c, line, kind);
    }

    function EV_DoDoor(GameContext memory c, uint32 line, DoorType kind) internal pure returns (int32) {
        return EV_DoDoorTag(c, c.map.lines[line].tag, kind);
    }

    function EV_DoDoorTag(GameContext memory c, int32 tag, DoorType kind) internal pure returns (int32 rtn) {
        int32 secnum = -1;
        while ((secnum = P_Spec.P_FindSectorFromTag(c, tag, secnum)) >= 0) {
            uint32 sector = uint32(secnum);
            if (c.state.sectors[sector].specialdata != GameConst.NULL) continue;
            rtn = 1;
            uint32 id = _new(c, sector);
            Door memory door = c.state.doors[id];
            door.doorType = kind;
            door.topwait = 150;
            door.speed = 2 * 65536;
            unchecked {
                if (kind == DoorType.blazeClose || kind == DoorType.close) {
                    door.topheight = P_Spec.P_FindLowestCeilingSurrounding(c, sector) - 4 * 65536;
                    door.direction = -1;
                    if (kind == DoorType.blazeClose) door.speed *= 4;
                } else if (kind == DoorType.close30ThenOpen) {
                    door.topheight = c.map.sectors[sector].ceilingheight;
                    door.direction = -1;
                } else if (
                    kind == DoorType.blazeRaise || kind == DoorType.blazeOpen || kind == DoorType.normal
                        || kind == DoorType.open
                ) {
                    door.direction = 1;
                    door.topheight = P_Spec.P_FindLowestCeilingSurrounding(c, sector) - 4 * 65536;
                    if (kind == DoorType.blazeRaise || kind == DoorType.blazeOpen) door.speed *= 4;
                }
            }
        }
    }

    function EV_VerticalDoor(GameContext memory c, uint32 line, uint32 thing) internal pure {
        uint32 player = c.state.mobjs[thing].player;
        int16 special = c.map.lines[line].special;
        if (
            special == 26 || special == 32 || special == 27 || special == 34 || special == 28 || special == 33
        ) {
            if (player == GameConst.NULL) return;
            Player memory p = c.state.players[player];
            uint32 card = special == 26 || special == 32 ? 0 : special == 27 || special == 34 ? 1 : 2;
            if (!p.cards[card] && !p.cards[card + 3]) {
                p.message = card == 0
                    ? "You need a blue key to open this door"
                    : card == 1
                        ? "You need a yellow key to open this door"
                        : "You need a red key to open this door";
                return;
            }
        }
        uint32 sector = c.map.sides[c.map.lines[line].sidenum[1]].sector;
        uint32 existing = c.state.sectors[sector].specialdata;
        if (
            existing != GameConst.NULL
                && (special == 1 || special == 26 || special == 27 || special == 28 || special == 117)
        ) {
            ThinkerKind thinkerKind = c.state.thinkers[existing].kind;
            uint32 payload = c.state.thinkers[existing].payload;
            // Pinned LP64 original miscast: vldoor.direction, plat.count, and
            // ceiling.speed have byte offset 48. Preserve the measured integer overlaps.
            if (
                thinkerKind != ThinkerKind.door && thinkerKind != ThinkerKind.plat
                    && thinkerKind != ThinkerKind.ceiling
            ) {
                revert InvalidDoorThinker(existing);
            }
            int32 direction = thinkerKind == ThinkerKind.door
                ? c.state.doors[payload].direction
                : thinkerKind == ThinkerKind.plat
                    ? c.state.plats[payload].count
                    : c.state.ceilings[payload].speed;
            if (direction == -1) {
                if (thinkerKind == ThinkerKind.door) c.state.doors[payload].direction = 1;
                else if (thinkerKind == ThinkerKind.plat) c.state.plats[payload].count = 1;
                else c.state.ceilings[payload].speed = 1;
            } else {
                if (player == GameConst.NULL) return;
                if (thinkerKind == ThinkerKind.door) c.state.doors[payload].direction = -1;
                else if (thinkerKind == ThinkerKind.plat) c.state.plats[payload].count = -1;
                else c.state.ceilings[payload].speed = -1;
            }
            return;
        }
        uint32 id = _new(c, sector);
        Door memory door = c.state.doors[id];
        door.direction = 1;
        door.speed = 2 * 65536;
        door.topwait = 150;
        if (special == 1 || special == 26 || special == 27 || special == 28) {
            door.doorType = DoorType.normal;
        } else if (special == 31 || special == 32 || special == 33 || special == 34) {
            door.doorType = DoorType.open;
            c.map.lines[line].special = 0;
        } else if (special == 117) {
            door.doorType = DoorType.blazeRaise;
            door.speed *= 4;
        } else if (special == 118) {
            door.doorType = DoorType.blazeOpen;
            c.map.lines[line].special = 0;
            door.speed *= 4;
        }
        unchecked {
            door.topheight = P_Spec.P_FindLowestCeilingSurrounding(c, sector) - 4 * 65536;
        }
    }

    function P_SpawnDoorCloseIn30(GameContext memory c, uint32 sector) internal pure {
        uint32 id = _new(c, sector);
        Door memory door = c.state.doors[id];
        c.state.sectors[sector].special = 0;
        door.direction = 0;
        door.doorType = DoorType.normal;
        door.speed = 2 * 65536;
        door.topcountdown = 30 * 35;
        // Original does not initialize topheight/topwait. Zero heap profile retained;
        // obstruction reversal after this spawn is an original uninitialized-field domain.
    }

    function P_SpawnDoorRaiseIn5Mins(GameContext memory c, uint32 sector, int32) internal pure {
        uint32 id = _new(c, sector);
        Door memory door = c.state.doors[id];
        c.state.sectors[sector].special = 0;
        door.direction = 2;
        door.doorType = DoorType.raiseIn5Mins;
        door.speed = 2 * 65536;
        unchecked {
            door.topheight = P_Spec.P_FindLowestCeilingSurrounding(c, sector) - 4 * 65536;
        }
        door.topwait = 150;
        door.topcountdown = 5 * 60 * 35;
    }

    function _new(GameContext memory c, uint32 sector) private pure returns (uint32 id) {
        id = P_Heap.allocateDoor(c.state);
        Door memory door = c.state.doors[id];
        door.thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.door, id);
        c.state.sectors[sector].specialdata = door.thinker;
        door.sector = sector;
    }
}
