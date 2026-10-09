// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {
    GameContext,
    GameConst as C,
    Mobj,
    GameSector,
    FloorType,
    DoorType,
    ThinkerKind
} from "../../src/doom/p_game_state.sol";
import {Sector, Side, Line, Subsector} from "../../src/doom/r_defs.sol";
import {P_Enemy as E} from "../../src/doom/p_enemy.sol";
import {P_Info as I} from "../../src/doom/p_info.sol";
import {P_Heap} from "../../src/doom/p_heap.sol";
import {P_Tick} from "../../src/doom/p_tick.sol";
import {RenderState} from "../../src/doom/r_state.sol";
import {R_Main} from "../../src/doom/r_main.sol";

interface VmEnemy {
    function readFileBinary(string calldata path) external view returns (bytes memory);
}

contract PEnemyTest {
    VmEnemy constant vm = VmEnemy(address(uint160(uint256(keccak256("hevm cheat code")))));
    event log_named_uint(string key, uint256 value);

    struct Output {
        bytes data;
        uint32 cursor;
    }

    function word(bytes memory b, uint256 p) private pure returns (uint32 v) {
        assembly ("memory-safe") { v := shr(224, mload(add(add(b, 32), p))) }
    }

    function put(Output memory out, int32 v) private pure {
        uint32 p = out.cursor;
        bytes memory b = out.data;
        assembly ("memory-safe") { mstore(add(add(b, 32), p), shl(224, v)) }
        out.cursor = p + 4;
    }

    function trace(GameContext memory c, int32 code, int32 a, int32 b, int32 d, int32 e, int32 f)
        private
        pure
    {
        bytes memory data = c.state.rejectmatrix;
        uint256 p = uint256(c.path.count++) * 24;
        int32[6] memory row = [code, a, b, d, e, f];
        for (uint256 i; i < 6; i++) {
            int32 v = row[i];
            assembly ("memory-safe") { mstore(add(add(data, 32), add(p, mul(i, 4))), shl(224, v)) }
        }
    }

    function mode(GameContext memory c, uint32 mask) private pure returns (bool) {
        return (uint32(c.state.levelTimeCount) & mask) != 0;
    }

    function newObject(GameContext memory c, uint32 kind, int32 x, int32 y, int32 z)
        private
        pure
        returns (uint32 id)
    {
        id = P_Heap.allocateMobj(c.state);
        Mobj memory m = c.state.mobjs[id];
        m.mobjType = kind;
        m.x = x;
        m.y = y;
        m.z = z;
        m.state = uint32(c.definitions.mobjinfo[kind].spawnstate);
        m.tics = c.definitions.states[m.state].tics;
        m.sprite = c.definitions.states[m.state].sprite;
        m.frame = c.definitions.states[m.state].frame;
        m.flags = uint32(c.definitions.mobjinfo[kind].flags);
        m.health = c.definitions.mobjinfo[kind].spawnhealth;
        m.radius = c.definitions.mobjinfo[kind].radius;
        m.height = c.definitions.mobjinfo[kind].height;
        m.subsector = 0;
        m.target = C.NULL;
        m.tracer = C.NULL;
        m.player = C.NULL;
        m.snext = C.NULL;
        m.sprev = C.NULL;
        m.bnext = C.NULL;
        m.bprev = C.NULL;
        m.allocated = true;
        m.thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.mobj, id);
    }

    function spawn(GameContext memory c, int32 x, int32 y, int32 z, uint32 kind)
        internal
        pure
        returns (uint32 id)
    {
        id = newObject(c, kind, x, y, z);
        trace(c, 2, int32(id), x, y, z, int32(kind));
    }

    function missile(GameContext memory c, uint32 a, uint32 b, uint32 kind)
        internal
        pure
        returns (uint32 id)
    {
        Mobj memory m = c.state.mobjs[a];
        Mobj memory target = c.state.mobjs[b];
        id = newObject(c, kind, m.x, m.y, m.z + 32 * 65536);
        RenderState memory rs;
        c.state.mobjs[id].angle = R_Main.R_PointToAngle2(rs, m.x, m.y, target.x, target.y);
        c.state.mobjs[id].momx = 100000;
        c.state.mobjs[id].momy = 200000;
        c.state.mobjs[id].momz = 300000;
        trace(c, 3, int32(a), int32(b), int32(kind), int32(id), 0);
    }

    function setState(GameContext memory c, uint32 id, uint32 state) internal pure returns (bool) {
        trace(c, 1, int32(id), int32(state), 0, 0, 0);
        Mobj memory m = c.state.mobjs[id];
        m.state = state;
        m.tics = c.definitions.states[state].tics;
        m.sprite = c.definitions.states[state].sprite;
        m.frame = c.definitions.states[state].frame;
        return true;
    }

    function damage(GameContext memory c, uint32 target, uint32 inflictor, uint32 source, int32 amount)
        internal
        pure
    {
        trace(c, 5, int32(target), int32(inflictor), int32(source), amount, 0);
        c.state.mobjs[target].health -= amount;
    }

    function radius(GameContext memory c, uint32 spot, uint32 source, int32 amount) internal pure {
        trace(c, 6, int32(spot), int32(source), amount, 0, 0);
    }

    function puff(GameContext memory c, int32 x, int32 y, int32 z) internal pure {
        trace(c, 4, x, y, z, 0, 0);
    }

    function aim(GameContext memory c, uint32 id, uint32 angle, int32 range) internal pure returns (int32) {
        trace(c, 7, int32(id), int32(angle), range, 0, 0);
        return 123456;
    }

    function lineAttack(GameContext memory c, uint32 id, uint32 angle, int32 range, int32 slope, int32 amount)
        internal
        pure
    {
        trace(c, 14, int32(id), int32(angle), range, slope, amount);
    }

    function sight(GameContext memory c, uint32 a, uint32 b) internal pure returns (bool) {
        trace(c, 9, int32(a), int32(b), 0, 0, 0);
        return !mode(c, 2);
    }

    function tryMove(GameContext memory c, uint32 id, int32 x, int32 y) internal pure returns (bool) {
        trace(c, 8, int32(id), x, y, 0, 0);
        c.move.floatok = mode(c, 1024);
        c.move.tmfloorz = 16 * 65536;
        c.move.numspechit = mode(c, 2048) ? int32(2) : int32(0);
        c.move.spechit[0] = 0;
        c.move.spechit[1] = 1;
        if (mode(c, 4)) return false;
        c.state.mobjs[id].x = x;
        c.state.mobjs[id].y = y;
        return true;
    }

    function useLine(GameContext memory c, uint32 id, uint32 line, int32 side) internal pure returns (bool) {
        trace(c, 10, int32(id), int32(line), side, 0, 0);
        return line == 1;
    }

    function position(GameContext memory c, uint32 id, int32 x, int32 y) internal pure returns (bool) {
        trace(c, 11, int32(id), x, y, 0, 0);
        return !mode(c, 32);
    }

    function teleport(GameContext memory c, uint32 id, int32 x, int32 y) internal pure returns (bool) {
        trace(c, 12, int32(id), x, y, 0, 0);
        c.state.mobjs[id].x = x;
        c.state.mobjs[id].y = y;
        return true;
    }

    function remove(GameContext memory c, uint32 id) internal pure {
        trace(c, 13, int32(id), 0, 0, 0, 0);
        P_Tick.P_RemoveThinker(c.state, c.state.mobjs[id].thinker);
    }

    function floorAction(GameContext memory c, int32 tag, FloorType kind) internal pure returns (bool) {
        trace(c, 15, tag, int32(uint32(kind)), 0, 0, 0);
        return true;
    }

    function doorAction(GameContext memory c, int32 tag, DoorType kind) internal pure returns (bool) {
        trace(c, 16, tag, int32(uint32(kind)), 0, 0, 0);
        return true;
    }

    function exitLevel(GameContext memory c) internal pure {
        trace(c, 17, 0, 0, 0, 0, 0);
    }

    function psprite(GameContext memory c, uint32 action, uint32 player, uint32 slot) internal pure {
        require(action == I.A_ReFire);
        trace(c, 18, int32(player), int32(slot), 0, 0, 0);
    }

    function context(uint32[11] calldata args) private pure returns (GameContext memory c) {
        c.definitions = I.load();
        P_Tick.P_InitThinkers(c.state);
        c.state.prndindex = args[2];
        c.state.validcount = 1;
        c.state.gametic = (args[3] & 4096) != 0 ? 1 : 0;
        c.state.gamemode = int32(args[6]);
        c.state.gameepisode = int32(args[7]);
        c.state.gamemap = int32(args[8]);
        c.state.gameskill = int32(args[9]);
        c.state.brainEasy = int32(args[10]);
        c.state.netgame = (args[3] & 8192) != 0;
        c.state.fastparm = (args[3] & 16384) != 0;
        c.state.levelTimeCount = int32(args[3]);
        c.state.rejectmatrix = new bytes(65568);
        c.map.sectors = new Sector[](3);
        c.state.sectors = new GameSector[](3);
        c.map.lines = new Line[](3);
        c.map.sides = new Side[](6);
        c.map.subsectors = new Subsector[](1);
        c.map.subsectors[0].sector = 0;
        for (uint32 i; i < 3; i++) {
            c.map.sectors[i].ceilingheight = 128 * 65536;
            c.state.sectors[i].lines = new uint32[](2);
            c.state.sectors[i].lines[0] = i;
            c.state.sectors[i].lines[1] = (i + 2) % 3;
            c.state.sectors[i].soundtarget = C.NULL;
            c.state.sectors[i].thinglist = C.NULL;
            c.map.lines[i].flags = uint16(4 + (i == 0 ? 0 : 64));
            c.map.lines[i].sidenum[0] = 2 * i;
            c.map.lines[i].sidenum[1] = 2 * i + 1;
            c.map.sides[2 * i].sector = i;
            c.map.sides[2 * i + 1].sector = (i + 1) % 3;
            c.map.lines[i].frontsector = i;
            c.map.lines[i].backsector = (i + 1) % 3;
        }
        if (mode(c, 32768)) c.map.sectors[1].ceilingheight = 0;
        c.state.map = c.map;
        c.state.blockmap.width = 16;
        c.state.blockmap.height = 16;
        c.state.blockmap.orgx = -128 * 65536;
        c.state.blockmap.orgy = -128 * 65536;
        c.state.blockmap.heads = new uint32[](256);
        for (uint32 i; i < 256; i++) {
            c.state.blockmap.heads[i] = C.NULL;
        }
        newObject(c, args[1], -16 * 65536, 8 * 65536, 0);
        newObject(c, I.MT_PLAYER, int32(args[4]) * 65536, int32(args[5]) * 65536, 8 * 65536);
        newObject(c, I.MT_POSSESSED, -8 * 65536, 8 * 65536, 0);
        newObject(c, I.MT_BOSSTARGET, 0, 256 * 65536, 0);
        Mobj memory actor = c.state.mobjs[0];
        actor.target = mode(c, 16) ? C.NULL : 1;
        actor.tracer = 1;
        actor.angle = 0x18000000;
        actor.movedir = mode(c, 65536) ? int32(8) : int32(0);
        actor.movecount = mode(c, 131072) ? int32(3) : int32(0);
        actor.lastlook = int32(args[2] & 3);
        actor.reactiontime = mode(c, 8) ? int32(2) : int32(0);
        actor.threshold = 3;
        if (mode(c, 1)) c.state.mobjs[1].flags |= C.MF_SHADOW;
        if (mode(c, 262144)) actor.flags |= C.MF_JUSTHIT;
        if (mode(c, 524288)) actor.flags |= C.MF_JUSTATTACKED;
        if (mode(c, 1048576)) actor.flags |= C.MF_AMBUSH;
        c.state.mobjs[1].health = mode(c, 256) ? int32(0) : int32(100);
        Mobj memory corpse = c.state.mobjs[2];
        corpse.health = 0;
        corpse.flags = C.MF_CORPSE;
        corpse.tics = -1;
        corpse.height = c.definitions.mobjinfo[I.MT_POSSESSED].height / 4;
        corpse.target = 1;
        corpse.momx = 123;
        corpse.momy = 456;
        corpse.bnext = 0;
        c.state.blockmap.heads[16] = 2;
        if (mode(c, 64)) {
            uint32 other = newObject(c, args[1], 256 * 65536, 256 * 65536, 0);
            c.state.mobjs[other].health = 100;
        }
        if (mode(c, 2097152)) {
            for (int32 i; i < 21; i++) {
                newObject(c, I.MT_SKULL, i * 65536, 0, 0);
            }
        }
        c.state.playeringame[0] = true;
        c.state.players[0].mo = 1;
        c.state.players[0].health = c.state.mobjs[1].health;
        c.state.mobjs[1].player = 0;
        c.move.soundtarget = 1;
        c.state.brainTargets = new uint32[](1);
        c.state.brainTargets[0] = 3;
        c.hooks.checkSight = sight;
        c.hooks.tryMove = tryMove;
        c.hooks.useSpecialLine = useLine;
        c.hooks.checkPosition = position;
        c.hooks.teleportMove = teleport;
        c.hooks.removeMobj = remove;
        c.hooks.setMobjState = setState;
        c.hooks.spawnMobj = spawn;
        c.hooks.spawnMissile = missile;
        c.hooks.spawnPuff = puff;
        c.hooks.damageMobj = damage;
        c.hooks.radiusAttack = radius;
        c.hooks.aimLineAttack = aim;
        c.hooks.lineAttack = lineAttack;
        c.hooks.bossDoFloor = floorAction;
        c.hooks.bossDoDoor = doorAction;
        c.hooks.exitLevel = exitLevel;
        c.hooks.actionPSprite = psprite;
    }

    function invoke(GameContext memory c, uint32 operation) private view returns (int32 result) {
        if (operation == 0) {
            E.P_RecursiveSound(c, 0, 0);
            return 0;
        }
        if (operation == 1) {
            E.P_NoiseAlert(c, 1, 0);
            return 0;
        }
        if (operation == 2) return E.P_CheckMeleeRange(c, 0) ? int32(1) : int32(0);
        if (operation == 3) return E.P_CheckMissileRange(c, 0) ? int32(1) : int32(0);
        if (operation == 4) return E.P_Move(c, 0) ? int32(1) : int32(0);
        if (operation == 5) return E.P_TryWalk(c, 0) ? int32(1) : int32(0);
        if (operation == 6) {
            E.P_NewChaseDir(c, 0);
            return 0;
        }
        if (operation == 7) return E.P_LookForPlayers(c, 0, mode(c, 512)) ? int32(1) : int32(0);
        if (operation == 8) {
            E.A_KeenDie(c, 0);
            return 0;
        }
        if (operation == 9) {
            E.A_Look(c, 0);
            return 0;
        }
        if (operation == 10) {
            E.A_Chase(c, 0);
            return 0;
        }
        if (operation == 11) {
            E.A_FaceTarget(c, 0);
            return 0;
        }
        if (operation == 12) {
            E.A_PosAttack(c, 0);
            return 0;
        }
        if (operation == 13) {
            E.A_SPosAttack(c, 0);
            return 0;
        }
        if (operation == 14) {
            E.A_CPosAttack(c, 0);
            return 0;
        }
        if (operation == 15) {
            E.A_CPosRefire(c, 0);
            return 0;
        }
        if (operation == 16) {
            E.A_SpidRefire(c, 0);
            return 0;
        }
        if (operation == 17) {
            E.A_BspiAttack(c, 0);
            return 0;
        }
        if (operation == 18) {
            E.A_TroopAttack(c, 0);
            return 0;
        }
        if (operation == 19) {
            E.A_SargAttack(c, 0);
            return 0;
        }
        if (operation == 20) {
            E.A_HeadAttack(c, 0);
            return 0;
        }
        if (operation == 21) {
            E.A_CyberAttack(c, 0);
            return 0;
        }
        if (operation == 22) {
            E.A_BruisAttack(c, 0);
            return 0;
        }
        if (operation == 23) {
            E.A_SkelMissile(c, 0);
            return 0;
        }
        if (operation == 24) {
            E.A_Tracer(c, 0);
            return 0;
        }
        if (operation == 25) {
            E.A_SkelWhoosh(c, 0);
            return 0;
        }
        if (operation == 26) {
            E.A_SkelFist(c, 0);
            return 0;
        }
        if (operation == 27) {
            E.VileSearch memory search;
            search.corpsehit = C.NULL;
            search.viletryx = -8 * 65536;
            search.viletryy = 8 * 65536;
            return E.PIT_VileCheck(c, search, 2) ? int32(1) : int32(0);
        }
        if (operation == 28) {
            E.A_VileChase(c, 0);
            return 0;
        }
        if (operation == 29) {
            E.A_VileStart(c, 0);
            return 0;
        }
        if (operation == 30) {
            E.A_StartFire(c, 0);
            return 0;
        }
        if (operation == 31) {
            E.A_FireCrackle(c, 0);
            return 0;
        }
        if (operation == 32) {
            E.A_Fire(c, 0);
            return 0;
        }
        if (operation == 33) {
            E.A_VileTarget(c, 0);
            return 0;
        }
        if (operation == 34) {
            E.A_VileAttack(c, 0);
            return 0;
        }
        if (operation == 35) {
            E.A_FatRaise(c, 0);
            return 0;
        }
        if (operation == 36) {
            E.A_FatAttack1(c, 0);
            return 0;
        }
        if (operation == 37) {
            E.A_FatAttack2(c, 0);
            return 0;
        }
        if (operation == 38) {
            E.A_FatAttack3(c, 0);
            return 0;
        }
        if (operation == 39) {
            E.A_SkullAttack(c, 0);
            return 0;
        }
        if (operation == 40) {
            E.A_PainShootSkull(c, 0, mode(c, 512) ? uint32(0x40000000) : uint32(0));
            return 0;
        }
        if (operation == 41) {
            E.A_PainAttack(c, 0);
            return 0;
        }
        if (operation == 42) {
            E.A_PainDie(c, 0);
            return 0;
        }
        if (operation == 43) {
            E.A_Scream(c, 0);
            return 0;
        }
        if (operation == 44) {
            E.A_XScream(c, 0);
            return 0;
        }
        if (operation == 45) {
            E.A_Pain(c, 0);
            return 0;
        }
        if (operation == 46) {
            E.A_Fall(c, 0);
            return 0;
        }
        if (operation == 47) {
            E.A_Explode(c, 0);
            return 0;
        }
        if (operation == 48) {
            E.A_BossDeath(c, 0);
            return 0;
        }
        if (operation == 49) {
            E.A_Hoof(c, 0);
            return 0;
        }
        if (operation == 50) {
            E.A_Metal(c, 0);
            return 0;
        }
        if (operation == 51) {
            E.A_BabyMetal(c, 0);
            return 0;
        }
        if (operation == 52) {
            E.A_OpenShotgun2(c, 0, 0);
            return 0;
        }
        if (operation == 53) {
            E.A_LoadShotgun2(c, 0, 0);
            return 0;
        }
        if (operation == 54) {
            E.A_CloseShotgun2(c, 0, 0);
            return 0;
        }
        if (operation == 55) {
            E.A_BrainAwake(c, 0);
            return 0;
        }
        if (operation == 56) {
            E.A_BrainPain(c, 0);
            return 0;
        }
        if (operation == 57) {
            E.A_BrainScream(c, 0);
            return 0;
        }
        if (operation == 58) {
            E.A_BrainExplode(c, 0);
            return 0;
        }
        if (operation == 59) {
            E.A_BrainDie(c, 0);
            return 0;
        }
        if (operation == 60) {
            E.A_BrainSpit(c, 0);
            return 0;
        }
        if (operation == 61) {
            E.A_SpawnSound(c, 0);
            return 0;
        }
        if (operation == 62) {
            E.A_SpawnFly(c, 0);
            return 0;
        }
        if (operation == 63) {
            E.A_PlayerScream(c, 0);
            return 0;
        }
        revert("operation");
    }

    function snapshot(GameContext memory c, int32 result) private pure returns (bytes memory data) {
        Output memory out;
        out.data = new bytes(65568);
        put(out, result);
        put(out, int32(c.state.prndindex));
        put(out, int32(c.state.validcount));
        put(out, c.move.numspechit);
        put(out, int32(c.state.brainTargetOn));
        put(out, int32(uint32(c.state.brainTargets.length)));
        put(out, c.state.brainEasy);
        put(out, int32(c.state.mobjCount));
        for (uint32 i; i < c.state.mobjCount; i++) {
            Mobj memory m = c.state.mobjs[i];
            int32[21] memory row = [
                int32(m.mobjType),
                m.x,
                m.y,
                m.z,
                int32(m.angle),
                m.momx,
                m.momy,
                m.momz,
                int32(m.flags),
                m.health,
                m.height,
                m.tics,
                int32(m.state),
                int32(m.target),
                int32(m.tracer),
                m.reactiontime,
                m.threshold,
                m.movedir,
                m.movecount,
                m.lastlook,
                c.state.thinkers[m.thinker].status == C.THINKER_REMOVE ? int32(1) : int32(0)
            ];
            for (uint32 j; j < 21; j++) {
                put(out, row[j]);
            }
        }
        for (uint32 i; i < 3; i++) {
            put(out, int32(c.state.sectors[i].validcount));
            put(out, c.state.sectors[i].soundtraversed);
            put(out, int32(c.state.sectors[i].soundtarget));
        }
        put(out, int32(c.path.count));
        for (uint32 i; i < c.path.count * 6; i++) {
            put(out, int32(word(c.state.rejectmatrix, i * 4)));
        }
        data = out.data;
        uint32 length = out.cursor;
        assembly ("memory-safe") { mstore(data, length) }
    }

    function evaluate(uint32[11] calldata args) external view returns (bytes memory) {
        GameContext memory c = context(args);
        if (args[0] == 62 || args[0] == 61) {
            c.state.mobjs[0].target = 3;
            c.state.mobjs[0].reactiontime = mode(c, 8) ? int32(2) : int32(1);
        }
        return snapshot(c, invoke(c, args[0]));
    }

    function runOperation(uint32 operation) private view {
        bytes memory vectors = vm.readFileBinary("test/fixtures/phase3_enemy/vectors.bin");
        uint256 pos;
        uint32 index;
        while (pos < vectors.length) {
            uint32 words = word(vectors, pos);
            pos += 4;
            uint256 end = pos + uint256(words) * 4;
            require(end <= vectors.length && words >= 19, "record framing");
            if (word(vectors, pos) == operation) {
                uint32[11] memory args;
                for (uint32 i; i < 11; i++) {
                    args[i] = word(vectors, pos + i * 4);
                }
                bytes memory actual = this.evaluate(args);
                uint256 expectedBytes = (uint256(words) - 11) * 4;
                bytes memory expected = new bytes(expectedBytes);
                for (uint256 i; i < expectedBytes; i++) {
                    expected[i] = vectors[pos + 44 + i];
                }
                if (keccak256(actual) != keccak256(expected)) {
                    {
                        if (actual.length != expected.length) {
                            revert NativeMismatch(
                                index,
                                args[0],
                                type(uint32).max,
                                uint32(actual.length),
                                uint32(expected.length)
                            );
                        }
                        for (uint32 wi; wi < actual.length / 4; wi++) {
                            if (word(actual, wi * 4) != word(expected, wi * 4)) {
                                revert NativeMismatch(
                                    index, args[0], wi, word(actual, wi * 4), word(expected, wi * 4)
                                );
                            }
                        }
                        revert("byte mismatch");
                    }
                }
            }
            pos = end;
            index++;
        }
        require(pos == vectors.length && index >= 1137, "coverage count");
    }
    error NativeMismatch(uint32 row, uint32 operation, uint32 field, uint32 actual, uint32 expected);

    function testNative_P_RecursiveSound() public view {
        runOperation(0);
    }

    function testNative_P_NoiseAlert() public view {
        runOperation(1);
    }

    function testNative_P_CheckMeleeRange() public view {
        runOperation(2);
    }

    function testNative_P_CheckMissileRange() public view {
        runOperation(3);
    }

    function testNative_P_Move() public view {
        runOperation(4);
    }

    function testNative_P_TryWalk() public view {
        runOperation(5);
    }

    function testNative_P_NewChaseDir() public view {
        runOperation(6);
    }

    function testNative_P_LookForPlayers() public view {
        runOperation(7);
    }

    function testNative_A_KeenDie() public view {
        runOperation(8);
    }

    function testNative_A_Look() public view {
        runOperation(9);
    }

    function testNative_A_Chase() public view {
        runOperation(10);
    }

    function testNative_A_FaceTarget() public view {
        runOperation(11);
    }

    function testNative_A_PosAttack() public view {
        runOperation(12);
    }

    function testNative_A_SPosAttack() public view {
        runOperation(13);
    }

    function testNative_A_CPosAttack() public view {
        runOperation(14);
    }

    function testNative_A_CPosRefire() public view {
        runOperation(15);
    }

    function testNative_A_SpidRefire() public view {
        runOperation(16);
    }

    function testNative_A_BspiAttack() public view {
        runOperation(17);
    }

    function testNative_A_TroopAttack() public view {
        runOperation(18);
    }

    function testNative_A_SargAttack() public view {
        runOperation(19);
    }

    function testNative_A_HeadAttack() public view {
        runOperation(20);
    }

    function testNative_A_CyberAttack() public view {
        runOperation(21);
    }

    function testNative_A_BruisAttack() public view {
        runOperation(22);
    }

    function testNative_A_SkelMissile() public view {
        runOperation(23);
    }

    function testNative_A_Tracer() public view {
        runOperation(24);
    }

    function testNative_A_SkelWhoosh() public view {
        runOperation(25);
    }

    function testNative_A_SkelFist() public view {
        runOperation(26);
    }

    function testNative_PIT_VileCheck() public view {
        runOperation(27);
    }

    function testNative_A_VileChase() public view {
        runOperation(28);
    }

    function testNative_A_VileStart() public view {
        runOperation(29);
    }

    function testNative_A_StartFire() public view {
        runOperation(30);
    }

    function testNative_A_FireCrackle() public view {
        runOperation(31);
    }

    function testNative_A_Fire() public view {
        runOperation(32);
    }

    function testNative_A_VileTarget() public view {
        runOperation(33);
    }

    function testNative_A_VileAttack() public view {
        runOperation(34);
    }

    function testNative_A_FatRaise() public view {
        runOperation(35);
    }

    function testNative_A_FatAttack1() public view {
        runOperation(36);
    }

    function testNative_A_FatAttack2() public view {
        runOperation(37);
    }

    function testNative_A_FatAttack3() public view {
        runOperation(38);
    }

    function testNative_A_SkullAttack() public view {
        runOperation(39);
    }

    function testNative_A_PainShootSkull() public view {
        runOperation(40);
    }

    function testNative_A_PainAttack() public view {
        runOperation(41);
    }

    function testNative_A_PainDie() public view {
        runOperation(42);
    }

    function testNative_A_Scream() public view {
        runOperation(43);
    }

    function testNative_A_XScream() public view {
        runOperation(44);
    }

    function testNative_A_Pain() public view {
        runOperation(45);
    }

    function testNative_A_Fall() public view {
        runOperation(46);
    }

    function testNative_A_Explode() public view {
        runOperation(47);
    }

    function testNative_A_BossDeath() public view {
        runOperation(48);
    }

    function testNative_A_Hoof() public view {
        runOperation(49);
    }

    function testNative_A_Metal() public view {
        runOperation(50);
    }

    function testNative_A_BabyMetal() public view {
        runOperation(51);
    }

    function testNative_A_OpenShotgun2() public view {
        runOperation(52);
    }

    function testNative_A_LoadShotgun2() public view {
        runOperation(53);
    }

    function testNative_A_CloseShotgun2() public view {
        runOperation(54);
    }

    function testNative_A_BrainAwake() public view {
        runOperation(55);
    }

    function testNative_A_BrainPain() public view {
        runOperation(56);
    }

    function testNative_A_BrainScream() public view {
        runOperation(57);
    }

    function testNative_A_BrainExplode() public view {
        runOperation(58);
    }

    function testNative_A_BrainDie() public view {
        runOperation(59);
    }

    function testNative_A_BrainSpit() public view {
        runOperation(60);
    }

    function testNative_A_SpawnSound() public view {
        runOperation(61);
    }

    function testNative_A_SpawnFly() public view {
        runOperation(62);
    }

    function testNative_A_PlayerScream() public view {
        runOperation(63);
    }
}
