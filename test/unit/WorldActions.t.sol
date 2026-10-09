// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {
    GameContext,
    GameConst,
    Thinker,
    ThinkerKind,
    Door,
    DoorType,
    FloorMove,
    FloorType,
    CeilingMove,
    CeilingType,
    Plat,
    PlatType,
    FireFlicker,
    LightFlash,
    Strobe,
    Glow,
    GameSector,
    Mobj,
    PlaneResult
} from "../../src/doom/p_game_state.sol";
import {Sector, Line, Side} from "../../src/doom/r_defs.sol";
import {Texture} from "../../src/doom/r_data_types.sol";
import {P_Doors} from "../../src/doom/p_doors.sol";
import {P_Floor, StairType} from "../../src/doom/p_floor.sol";
import {P_Ceilng} from "../../src/doom/p_ceilng.sol";
import {P_Plats} from "../../src/doom/p_plats.sol";
import {P_Lights} from "../../src/doom/p_lights.sol";
import {P_Heap} from "../../src/doom/p_heap.sol";
import {P_Tick} from "../../src/doom/p_tick.sol";

struct WorldWords {
    bytes data;
    uint256 cursor;
    bool maskUninitializedCloseDoor;
    bool maskUninitializedStairFloors;
}

interface VmWorld {
    function readFileBinary(string calldata path) external view returns (bytes memory);
}

// Shared native fixture adapter only. No world algorithms are duplicated here.
abstract contract WorldFixtureBase {
    function _mix(uint32 h, uint32 v) internal pure returns (uint32) {
        unchecked {
            return (h ^ v) * 16777619;
        }
    }

    function _worldChange(GameContext memory c, uint32 sector, bool crush) internal pure returns (bool) {
        ++c.move.la_damage;
        c.move.aimslope = int32(
            _mix(
                _mix(
                    _mix(_mix(uint32(c.move.aimslope), sector), uint32(c.map.sectors[sector].floorheight)),
                    uint32(c.map.sectors[sector].ceilingheight)
                ),
                crush ? 1 : 0
            )
        );
        if (c.move.bombdamage == 0) return false;
        if (c.move.bombdamage == 1) return true;
        if (c.move.bombdamage == 2) return c.move.la_damage & 1 != 0;
        return c.state.leveltime >= 10 && c.state.leveltime < 30;
    }

    function _worldDispatch(GameContext memory c, uint32 thinker) internal view {
        Thinker memory t = c.state.thinkers[thinker];
        if (t.kind == ThinkerKind.door) P_Doors.T_VerticalDoor(c, t.payload);
        else if (t.kind == ThinkerKind.floor) P_Floor.T_MoveFloor(c, t.payload);
        else if (t.kind == ThinkerKind.ceiling) P_Ceilng.T_MoveCeiling(c, t.payload);
        else if (t.kind == ThinkerKind.plat) P_Plats.T_PlatRaise(c, t.payload);
        else if (t.kind == ThinkerKind.fireFlicker) P_Lights.T_FireFlicker(c, t.payload);
        else if (t.kind == ThinkerKind.lightFlash) P_Lights.T_LightFlash(c, t.payload);
        else if (t.kind == ThinkerKind.strobe) P_Lights.T_StrobeFlash(c, t.payload);
        else if (t.kind == ThinkerKind.glow) P_Lights.T_Glow(c, t.payload);
        else revert("unknown world thinker");
    }

    function _worldContext() internal pure returns (GameContext memory c) {
        c.hooks.changeSector = _worldChange;
        c.hooks.thinkerDispatch = _worldDispatch;
    }

    function _worldSetup(GameContext memory c, uint32[8] memory a) internal pure {
        c.map.sectors = new Sector[](4);
        c.map.lines = new Line[](3);
        c.map.sides = new Side[](6);
        c.state.sectors = new GameSector[](4);
        c.resources.textures = new Texture[](3);
        c.resources.textures[0].height = 32;
        c.resources.textures[1].height = 64;
        c.resources.textures[2].height = 24;
        int32[4] memory floors = [int32(0), 16, -16, 32];
        int32[4] memory ceilings = [int32(64), 128, 96, 160];
        int16[4] memory lights = [int16(160), 128, 64, 192];
        uint32[4] memory pics = [uint32(3), 3, 5, 7];
        for (uint32 i; i < 4; ++i) {
            c.map.sectors[i].floorheight = floors[i] * 65536;
            c.map.sectors[i].ceilingheight = ceilings[i] * 65536;
            c.map.sectors[i].lightlevel = a[7] != 0 ? int16(160) : lights[i];
            c.map.sectors[i].floorpic = pics[i];
            c.state.sectors[i].special = i == 0 ? int16(5) : int16(9);
            c.state.sectors[i].tag = i < 2 ? int16(7) : int16(0);
            c.state.sectors[i].specialdata = GameConst.NULL;
        }
        uint32[3] memory front = [uint32(2), 0, 1];
        uint32[3] memory back = [uint32(0), 1, 3];
        for (uint32 i; i < 3; ++i) {
            c.map.lines[i].flags = 4;
            c.map.lines[i].frontsector = front[i];
            c.map.lines[i].backsector = back[i];
            c.map.lines[i].sidenum[0] = i * 2;
            c.map.lines[i].sidenum[1] = i * 2 + 1;
            c.map.sides[i * 2].sector = front[i];
            c.map.sides[i * 2 + 1].sector = back[i];
            c.map.sides[i * 2].bottomtexture = 0;
            c.map.sides[i * 2 + 1].bottomtexture = i % 3;
        }
        c.state.sectors[0].lines = new uint32[](2);
        c.state.sectors[0].lines[0] = 0;
        c.state.sectors[0].lines[1] = 1;
        c.state.sectors[1].lines = new uint32[](2);
        c.state.sectors[1].lines[0] = 1;
        c.state.sectors[1].lines[1] = 2;
        c.state.sectors[2].lines = new uint32[](1);
        c.state.sectors[2].lines[0] = 0;
        c.state.sectors[3].lines = new uint32[](1);
        c.state.sectors[3].lines[0] = 2;
        c.map.lines[0].tag = 7;
        c.map.lines[0].special = int16(int32(a[1]));
        c.state.map = c.map;
        c.state.mobjs = new Mobj[](1);
        c.state.mobjs[0].player = a[3] != 0 ? GameConst.NULL : uint32(0);
        c.state.players[0].mo = 0;
        for (uint32 i; i < 6; ++i) {
            c.state.players[0].cards[i] = a[4] & (uint32(1) << i) != 0;
        }
        for (uint32 i; i < 30; ++i) {
            c.state.activeceilings[i] = GameConst.NULL;
            c.state.activeplats[i] = GameConst.NULL;
        }
        c.move.bombdamage = int32(a[2]);
        c.move.aimslope = int32(uint32(2166136261));
        c.state.prndindex = a[5];
        P_Tick.P_InitThinkers(c.state);
        if (a[0] == 8 && a[7] == 2) {
            c.map.lines[0].frontsector = 0;
            c.map.lines[0].backsector = 2;
            c.map.sides[0].sector = 0;
            c.map.sides[1].sector = 2;
            c.map.sectors[2].floorpic = 3;
            c.state.sectors[0].lines[0] = 1;
            c.state.sectors[0].lines[1] = 0;
            uint32 id = P_Heap.allocateFloorMove(c.state);
            FloorMove memory floor = c.state.floors[id];
            floor.sector = 1;
            floor.thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.floor, id);
            c.state.thinkers[floor.thinker].status = GameConst.THINKER_STASIS;
            c.state.sectors[1].specialdata = floor.thinker;
        }
    }

    function _put(WorldWords memory b, uint32 value) internal pure {
        require(b.cursor + 32 <= 8192, "world buffer bounds");
        uint256 cursor = b.cursor;
        bytes memory data = b.data;
        // The buffer is allocated with 8192 bytes. Each full 32-byte write is in-bounds;
        // trailing zero bytes overwrite only unwritten capacity. Only cursor bytes are hashed.
        assembly ("memory-safe") { mstore(add(add(data, 32), cursor), shl(224, value)) }
        b.cursor = cursor + 4;
    }

    function _messageHash(string memory text) internal pure returns (uint32 h) {
        bytes memory data = bytes(text);
        if (data.length == 0) return 0;
        h = 2166136261;
        for (uint256 i; i < data.length; ++i) {
            h = _mix(h, uint8(data[i]));
        }
    }

    function _worldPayload(GameContext memory c, Thinker memory t, WorldWords memory b) internal pure {
        if (t.kind == ThinkerKind.door) {
            Door memory p = c.state.doors[t.payload];
            _put(b, p.sector);
            _put(b, uint32(p.doorType));
            _put(b, b.maskUninitializedCloseDoor ? uint32(0) : uint32(p.topheight));
            _put(b, uint32(p.speed));
            _put(b, uint32(p.direction));
            _put(b, b.maskUninitializedCloseDoor ? uint32(0) : uint32(p.topwait));
            _put(b, uint32(p.topcountdown));
        } else if (t.kind == ThinkerKind.floor) {
            FloorMove memory p = c.state.floors[t.payload];
            _put(b, p.sector);
            _put(b, b.maskUninitializedStairFloors ? uint32(0) : uint32(p.floorType));
            _put(b, b.maskUninitializedStairFloors ? uint32(0) : (p.crush ? 1 : 0));
            _put(b, uint32(p.direction));
            _put(b, uint32(p.newspecial));
            _put(b, uint32(int32(p.texture)));
            _put(b, uint32(p.floordestheight));
            _put(b, uint32(p.speed));
        } else if (t.kind == ThinkerKind.ceiling) {
            CeilingMove memory p = c.state.ceilings[t.payload];
            _put(b, p.sector);
            _put(b, uint32(p.ceilingType));
            _put(b, uint32(p.bottomheight));
            _put(b, uint32(p.topheight));
            _put(b, uint32(p.speed));
            _put(b, p.crush ? 1 : 0);
            _put(b, uint32(p.direction));
            _put(b, uint32(p.tag));
            _put(b, uint32(p.olddirection));
        } else if (t.kind == ThinkerKind.plat) {
            Plat memory p = c.state.plats[t.payload];
            _put(b, p.sector);
            _put(b, uint32(p.speed));
            _put(b, uint32(p.low));
            _put(b, uint32(p.high));
            _put(b, uint32(p.wait));
            _put(b, uint32(p.count));
            _put(b, uint32(p.status));
            _put(b, uint32(p.oldstatus));
            _put(b, p.crush ? 1 : 0);
            _put(b, uint32(p.tag));
            _put(b, uint32(p.platType));
        } else if (t.kind == ThinkerKind.fireFlicker) {
            FireFlicker memory p = c.state.fireFlickers[t.payload];
            _put(b, p.sector);
            _put(b, uint32(p.count));
            _put(b, uint32(p.maxlight));
            _put(b, uint32(p.minlight));
        } else if (t.kind == ThinkerKind.lightFlash) {
            LightFlash memory p = c.state.lightFlashes[t.payload];
            _put(b, p.sector);
            _put(b, uint32(p.count));
            _put(b, uint32(p.maxlight));
            _put(b, uint32(p.minlight));
            _put(b, uint32(p.maxtime));
            _put(b, uint32(p.mintime));
        } else if (t.kind == ThinkerKind.strobe) {
            Strobe memory p = c.state.strobes[t.payload];
            _put(b, p.sector);
            _put(b, uint32(p.count));
            _put(b, uint32(p.minlight));
            _put(b, uint32(p.maxlight));
            _put(b, uint32(p.darktime));
            _put(b, uint32(p.brighttime));
        } else if (t.kind == ThinkerKind.glow) {
            Glow memory p = c.state.glows[t.payload];
            _put(b, p.sector);
            _put(b, uint32(p.minlight));
            _put(b, uint32(p.maxlight));
            _put(b, uint32(p.direction));
        } else {
            revert("unknown world payload");
        }
    }

    function _worldHash(GameContext memory c, int32 rtn, WorldWords memory b)
        internal
        pure
        returns (bytes32)
    {
        require(b.data.length <= 8192, "invalid world buffer");
        bytes memory data = b.data;
        // Restore the original allocated capacity before reusing this buffer.
        assembly ("memory-safe") { mstore(data, 8192) }
        b.cursor = 0;
        _put(b, uint32(rtn));
        _put(b, c.state.prndindex);
        _put(b, uint32(c.move.la_damage));
        _put(b, uint32(c.move.aimslope));
        _put(b, uint32(c.state.leveltime));
        _put(b, c.state.thinkerCount);
        for (uint32 i; i < 4; ++i) {
            _put(b, uint32(c.map.sectors[i].floorheight));
            _put(b, uint32(c.map.sectors[i].ceilingheight));
            _put(b, uint32(int32(c.map.sectors[i].lightlevel)));
            _put(b, c.map.sectors[i].floorpic);
            _put(b, uint32(int32(c.state.sectors[i].special)));
            _put(b, uint32(int32(c.state.sectors[i].tag)));
            _put(b, c.state.sectors[i].specialdata);
        }
        for (uint32 i; i < 3; ++i) {
            _put(b, uint32(int32(c.map.lines[i].special)));
        }
        uint32 live;
        for (uint32 id = c.state.thinkers[0].next; id != 0; id = c.state.thinkers[id].next) {
            ++live;
        }
        _put(b, live);
        for (uint32 id = c.state.thinkers[0].next; id != 0; id = c.state.thinkers[id].next) {
            Thinker memory t = c.state.thinkers[id];
            _put(b, id);
            _put(b, uint32(t.kind));
            _put(b, t.status);
            _put(b, t.prev);
            _put(b, t.next);
            _worldPayload(c, t, b);
        }
        for (uint32 i; i < 30; ++i) {
            _put(
                b,
                c.state.activeceilings[i] == GameConst.NULL
                    ? GameConst.NULL
                    : c.state.ceilings[c.state.activeceilings[i]].thinker
            );
        }
        for (uint32 i; i < 30; ++i) {
            _put(
                b,
                c.state.activeplats[i] == GameConst.NULL
                    ? GameConst.NULL
                    : c.state.plats[c.state.activeplats[i]].thinker
            );
        }
        _put(b, _messageHash(c.state.players[0].message));
        uint256 size = b.cursor;
        assembly ("memory-safe") { mstore(data, size) }
        return sha256(data);
    }
}

contract WorldActionsTest is WorldFixtureBase {
    struct Case {
        GameContext context;
        WorldWords buffer;
        uint32[8] input;
        bytes expected;
        uint32 snapshot;
        int32 rtn;
    }
    VmWorld constant vm = VmWorld(address(uint160(uint256(keccak256("hevm cheat code")))));
    event log_named_uint(string key, uint256 value);
    event log_named_bytes(string key, bytes value);

    function _word(bytes memory data, uint256 p) private pure returns (uint32 v) {
        require(p + 4 <= data.length);
        for (uint32 i; i < 4; ++i) {
            v = (v << 8) | uint8(data[p + i]);
        }
    }

    function _digest(bytes memory data, uint256 p) private pure returns (bytes32 v) {
        require(p + 32 <= data.length);
        assembly ("memory-safe") { v := mload(add(add(data, 32), p)) }
    }

    function _begin(GameContext memory c, uint32[8] memory a) private pure returns (int32 rtn) {
        if (a[0] == 1) {
            rtn = P_Doors.EV_DoDoor(c, 0, DoorType(a[1]));
        } else if (a[0] == 2) {
            P_Doors.EV_VerticalDoor(c, 0, 0);
        } else if (a[0] == 3) {
            if (a[1] != 0) P_Doors.P_SpawnDoorRaiseIn5Mins(c, 0, 0);
            else P_Doors.P_SpawnDoorCloseIn30(c, 0);
        } else if (a[0] == 4) {
            rtn = P_Floor.EV_DoFloor(c, 0, FloorType(a[1]));
        } else if (a[0] == 5) {
            rtn = P_Ceilng.EV_DoCeiling(c, 0, CeilingType(a[1]));
        } else if (a[0] == 6) {
            rtn = P_Plats.EV_DoPlat(c, 0, PlatType(a[1]), int32(a[4]));
        } else if (a[0] == 7) {
            if (a[1] == 0) P_Lights.P_SpawnFireFlicker(c, 0);
            else if (a[1] == 1) P_Lights.P_SpawnLightFlash(c, 0);
            else if (a[1] == 2) P_Lights.P_SpawnStrobeFlash(c, 0, int32(a[4]), int32(a[3]));
            else if (a[1] == 3) P_Lights.P_SpawnGlowingLight(c, 0);
            else if (a[1] == 4) P_Lights.EV_StartLightStrobing(c, 0);
            else if (a[1] == 5) P_Lights.EV_TurnTagLightsOff(c, 0);
            else if (a[1] == 6) P_Lights.EV_LightTurnOn(c, 0, 0);
            else if (a[1] == 7) P_Lights.EV_LightTurnOn(c, 0, 255);
        } else if (a[0] == 8) {
            rtn = P_Floor.EV_BuildStairs(c, 0, StairType(a[1]));
        } else if (a[0] == 9) {
            uint32 id = P_Heap.allocateFloorMove(c.state);
            FloorMove memory f = c.state.floors[id];
            f.thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.floor, id);
            f.sector = 0;
            c.state.sectors[0].specialdata = f.thinker;
            f.floorType = FloorType(a[1]);
            f.direction = a[3] != 0 ? int32(-1) : int32(1);
            f.speed = 65536;
            f.floordestheight = a[3] != 0 ? int32(-8 * 65536) : int32(8 * 65536);
            f.texture = 7;
            f.newspecial = 11;
            f.crush = a[4] != 0;
        } else if (a[0] == 10) {
            for (uint32 i; i < 31; ++i) {
                uint32 id = P_Heap.allocateCeilingMove(c.state);
                CeilingMove memory p = c.state.ceilings[id];
                p.thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.ceiling, id);
                p.sector = 0;
                p.tag = 7;
                P_Ceilng.P_AddActiveCeiling(c, id);
            }
            P_Ceilng.P_RemoveActiveCeiling(c, 30);
        } else if (a[0] == 11) {
            rtn = P_Doors.EV_DoLockedDoor(c, 0, DoorType(a[7]), 0);
        } else {
            revert("unknown world fixture operation");
        }
    }

    function _advance(Case memory w) private view {
        GameContext memory c = w.context;
        uint32[8] memory a = w.input;
        uint32 tick = w.snapshot - 1;
        c.state.leveltime = int32(tick);
        if (a[0] == 2 && c.map.lines[0].special != 0 && (tick == 20 || tick == 40)) {
            P_Doors.EV_VerticalDoor(c, 0, 0);
        }
        if (a[0] == 5 && tick == 10) w.rtn = P_Ceilng.EV_CeilingCrushStop(c, 0);
        if (a[0] == 5 && tick == 30) P_Ceilng.P_ActivateInStasisCeiling(c, 0);
        if (a[0] == 6 && tick == 10) P_Plats.EV_StopPlat(c, 0);
        if (a[0] == 6 && tick == 30) P_Plats.P_ActivateInStasis(c, 7);
        if (a[0] == 5 && tick == 50) w.rtn = P_Ceilng.EV_DoCeiling(c, 0, CeilingType(a[1]));
        if (a[0] == 6 && tick == 50) w.rtn = P_Plats.EV_DoPlat(c, 0, PlatType(a[1]), int32(a[4]));
        P_Tick.P_RunThinkers(c);
    }

    function runCase(uint32[8] memory input, bytes memory expected) external {
        require(expected.length == (uint256(input[6]) + 1) * 32, "snapshot extent");
        Case memory w;
        w.input = input;
        w.expected = expected;
        w.context = _worldContext();
        w.buffer.data = new bytes(8192);
        w.buffer.maskUninitializedCloseDoor = input[0] == 3 && input[1] == 0;
        w.buffer.maskUninitializedStairFloors = input[0] == 8;
        _worldSetup(w.context, input);
        w.rtn = _begin(w.context, input);
        for (; w.snapshot <= w.input[6]; ++w.snapshot) {
            if (w.snapshot != 0) _advance(w);
            if (_worldHash(w.context, w.rtn, w.buffer) != _digest(w.expected, uint256(w.snapshot) * 32)) {
                emit log_named_uint("op", w.input[0]);
                emit log_named_uint("kind", w.input[1]);
                emit log_named_uint("obstruction", w.input[2]);
                emit log_named_uint("snapshot", w.snapshot);
                emit log_named_bytes("actual", w.buffer.data);
                revert("original world snapshot mismatch");
            }
        }
    }

    function _batch(uint32 operation, uint32 kind) private {
        bytes memory data = vm.readFileBinary("test/fixtures/phase3_world/vectors.bin");
        uint32 count = _word(data, 0);
        require(count == 359);
        uint256 pos = 4;
        uint32 selected;
        for (uint32 i; i < count; ++i) {
            uint32[8] memory input;
            for (uint32 j; j < 8; ++j) {
                input[j] = _word(data, pos + uint256(j) * 4);
            }
            uint32 snapshots = _word(data, pos + 32);
            require(snapshots == input[6] + 1);
            pos += 36;
            uint256 length = uint256(snapshots) * 32;
            require(pos + length <= data.length);
            if (input[0] == operation && (kind == GameConst.NULL || input[1] == kind)) {
                bytes memory expected = new bytes(length);
                uint256 offset = pos;
                // Exact initialized in-bounds source/destination spans; no padding or overread.
                assembly ("memory-safe") { mcopy(add(expected, 32), add(add(data, 32), offset), length) }
                this.runCase(input, expected);
                ++selected;
            }
            pos += length;
        }
        require(pos == data.length && selected != 0, "world fixture grouping");
    }

    function testOriginalCNormalDoors() public {
        _batch(1, 0);
    }

    function testOriginalCCloseThenOpenDoors() public {
        _batch(1, 1);
    }

    function testOriginalCCloseDoors() public {
        _batch(1, 2);
    }

    function testOriginalCOpenDoors() public {
        _batch(1, 3);
    }

    function testOriginalCBlazingDoors() public {
        _batch(1, 5);
        _batch(1, 6);
        _batch(1, 7);
    }

    function testOriginalCManualDoorsLocksPlayersAndMonsters() public {
        _batch(2, GameConst.NULL);
    }

    function testOriginalCDoorCloseTimer() public {
        _batch(3, 0);
    }

    function testOriginalCDoorFiveMinuteTimer() public {
        _batch(3, 1);
    }

    function testOriginalCFloorTypes() public {
        _batch(4, GameConst.NULL);
    }

    function testOriginalCCeilingsCrushStopResumeAndRetrigger() public {
        _batch(5, GameConst.NULL);
    }

    function testOriginalCPlatformsStopResumeAndRetrigger() public {
        _batch(6, GameConst.NULL);
    }

    function testOriginalCFireAndFlashLights() public {
        _batch(7, 0);
        _batch(7, 1);
    }

    function testOriginalCStrobeAndGlowLights() public {
        _batch(7, 2);
        _batch(7, 3);
    }

    function testOriginalCTagStrobeAction() public {
        _batch(7, 4);
    }

    function testOriginalCTagLightOffAction() public {
        _batch(7, 5);
    }

    function testOriginalCTagLightSearchOnAction() public {
        _batch(7, 6);
    }

    function testOriginalCTagLightFullOnAction() public {
        _batch(7, 7);
    }

    function testOriginalCStairs() public {
        _batch(8, GameConst.NULL);
    }

    function testOriginalCFloorCompletionTextureAndSpecial() public {
        _batch(9, GameConst.NULL);
    }

    function testOriginalCCeilingRegistryOverflowRemainsUntracked() public {
        _batch(10, GameConst.NULL);
    }

    function testOriginalCTaggedLockedDoorKeys() public {
        _batch(11, GameConst.NULL);
    }

    function _planeChange(GameContext memory c, uint32, bool crush) internal pure returns (bool) {
        ++c.move.la_damage;
        c.move.aimslope = int32(
            _mix(
                _mix(
                    _mix(uint32(c.move.aimslope), uint32(c.map.sectors[0].floorheight)),
                    uint32(c.map.sectors[0].ceilingheight)
                ),
                crush ? 1 : 0
            )
        );
        return c.move.bombdamage == 0 ? false : c.move.bombdamage == 1 ? true : c.move.la_damage & 1 != 0;
    }

    function _planes(uint32 plane) private view {
        bytes memory data = vm.readFileBinary("test/fixtures/phase3_world/planes.bin");
        require(_word(data, 0) == 2160 && data.length == 4 + 2160 * 52, "plane fixture extent");
        GameContext memory c;
        c.map.sectors = new Sector[](1);
        c.hooks.changeSector = _planeChange;
        uint32 count;
        for (uint32 row; row < 2160; ++row) {
            uint256 p = 4 + uint256(row) * 52;
            if (_word(data, p + 20) != plane) continue;
            c.map.sectors[0].floorheight = int32(_word(data, p));
            c.map.sectors[0].ceilingheight = int32(_word(data, p + 4));
            c.move.la_damage = 0;
            c.move.aimslope = int32(uint32(2166136261));
            c.move.bombdamage = int32(_word(data, p + 28));
            PlaneResult res = P_Floor.T_MovePlane(
                c,
                0,
                int32(_word(data, p + 8)),
                int32(_word(data, p + 12)),
                _word(data, p + 16) != 0,
                int32(plane),
                int32(_word(data, p + 24))
            );
            require(uint32(res) == _word(data, p + 32), "C plane result");
            require(uint32(c.map.sectors[0].floorheight) == _word(data, p + 36), "C floor endpoint");
            require(uint32(c.map.sectors[0].ceilingheight) == _word(data, p + 40), "C ceiling endpoint");
            require(
                uint32(c.move.la_damage) == _word(data, p + 44)
                    && uint32(c.move.aimslope) == _word(data, p + 48),
                "C callback sequence"
            );
            ++count;
        }
        require(count == 1080, "plane domain count");
    }

    function testOriginalCFloorPlaneEqualityCrushAndRollback() public view {
        _planes(0);
    }

    function testOriginalCCeilingPlaneEqualityCrushAndRollback() public view {
        _planes(1);
    }

    function overflowPlat() external pure {
        GameContext memory c = _worldContext();
        uint32[8] memory a;
        _worldSetup(c, a);
        for (uint32 i; i < 31; ++i) {
            uint32 id = P_Heap.allocatePlat(c.state);
            P_Plats.P_AddActivePlat(c, id);
        }
    }

    function missingPlat() external pure {
        GameContext memory c = _worldContext();
        uint32[8] memory a;
        _worldSetup(c, a);
        uint32 id = P_Heap.allocatePlat(c.state);
        P_Plats.P_RemoveActivePlat(c, id);
    }

    function incompatibleDoor() external pure {
        GameContext memory c = _worldContext();
        uint32[8] memory a;
        a[1] = 1;
        _worldSetup(c, a);
        uint32 payload = P_Heap.allocateFloorMove(c.state);
        uint32 thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.floor, payload);
        c.state.sectors[0].specialdata = thinker;
        P_Doors.EV_VerticalDoor(c, 0, 0);
    }

    function testOriginalLP64DoorPlatMiscastPlayersAndMonsters() public view {
        bytes memory data = vm.readFileBinary("test/fixtures/phase3_world/door-plat.bin");
        require(_word(data, 0) == 4 && data.length == 52, "door plat fixture extent");
        for (uint32 i; i < 4; ++i) {
            uint256 pos = 4 + uint256(i) * 12;
            GameContext memory c = _worldContext();
            uint32[8] memory a;
            a[1] = 1;
            a[3] = _word(data, pos) != 0 ? uint32(0) : uint32(1);
            _worldSetup(c, a);
            uint32 payload = P_Heap.allocatePlat(c.state);
            c.state.plats[payload].count = int32(_word(data, pos + 4));
            uint32 thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.plat, payload);
            c.state.sectors[0].specialdata = thinker;
            P_Doors.EV_VerticalDoor(c, 0, 0);
            require(
                uint32(c.state.plats[payload].count) == _word(data, pos + 8),
                "original door plat count mutation"
            );
            require(
                c.state.sectors[0].specialdata == thinker && c.state.doorCount == 0,
                "miscast created a new door"
            );
        }
    }

    function syntheticChangeFloor() external pure {
        GameContext memory c = _worldContext();
        uint32[8] memory a;
        _worldSetup(c, a);
        P_Floor.EV_DoFloorTag(c, 7, FloorType.raiseFloor24AndChange);
    }

    function testOriginalLP64DoorCeilingSpeedMiscastPlayersAndMonsters() public view {
        bytes memory data = vm.readFileBinary("test/fixtures/phase3_world/door-ceiling.bin");
        require(_word(data, 0) == 4 && data.length == 52, "door ceiling fixture extent");
        for (uint32 i; i < 4; ++i) {
            uint256 pos = 4 + uint256(i) * 12;
            GameContext memory c = _worldContext();
            uint32[8] memory a;
            a[1] = 1;
            a[3] = _word(data, pos) != 0 ? uint32(0) : uint32(1);
            _worldSetup(c, a);
            uint32 payload = P_Heap.allocateCeilingMove(c.state);
            c.state.ceilings[payload].speed = int32(_word(data, pos + 4));
            uint32 thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.ceiling, payload);
            c.state.sectors[0].specialdata = thinker;
            P_Doors.EV_VerticalDoor(c, 0, 0);
            require(
                uint32(c.state.ceilings[payload].speed) == _word(data, pos + 8),
                "original door ceiling speed mutation"
            );
            require(
                c.state.sectors[0].specialdata == thinker && c.state.doorCount == 0,
                "miscast created a new door"
            );
        }
    }

    function genericDonut() external pure {
        GameContext memory c = _worldContext();
        uint32[8] memory a;
        _worldSetup(c, a);
        P_Floor.EV_DoFloor(c, 0, FloorType.donutRaise);
    }

    function testUndefinedGenericDonutRejectsOnlyEligibleAllocation() public view {
        try this.genericDonut() {
            revert("undefined generic donut accepted");
        } catch (bytes memory r) {
            require(
                keccak256(r)
                    == keccak256(
                        abi.encodeWithSelector(P_Floor.UninitializedFloorType.selector, FloorType.donutRaise)
                    )
            );
        }
    }

    function testUndefinedFloorTypesPreserveDefinedEmptyAndBusyTagReturns() public pure {
        GameContext memory c = _worldContext();
        uint32[8] memory a;
        _worldSetup(c, a);
        require(P_Floor.EV_DoFloorTag(c, 999, FloorType.donutRaise) == 0, "empty generic donut tag");
        require(
            P_Floor.EV_DoFloorTag(c, 999, FloorType.raiseFloor24AndChange) == 0, "empty synthetic change tag"
        );
        c.state.sectors[0].specialdata = 1;
        c.state.sectors[1].specialdata = 1;
        require(P_Floor.EV_DoFloor(c, 0, FloorType.donutRaise) == 0, "busy generic donut tag");
        require(P_Floor.EV_DoFloorTag(c, 7, FloorType.donutRaise) == 0, "busy generic donut tag variant");
        require(
            P_Floor.EV_DoFloorTag(c, 7, FloorType.raiseFloor24AndChange) == 0, "busy synthetic change tag"
        );
    }

    function testOriginalPlatErrorsAndExplicitUnsupportedDomains() public view {
        try this.overflowPlat() {
            revert("overflow accepted");
        } catch (bytes memory r) {
            require(keccak256(r) == keccak256(abi.encodeWithSelector(P_Plats.NoMorePlats.selector)));
        }
        try this.missingPlat() {
            revert("missing accepted");
        } catch (bytes memory r) {
            require(
                keccak256(r)
                    == keccak256(abi.encodeWithSelector(P_Plats.ActivePlatNotFound.selector, uint32(0)))
            );
        }
        try this.incompatibleDoor() {
            revert("incompatible payload accepted");
        } catch (bytes memory r) {
            require(
                keccak256(r)
                    == keccak256(abi.encodeWithSelector(P_Doors.InvalidDoorThinker.selector, uint32(1)))
            );
        }
        try this.syntheticChangeFloor() {
            revert("missing synthetic front accepted");
        } catch (bytes memory r) {
            require(
                keccak256(r)
                    == keccak256(abi.encodeWithSelector(P_Floor.SyntheticFloorNeedsFrontSector.selector))
            );
        }
    }
}
