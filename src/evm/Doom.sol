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
import {DoomUI, UIState} from "./DoomUI.sol";

/// @notice Freedoom E1M1 rendering and original gameplay inside the ordinary EVM.
/// @dev Explicit startup preserves the accepted static renderer before gameplay begins.
contract Doom is IFrameProtocol, WadResources {
    error NotDriver();
    error BadSequence();
    error UnsupportedButtons();
    error InvalidFrame();
    error GameAlreadyStarted();
    error GameNotStarted();
    error UINotEnabled();

    /// @notice EVM-selected RGB8 palette for the matching unchanged indexed8 Frame.
    event FramePalette(
        uint64 indexed frameId,
        uint32 indexed inputSeq,
        uint32 revision,
        int32 palette,
        uint8 gamma,
        bytes rgb
    );

    address public immutable driver = msg.sender;
    uint64 public frameId;
    uint32 public inputSeq;
    uint32 private fuzzpos;
    DoomState internal doomState;
    bool public gameStarted;
    GameState internal gameState;
    UIState internal uiState;

    constructor(address[] memory chunks, bytes memory directory) WadResources(chunks, directory) {}

    /// @notice Start original single-player retail E1M1 at medium skill.
    /// @dev Startup has no command, tic or Frame; the first accepted input advances tic one.
    function initializeGame() external {
        _initializeGame(true);
    }

    /// @notice Diagnostic profile: reject every source-unwritten backing byte.
    function initializeGameStrict() external {
        _initializeGame(false);
    }

    /// @notice Start original Status Bar/HUD; fullscreen keeps HUD and palette effects.
    /// @dev Existing initializeGame retains the accepted world-only profile.
    function initializeGameUI(bool fullscreen) external {
        _initializeGame(true);
        GameContext memory c = DoomGame.load(_resourceView(), gameState);
        UIState memory u;
        DoomUI.initialize(u, c, fullscreen);
        uiState = u;
    }

    /// @notice Select original view size 10 or 11 for the next drawn frame, without advancing a tic.
    function setUIFullscreen(bool fullscreen) external {
        if (msg.sender != driver) revert NotDriver();
        if (!uiState.enabled) revert UINotEnabled();
        if (uiState.fullscreen != fullscreen) {
            uiState.fullscreen = fullscreen;
            uiState.refresh = true;
        }
    }

    function _initializeGame(bool initializeZone) private {
        if (msg.sender != driver) revert NotDriver();
        if (gameStarted) revert GameAlreadyStarted();
        GameContext memory c = DoomGame.initializeNativeWithPolicy(_resourceView(), false, initializeZone);
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
            UIState memory u;
            if (uiState.enabled) {
                u = uiState;
                DoomUI.tick(u, c);
            }
            bytes memory pixels;
            if (draw) {
                if (u.enabled) {
                    DoomUI.erase(u);
                    DoomUI.drawStatus(u, c);
                }
                pixels = DoomGame.render(c, u.enabled && !u.fullscreen ? 10 : 11);
                if (u.enabled) DoomUI.drawHUD(u, c.resources.source, pixels);
            }
            if (u.enabled) uiState = u;
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
        if (uiState.enabled) {
            emit FramePalette(
                frameId,
                sequence,
                uiState.status.paletteRevision,
                uiState.status.st_palette,
                uiState.status.usegamma,
                uiState.status.paletteRGB
            );
        }
        emit Frame(frameId, sequence, 320, 200, pixels);
    }

    /// @notice Persistent UI globals for transaction/timing inspection.
    function uiStatus()
        external
        view
        returns (
            bool enabled,
            bool fullscreen,
            uint32 clock,
            int32 face,
            int32 facecount,
            int32 palette,
            uint32 revision,
            uint32 rndindex,
            bool messageOn,
            int32 messageCounter,
            bytes memory message
        )
    {
        UIState storage u = uiState;
        return (
            u.enabled,
            u.fullscreen,
            u.status.st_clock,
            u.status.st_faceindex,
            u.status.st_facecount,
            u.status.st_palette,
            u.status.paletteRevision,
            gameState.rndindex,
            u.hud.message.on,
            u.hud.message_counter,
            u.hud.message.lines[u.hud.message.cl].text
        );
    }

    /// @notice Authoritative inventory, used by the original UI widgets.
    function playerInventory()
        external
        view
        returns (int32[4] memory ammo, int32[4] memory maxammo, bool[6] memory cards, bool[9] memory weapons)
    {
        if (!gameStarted) revert GameNotStarted();
        Player storage p = gameState.players[uint32(gameState.consoleplayer)];
        return (p.ammo, p.maxammo, p.cards, p.weaponowned);
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
