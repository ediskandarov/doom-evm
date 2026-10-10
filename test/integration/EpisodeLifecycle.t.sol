// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {EpisodeStartup} from "../../src/evm/EpisodeStartup.sol";
import {EpisodeRuntime, EpisodeState} from "../../src/evm/EpisodeRuntime.sol";
import {InputProtocol, InputRuntimeState} from "../../src/evm/InputProtocol.sol";
import {DoomUI, UIState} from "../../src/evm/DoomUI.sol";
import {GameContext, GameConst, PlayerState} from "../../src/doom/p_game_state.sol";
import {GameflowState, G_Game} from "../../src/doom/g_game.sol";
import {P_Inter} from "../../src/doom/p_inter.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {ResourceIdentity, LumpDescriptor} from "../../src/evm/ResourceTypes.sol";

interface CompletionVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function etch(address, bytes calldata) external;
    function toString(uint256) external pure returns (string memory);
}

contract EpisodeLifecycleTest {
    CompletionVm constant vm = CompletionVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function setUp() public {
        for (uint256 i; i < 1755; ++i) {
            this.install(i);
        }
    }

    function install(uint256 i) external {
        vm.etch(
            address(uint160(0x100000 + i)),
            vm.readFileBinary(string.concat("artifacts/local/wad/phase2-chunks/", vm.toString(i), ".bin"))
        );
    }

    function source() private view returns (ResourceView memory v) {
        v.identity = ResourceIdentity(
            0,
            0x7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d,
            0xd379076f21645cf7cc5acb056663d0faacc4065489a0ca99738479323c9f7a47,
            0xfd895921b5d0a394612bb29852ed003d44d69f76dec31c0dc6b5d5fc7d63f7bb,
            0
        );
        v.byteLength = 28741889;
        v.chunks = new address[](1755);
        for (uint256 i; i < v.chunks.length; ++i) {
            v.chunks[i] = address(uint160(0x100000 + i));
        }
        bytes memory directory = vm.readFileBinary("test/fixtures/phase2_data/directory.bin");
        v.lumps = new LumpDescriptor[](3163);
        for (uint256 i; i < v.lumps.length; ++i) {
            uint256 p = i * 16;
            bytes8 name;
            // Each record owns16 bytes and name occupies its first8 bytes.
            assembly ("memory-safe") { name := mload(add(add(directory, 32), p)) }
            v.lumps[i] = LumpDescriptor(name, le32(directory, p + 8), le32(directory, p + 12));
        }
    }

    function le32(bytes memory data, uint256 p) private pure returns (uint32) {
        return uint32(uint8(data[p])) | uint32(uint8(data[p + 1])) << 8 | uint32(uint8(data[p + 2])) << 16
            | uint32(uint8(data[p + 3])) << 24;
    }

    function testOriginalDamageDeathUseAndFollowingTicReload() public {
        (GameContext memory c, GameflowState memory f) =
            EpisodeStartup.initialize(source(), 1, 1, 2, false, true);
        UIState memory u;
        DoomUI.initialize(u, c, false);
        InputRuntimeState memory s;
        InputProtocol.initialize(s);
        s.flow = f;
        EpisodeState memory e;
        EpisodeRuntime.saveDifficulty(c, e);
        EpisodeRuntime.tick(c, s, u, e, hex"");
        P_Inter.P_DamageMobj(c, c.state.players[0].mo, GameConst.NULL, GameConst.NULL, 10000);
        require(c.state.players[0].playerstate == PlayerState.dead, "original lethal damage");
        EpisodeRuntime.tick(c, s, u, e, hex"0020");
        require(c.state.players[0].playerstate == PlayerState.reborn, "original dead-use defers rebirth");
        require(c.state.leveltime == 2, "death-use does not reload immediately");
        EpisodeRuntime.tick(c, s, u, e, hex"0120");
        require(
            c.state.players[0].playerstate == PlayerState.live && c.state.players[0].health == 100,
            "next original G_Ticker reloads"
        );
        require(
            c.state.leveltime == 1 && c.state.gametic == 3 && c.state.gamemap == 1,
            "one world ticker after reload"
        );
        require(s.gamekeydown == 0 && u.status.st_clock == 1, "held keys clear and UI restarts");
    }

    function testNightmareDefinitionHistoryAcrossReloadedContext() public {
        (GameContext memory c, GameflowState memory f) =
            EpisodeStartup.initialize(source(), 1, 1, 4, false, true);
        UIState memory u;
        DoomUI.initialize(u, c, false);
        InputRuntimeState memory s;
        InputProtocol.initialize(s);
        s.flow = f;
        EpisodeState memory e;
        EpisodeRuntime.saveDifficulty(c, e);
        G_Game.G_DeferedInitNew(c.state, s.flow, 2, 1, 2);
        EpisodeRuntime.tick(c, s, u, e, hex"");
        require(c.state.gameskill == 2 && c.state.gamemap == 2, "new skill and map");
        require(
            e.projectileSpeeds[0] == 15 * 65536 && e.projectileSpeeds[1] == 10 * 65536,
            "original nightmare reversal"
        );
        require(s.gamekeydown == 0, "original keys cleared");
    }
}
