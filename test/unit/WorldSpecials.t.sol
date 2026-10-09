// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {P_Spec} from "../../src/doom/p_spec.sol";
import {P_Switch} from "../../src/doom/p_switch.sol";
import {P_Telept} from "../../src/doom/p_telept.sol";
import {P_Info} from "../../src/doom/p_info.sol";
import {
    GameContext,
    GameSector,
    Mobj,
    Thinker,
    ThinkerKind,
    Animation,
    Button,
    ButtonWhere,
    GameConst as C
} from "../../src/doom/p_game_state.sol";
import {Sector, Side, Line, Subsector} from "../../src/doom/r_defs.sol";
import {Texture} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
import {WorldFixtureBase, WorldWords} from "./WorldActions.t.sol";
import {P_Tick} from "../../src/doom/p_tick.sol";

interface VmWorldSpecials {
    function readFileBinary(string calldata path) external view returns (bytes memory);
}

contract WorldSpecials_Test is WorldFixtureBase {
    VmWorldSpecials constant vm = VmWorldSpecials(address(uint160(uint256(keccak256("hevm cheat code")))));
    error NativeSpecialMismatch(uint32 row, uint32 op, uint32 offset, uint32 actual, uint32 expected);

    struct Proof {
        bytes data;
        uint256 p;
        uint32 row;
        uint32 op;
        uint32 ni;
        uint32 no;
        int32[] args;
        uint32[] actual;
        uint32 count;
    }

    function word(bytes memory b, uint256 p) internal pure returns (uint32 n) {
        for (uint256 i; i < 4; i++) {
            n = (n << 8) | uint8(b[p + i]);
        }
    }

    function bytesName(bytes memory b, uint256 p) private pure returns (bytes8 name) {
        uint64 n;
        for (uint256 i; i < 8; i++) {
            n = (n << 8) | uint8(b[p + i]);
        }
        return bytes8(n);
    }

    function setup() private pure returns (GameContext memory c) {
        c.map.sectors = new Sector[](4);
        c.map.lines = new Line[](3);
        c.map.sides = new Side[](6);
        c.map.subsectors = new Subsector[](2);
        c.state.sectors = new GameSector[](4);
        for (uint32 i; i < 4; i++) {
            c.map.sectors[i].floorheight = int32(i) * 16 * 65536;
            c.map.sectors[i].ceilingheight = (128 + int32(i) * 16) * 65536;
            c.map.sectors[i].lightlevel = int16(128 + int32(i) * 16);
            c.state.sectors[i].specialdata = C.NULL;
        }
        c.state.sectors[0].tag = 7;
        c.state.sectors[1].tag = -2;
        c.state.sectors[2].tag = 7;
        for (uint32 i; i < 3; i++) {
            Line memory l = c.map.lines[i];
            l.frontsector = i;
            l.backsector = i + 1;
            l.flags = 4;
            l.sidenum[0] = i * 2;
            l.sidenum[1] = i * 2 + 1;
            c.map.sides[i * 2].sector = i;
            c.map.sides[i * 2 + 1].sector = i + 1;
        }
        c.state.sectors[0].lines = new uint32[](1);
        c.state.sectors[0].lines[0] = 0;
        c.state.sectors[1].lines = new uint32[](2);
        c.state.sectors[1].lines[0] = 0;
        c.state.sectors[1].lines[1] = 1;
        c.state.sectors[2].lines = new uint32[](2);
        c.state.sectors[2].lines[0] = 1;
        c.state.sectors[2].lines[1] = 2;
        c.state.sectors[3].lines = new uint32[](1);
        c.state.sectors[3].lines[0] = 2;
        c.map.lines[0].tag = 7;
        c.map.subsectors[0].sector = 0;
        c.map.subsectors[1].sector = 1;
        c.state.mobjs = new Mobj[](8);
        c.state.mobjCount = 4;
        c.state.mobjs[0].player = 0;
        c.state.mobjs[0].health = 100;
        c.state.players[0].mo = 0;
        c.state.players[0].health = 100;
        c.state.players[0].viewheight = 41 * 65536;
        c.state.texturetranslation = new uint32[](256);
        c.state.flattranslation = new uint32[](256);
        for (uint32 i; i < 256; i++) {
            c.state.texturetranslation[i] = i;
            c.state.flattranslation[i] = i;
        }
        c.resources.texturetranslation = c.state.texturetranslation;
        c.resources.flattranslation = c.state.flattranslation;
        c.resources.spritewidth = new int32[](128); // Test-only callback record buffer, not sprite geometry.
        c.hooks.damageMobj = damage;
        c.hooks.teleportMove = teleportMove;
        c.hooks.spawnMobj = spawnFog;
        for (uint256 i; i < 16; i++) {
            c.state.buttons[i] = Button(C.NULL, ButtonWhere.top, 0, 0, C.NULL);
        }
        c.state.map = c.map;
    }

    function names(GameContext memory c, int32 mask) private view {
        bytes memory b = vm.readFileBinary("test/fixtures/phase3_specials/names.bin");
        uint256 textures = 119;
        uint256 flats = 27;
        require(b.length == (textures + flats) * 8, "names corpus");
        c.resources.textures = new Texture[](textures);
        c.resources.source.lumps = new LumpDescriptor[](flats);
        for (uint256 i; i < textures; i++) {
            bytes8 name = bytesName(b, i * 8);
            if (!(mask == 1 && name == "BLODGR1")) c.resources.textures[i].name = name;
        }
        for (uint256 i; i < flats; i++) {
            bytes8 name = bytesName(b, (textures + i) * 8);
            if (!(mask == 2 && name == "NUKAGE1")) c.resources.source.lumps[i].name = name;
        }
    }

    function logcall(GameContext memory c, int32 op, int32 a, int32 b, int32 d, int32 e) private pure {
        uint32 p = c.resources.numspritelumps;
        c.resources.spritewidth[p] = op;
        c.resources.spritewidth[p + 1] = a;
        c.resources.spritewidth[p + 2] = b;
        c.resources.spritewidth[p + 3] = d;
        c.resources.spritewidth[p + 4] = e;
        c.resources.numspritelumps = p + 5;
    }

    function damage(GameContext memory c, uint32 actor, uint32 inflictor, uint32 source, int32 amount)
        private
        pure
    {
        logcall(c, 1, int32(actor), int32(inflictor), int32(source), amount);
        c.state.mobjs[actor].health -= amount;
        if (c.state.mobjs[actor].player != C.NULL) {
            c.state.players[c.state.mobjs[actor].player].health -= amount;
        }
    }

    function teleportMove(GameContext memory c, uint32 actor, int32 x, int32 y) private pure returns (bool) {
        logcall(c, 2, int32(actor), x, y, 0);
        if (c.resources.firstspritelump == 1) return false;
        c.state.mobjs[actor].x = x;
        c.state.mobjs[actor].y = y;
        c.state.mobjs[actor].floorz = c.map.sectors[1].floorheight;
        c.state.mobjs[actor].subsector = 1;
        return true;
    }

    function spawnFog(GameContext memory c, int32 x, int32 y, int32 z, uint32 kind)
        private
        pure
        returns (uint32 id)
    {
        id = c.state.mobjCount++;
        c.state.mobjs[id].x = x;
        c.state.mobjs[id].y = y;
        c.state.mobjs[id].z = z;
        c.state.mobjs[id].mobjType = kind;
        logcall(c, 3, x, y, z, int32(kind));
    }

    function buttonSnapshot(GameContext memory c, uint32[] memory actual, uint32 p)
        private
        pure
        returns (uint32)
    {
        for (uint32 i; i < 16; i++) {
            Button memory b = c.state.buttons[i];
            actual[p++] = uint32(b.btimer);
            actual[p++] = b.line;
            actual[p++] = uint32(b.where);
            actual[p++] = uint32(b.btexture);
            actual[p++] = b.soundsector;
        }
        return p;
    }

    function evaluate(Proof memory f) private view {
        GameContext memory c = setup();
        f.actual = new uint32[](2048);
        uint32 p;
        if (f.op == 0) {
            for (uint32 i; i < 4; i++) {
                c.map.sectors[i].floorheight = f.args[i];
                c.map.sectors[i].ceilingheight = f.args[4 + i];
                c.map.sectors[i].lightlevel = int16(f.args[8 + i]);
            }
            for (uint32 i; i < 3; i++) {
                c.map.lines[i].flags = uint16(uint32(f.args[12 + i]));
            }
            uint32 sector = uint32(f.args[17]);
            f.actual[p++] = uint32(P_Spec.P_FindLowestFloorSurrounding(c, sector));
            f.actual[p++] = uint32(P_Spec.P_FindHighestFloorSurrounding(c, sector));
            f.actual[p++] = uint32(P_Spec.P_FindNextHighestFloor(c, sector, f.args[15]));
            f.actual[p++] = uint32(P_Spec.P_FindLowestCeilingSurrounding(c, sector));
            f.actual[p++] = uint32(P_Spec.P_FindHighestCeilingSurrounding(c, sector));
            f.actual[p++] = uint32(P_Spec.P_FindMinSurroundingLight(c, sector, f.args[18]));
            f.actual[p++] = P_Spec.getNextSector(c, 0, 1);
            f.actual[p++] = P_Spec.getSide(c, 1, 1, 1);
            f.actual[p++] = P_Spec.getSector(c, 1, 1, 1);
            f.actual[p++] = uint32(P_Spec.twoSided(c, 1, 1));
            f.actual[p++] = uint32(P_Spec.P_FindSectorFromLineTag(c, 0, f.args[16]));
        } else if (f.op == 1 || f.op == 2) {
            c.state.switchlist = new int32[](7);
            c.state.switchlist[0] = 10;
            c.state.switchlist[1] = 11;
            c.state.switchlist[2] = 20;
            c.state.switchlist[3] = 21;
            c.state.switchlist[4] = 30;
            c.state.switchlist[5] = 31;
            c.state.switchlist[6] = -1;
            c.state.numswitches = 3;
            if (f.op == 1) {
                c.map.sides[0].toptexture = uint32(f.args[0]);
                c.map.sides[0].midtexture = uint32(f.args[1]);
                c.map.sides[0].bottomtexture = uint32(f.args[2]);
                c.map.lines[0].special = int16(f.args[4]);
                P_Switch.P_ChangeSwitchTexture(c, 0, f.args[3]);
            } else {
                if (f.args[0] == 0) P_Switch.P_StartButton(c, 0, ButtonWhere.bottom, 30, 7);
                P_Switch.P_StartButton(c, 0, ButtonWhere.top, 10, 35);
            }
            f.actual[p++] = uint32(int32(c.map.lines[0].special));
            f.actual[p++] = c.map.sides[0].toptexture;
            f.actual[p++] = c.map.sides[0].midtexture;
            f.actual[p++] = c.map.sides[0].bottomtexture;
            p = buttonSnapshot(c, f.actual, p);
        } else if (f.op == 3) {
            c.state.leveltime = f.args[0];
            c.state.levelTimer = f.args[1] != 0;
            c.state.levelTimeCount = f.args[2];
            c.state.animations = new Animation[](2);
            c.state.animations[0] = Animation(false, 4, 2, 3, 8);
            c.state.animations[1] = Animation(true, 5, 4, 2, 8);
            c.map.lines[0].special = 48;
            c.state.scrollingLines = new uint32[](1);
            c.map.sides[0].toptexture = 11;
            c.map.sides[0].midtexture = 21;
            c.state.buttons[0] = Button(0, ButtonWhere.top, 10, 35, 0);
            c.state.buttons[1] = Button(0, ButtonWhere.middle, 20, 1, 0);
            P_Spec.P_UpdateSpecials(c);
            f.actual[p++] = uint32(c.state.gameaction);
            f.actual[p++] = c.state.secretExit ? 1 : 0;
            f.actual[p++] = uint32(c.state.levelTimeCount);
            for (uint32 i; i < 16; i++) {
                f.actual[p++] = c.state.texturetranslation[i];
            }
            for (uint32 i; i < 16; i++) {
                f.actual[p++] = c.state.flattranslation[i];
            }
            f.actual[p++] = uint32(c.map.sides[0].textureoffset);
            f.actual[p++] = c.map.sides[0].toptexture;
            f.actual[p++] = c.map.sides[0].midtexture;
            f.actual[p++] = c.map.sides[0].bottomtexture;
            p = buttonSnapshot(c, f.actual, p);
            require(
                c.resources.texturetranslation[4] == c.state.texturetranslation[4], "persistent texture alias"
            );
            require(c.resources.flattranslation[2] == c.state.flattranslation[2], "persistent flat alias");
        } else if (f.op == 4) {
            names(c, f.args[0]);
            P_Spec.P_InitPicAnims(c);
            f.actual[p++] = uint32(c.state.animations.length);
            for (uint32 i; i < c.state.animations.length; i++) {
                Animation memory a = c.state.animations[i];
                f.actual[p++] = a.istexture ? 1 : 0;
                f.actual[p++] = uint32(a.picnum);
                f.actual[p++] = uint32(a.basepic);
                f.actual[p++] = uint32(a.numpics);
                f.actual[p++] = uint32(a.speed);
            }
        } else if (f.op == 5) {
            names(c, 0);
            c.state.gamemode = f.args[0];
            P_Switch.P_InitSwitchList(c);
            f.actual[p++] = uint32(c.state.numswitches);
            for (uint32 i; i < c.state.switchlist.length; i++) {
                f.actual[p++] = uint32(c.state.switchlist[i]);
            }
        } else if (f.op == 6) {
            c.state.sectors[0].special = int16(f.args[0]);
            c.state.players[0].powers[3] = f.args[1];
            c.state.leveltime = f.args[2];
            c.state.prndindex = uint32(f.args[3]);
            c.state.players[0].health = f.args[4];
            c.state.mobjs[0].health = f.args[4];
            c.state.mobjs[0].z = f.args[5] != 0 ? int32(65536) : int32(0);
            c.state.players[0].cheats = 2;
            P_Spec.P_PlayerInSpecialSector(c, 0);
            f.actual[p++] = uint32(c.state.mobjs[0].health);
            f.actual[p++] = uint32(c.state.players[0].health);
            f.actual[p++] = uint32(c.state.players[0].secretcount);
            f.actual[p++] = uint32(int32(c.state.sectors[0].special));
            f.actual[p++] = uint32(c.state.players[0].cheats);
            f.actual[p++] = uint32(c.state.gameaction);
            f.actual[p++] = c.state.secretExit ? 1 : 0;
            f.actual[p++] = c.state.prndindex;
            f.actual[p++] = c.resources.numspritelumps;
            for (uint32 i; i < c.resources.numspritelumps; i++) {
                f.actual[p++] = uint32(c.resources.spritewidth[i]);
            }
        } else if (f.op == 7) {
            int32 v = f.args[0];
            c.state.sectors[0].tag = 0;
            c.state.sectors[1].tag = 7;
            c.map.lines[0].tag = v == 6 ? int16(999) : int16(7);
            Mobj memory actor = c.state.mobjs[0];
            actor.x = 10 * 65536;
            actor.y = 20 * 65536;
            actor.z = 8 * 65536;
            actor.momx = 3 * 65536;
            actor.momy = 4 * 65536;
            actor.momz = 5 * 65536;
            actor.reactiontime = 5;
            actor.flags = v == 1 ? C.MF_MISSILE : 0;
            if (v == 4) actor.player = C.NULL;
            for (uint32 i = 1; i < 4; i++) {
                Mobj memory marker = c.state.mobjs[i];
                marker.mobjType = P_Info.MT_TELEPORTMAN;
                marker.subsector = i == 2 ? 0 : 1;
                marker.x = int32(i) * 128 * 65536;
                marker.y = 32 * 65536;
                marker.angle = i == 1 ? uint32(0x40000000) : uint32(0x80000000);
            }
            c.state.thinkers = new Thinker[](5);
            c.state.thinkerCount = 5;
            uint32[4] memory order = [uint32(1), uint32(3), uint32(2), uint32(4)];
            c.state.thinkers[0].next = order[0];
            c.state.thinkers[0].prev = order[3];
            for (uint32 i; i < 4; i++) {
                Thinker memory t = c.state.thinkers[order[i]];
                t.prev = i == 0 ? 0 : order[i - 1];
                t.next = i == 3 ? 0 : order[i + 1];
                t.kind = ThinkerKind.mobj;
                t.payload = order[i] - 1;
            }
            if (v == 5) c.state.thinkers[2].status = C.THINKER_REMOVE;
            if (v == 7) c.state.thinkers[2].status = C.THINKER_STASIS;
            c.resources.firstspritelump = v == 3 ? 1 : 0;
            f.actual[p++] = uint32(P_Telept.EV_Teleport(c, 0, v == 2 ? int32(1) : int32(0), 0));
            f.actual[p++] = uint32(actor.x);
            f.actual[p++] = uint32(actor.y);
            f.actual[p++] = uint32(actor.z);
            f.actual[p++] = actor.angle;
            f.actual[p++] = uint32(actor.momx);
            f.actual[p++] = uint32(actor.momy);
            f.actual[p++] = uint32(actor.momz);
            f.actual[p++] = uint32(actor.reactiontime);
            f.actual[p++] = uint32(c.state.players[0].viewz);
            f.actual[p++] = c.state.mobjCount;
            f.actual[p++] = c.resources.numspritelumps;
            for (uint32 i; i < c.resources.numspritelumps; i++) {
                f.actual[p++] = uint32(c.resources.spritewidth[i]);
            }
        } else if (f.op == 8) {
            c.map.sectors = new Sector[](26);
            c.map.lines = new Line[](25);
            c.state.sectors = new GameSector[](26);
            c.state.sectors[0].lines = new uint32[](25);
            for (uint32 i; i < 25; i++) {
                c.map.lines[i].flags = 4;
                c.map.lines[i].frontsector = 0;
                c.map.lines[i].backsector = i + 1;
                c.state.sectors[0].lines[i] = i;
                c.map.sectors[i + 1].floorheight = (100 - int32(i)) * 65536;
            }
            c.map.sectors[21].floorheight = 65536;
            f.actual[p++] = uint32(P_Spec.P_FindNextHighestFloor(c, 0, 0));
        } else {
            revert("native special op");
        }
        f.count = p;
    }

    function checkRows(uint32 first, uint32 last) private view {
        Proof memory f;
        f.data = vm.readFileBinary("test/fixtures/phase3_specials/vectors.bin");
        require(word(f.data, 0) == 416, "native special count");
        f.p = 4;
        uint32 checked;
        for (f.row = 0; f.row < 416; f.row++) {
            f.op = word(f.data, f.p);
            f.ni = word(f.data, f.p + 4);
            f.no = word(f.data, f.p + 8);
            f.p += 12;
            if (f.row < first || f.row >= last) {
                f.p += (f.ni + f.no) * 4;
                continue;
            }
            f.args = new int32[](f.ni);
            for (uint32 i; i < f.ni; i++) {
                f.args[i] = int32(word(f.data, f.p));
                f.p += 4;
            }
            evaluate(f);
            require(f.count == f.no, "special serializer length");
            for (uint32 i; i < f.no; i++) {
                uint32 expected = word(f.data, f.p);
                f.p += 4;
                if (f.actual[i] != expected) {
                    revert NativeSpecialMismatch(f.row, f.op, i, f.actual[i], expected);
                }
            }
            checked++;
        }
        require(checked == last - first && f.p == f.data.length, "special coverage consumed");
    }

    function testOriginalNeighborHelpersA() public view {
        checkRows(0, 80);
    }

    function testOriginalNeighborHelpersB() public view {
        checkRows(80, 160);
    }

    function testOriginalNeighborHelpersC() public view {
        checkRows(160, 240);
    }

    function testOriginalSwitchButtonsAndAnimations() public view {
        checkRows(240, 309);
    }

    function testOriginalPlayerSectorPowersDamageSecretsExit() public view {
        checkRows(309, 407);
    }

    function testOriginalTeleportCallbacksAndAdjacencyCap() public view {
        checkRows(407, 416);
    }

    struct DispatchCase {
        GameContext context;
        WorldWords buffer;
        uint32[8] input;
        bytes expected;
        uint32 snapshot;
        int32 result;
    }
    error DispatchMismatch(
        uint32 op,
        uint32 special,
        uint32 actor,
        uint32 side,
        uint32 snapshot,
        bool overlay,
        bytes32 actual,
        bytes32 expected
    );

    function digest(bytes memory data, uint256 p) private pure returns (bytes32 value) {
        require(p + 32 <= data.length, "dispatch digest bounds");
        assembly ("memory-safe") { value := mload(add(add(data, 32), p)) }
    }

    function overlayHash(GameContext memory c, WorldWords memory b) private pure returns (bytes32) {
        bytes memory data = b.data;
        assembly ("memory-safe") { mstore(data, 8192) }
        b.cursor = 0;
        _put(b, uint32(c.state.gameaction));
        _put(b, c.state.secretExit ? 1 : 0);
        _put(b, uint32(c.state.totalsecret));
        _put(b, c.state.levelTimer ? 1 : 0);
        _put(b, uint32(c.state.levelTimeCount));
        _put(b, uint32(c.state.numswitches));
        for (uint32 i; i < c.state.switchlist.length; i++) {
            _put(b, uint32(c.state.switchlist[i]));
        }
        for (uint32 i; i < 6; i++) {
            Side memory s = c.map.sides[i];
            _put(b, uint32(s.textureoffset));
            _put(b, uint32(s.rowoffset));
            _put(b, s.toptexture);
            _put(b, s.midtexture);
            _put(b, s.bottomtexture);
        }
        for (uint32 i; i < 16; i++) {
            Button memory button = c.state.buttons[i];
            _put(b, uint32(button.btimer));
            _put(b, button.line);
            _put(b, uint32(button.where));
            _put(b, uint32(button.btexture));
            _put(b, button.soundsector);
        }
        _put(b, uint32(c.state.scrollingLines.length));
        for (uint32 i; i < c.state.scrollingLines.length; i++) {
            _put(b, c.state.scrollingLines[i]);
        }
        uint256 size = b.cursor;
        assembly ("memory-safe") { mstore(data, size) }
        return sha256(data);
    }

    function dispatchCheck(DispatchCase memory f) private pure {
        bytes32 actual = _worldHash(f.context, f.result, f.buffer);
        bytes32 expected = digest(f.expected, uint256(f.snapshot) * 64);
        if (actual != expected) {
            revert DispatchMismatch(
                f.input[0], f.input[1], f.input[3], f.input[7], f.snapshot, false, actual, expected
            );
        }
        actual = overlayHash(f.context, f.buffer);
        expected = digest(f.expected, uint256(f.snapshot) * 64 + 32);
        if (actual != expected) {
            revert DispatchMismatch(
                f.input[0], f.input[1], f.input[3], f.input[7], f.snapshot, true, actual, expected
            );
        }
    }

    // An external per-case boundary releases fixture scratch between scenarios; engine remains memory-only.
    function runDispatchCase(uint32[8] memory input, bytes memory expected) external view {
        DispatchCase memory f;
        f.context = _worldContext();
        f.buffer.data = new bytes(8192);
        f.input = input;
        f.expected = expected;
        _worldSetup(f.context, input);
        GameContext memory c = f.context;
        c.state.gameaction = 0;
        c.state.mobjs[0].mobjType =
            input[3] == 2 ? P_Info.MT_ROCKET : input[3] != 0 ? P_Info.MT_POSSESSED : P_Info.MT_PLAYER;
        c.state.switchlist = new int32[](3);
        c.state.switchlist[0] = 0;
        c.state.switchlist[1] = 1;
        c.state.switchlist[2] = -1;
        c.state.numswitches = 1;
        for (uint32 i; i < 16; i++) {
            c.state.buttons[i] = Button(C.NULL, ButtonWhere.top, 0, 0, C.NULL);
        }
        if (input[0] == 3) {
            c.state.sectors[0].special = int16(uint16(input[1]));
            for (uint32 i; i < 3; i++) {
                c.map.lines[i].special = 48;
            }
        }
        if (input[0] == 4 && input[3] != 0) c.state.sectors[0].specialdata = 0;
        if (input[0] == 0) {
            P_Spec.P_CrossSpecialLine(c, 0, int32(input[7]), 0);
        } else if (input[0] == 1) {
            P_Spec.P_ShootSpecialLine(c, 0, 0);
        } else if (input[0] == 2) {
            f.result = P_Switch.P_UseSpecialLine(c, 0, 0, int32(input[7])) ? int32(1) : int32(0);
        } else if (input[0] == 3) {
            P_Spec.P_SpawnSpecials(c);
        } else if (input[0] == 4) {
            f.result = P_Spec.EV_DoDonut(c, 0);
        } else {
            revert("dispatch operation");
        }
        dispatchCheck(f);
        for (uint32 tick; tick < input[6]; tick++) {
            c.state.leveltime = int32(tick);
            P_Tick.P_RunThinkers(c);
            P_Spec.P_UpdateSpecials(c);
            f.snapshot = tick + 1;
            dispatchCheck(f);
        }
    }

    function dispatchBatch(uint32 operation, uint32 first, uint32 last) private view {
        bytes memory data = vm.readFileBinary("test/fixtures/phase3_specials/dispatch-vectors.bin");
        uint32 count = word(data, 0);
        require(count == 1007, "dispatch count");
        uint256 p = 4;
        uint32 selected;
        for (uint32 row; row < count; row++) {
            uint32[8] memory input;
            for (uint32 i; i < 8; i++) {
                input[i] = word(data, p + uint256(i) * 4);
            }
            uint32 snapshots = word(data, p + 32);
            p += 36;
            require(snapshots == input[6] + 1, "dispatch snapshots");
            uint256 length = uint256(snapshots) * 64;
            require(p + length <= data.length, "dispatch record bounds");
            if (input[0] == operation && input[1] >= first && input[1] < last) {
                bytes memory expected = new bytes(length);
                uint256 offset = p;
                assembly ("memory-safe") { mcopy(add(expected, 32), add(add(data, 32), offset), length) }
                this.runDispatchCase(input, expected);
                selected++;
            }
            p += length;
        }
        require(p == data.length && selected != 0, "dispatch fixture coverage");
    }

    function testOriginalCrossSpecials0To19() public view {
        dispatchBatch(0, 0, 20);
    }

    function testOriginalCrossSpecials20To39() public view {
        dispatchBatch(0, 20, 40);
    }

    function testOriginalCrossSpecials40To59() public view {
        dispatchBatch(0, 40, 60);
    }

    function testOriginalCrossSpecials60To79() public view {
        dispatchBatch(0, 60, 80);
    }

    function testOriginalCrossSpecials80To99() public view {
        dispatchBatch(0, 80, 100);
    }

    function testOriginalCrossSpecials100To119() public view {
        dispatchBatch(0, 100, 120);
    }

    function testOriginalCrossSpecials120To139() public view {
        dispatchBatch(0, 120, 140);
    }

    function testOriginalCrossSpecials140To145() public view {
        dispatchBatch(0, 140, 146);
    }

    function testOriginalUseSpecials0To19() public view {
        dispatchBatch(2, 0, 20);
    }

    function testOriginalUseSpecials20To39() public view {
        dispatchBatch(2, 20, 40);
    }

    function testOriginalUseSpecials40To59() public view {
        dispatchBatch(2, 40, 60);
    }

    function testOriginalUseSpecials60To79() public view {
        dispatchBatch(2, 60, 80);
    }

    function testOriginalUseSpecials80To99() public view {
        dispatchBatch(2, 80, 100);
    }

    function testOriginalUseSpecials100To119() public view {
        dispatchBatch(2, 100, 120);
    }

    function testOriginalUseSpecials120To139() public view {
        dispatchBatch(2, 120, 140);
    }

    function testOriginalUseSpecials140To145() public view {
        dispatchBatch(2, 140, 146);
    }

    function testOriginalShootSpecialsAll() public view {
        dispatchBatch(1, 0, 146);
    }

    function testOriginalSpawnSectorSpecialsAll() public view {
        dispatchBatch(3, 0, 18);
    }

    function testOriginalDonutThinkerCreationAndBusySector() public view {
        dispatchBatch(4, 0, 1);
    }
}
