// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {CheatState, ST_Cheats} from "../../src/doom/st_cheats.sol";
import {GameContext, GameConst, GameSector, MobjInfo} from "../../src/doom/p_game_state.sol";
import {GameflowState} from "../../src/doom/g_game.sol";
import {P_User} from "../../src/doom/p_user.sol";
import {P_Inter} from "../../src/doom/p_inter.sol";
import {Subsector} from "../../src/doom/r_defs.sol";
import {CheatFixture} from "../../src/support/CheatFixture.sol";
import {CheatProbe} from "../../src/support/CheatProbe.sol";
import {ST_Stuff, STState, STGraphics} from "../../src/doom/st_stuff.sol";
import {HU_Stuff, HudState} from "../../src/doom/hu_stuff.sol";
import {V_Video} from "../../src/doom/v_video.sol";
import {VideoState} from "../../src/doom/v_video_types.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";

interface CheatsVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function toString(uint256) external pure returns (string memory);
    function etch(address, bytes calldata) external;
}

contract CheatsIntegrationTest {
    CheatsVm constant vm = CheatsVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function fresh() private pure returns (GameContext memory c) {
        c = CheatFixture.fresh([int32(0), 0, 4, 0, 1, 37, 29, 0]);
        c.state.sectors = new GameSector[](1);
        c.map.subsectors = new Subsector[](1);
        c.state.mobjs[0].ceilingz = 128 * 65536;
        c.state.mobjs[0].reactiontime = 10;
        c.state.players[0].readyweapon = 1;
        c.hooks.movePsprites = noPsprites;
    }
    function noPsprites(GameContext memory, uint32) internal pure {}

    function input(GameContext memory c, GameflowState memory f, CheatState memory s, string memory text)
        private
        pure
    {
        bytes memory b = bytes(text);
        for (uint256 i; i < b.length; ++i) {
            ST_Cheats.ST_Responder(c, f, s, 0, int32(uint32(uint8(b[i]))));
        }
    }

    function testCheatsReachDamageAndArmorConsumers() public view {
        GameContext memory c = fresh();
        GameflowState memory f;
        CheatState memory s;
        c.definitions.mobjinfo = new MobjInfo[](1);
        c.state.mobjs[0].flags = GameConst.MF_SHOOTABLE;
        input(c, f, s, "iddqd");
        P_Inter.P_DamageMobj(c, 0, GameConst.NULL, GameConst.NULL, 50);
        require(c.state.players[0].health == 100 && c.state.mobjs[0].health == 100);
        input(c, f, s, "iddqd idkfa");
        P_Inter.P_DamageMobj(c, 0, GameConst.NULL, GameConst.NULL, 20);
        require(c.state.players[0].health == 90 && c.state.mobjs[0].health == 90);
        require(c.state.players[0].armorpoints == 190 && c.state.players[0].weaponowned[8]);
        for (uint256 i; i < 6; ++i) {
            require(c.state.players[0].cards[i]);
        }
    }

    function testNoclipAppliesOnNextPlayerTic() public view {
        GameContext memory c = fresh();
        GameflowState memory f;
        CheatState memory s;
        input(c, f, s, "idclip");
        require(c.state.mobjs[0].flags & GameConst.MF_NOCLIP == 0);
        P_User.P_PlayerThink(c, 0);
        require(c.state.mobjs[0].flags & GameConst.MF_NOCLIP != 0);
        input(c, f, s, "idspispopd");
        P_User.P_PlayerThink(c, 0);
        require(c.state.mobjs[0].flags & GameConst.MF_NOCLIP == 0);
    }

    function testPowerOffAndChoppersExpireOnNextTic() public view {
        GameContext memory c = fresh();
        GameflowState memory f;
        CheatState memory s;
        input(c, f, s, "idbeholdi");
        require(c.state.mobjs[0].flags & GameConst.MF_SHADOW != 0);
        input(c, f, s, "idbeholdi idbeholdv idbeholdl idbeholdr idbeholda");
        require(c.state.players[0].powers[2] == 1 && c.state.mobjs[0].flags & GameConst.MF_SHADOW != 0);
        P_User.P_PlayerThink(c, 0);
        require(c.state.players[0].powers[2] == 0 && c.state.mobjs[0].flags & GameConst.MF_SHADOW == 0);
        require(c.state.players[0].fixedcolormap == 32);
        input(c, f, s, "idbeholdv idbeholdl idbeholdr idbeholda idchoppers");
        require(c.state.players[0].powers[0] == 1);
        P_User.P_PlayerThink(c, 0);
        require(
            c.state.players[0].powers[0] == 0 && c.state.players[0].powers[3] == 0
                && c.state.players[0].powers[5] == 0
        );
        require(
            c.state.players[0].powers[4] == 1 && c.state.players[0].fixedcolormap == 0
                && c.state.players[0].weaponowned[7]
        );
    }

    function eventBatch(string memory text) private pure returns (int32[4][] memory e) {
        bytes memory b = bytes(text);
        e = new int32[4][](b.length);
        for (uint256 i; i < b.length; ++i) {
            e[i] = [int32(0), int32(uint32(uint8(b[i]))), int32(1), int32(0)];
        }
    }

    function testPersistPrefixParamAndIndependentAutomapState() public {
        CheatProbe probe = new CheatProbe();
        probe.reset([int32(0), 0, 4, 0, 1, 37, 29, 0]);
        GameContext memory c = CheatFixture.fresh([int32(0), 0, 4, 0, 1, 37, 29, 0]);
        GameflowState memory f;
        CheatState memory s;
        string[4] memory chunks = ["idd", "qd idclev1", "9 idd", "t"];
        for (uint32 i; i < 4; ++i) {
            int32[4][] memory e = eventBatch(chunks[i]);
            probe.rawEvents(i + 1, e, false);
            for (uint256 j; j < e.length; ++j) {
                ST_Cheats.ST_Responder(c, f, s, 0, e[j][1]);
                ST_Cheats.AM_CheckCheat(s, 0, e[j][1], true, 0);
            }
            require(probe.observe() == sha256(CheatFixture.snapshot(c, f, s)));
        }
        require(c.state.players[0].health == 100 && f.deferredMap == 9 && s.automapCheating == 1);
    }

    function testRollbackIncludesParserEffectMessageAndInputSequence() public {
        CheatProbe probe = new CheatProbe();
        probe.reset([int32(0), 0, 4, 0, 1, 37, 29, 0]);
        probe.rawEvents(1, eventBatch("iddq"), false);
        bytes32 before = probe.observe();
        (bool ok,) = address(probe).call(abi.encodeCall(CheatProbe.rawEvents, (2, eventBatch("d"), true)));
        require(!ok && probe.inputSeq() == 1 && probe.observe() == before);
        probe.rawEvents(2, eventBatch("d"), false);
        require(probe.observe() != before);
        bytes32 afterHash = probe.observe();
        (ok,) = address(probe).call(abi.encodeCall(CheatProbe.rawEvents, (2, eventBatch("d"), false)));
        require(!ok && probe.inputSeq() == 2 && probe.observe() == afterHash);
    }

    function be32(bytes memory b, uint256 p) private pure returns (uint32 n) {
        for (uint256 i; i < 4; ++i) {
            n = (n << 8) | uint8(b[p + i]);
        }
    }

    function le32(bytes memory b, uint256 p) private pure returns (uint32 n) {
        for (uint256 i; i < 4; ++i) {
            n |= uint32(uint8(b[p + i])) << uint32(i * 8);
        }
    }

    function digest(bytes memory b, uint256 p) private pure returns (bytes32 h) {
        assembly ("memory-safe") { h := mload(add(add(b, 32), p)) }
    }

    function statusResources() private returns (ResourceView memory r) {
        bytes memory blob = vm.readFileBinary("test/fixtures/phase4_statusbar/resources.bin");
        bytes memory dir = vm.readFileBinary("test/fixtures/phase4_statusbar/directory.bin");
        r.byteLength = uint32(blob.length);
        r.chunks = new address[]((blob.length + 16383) / 16384);
        for (uint256 i; i < r.chunks.length; ++i) {
            uint256 n = blob.length - i * 16384;
            if (n > 16384) n = 16384;
            bytes memory code = new bytes(n + 1);
            for (uint256 j; j < n; ++j) {
                code[j + 1] = blob[i * 16384 + j];
            }
            r.chunks[i] = address(uint160(0x440000 + i));
            vm.etch(r.chunks[i], code);
        }
        r.lumps = new LumpDescriptor[](dir.length / 16);
        for (uint256 i; i < r.lumps.length; ++i) {
            bytes8 name;
            uint256 pos = i * 16;
            assembly ("memory-safe") { name := mload(add(add(dir, 32), pos)) }
            r.lumps[i] = LumpDescriptor(name, le32(dir, pos + 8), le32(dir, pos + 12));
        }
    }

    function testNativeRawCheatsRenderStatusPaletteAndHud() public {
        GameContext memory c = fresh();
        GameflowState memory f;
        CheatState memory s;
        int32[9] memory ammo = [int32(5), 0, 1, 0, 3, 2, 2, 5, 1];
        for (uint256 i; i < 9; ++i) {
            c.definitions.weaponinfo[i].ammo = ammo[i];
        }
        VideoState memory v;
        V_Video.V_Init(v);
        STState memory st;
        STGraphics memory a;
        ST_Stuff.ST_Init(st, v, a, statusResources(), 0);
        for (uint256 i; i < 64000; ++i) {
            v.screens[0][i] = bytes1(uint8(i * 13 + (i / 320) * 7 + 19));
        }
        ST_Stuff.ST_Start(st, a, c.state, c.definitions);
        bytes[] memory font = new bytes[](63);
        for (uint256 i; i < 63; ++i) {
            font[i] = vm.readFileBinary(
                string.concat("test/fixtures/phase4_hud/STCFN0", vm.toString(i + 33), ".bin")
            );
        }
        HudState memory h;
        HU_Stuff.HU_Start(h, font, 1, 1, 1);
        bytes memory golden = vm.readFileBinary("test/fixtures/phase4_cheats/presentation.bin");
        uint256 count = be32(golden, 0);
        uint256 at = 4;
        for (uint256 row; row < count; ++row) {
            uint256 n = be32(golden, at);
            at += 4;
            bytes memory code = new bytes(n);
            for (uint256 i; i < n; ++i) {
                code[i] = golden[at + i];
            }
            at += n;
            input(c, f, s, string(code));
            ST_Stuff.ST_Ticker(st, c.state, c.definitions);
            ST_Stuff.ST_Drawer(st, a, v, c.state, c.definitions, false, false, false);
            HU_Stuff.HU_Ticker(h, c.state.players[0], true);
            HU_Stuff.HU_Drawer(h, v, false);
            require(
                sha256(v.screens[0]) == digest(golden, at),
                string.concat("native combined pixels ", vm.toString(row))
            );
            require(sha256(v.screens[4]) == digest(golden, at + 32), "native status background");
            require(sha256(st.paletteRGB) == digest(golden, at + 64), "native palette");
            require(
                uint32(st.st_faceindex) == be32(golden, at + 96)
                    && uint32(st.st_palette) == be32(golden, at + 100),
                "native status state"
            );
            at += 104;
            require(bytes(c.state.players[0].message).length == 0 && h.message.on && h.message_counter == 140);
        }
        require(at == golden.length);
    }
}
