// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {
    GameContext,
    GameConst as C,
    Mobj,
    Player,
    PlayerState,
    GameSector,
    ThinkerKind
} from "../../src/doom/p_game_state.sol";
import {Sector, Line, Subsector, MapThing} from "../../src/doom/r_defs.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
import {P_Info as I} from "../../src/doom/p_info.sol";
import {P_Tick} from "../../src/doom/p_tick.sol";
import {P_Mobj as M} from "../../src/doom/p_mobj.sol";
import {P_User as U} from "../../src/doom/p_user.sol";
import {G_Game as G} from "../../src/doom/g_game.sol";
import {Ticcmd} from "../../src/doom/d_ticcmd.sol";

interface VmLifecycle {
    function readFileBinary(string calldata path) external view returns (bytes memory);
}

abstract contract LifecycleOracle {
    VmLifecycle constant vm = VmLifecycle(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Output {
        bytes data;
        uint32 cursor;
    }
    error NativeMismatch(uint32 row, uint32 operation, uint32 field, uint32 actual, uint32 expected);

    function word(bytes memory b, uint256 p) private pure returns (uint32 v) {
        assembly ("memory-safe") { v := shr(224, mload(add(add(b, 32), p))) }
    }

    function put(Output memory out, int32 v) private pure {
        uint32 p = out.cursor;
        bytes memory b = out.data;
        assembly ("memory-safe") { mstore(add(add(b, 32), p), shl(224, v)) }
        out.cursor = p + 4;
    }

    function mode(GameContext memory c, uint32 mask) private pure returns (bool) {
        return (uint32(c.state.levelTimeCount) & mask) != 0;
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

    function movePsprites(GameContext memory c, uint32 p) internal pure {
        trace(c, 1, int32(p), 0, 0, 0, 0);
    }

    function setupPsprites(GameContext memory c, uint32 p) internal pure {
        trace(c, 2, int32(p), 0, 0, 0, 0);
    }

    function useLines(GameContext memory c, uint32 p) internal pure {
        trace(c, 3, int32(p), 0, 0, 0, 0);
    }

    function special(GameContext memory c, uint32 p) internal pure {
        trace(c, 4, int32(p), 0, 0, 0, 0);
    }

    function tryMove(GameContext memory c, uint32 id, int32 x, int32 y) internal pure returns (bool) {
        trace(c, 5, int32(id), x, y, 0, 0);
        c.move.ceilingline = mode(c, 128) ? 0 : C.NULL;
        if (mode(c, 4)) return false;
        c.state.mobjs[id].x = x;
        c.state.mobjs[id].y = y;
        return true;
    }

    function position(GameContext memory c, uint32 id, int32 x, int32 y) internal pure returns (bool) {
        trace(c, 6, int32(id), x, y, 0, 0);
        return !mode(c, 2);
    }

    function slide(GameContext memory c, uint32 id) internal pure {
        trace(c, 7, int32(id), 0, 0, 0, 0);
        c.state.mobjs[id].momx /= 2;
        c.state.mobjs[id].momy /= 2;
    }

    function aim(GameContext memory c, uint32 id, uint32 angle, int32 range) internal pure returns (int32) {
        trace(c, 8, int32(id), int32(angle), range, 0, 0);
        c.move.tmx++;
        c.move.linetarget = c.move.tmx >= int32(1 + (uint32(c.state.levelTimeCount) & 3)) ? 1 : C.NULL;
        return 123456;
    }

    function action(GameContext memory c, uint32 actionId, uint32 id) internal view {
        trace(c, 9, int32(actionId), int32(id), 0, 0, 0);
        if (mode(c, 8192)) c.state.mobjs[id].tics = 7;
        if (mode(c, 65536) && c.move.tmy == 0) {
            c.move.tmy = 1;
            M.P_SetMobjState(c, id, I.S_PLAY);
        }
    }

    function context(uint32[14] calldata a) private pure returns (GameContext memory c) {
        c.definitions = I.load();
        c.definitions.states[900].tics = 0;
        c.definitions.states[900].action = I.A_Look;
        c.definitions.states[900].nextstate = 901;
        c.definitions.states[901].tics = 0;
        c.definitions.states[901].action = I.A_Fall;
        c.definitions.states[901].nextstate = 902;
        c.definitions.states[902].tics = 4;
        c.definitions.states[902].action = I.A_Pain;
        c.state.levelTimeCount = int32(a[3]);
        c.state.prndindex = a[2];
        c.state.leveltime = mode(c, 262144) ? int32(416) : int32(1050);
        c.state.gamemode = int32(a[10]);
        c.state.gameskill = int32(a[9]);
        c.state.secretExit = true;
        c.state.deathmatch = mode(c, 524288) ? int32(2) : int32(0);
        c.state.netgame = mode(c, 2097152);
        c.state.respawnmonsters = mode(c, 131072);
        c.state.nomonsters = mode(c, 1048576);
        c.state.skyflatnum = 3;
        c.move.onground = !mode(c, 536870912);
        c.move.attackrange = mode(c, 4194304) ? C.MELEERANGE : C.MISSILERANGE;
        c.move.ceilingline = C.NULL;
        c.move.linetarget = C.NULL;
        c.state.rejectmatrix = new bytes(131104);
        c.map.sectors = new Sector[](1);
        c.map.sectors[0].ceilingheight = mode(c, 1073741824) ? int32(64 * 65536) : int32(128 * 65536);
        c.map.sectors[0].ceilingpic = mode(c, 128) ? 3 : 0;
        c.map.lines = new Line[](1);
        c.map.lines[0].backsector = 0;
        c.map.subsectors = new Subsector[](1);
        c.state.map = c.map;
        c.state.sectors = new GameSector[](1);
        c.state.sectors[0].special = mode(c, 16384) ? int16(5) : int16(0);
        c.state.sectors[0].thinglist = C.NULL;
        c.state.blockmap.width = 16;
        c.state.blockmap.height = 16;
        c.state.blockmap.orgx = -1024 * 65536;
        c.state.blockmap.orgy = -1024 * 65536;
        c.state.blockmap.heads = new uint32[](256);
        for (uint32 i; i < 256; i++) {
            c.state.blockmap.heads[i] = C.NULL;
        }
        P_Tick.P_InitThinkers(c.state);
        M.P_SpawnMobj(c, -16 * 65536, 8 * 65536, int32(a[7]), a[1]);
        M.P_SpawnMobj(c, 128 * 65536, 64 * 65536, 8 * 65536, I.MT_POSSESSED);
        M.P_SpawnMobj(c, -64 * 65536, 16 * 65536, C.ONFLOORZ, I.MT_CLIP);
        c.state.mobjs[2].spawnpoint = MapThing(-64, 16, 270, 2007, 7);
        Mobj memory mo = c.state.mobjs[0];
        if (mode(c, 2)) mo.reactiontime = 2;
        if (mode(c, 4)) mo.reactiontime = 0;
        mo.player = mode(c, 1) ? C.NULL : 0;
        mo.target = 1;
        mo.tracer = 1;
        mo.momx = int32(a[4]);
        mo.momy = int32(a[5]);
        mo.momz = int32(a[6]);
        mo.angle = a[13];
        mo.spawnpoint = MapThing(-64, 16, int16(int32(a[13])), 3004, int16(int32(a[12])));
        if (mode(c, 8)) mo.flags |= C.MF_SKULLFLY;
        if (mode(c, 16)) mo.flags |= C.MF_FLOAT;
        if (mode(c, 32)) mo.flags |= C.MF_MISSILE;
        if (mode(c, 64)) mo.flags |= C.MF_CORPSE;
        if (mode(c, 4096)) mo.flags |= C.MF_DROPPED;
        if (mode(c, 33554432)) mo.flags |= C.MF_NOGRAVITY;
        if (mode(c, 67108864)) c.state.mobjs[1].flags |= C.MF_SHADOW;
        if (mode(c, 2147483648)) mo.flags |= C.MF_JUSTATTACKED;
        if (mode(c, 131072)) {
            mo.tics = -1;
            mo.movecount = 419;
            mo.flags |= C.MF_COUNTKILL;
        }
        for (uint32 i; i < 4; i++) {
            c.state.players[i].mo = C.NULL;
            c.state.players[i].attacker = C.NULL;
            c.state.players[i].psprites[0].state = C.NULL;
            c.state.players[i].psprites[1].state = C.NULL;
        }
        c.state.playeringame[0] = true;
        c.state.playeringame[1] = mode(c, 2097152);
        c.state.players[1].health = 77;
        Player memory p = c.state.players[0];
        p.mo = 0;
        p.attacker = 1;
        p.viewheight = 41 * 65536;
        p.deltaviewheight = -65536 / 4;
        p.health = 97;
        p.armorpoints = 25;
        p.armortype = 1;
        p.readyweapon = 1;
        p.pendingweapon = 10;
        p.damagecount = 7;
        p.bonuscount = 3;
        p.usedown = mode(c, 16777216) ? int32(1) : int32(0);
        p.attackdown = 1;
        p.killcount = 5;
        p.itemcount = 6;
        p.secretcount = 7;
        p.message = "test";
        p.backpack = true;
        p.extralight = 2;
        p.fixedcolormap = 1;
        p.colormap = 2;
        p.didsecret = true;
        p.playerstate = mode(c, 1024)
            ? PlayerState.dead
            : (mode(c, 2048) ? PlayerState.reborn : PlayerState.live);
        p.cheats = (mode(c, 256) ? int32(4) : int32(0)) | (mode(c, 512) ? int32(1) : int32(0));
        p.cmd = Ticcmd(
            int8(int32(a[4]) / 2048), int8(int32(a[5]) / 2048), int16(int32(a[6])), 42, 65, uint8(a[12])
        );
        for (uint32 i; i < 4; i++) {
            p.frags[i] = int32(13 * (i + 1));
            p.ammo[i] = int32(20 + i);
            p.maxammo[i] = int32(100 + i);
        }
        for (uint32 i; i < 9; i++) {
            p.weaponowned[i] = mode(c, 8388608) || i <= 1;
        }
        for (uint32 i; i < 6; i++) {
            p.powers[i] = mode(c, 268435456) ? int32(1) : (mode(c, 4194304) ? int32(129) : int32(0));
            p.cards[i] = (i & 1) != 0;
        }
        p.psprites[0].state = I.S_PISTOL;
        p.psprites[0].tics = 4;
        p.psprites[0].sx = 1234;
        p.psprites[0].sy = 5678;
        p.psprites[1].state = I.S_PISTOLFLASH;
        p.psprites[1].tics = 3;
        p.psprites[1].sx = 2345;
        p.psprites[1].sy = 6789;
        if (mode(c, 32768)) {
            c.state.iquehead = 127;
            c.state.iquetail = 0;
            for (uint32 i; i < 128; i++) {
                c.state.itemrespawnque[i] = c.state.mobjs[2].spawnpoint;
            }
        }
        if (mode(c, 134217728)) {
            c.resources.source.lumps = new LumpDescriptor[](1);
            c.resources.source.lumps[0].name = "MAP31";
        }
        c.hooks.movePsprites = movePsprites;
        c.hooks.setupPsprites = setupPsprites;
        c.hooks.useLines = useLines;
        c.hooks.playerSpecialSector = special;
        c.hooks.tryMove = tryMove;
        c.hooks.checkPosition = position;
        c.hooks.slideMove = slide;
        c.hooks.aimLineAttack = aim;
        c.hooks.actionMobj = action;
        c.hooks.setMobjState = M.P_SetMobjState;
    }

    function invoke(GameContext memory c, uint32 op, uint32[14] calldata a) private view returns (int32) {
        MapThing memory thing = MapThing(
            -64, 16, int16(int32(a[13])), int16(int32(a[11])), int16(int32(a[12]))
        );
        if (op == 0) {
            U.P_Thrust(c, 0, a[13], c.state.mobjs[0].momx);
            return 0;
        }
        if (op == 1) {
            U.P_CalcHeight(c, 0);
            return 0;
        }
        if (op == 2) {
            U.P_MovePlayer(c, 0);
            return 0;
        }
        if (op == 3) {
            U.P_DeathThink(c, 0);
            return 0;
        }
        if (op == 4) {
            U.P_PlayerThink(c, 0);
            return 0;
        }
        if (op == 5) return M.P_SetMobjState(c, 0, 900) ? int32(1) : int32(0);
        if (op == 6) {
            M.P_ExplodeMissile(c, 0);
            return 0;
        }
        if (op == 7) {
            M.P_XYMovement(c, 0);
            return 0;
        }
        if (op == 8) {
            M.P_ZMovement(c, 0);
            return 0;
        }
        if (op == 9) {
            M.P_NightmareRespawn(c, 0);
            return 0;
        }
        if (op == 10) {
            M.P_MobjThinker(c, 0);
            return 0;
        }
        if (op == 11) {
            return int32(
                M.P_SpawnMobj(
                    c,
                    -64 * 65536,
                    16 * 65536,
                    mode(c, 32) ? C.ONCEILINGZ : C.ONFLOORZ,
                    c.state.mobjs[0].mobjType
                )
            );
        }
        if (op == 12) {
            M.P_RemoveMobj(c, 0);
            return 0;
        }
        if (op == 13) {
            M.P_RespawnSpecials(c);
            return 0;
        }
        if (op == 14) {
            M.P_SpawnPlayer(c, thing);
            return 0;
        }
        if (op == 15) {
            M.P_SpawnMapThing(c, thing);
            return 0;
        }
        if (op == 16) {
            M.P_SpawnPuff(c, -64 * 65536, 16 * 65536, 32 * 65536);
            return 0;
        }
        if (op == 17) {
            M.P_SpawnBlood(c, -64 * 65536, 16 * 65536, 32 * 65536, int32(a[12]));
            return 0;
        }
        if (op == 18) {
            M.P_CheckMissileSpawn(c, 0);
            return 0;
        }
        if (op == 19) return int32(M.P_SpawnMissile(c, 0, 1, I.MT_ROCKET));
        if (op == 20) {
            M.P_SpawnPlayerMissile(c, 0, I.MT_ROCKET);
            return 0;
        }
        if (op == 21) {
            G.G_PlayerReborn(c.state, 0);
            return 0;
        }
        if (op == 22) {
            G.G_ExitLevel(c.state);
            return 0;
        }
        if (op == 23) {
            G.G_SecretExitLevel(c);
            return 0;
        }
        revert("operation");
    }

    function writeThing(Output memory o, MapThing memory m) private pure {
        put(o, int32(m.x));
        put(o, int32(m.y));
        put(o, int32(m.angle));
        put(o, int32(m.thingType));
        put(o, int32(m.options));
    }

    function writePlayer(Output memory o, Player memory p) private pure {
        put(o, int32(p.mo));
        put(o, int32(uint32(p.playerstate)));
        put(o, int32(p.cmd.forwardmove));
        put(o, int32(p.cmd.sidemove));
        put(o, int32(p.cmd.angleturn));
        put(o, int32(p.cmd.consistancy));
        put(o, int32(uint32(p.cmd.chatchar)));
        put(o, int32(uint32(p.cmd.buttons)));
        int32[25] memory row = [
            p.viewz,
            p.viewheight,
            p.deltaviewheight,
            p.bob,
            p.health,
            p.armorpoints,
            p.armortype,
            p.backpack ? int32(1) : int32(0),
            int32(p.readyweapon),
            int32(p.pendingweapon),
            p.attackdown,
            p.usedown,
            p.cheats,
            p.refire,
            p.killcount,
            p.itemcount,
            p.secretcount,
            p.damagecount,
            p.bonuscount,
            int32(p.attacker),
            p.extralight,
            p.fixedcolormap,
            p.colormap,
            p.didsecret ? int32(1) : int32(0),
            bytes(p.message).length != 0 ? int32(1) : int32(0)
        ];
        for (uint32 i; i < 25; i++) {
            put(o, row[i]);
        }
        for (uint32 i; i < 6; i++) {
            put(o, p.powers[i]);
            put(o, p.cards[i] ? int32(1) : int32(0));
        }
        for (uint32 i; i < 4; i++) {
            put(o, p.frags[i]);
            put(o, p.ammo[i]);
            put(o, p.maxammo[i]);
        }
        for (uint32 i; i < 9; i++) {
            put(o, p.weaponowned[i] ? int32(1) : int32(0));
        }
        for (uint32 i; i < 2; i++) {
            put(o, int32(p.psprites[i].state));
            put(o, p.psprites[i].tics);
            put(o, p.psprites[i].sx);
            put(o, p.psprites[i].sy);
        }
    }

    function snapshot(GameContext memory c, int32 result) private pure returns (bytes memory data) {
        Output memory o;
        o.data = new bytes(131104);
        put(o, result);
        put(o, int32(c.state.prndindex));
        put(o, c.state.leveltime);
        put(o, int32(uint32(c.state.gametic)));
        put(o, c.move.onground ? int32(1) : int32(0));
        put(o, c.state.gameaction);
        put(o, c.state.secretExit ? int32(1) : int32(0));
        put(o, c.state.totalkills);
        put(o, c.state.totalitems);
        put(o, c.state.totalsecret);
        for (uint32 i; i < 4; i++) {
            writePlayer(o, c.state.players[i]);
        }
        put(o, int32(c.state.mobjCount));
        for (uint32 i; i < c.state.mobjCount; i++) {
            Mobj memory m = c.state.mobjs[i];
            int32[31] memory row = [
                int32(m.mobjType),
                m.x,
                m.y,
                m.z,
                int32(m.angle),
                int32(m.sprite),
                int32(m.frame),
                m.floorz,
                m.ceilingz,
                m.radius,
                m.height,
                m.momx,
                m.momy,
                m.momz,
                m.tics,
                int32(m.state),
                int32(m.flags),
                m.health,
                m.movedir,
                m.movecount,
                int32(m.target),
                m.reactiontime,
                m.threshold,
                int32(m.player),
                m.lastlook,
                int32(m.tracer),
                int32(m.snext),
                int32(m.sprev),
                int32(m.bnext),
                int32(m.bprev),
                c.state.thinkers[m.thinker].status == C.THINKER_REMOVE ? int32(1) : int32(0)
            ];
            for (uint32 j; j < 31; j++) {
                put(o, row[j]);
            }
            writeThing(o, m.spawnpoint);
        }
        put(o, int32(c.state.sectors[0].thinglist));
        for (uint32 i; i < 256; i++) {
            put(o, int32(c.state.blockmap.heads[i]));
        }
        put(o, int32(c.state.deathmatchStartCount));
        for (uint32 i; i < 4; i++) {
            writeThing(o, c.state.playerstarts[i]);
        }
        for (uint32 i; i < 10; i++) {
            writeThing(o, c.state.deathmatchstarts[i]);
        }
        put(o, int32(c.state.iquehead));
        put(o, int32(c.state.iquetail));
        for (uint32 i; i < 128; i++) {
            put(o, c.state.itemrespawntime[i]);
            writeThing(o, c.state.itemrespawnque[i]);
        }
        put(o, int32(c.path.count));
        for (uint32 i; i < c.path.count * 6; i++) {
            put(o, int32(word(c.state.rejectmatrix, i * 4)));
        }
        data = o.data;
        uint32 length = o.cursor;
        assembly ("memory-safe") { mstore(data, length) }
    }

    function evaluate(uint32[14] calldata a) external view returns (bytes memory) {
        GameContext memory c = context(a);
        if (a[0] == 13) M.P_RemoveMobj(c, 2);
        int32 result;
        for (uint32 i; i < a[8]; i++) {
            result = invoke(c, a[0], a);
            c.state.leveltime++;
            c.state.gametic++;
        }
        return snapshot(c, result);
    }

    function runOperation(uint32 operation) internal view {
        bytes memory vectors = vm.readFileBinary("test/fixtures/phase3_lifecycle/vectors.bin");
        uint256 pos;
        uint32 index;
        while (pos < vectors.length) {
            uint32 words = word(vectors, pos);
            pos += 4;
            uint256 end = pos + uint256(words) * 4;
            require(end <= vectors.length && words >= 24, "record framing");
            if (word(vectors, pos) == operation) {
                uint32[14] memory a;
                for (uint32 i; i < 14; i++) {
                    a[i] = word(vectors, pos + i * 4);
                }
                bytes memory actual = this.evaluate(a);
                uint256 expectedBytes = (uint256(words) - 14) * 4;
                if (actual.length != expectedBytes) {
                    revert NativeMismatch(
                        index, a[0], type(uint32).max, uint32(actual.length), uint32(expectedBytes)
                    );
                }
                for (uint32 i; i < actual.length / 4; i++) {
                    if (word(actual, i * 4) != word(vectors, pos + 56 + i * 4)) {
                        revert NativeMismatch(
                            index, a[0], i, word(actual, i * 4), word(vectors, pos + 56 + i * 4)
                        );
                    }
                }
            }
            pos = end;
            index++;
        }
        require(pos == vectors.length && index == 784, "coverage count");
    }
}

contract PMobjLifecycleTest is LifecycleOracle {
    function testNative_P_SetMobjState() public view {
        runOperation(5);
    }

    function testNative_P_ExplodeMissile() public view {
        runOperation(6);
    }

    function testNative_P_XYMovement() public view {
        runOperation(7);
    }

    function testNative_P_ZMovement() public view {
        runOperation(8);
    }

    function testNative_P_NightmareRespawn() public view {
        runOperation(9);
    }

    function testNative_P_MobjThinker() public view {
        runOperation(10);
    }

    function testNative_P_SpawnMobj() public view {
        runOperation(11);
    }

    function testNative_P_RemoveMobj() public view {
        runOperation(12);
    }

    function testNative_P_RespawnSpecials() public view {
        runOperation(13);
    }

    function testNative_P_SpawnPlayer() public view {
        runOperation(14);
    }

    function testNative_P_SpawnMapThing() public view {
        runOperation(15);
    }

    function testNative_P_SpawnPuff() public view {
        runOperation(16);
    }

    function testNative_P_SpawnBlood() public view {
        runOperation(17);
    }

    function testNative_P_CheckMissileSpawn() public view {
        runOperation(18);
    }

    function testNative_P_SpawnMissile() public view {
        runOperation(19);
    }

    function testNative_P_SpawnPlayerMissile() public view {
        runOperation(20);
    }
}
