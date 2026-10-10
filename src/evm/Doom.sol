// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {IFrameProtocol} from "./FrameProtocol.sol";
import {DoomState} from "../doom/doomstat.sol";
import {WadResources} from "./WadResources.sol";
import {DoomRenderer} from "./DoomRenderer.sol";
import {RenderContext} from "../doom/r_render_state.sol";
import {DoomGame} from "./DoomGame.sol";
import {InputProtocol, InputRuntimeState} from "./InputProtocol.sol";
import {GameState, GameContext, Player, Mobj, PlayerState} from "../doom/p_game_state.sol";
import {Ticcmd} from "../doom/d_ticcmd.sol";
import {DoomUI, UIState} from "./DoomUI.sol";
import {EpisodeStartup} from "./EpisodeStartup.sol";
import {EpisodeRuntime, EpisodeState} from "./EpisodeRuntime.sol";
import {G_Game, GameflowState} from "../doom/g_game.sol";

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
    error RawInputRequired();
    error RawInputNotEnabled();
    error EpisodeNotEnabled();

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
    bool public rawInput;
    InputRuntimeState internal inputRuntime;
    bool public episodeMode;
    EpisodeState internal episodeState;

    constructor(address[] memory chunks, bytes memory directory) WadResources(chunks, directory) {}

    /// @notice Opt into the complete Episode One lifecycle and original keyboard input.
    function initializeEpisode(int32 map, int32 skill, bool fullscreen) external {
        if (msg.sender != driver) revert NotDriver();
        if (gameStarted) revert GameAlreadyStarted();
        (GameContext memory c, GameflowState memory f) =
            EpisodeStartup.initialize(_resourceView(), 1, map, skill, false, true);
        c.state.nativeZone.canonicalPointerHighBytes = true;
        UIState memory u;
        DoomUI.initialize(u, c, fullscreen);
        InputRuntimeState memory s;
        InputProtocol.initialize(s);
        s.flow = f;
        EpisodeState memory e;
        EpisodeRuntime.saveDifficulty(c, e);
        gameState = c.state;
        uiState = u;
        inputRuntime = s;
        episodeState = e;
        gameStarted = true;
        rawInput = true;
        episodeMode = true;
    }

    /// @notice Original deferred new-game semantics; consumes one sequenced tic and Frame.
    function newEpisodeGame(int32 map, int32 skill, uint32 sequence) external {
        _episodeDriver();
        if (map < 1 || map > 9 || skill < 0 || skill > 4) {
            revert EpisodeStartup.UnsupportedSelection(1, map, skill);
        }
        GameState memory state = gameState;
        GameflowState memory flow = inputRuntime.flow;
        G_Game.G_DeferedInitNew(state, flow, skill, 1, map);
        gameState = state;
        inputRuntime.flow = flow;
        _stepEpisode(bytes(""), sequence, true);
    }

    /// @notice Restart the current level through the original rebirth/load lifecycle.
    function restartEpisode(uint32 sequence) external {
        _episodeDriver();
        gameState.players[0].playerstate = PlayerState.reborn;
        GameState memory state = gameState;
        G_Game.G_DoReborn(state, 0);
        gameState = state;
        _stepEpisode(bytes(""), sequence, true);
    }

    function setEpisodePaused(bool paused, uint32 sequence) external {
        _episodeDriver();
        if (gameState.paused != paused) inputRuntime.flow.sendpause = true;
        _stepEpisode(bytes(""), sequence, true);
    }

    function _episodeDriver() private view {
        if (msg.sender != driver) revert NotDriver();
        if (!episodeMode) revert EpisodeNotEnabled();
    }

    function episodeStatus()
        external
        view
        returns (
            int32 map,
            int32 skill,
            int32 state,
            int32 action,
            bool paused,
            int32 last,
            int32 next,
            int32 wiStage,
            int32 wiTic,
            int32 finaleStage,
            int32 finaleTic
        )
    {
        return (
            gameState.gamemap,
            gameState.gameskill,
            gameState.gamestate,
            gameState.gameaction,
            gameState.paused,
            inputRuntime.flow.wminfo.last,
            inputRuntime.flow.wminfo.next,
            episodeState.wi.sp_state,
            episodeState.wi.bcnt,
            episodeState.finale.finalestage,
            episodeState.finale.finalecount
        );
    }

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
        _initializeUI(fullscreen);
    }

    /// @notice Opt into original raw keyboard events, Cheats and Automap.
    /// @dev Retains the accepted UI/legacy initializers and Frame ABI unchanged.
    function initializeGameInput(bool fullscreen) external {
        _initializeUI(fullscreen);
        InputRuntimeState memory s;
        InputProtocol.initialize(s);
        inputRuntime = s;
        rawInput = true;
    }

    function _initializeUI(bool fullscreen) private {
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
        if (rawInput) revert RawInputRequired();
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

    function stepEventsAndRender(bytes calldata events, uint32 sequence) external {
        _stepEvents(events, sequence, true);
    }

    function stepEvents(bytes calldata events, uint32 sequence) external {
        _stepEvents(events, sequence, false);
    }

    /// @dev Original event -> command -> level tic boundary. IDCLEV's deferred
    /// GA_NEWGAME and selected skill/episode/map remain pending for Episode Runtime.
    /// No full G_Ticker action dispatch or map substitution occurs in this goal.
    function _stepEvents(bytes memory events, uint32 sequence, bool draw) private {
        if (msg.sender != driver) revert NotDriver();
        if (!rawInput) revert RawInputNotEnabled();
        if (inputSeq == type(uint32).max || sequence != inputSeq + 1) revert BadSequence();
        if (episodeMode) {
            _stepEpisode(events, sequence, draw);
            return;
        }
        GameContext memory c = DoomGame.load(_resourceView(), gameState);
        UIState memory u = uiState;
        InputRuntimeState memory s = inputRuntime;
        InputProtocol.respond(s, c, u, events);
        Ticcmd memory cmd = InputProtocol.build(s, c);
        // Original G_Ticker special-button branch; full gameaction dispatch is
        // reserved for Episode Runtime. Pause precedes P_Ticker in this profile.
        if (cmd.buttons & 128 != 0 && cmd.buttons & 3 == 1) c.state.paused = !c.state.paused;
        DoomGame.tick(c, cmd);
        DoomUI.tick(u, c, s.automap);
        bytes memory pixels;
        if (draw) {
            DoomUI.erase(u, s.automap.active);
            if (s.automap.active) pixels = DoomUI.drawAutomap(c, s.automap);
            DoomUI.drawStatus(u, c, s.automap.active);
            if (!s.automap.active) pixels = DoomGame.render(c, u.fullscreen ? 11 : 10);
            DoomUI.drawHUD(u, c.resources.source, pixels, s.automap.active);
            DoomUI.drawPause(c, pixels);
        }
        inputRuntime = s;
        uiState = u;
        gameState = c.state;
        inputSeq = sequence;
        if (draw) _emitFrame(sequence, pixels);
    }

    function _stepEpisode(bytes memory events, uint32 sequence, bool draw) private {
        if (inputSeq == type(uint32).max || sequence != inputSeq + 1) revert BadSequence();
        GameContext memory c = DoomGame.load(_resourceView(), gameState);
        UIState memory u = uiState;
        InputRuntimeState memory s = inputRuntime;
        EpisodeState memory e = episodeState;
        EpisodeRuntime.tick(c, s, u, e, events);
        bytes memory pixels;
        if (draw) pixels = EpisodeRuntime.draw(c, s, u, e);
        gameState = c.state;
        uiState = u;
        inputRuntime = s;
        episodeState = e;
        inputSeq = sequence;
        if (draw) _emitFrame(sequence, pixels);
    }

    /// @notice Original cheat mutations and pending Episode Runtime selection.
    function cheatStatus()
        external
        view
        returns (
            int32 cheats,
            int32[6] memory powers,
            int32 action,
            int32 skill,
            int32 episode,
            int32 map,
            uint256 gamekeydown
        )
    {
        Player storage p = gameState.players[uint32(gameState.consoleplayer)];
        return (
            p.cheats,
            p.powers,
            gameState.gameaction,
            inputRuntime.flow.deferredSkill,
            inputRuntime.flow.deferredEpisode,
            inputRuntime.flow.deferredMap,
            inputRuntime.gamekeydown
        );
    }

    function cheatSequence(uint8 index) external view returns (bytes memory sequence, uint32 cursor) {
        return (inputRuntime.cheats.sequences[index].sequence, inputRuntime.cheats.sequences[index].cursor);
    }

    function automapStatus()
        external
        view
        returns (
            bool active,
            bool viewactive,
            bool follow,
            bool grid,
            uint32 cheating,
            uint32 cheatPos,
            int32 x,
            int32 y,
            int32 w,
            int32 h,
            int32 scale,
            int32 zoomM,
            int32 panX,
            int32 panY,
            uint32 mark,
            uint32 loads,
            uint32 unloads
        )
    {
        return (
            inputRuntime.automap.active,
            inputRuntime.automap.viewactive,
            inputRuntime.automap.follow,
            inputRuntime.automap.grid,
            inputRuntime.automap.cheating,
            inputRuntime.automap.cheatPos,
            inputRuntime.automap.x,
            inputRuntime.automap.y,
            inputRuntime.automap.w,
            inputRuntime.automap.h,
            inputRuntime.automap.scale,
            inputRuntime.automap.zoomM,
            inputRuntime.automap.panX,
            inputRuntime.automap.panY,
            inputRuntime.automap.mark,
            inputRuntime.automap.loads,
            inputRuntime.automap.unloads
        );
    }

    function automapMark(uint8 index) external view returns (int32 x, int32 y) {
        return (inputRuntime.automap.marks[index].x, inputRuntime.automap.marks[index].y);
    }

    /// @notice Original ordered linedef flags; discovery remains renderer-owned.
    function automapDiscovery() external view returns (uint32 mapped, bytes32 flagsSha256) {
        bytes memory flags = new bytes(gameState.map.lines.length * 2);
        for (uint256 i; i < gameState.map.lines.length; ++i) {
            uint16 value = gameState.map.lines[i].flags;
            if (value & 256 != 0) ++mapped;
            flags[i * 2] = bytes1(uint8(value >> 8));
            flags[i * 2 + 1] = bytes1(uint8(value));
        }
        flagsSha256 = sha256(flags);
    }

    function _emitFrame(uint32 sequence, bytes memory pixels) private {
        if (pixels.length != 320 * 200) revert InvalidFrame();
        ++frameId;
        if (uiState.enabled) {
            emit FramePalette(
                frameId,
                sequence,
                uiState.status.paletteRevision,
                episodeMode && gameState.gamestate != 0 ? int32(0) : uiState.status.st_palette,
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
