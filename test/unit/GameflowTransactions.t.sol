// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {GameflowHarness} from "./GameflowHarness.sol";
import {G_Game, GameflowState, GameflowHooks} from "../../src/doom/g_game.sol";
import {GameContext, GameState, GameDefinitions, PlayerState} from "../../src/doom/p_game_state.sol";
import {Ticcmd} from "../../src/doom/d_ticcmd.sol";

contract GameflowTransactionHost is GameflowHarness {
    bytes private saved;
    uint256 public commits;
    event Committed(uint256 sequence, bytes32 digest);
    error SetupFailed();

    function digest() external view returns (bytes32) {
        return keccak256(saved);
    }

    function summary()
        external
        view
        returns (
            int32 action,
            int32 state,
            bool paused,
            int32 leveltime,
            uint64 gametic,
            bool initialized,
            int32 tics,
            int32 next,
            bool secret
        )
    {
        (GameState memory s, GameflowState memory f, GameDefinitions memory d) =
            abi.decode(saved, (GameState, GameflowState, GameDefinitions));
        return (
            s.gameaction,
            s.gamestate,
            s.paused,
            s.leveltime,
            s.gametic,
            f.initialized,
            d.states[477].tics,
            f.wminfo.next,
            s.players[0].didsecret
        );
    }

    function failSetup(GameContext memory c, GameflowState memory) internal pure {
        c.state.players[0].health = 999;
        revert SetupFailed();
    }

    function incompleteSetup(GameContext memory c, GameflowState memory) internal pure {
        c.state.players[0].playerstate = PlayerState.reborn;
    }

    function operate(uint32 op, int32 arg) external {
        GameContext memory c;
        GameflowState memory f;
        if (saved.length == 0) {
            (c, f) = context(1, 0);
            f.initialized = false;
        } else {
            (c.state, f, c.definitions) = abi.decode(saved, (GameState, GameflowState, GameDefinitions));
            bind(c);
        }
        GameflowHooks memory h = hooks();
        if (op == 0) {
            G_Game.G_InitNew(c, f, h, 2, 1, 1);
        } else if (op == 1) {
            G_Game.G_DeferedInitNew(c.state, f, arg, 1, 1);
        } else if (op == 2) {
            tick(c, f, h, uint8(uint32(arg)), 0);
        } else if (op == 3) {
            G_Game.G_WorldDone(c.state, f);
        } else if (op == 4) {
            c.state.gamemap = arg;
            G_Game.G_SecretExitLevel(c);
            tick(c, f, h, 0, 0);
        } else if (op == 5) {
            h.setupLevel = failSetup;
            G_Game.G_InitNew(c, f, h, 2, 1, 1);
        } else if (op == 6) {
            h.setupLevel = incompleteSetup;
            G_Game.G_DoLoadLevel(c, f, h);
        } else if (op == 7) {
            c.state.gameaction = arg;
            tick(c, f, h, 0, 0);
        } else if (op == 8) {
            c.state.gamestate = arg;
            tick(c, f, h, 0, 0);
        } else if (op == 9) {
            c.state.netgame = true;
            tick(c, f, h, 0, 0);
        } else if (op == 10) {
            G_Game.G_InitNew(c, f, h, 2, arg, 1);
        } else if (op == 11) {
            G_Game.G_ExitLevel(c.state);
            tick(c, f, h, 0, 0);
        }
        saved = abi.encode(c.state, f, c.definitions);
        emit Committed(++commits, keccak256(saved));
    }
}

contract GameflowTransactionsTest {
    function reject(GameflowTransactionHost host, uint32 op, int32 arg, bytes4 expected) private {
        bytes32 beforeHash = host.digest();
        uint256 commits = host.commits();
        (bool ok, bytes memory reason) = address(host).call(abi.encodeCall(host.operate, (op, arg)));
        require(!ok && reason.length >= 4 && bytes4(reason) == expected, "expected transition rejection");
        require(host.digest() == beforeHash && host.commits() == commits, "atomic rollback");
    }

    function testStoragePauseResumeAndDeferredNightmareAcrossCalls() public {
        GameflowTransactionHost h = new GameflowTransactionHost();
        h.operate(0, 0);
        h.operate(2, 129);
        (,, bool paused, int32 time, uint64 tic, bool ready,,,) = h.summary();
        require(paused && time == 0 && tic == 129 && ready);
        h.operate(2, 0);
        (,, paused, time, tic,,,,) = h.summary();
        require(paused && time == 0 && tic == 130);
        h.operate(2, 129);
        (,, paused, time, tic,,,,) = h.summary();
        require(!paused && time == 1 && tic == 131);
        h.operate(1, 4);
        (int32 action,,,,,, int32 tics,,) = h.summary();
        require(action == 2 && tics == 3);
        h.operate(2, 0);
        (action,,,,,, tics,,) = h.summary();
        require(action == 0 && tics == 1);
        h.operate(1, 4);
        h.operate(2, 0);
        (,,,,,, tics,,) = h.summary();
        require(tics == 1, "definitions persist; no repeat nightmare half");
        h.operate(1, 2);
        h.operate(2, 0);
        (,,,,,, tics,,) = h.summary();
        require(tics == 2, "original odd tic loss retained");
    }

    function testSecretRouteAndFinaleAcrossCommittedCalls() public {
        GameflowTransactionHost h = new GameflowTransactionHost();
        h.operate(0, 0);
        h.operate(4, 3);
        (, int32 state,,,,,, int32 next, bool secret) = h.summary();
        require(state == 1 && next == 8 && !secret);
        int32 action;
        h.operate(3, 0);
        (action,,,,,,,, secret) = h.summary();
        require(action == 8 && secret);
        h.operate(2, 0);
        (action, state,,,,,,,) = h.summary();
        require(action == 0 && state == 0);
        // Request normal exit from map 9; completion picks map 4.
        h.operate(11, 0);
        (, state,,,,,, next, secret) = h.summary();
        require(state == 1 && secret && next == 3);
        h.operate(3, 0);
        h.operate(2, 0);
        h.operate(4, 8);
        (action, state,,,,,,,) = h.summary();
        require(action == 0 && state == 2);
    }

    function testInvalidStartupStateActionsAndSetupRollback() public {
        GameflowTransactionHost h = new GameflowTransactionHost();
        bytes4 invalid = G_Game.InvalidGameflowTransition.selector;
        reject(h, 2, 0, invalid);
        reject(h, 3, 0, invalid);
        h.operate(0, 0);
        reject(h, 3, 0, invalid);
        for (int32 a = 3; a <= 5; ++a) {
            reject(h, 7, a, invalid);
        }
        reject(h, 7, 9, invalid);
        reject(h, 7, -1, invalid);
        reject(h, 8, 3, invalid);
        reject(h, 2, 130, G_Game.UnsupportedGameflowProfile.selector);
        reject(h, 9, 0, G_Game.UnsupportedGameflowProfile.selector);
        reject(h, 10, 2, G_Game.UnsupportedGameflowProfile.selector);
        reject(h, 5, 0, GameflowTransactionHost.SetupFailed.selector);
        reject(h, 6, 0, G_Game.IncompleteLevelSetup.selector);
        h.operate(4, 1); // completed state cannot finish twice
        reject(h, 7, 6, invalid);
    }
}
