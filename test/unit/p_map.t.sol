// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {P_Map} from "../../src/doom/p_map.sol";
import {P_MapUtl as U} from "../../src/doom/p_maputl.sol";
import {P_Sight} from "../../src/doom/p_sight.sol";
import {P_Info} from "../../src/doom/p_info.sol";
import {
    GameContext,
    Mobj,
    GameSector,
    MobjInfo,
    Intercept,
    GameConst as C
} from "../../src/doom/p_game_state.sol";
import {Vertex, Line, Sector, Subsector, Seg} from "../../src/doom/r_defs.sol";

interface VmMap {
    function readFileBinary(string calldata path) external view returns (bytes memory);
}

contract P_Map_Test {
    VmMap constant vm = VmMap(address(uint160(uint256(keccak256("hevm cheat code")))));
    error NativeMismatch(uint32 op, uint32 variant, uint32 offset, uint32 actual, uint32 expected);

    function word(bytes memory data, uint256 p) private pure returns (uint32 n) {
        for (uint256 i; i < 4; i++) {
            n = (n << 8) | uint8(data[p + i]);
        }
    }

    function wall(GameContext memory c, uint32 id, int32 x, bool two) private pure {
        c.map.vertexes[id * 2] = Vertex(x * 65536, 128 * 65536);
        c.map.vertexes[id * 2 + 1] = Vertex(x * 65536, -128 * 65536);
        Line memory l = c.map.lines[id];
        l.v1 = id * 2;
        l.v2 = id * 2 + 1;
        l.dx = 0;
        l.dy = -256 * 65536;
        l.slopetype = 1;
        l.frontsector = 0;
        l.backsector = two ? 1 : C.NULL;
        l.flags = two ? 4 : 0;
        l.sidenum[1] = two ? 0 : C.NULL;
        l.bbox = [int32(128 * 65536), int32(-128 * 65536), x * 65536, x * 65536];
        c.map.segs[id].linedef = id;
        c.map.segs[id].frontsector = 0;
        c.map.segs[id].backsector = l.backsector;
    }

    function setup(uint32 op, uint32 variant) private pure returns (GameContext memory c) {
        c.map.vertexes = new Vertex[](4);
        c.map.lines = new Line[](2);
        c.map.sectors = new Sector[](2);
        c.map.segs = new Seg[](2);
        c.map.subsectors = new Subsector[](1);
        c.map.subsectors[0] = Subsector(0, 2, 0);
        c.map.sectors[0].ceilingheight = 128 * 65536;
        c.map.sectors[1].ceilingheight = 128 * 65536;
        c.state.sectors = new GameSector[](2);
        c.state.sectors[0].thinglist = C.NULL;
        c.state.sectors[1].thinglist = C.NULL;
        c.state.sectors[0].blockbox = [int32(3), int32(0), int32(0), int32(3)];
        wall(c, 0, 64, false);
        wall(c, 1, -64, true);
        c.state.lineValidcount = new uint32[](2);
        c.state.rejectmatrix = new bytes(1);
        c.state.blockmap.width = 4;
        c.state.blockmap.height = 4;
        c.state.blockmap.orgx = -256 * 65536;
        c.state.blockmap.orgy = -256 * 65536;
        c.state.blockmap.heads = new uint32[](16);
        for (uint256 i; i < 16; i++) {
            c.state.blockmap.heads[i] = C.NULL;
        }
        c.state.blockmap.lump = new int16[](23);
        c.state.blockmap.lump[0] = -256;
        c.state.blockmap.lump[1] = -256;
        c.state.blockmap.lump[2] = 4;
        c.state.blockmap.lump[3] = 4;
        for (uint256 i = 4; i < 20; i++) {
            c.state.blockmap.lump[i] = 20;
        }
        c.state.blockmap.lump[20] = 0;
        c.state.blockmap.lump[21] = 1;
        c.state.blockmap.lump[22] = -1;
        c.state.mobjs = new Mobj[](8);
        c.state.mobjCount = 2;
        c.state.gamemap = 1;
        c.state.skyflatnum = 17;
        c.definitions.mobjinfo = new MobjInfo[](137);
        c.definitions.mobjinfo[P_Info.MT_PLAYER].damage = 3;
        c.definitions.mobjinfo[P_Info.MT_PLAYER].spawnstate = int32(P_Info.S_PLAY);
        for (uint32 i; i < 2; i++) {
            Mobj memory t = c.state.mobjs[i];
            t.radius = 16 * 65536;
            t.height = 56 * 65536;
            t.health = 100;
            t.flags = C.MF_SOLID | C.MF_SHOOTABLE;
            t.mobjType = i == 0 ? P_Info.MT_PLAYER : P_Info.MT_POSSESSED;
            t.ceilingz = 128 * 65536;
            t.state = P_Info.S_PLAY;
            t.target = C.NULL;
            t.player = C.NULL;
            t.snext = C.NULL;
            t.sprev = C.NULL;
            t.bnext = C.NULL;
            t.bprev = C.NULL;
        }
        c.state.mobjs[0].flags |= C.MF_PICKUP;
        c.state.mobjs[0].player = 0;
        c.state.players[0].mo = 0;
        c.state.mobjs[1].x = 32 * 65536;
        c.move.ceilingline = C.NULL;
        c.move.bestslideline = C.NULL;
        c.move.secondslideline = C.NULL;
        c.move.linetarget = C.NULL;
        c.hooks.damageMobj = damage;
        c.hooks.touchSpecialThing = touch;
        c.hooks.setMobjState = setState;
        c.hooks.removeMobj = remove;
        c.hooks.crossSpecialLine = cross;
        c.hooks.shootSpecialLine = shoot;
        c.hooks.useSpecialLine = use;
        c.hooks.spawnPuff = puff;
        c.hooks.spawnBlood = blood;
        c.hooks.spawnMobj = spawn;
        c.hooks.checkSight = sight;
        c.resources.texturetranslation = new uint32[](256); // test-only recorded callback buffer.
        if (op <= 1) {
            if (variant >= 2 && variant <= 9) c.state.mobjs[1].flags = 0;
            if (variant >= 3 && variant <= 8) wall(c, 0, 64, true);
            if (variant == 3) c.map.lines[0].flags |= 1;
            if (variant == 4) c.map.sectors[1].floorheight = 24 * 65536;
            if (variant == 5) c.map.sectors[1].floorheight = 25 * 65536;
            if (variant == 6) c.map.sectors[1].ceilingheight = 55 * 65536;
            if (variant == 7) c.state.mobjs[0].flags |= C.MF_NOCLIP;
            if (variant == 8) {
                c.map.sectors[1].floorheight = -25 * 65536;
                c.state.mobjs[0].flags |= C.MF_FLOAT;
            }
            if (variant == 10 || variant == 11) {
                c.state.mobjs[0].flags = C.MF_MISSILE;
                c.state.mobjs[0].radius = 6 * 65536;
                c.state.mobjs[0].target = variant == 11 ? 1 : 0;
            }
            if (variant == 12) c.state.mobjs[0].flags |= C.MF_SKULLFLY;
            if (variant == 16) {
                c.state.mobjs[0].flags |= C.MF_SKULLFLY;
                c.resources.numflats = 1;
            }
            if (variant == 13 || variant == 14) {
                c.state.mobjs[1].x = 24 * 65536;
                c.state.mobjs[1].flags = C.MF_SPECIAL | (variant == 14 ? C.MF_SOLID : 0);
            }
            if (variant == 15) {
                c.state.mobjs[1].flags = 0;
                wall(c, 0, 40, true);
                wall(c, 1, 48, true);
                c.map.lines[0].special = 7;
                c.map.lines[1].special = 9;
            }
        } else if (op == 2) {
            if (variant == 1) c.state.mobjs[0].player = C.NULL;
            if (variant == 2) {
                c.state.mobjs[0].player = C.NULL;
                c.state.gamemap = 30;
            }
            if (variant == 3) c.state.mobjs[1].flags = C.MF_SOLID;
        } else if (op == 3) {
            c.state.mobjs[1].flags = 0;
            c.state.mobjs[0].momx = 80 * 65536;
            c.state.mobjs[0].momy = variant == 0 ? int32(0) : int32(16 * 65536);
        } else if (op == 4 || op == 5) {
            if (variant == 1) c.state.mobjs[1].z = 80 * 65536;
            if (variant == 2) c.state.mobjs[1].flags = 0;
            if (variant == 3) c.state.mobjs[1].flags |= C.MF_NOBLOOD;
            if (variant == 4) {
                c.state.mobjs[1].flags = 0;
                c.map.sectors[0].ceilingpic = 17;
                c.map.sectors[0].ceilingheight = 16 * 65536;
            }
            if (variant == 5) c.map.lines[0].special = 46;
            if (variant == 6) {
                c.state.mobjs[1].flags = 0;
                wall(c, 0, 64, true);
                c.map.lines[0].special = 46;
                c.map.sectors[1].ceilingheight = 48 * 65536;
                c.resources.numflats = 2;
            }
        } else if (op == 6) {
            c.state.mobjs[1].flags = 0;
            if (variant != 0) c.map.lines[0].special = 1;
        } else if (op == 7) {
            if (variant == 1) c.state.mobjs[1].mobjType = P_Info.MT_CYBORG;
            if (variant == 2) c.state.mobjs[1].x = 200 * 65536;
            if (variant == 3) c.state.rejectmatrix[0] = 0x01;
        } else if (op == 8) {
            c.map.sectors[0].ceilingheight = 48 * 65536;
            if (variant == 1) c.state.mobjs[1].health = 0;
            if (variant == 2) c.state.mobjs[1].flags |= C.MF_DROPPED;
            if (variant == 3) c.state.mobjs[1].flags = 0;
        }
        if (op == 9) {
            if (variant == 2) c.state.mobjs[0].flags |= C.MF_NOSECTOR | C.MF_NOBLOCKMAP;
            if (variant == 3) c.state.mobjs[0].flags |= C.MF_NOSECTOR;
        } else if (op == 10) {
            c.state.mobjs[1].flags = 0;
            if (variant == 1) wall(c, 1, 64, true);
        }
        c.state.map = c.map;
        for (uint32 i; i < 2; i++) {
            U.P_SetThingPosition(c, i);
        }
    }

    function logcall(GameContext memory c, uint32 op, uint32 a, uint32 b, uint32 d, uint32 e) private pure {
        uint32 p = c.resources.numspritelumps;
        c.resources.texturetranslation[p] = op;
        c.resources.texturetranslation[p + 1] = a;
        c.resources.texturetranslation[p + 2] = b;
        c.resources.texturetranslation[p + 3] = d;
        c.resources.texturetranslation[p + 4] = e;
        c.resources.numspritelumps = p + 5;
    }

    function damage(GameContext memory c, uint32 t, uint32 inflictor, uint32 source, int32 amount)
        private
        pure
    {
        logcall(c, 1, t, inflictor, source, uint32(amount));
        c.state.mobjs[t].health -= amount;
        if (c.resources.numflats == 1) c.move.tmthing = 1;
    }

    function touch(GameContext memory c, uint32 special, uint32 toucher) private pure {
        logcall(c, 2, special, toucher, 0, 0);
    }

    function setState(GameContext memory c, uint32 t, uint32 state) private pure returns (bool) {
        logcall(c, 3, t, state, 0, 0);
        c.state.mobjs[t].state = state;
        return true;
    }

    function remove(GameContext memory c, uint32 t) private pure {
        logcall(c, 4, t, 0, 0, 0);
    }

    function cross(GameContext memory c, uint32 line, int32 side, uint32 t) private pure {
        logcall(c, 5, line, uint32(side), t, 0);
    }

    function shoot(GameContext memory c, uint32 t, uint32 line) private pure {
        logcall(c, 6, t, line, 0, 0);
        if (c.resources.numflats == 2) c.move.attackrange = 64 * 65536;
    }

    function use(GameContext memory c, uint32 t, uint32 line, int32 side) private pure returns (bool) {
        logcall(c, 7, t, line, uint32(side), 0);
        return true;
    }

    function puff(GameContext memory c, int32 x, int32 y, int32 z) private pure {
        logcall(c, 8, uint32(x), uint32(y), uint32(z), 0);
    }

    function blood(GameContext memory c, int32 x, int32 y, int32 z, int32 amount) private pure {
        logcall(c, 9, uint32(x), uint32(y), uint32(z), uint32(amount));
    }

    function spawn(GameContext memory c, int32 x, int32 y, int32 z, uint32 kind)
        private
        pure
        returns (uint32 id)
    {
        id = c.state.mobjCount++;
        Mobj memory t = c.state.mobjs[id];
        t.x = x;
        t.y = y;
        t.z = z;
        t.mobjType = kind;
        t.state = C.NULL;
        t.snext = C.NULL;
        t.sprev = C.NULL;
        t.bnext = C.NULL;
        t.bprev = C.NULL;
        logcall(c, 10, uint32(x), uint32(y), uint32(z), kind);
    }

    function sight(GameContext memory c, uint32 t1, uint32 t2) private pure returns (bool) {
        return P_Sight.P_CheckSight(c, t1, t2);
    }

    function pathCallback(GameContext memory c, Intercept memory hit) private pure returns (bool) {
        logcall(c, 11, hit.index, uint32(hit.frac), hit.isaline ? 1 : 0, 0);
        return true;
    }

    function run(GameContext memory c, uint32 op, uint32 variant) private view returns (int32 result) {
        if (op <= 1) {
            int32 x = variant == 0
                ? int32(0)
                : variant == 1 || variant == 13 || variant == 14
                    ? int32(8)
                    : variant >= 10 && variant <= 12 || variant == 16
                        ? int32(32)
                        : variant == 15 ? int32(60) : int32(50);
            result = (op == 0
                    ? P_Map.P_CheckPosition(c, 0, x * 65536, 0)
                    : P_Map.P_TryMove(c, 0, x * 65536, 0))
                ? int32(1)
                : int32(0);
        } else if (op == 2) {
            result = P_Map.P_TeleportMove(c, 0, 32 * 65536, 0) ? int32(1) : int32(0);
        } else if (op == 3) {
            P_Map.P_SlideMove(c, 0);
        } else if (op == 4) {
            result = P_Map.P_AimLineAttack(c, 0, 0, 128 * 65536);
        } else if (op == 5) {
            int32 slope = P_Map.P_AimLineAttack(c, 0, 0, 128 * 65536);
            P_Map.P_LineAttack(c, 0, 0, 128 * 65536, variant == 6 ? int32(65536 / 4) : slope, 7);
        } else if (op == 6) {
            P_Map.P_UseLines(c, 0);
        } else if (op == 7) {
            P_Map.P_RadiusAttack(c, 0, C.NULL, 64);
        } else if (op == 8) {
            result = P_Map.P_ChangeSector(c, 0, variant != 4) ? int32(1) : int32(0);
        } else if (op == 9) {
            if (variant == 0) {
                U.P_UnsetThingPosition(c, 1);
            } else {
                U.P_UnsetThingPosition(c, 0);
                c.state.mobjs[0].x = 1000 * 65536;
                U.P_SetThingPosition(c, 0);
            }
        } else if (op == 10) {
            result = U.P_PathTraverse(
                c,
                -128 * 65536,
                0,
                variant == 3 ? int32(10000 * 65536) : int32(128 * 65536),
                0,
                variant == 2 ? int32(5) : int32(1),
                pathCallback
            )
                ? int32(1)
                : int32(0);
        } else {
            revert("fixture op");
        }
    }

    function snapshot(GameContext memory c, int32 result) private pure returns (uint32[] memory a, uint32 p) {
        a = new uint32[](512);
        a[p++] = uint32(result);
        a[p++] = c.move.floatok ? 1 : 0;
        a[p++] = uint32(c.move.tmfloorz);
        a[p++] = uint32(c.move.tmceilingz);
        a[p++] = uint32(c.move.tmdropoffz);
        a[p++] = c.move.ceilingline;
        a[p++] = uint32(c.move.numspechit);
        a[p++] = c.state.prndindex;
        a[p++] = c.state.validcount;
        a[p++] = c.state.mobjCount;
        for (uint32 i; i < c.state.mobjCount; i++) {
            Mobj memory t = c.state.mobjs[i];
            a[p++] = uint32(t.x);
            a[p++] = uint32(t.y);
            a[p++] = uint32(t.z);
            a[p++] = uint32(t.momx);
            a[p++] = uint32(t.momy);
            a[p++] = uint32(t.momz);
            a[p++] = uint32(t.floorz);
            a[p++] = uint32(t.ceilingz);
            a[p++] = t.flags;
            a[p++] = uint32(t.health);
            a[p++] = uint32(t.radius);
            a[p++] = uint32(t.height);
            a[p++] = t.state;
            a[p++] = t.snext;
            a[p++] = t.sprev;
            a[p++] = t.bnext;
            a[p++] = t.bprev;
        }
        a[p++] = c.move.linetarget;
        a[p++] = uint32(c.move.aimslope);
        a[p++] = c.path.count;
        a[p++] = c.move.nofit ? 1 : 0;
        a[p++] = c.move.sightcounts[0];
        a[p++] = c.move.sightcounts[1];
        a[p++] = c.state.sectors[0].thinglist;
        a[p++] = c.state.sectors[1].thinglist;
        for (uint32 i; i < 16; i++) {
            a[p++] = c.state.blockmap.heads[i];
        }
        a[p++] = c.resources.numspritelumps;
        for (uint32 i; i < c.resources.numspritelumps; i++) {
            a[p++] = c.resources.texturetranslation[i];
        }
    }

    function testEveryOriginalMapScenarioAndCallbackOrder() public view {
        bytes memory data = vm.readFileBinary("test/fixtures/phase3_map/scenarios.bin");
        uint32 count = word(data, 0);
        uint256 p = 4;
        require(count == 71, "scenario count");
        for (uint32 row; row < count; row++) {
            uint32 op = word(data, p);
            uint32 variant = word(data, p + 4);
            uint32 no = word(data, p + 8);
            p += 12;
            GameContext memory c = setup(op, variant);
            int32 result = run(c, op, variant);
            (uint32[] memory actual, uint32 n) = snapshot(c, result);
            require(n == no, "scenario serialization length");
            for (uint32 i; i < no; i++) {
                uint32 expected = word(data, p);
                p += 4;
                if (actual[i] != expected) revert NativeMismatch(op, variant, i, actual[i], expected);
            }
        }
        require(p == data.length, "scenario fixture consumed");
    }
}
