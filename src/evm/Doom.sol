// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {IFrameProtocol} from "./FrameProtocol.sol";
import {DoomState} from "../doom/doomstat.sol";
import {WadResources} from "./WadResources.sol";
import {DoomRenderer} from "./DoomRenderer.sol";
import {RenderContext} from "../doom/r_render_state.sol";
import {DoomGame} from "./DoomGame.sol";
import {InputProtocol} from "./InputProtocol.sol";
import {GameState, GameContext, Player, Mobj} from "../doom/p_game_state.sol";
import {Ticcmd} from "../doom/d_ticcmd.sol";

/// @notice Freedoom E1M1 rendering and original gameplay inside the ordinary EVM.
/// @dev Explicit startup preserves the accepted static renderer before gameplay begins.
contract Doom is IFrameProtocol, WadResources {
    error NotDriver();
    error BadSequence();
    error UnsupportedButtons();
    error InvalidFrame();
    error GameAlreadyStarted();
    error GameNotStarted();

    address public immutable driver = msg.sender;
    uint64 public frameId;
    uint32 public inputSeq;
    uint32 private fuzzpos;
    DoomState internal doomState;
    bool public gameStarted;
    GameState internal gameState;

    constructor(address[] memory chunks, bytes memory directory) WadResources(chunks, directory) {}

    /// @notice Start original single-player retail E1M1 at medium skill.
    /// @dev Startup has no command, tic or Frame; the first accepted input advances tic one.
    function initializeGame() external {
        if (msg.sender != driver) revert NotDriver();
        if (gameStarted) revert GameAlreadyStarted();
        GameContext memory c = DoomGame.initializeNative(_resourceView(), false);
        gameState = c.state;
        gameStarted = true;
    }

    function renderFrame() external {
        if (inputSeq == type(uint32).max) revert BadSequence();
        _step(0, inputSeq + 1, true);
    }

    function stepAndRender(uint32 buttons, uint32 sequence) external {
        if (!gameStarted && buttons != 0) revert UnsupportedButtons();
        _step(buttons, sequence, true);
    }

    /// @notice Advance one original tic without rendering; simulation cadence is independent of frames.
    function step(uint32 buttons, uint32 sequence) external {
        if (!gameStarted) revert GameNotStarted();
        _step(buttons, sequence, false);
    }

    function _step(uint32 buttons, uint32 sequence, bool draw) private {
        if (msg.sender != driver) revert NotDriver();
        if (inputSeq == type(uint32).max || sequence != inputSeq + 1) revert BadSequence();
        if (gameStarted) {
            GameState memory state = gameState;
            GameContext memory c = DoomGame.load(_resourceView(), state);
            Ticcmd memory cmd = InputProtocol.build(c.state.input, buttons);
            DoomGame.tick(c, cmd);
            bytes memory pixels;
            if (draw) pixels = DoomGame.render(c);
            gameState = c.state;
            inputSeq = sequence;
            if (draw) _emitFrame(sequence, pixels);
            return;
        }
        RenderContext memory ctx = DoomRenderer.initialize(_resourceView());
        ctx.rs.fuzzpos = fuzzpos;
        DoomRenderer.render(ctx);
        fuzzpos = ctx.rs.fuzzpos;
        inputSeq = sequence;
        _emitFrame(sequence, ctx.rs.framebuffer);
    }

    function _emitFrame(uint32 sequence, bytes memory pixels) private {
        if (pixels.length != 320 * 200) revert InvalidFrame();
        ++frameId;
        emit Frame(frameId, sequence, 320, 200, pixels);
    }

    /// @notice Small status view for clients; the authoritative world remains contract storage.
    function gameStatus()
        external
        view
        returns (uint64 gametic, int32 leveltime, int32 health, int32 armor, int32 weapon)
    {
        if (!gameStarted) revert GameNotStarted();
        uint32 player = uint32(gameState.consoleplayer);
        return (
            gameState.gametic,
            gameState.leveltime,
            gameState.players[player].health,
            gameState.players[player].armorpoints,
            int32(uint32(gameState.players[player].readyweapon))
        );
    }

    /// @notice Authoritative player camera/momentum and gameplay RNG for local inspection.
    function playerView()
        external
        view
        returns (
            int32 x,
            int32 y,
            int32 z,
            uint32 angle,
            int32 momx,
            int32 momy,
            int32 momz,
            int32 viewz,
            uint32 prndindex
        )
    {
        if (!gameStarted) revert GameNotStarted();
        Player storage player = gameState.players[uint32(gameState.consoleplayer)];
        Mobj storage actor = gameState.mobjs[player.mo];
        return (
            actor.x,
            actor.y,
            actor.z,
            actor.angle,
            actor.momx,
            actor.momy,
            actor.momz,
            player.viewz,
            gameState.prndindex
        );
    }
}
