// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {GameflowHarness} from "./GameflowHarness.sol";
import {GameflowSnapshot} from "./GameflowSnapshot.sol";
import {G_Game, GameflowState, GameflowHooks} from "../../src/doom/g_game.sol";
import {GameContext, PlayerState} from "../../src/doom/p_game_state.sol";
import {Ticcmd} from "../../src/doom/d_ticcmd.sol";

interface GameflowVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
}

contract GameflowTest is GameflowHarness {
    GameflowVm constant vm = GameflowVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    error Mismatch(uint256 row, uint256 field, uint32 expected, uint32 actual);

    function word(bytes memory data, uint256 p) private pure returns (uint32 result) {
        for (uint256 i; i < 4; ++i) {
            result = (result << 8) | uint8(data[p + i]);
        }
    }

    function batch(uint32 first, uint32 last) private view {
        bytes memory data = vm.readFileBinary("test/fixtures/phase4_gameflow/vectors.bin");
        uint256 p = 4;
        uint32 count = word(data, 0);
        uint32 visited;
        for (uint32 row; row < count; ++row) {
            uint32 size = word(data, p);
            p += 4;
            uint32 op = word(data, p);
            if (op >= first && op <= last) {
                int32 map = int32(word(data, p + 4));
                uint32 flags = word(data, p + 8);
                (GameContext memory c, GameflowState memory f) = context(map, flags);
                run(
                    c,
                    f,
                    op,
                    map,
                    flags,
                    int32(word(data, p + 12)),
                    int32(word(data, p + 16)),
                    uint8(word(data, p + 20))
                );
                uint32[] memory values = GameflowSnapshot.snapshot(c, f);
                require(values.length == size - 6, "snapshot extent");
                for (uint256 j; j < values.length; ++j) {
                    uint32 expected = word(data, p + 24 + j * 4);
                    if (expected != values[j]) revert Mismatch(row, j, expected, values[j]);
                }
                ++visited;
            }
            p += size * 4;
        }
        require(p == data.length && visited > 0, "fixture coverage");
    }

    function testOriginalCNewGameAndDeferredInitialization() public view {
        batch(0, 1);
    }

    function testOriginalCLoadLevelAndReborn() public view {
        batch(2, 2);
    }

    function testOriginalCCompletionAllEpisodeOneMaps() public view {
        batch(3, 4);
    }

    function testOriginalCWorldDoneAndInventoryCarryover() public view {
        batch(5, 5);
    }

    function testOriginalCPauseMenuAndStateDispatch() public view {
        batch(6, 6);
    }

    function testOriginalCDeathUseAndFollowingTicReload() public view {
        batch(7, 7);
    }

    function testOriginalCNightmareFastAndInitPlayer() public view {
        batch(8, 10);
    }

    function testPauseProducerIsOneShotReplacesButtonsKeepsMovement() public pure {
        (GameContext memory c, GameflowState memory f) = context(1, 0);
        f.sendpause = false;
        f.keys.up = true;
        f.keys.fire = true;
        f.keys.use = true;
        f.keys.weaponRequest = 3;
        G_Game.G_RequestPause(f);
        G_Game.G_RequestPause(f);
        Ticcmd memory cmd = G_Game.G_BuildTiccmd(c.state, f);
        require(cmd.buttons == 129 && cmd.forwardmove == 25 && !f.sendpause);
        cmd = G_Game.G_BuildTiccmd(c.state, f);
        require(cmd.buttons == 23 && cmd.forwardmove == 25);
    }

    function testCompletionStatsAreCopiedNotAliased() public view {
        (GameContext memory c, GameflowState memory f) = context(3, 1);
        G_Game.G_DoCompleted(c, f, hooks());
        c.state.players[0].frags[1] = 999;
        require(f.wminfo.plyr[0].frags[1] == 2);
        require(!f.wminfo.didsecret && !c.state.players[0].didsecret);
        G_Game.G_WorldDone(c.state, f);
        require(c.state.players[0].didsecret && !f.wminfo.didsecret);
    }

    function testIncomingCommandIsCopiedBeforeWorldTickerClearsSpecial() public view {
        (GameContext memory c, GameflowState memory f) = context(1, 4);
        Ticcmd memory cmd = Ticcmd(0, 0, 0, 0, 0, 129);
        G_Game.G_Ticker(c, f, hooks(), cmd);
        require(!c.state.paused && c.state.players[0].cmd.buttons == 0 && cmd.buttons == 129);
    }
}
