// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {GameContext} from "../doom/p_game_state.sol";
import {ResourceView} from "../doom/r_data_types.sol";
import {RenderState} from "../doom/r_state.sol";
import {ST_Stuff, STState, STGraphics} from "../doom/st_stuff.sol";
import {HU_Stuff, HudState} from "../doom/hu_stuff.sol";
import {V_Video} from "../doom/v_video.sol";
import {VideoState} from "../doom/v_video_types.sol";
import {AM_Map} from "../doom/am_map.sol";
import {AutomapState} from "../doom/am_map_types.sol";
import {DoomGame} from "./DoomGame.sol";
import {R_Data} from "../doom/r_data.sol";

/// @dev Consumer globals only. Original widget/face/message algorithms remain in ST_* and HU_*.
struct UIState {
    bool enabled;
    bool fullscreen;
    bool refresh;
    STState status;
    HudState hud;
}

library DoomUI {
    /// @dev Per-level ST_Start/HU_Start preserve original file-static histories.
    function restart(UIState memory u, GameContext memory c) internal view {
        STGraphics memory a;
        ST_Stuff.ST_loadData(a, c.resources.source, uint32(c.state.consoleplayer));
        ST_Stuff.ST_Start(u.status, a, c.state, c.definitions);
        HU_Stuff.HU_Start(
            u.hud,
            HU_Stuff.HU_Init(c.resources.source),
            c.state.gamemode,
            c.state.gameepisode,
            c.state.gamemap
        );
        u.refresh = true;
        releaseGraphics(u);
    }

    function basePalette(UIState memory u, ResourceView memory source) internal view {
        ST_Stuff.ST_BasePalette(
            u.status, R_Data.W_CacheLumpNum(source, R_Data.W_GetNumForName(source, "PLAYPAL"))
        );
    }

    function initialize(UIState memory u, GameContext memory c, bool fullscreen) internal view {
        u.enabled = true;
        u.fullscreen = fullscreen;
        u.refresh = true;
        STGraphics memory assets;
        VideoState memory video;
        ST_Stuff.ST_Init(u.status, video, assets, c.resources.source, uint32(c.state.consoleplayer));
        ST_Stuff.ST_Start(u.status, assets, c.state, c.definitions);
        HU_Stuff.HU_Start(
            u.hud,
            HU_Stuff.HU_Init(c.resources.source),
            c.state.gamemode,
            c.state.gameepisode,
            c.state.gamemap
        );
        releaseGraphics(u);
    }

    /// @dev Original G_Ticker GS_LEVEL order: P_Ticker, ST_Ticker, then HU_Ticker.
    function tick(UIState memory u, GameContext memory c) internal pure {
        ST_Stuff.ST_Ticker(u.status, c.state, c.definitions);
        HU_Stuff.HU_Ticker(u.hud, c.state.players[uint32(c.state.consoleplayer)], true);
    }

    function tick(UIState memory u, GameContext memory c, AutomapState memory am) internal pure {
        ST_Stuff.ST_Ticker(u.status, c.state, c.definitions);
        if (am.active) AM_Map.AM_Ticker(am, DoomGame.automapWorld(c, am.player));
        HU_Stuff.HU_Ticker(u.hud, c.state.players[uint32(c.state.consoleplayer)], true);
        // AM's string is a mirror of its selected player's pointer, not a queue.
        am.message = c.state.players[am.player].message;
    }

    /// @dev D_Display erases HUD before R_RenderPlayerView. Both supported views
    /// have viewwindowx=0, so original HU_Erase updates history without border copies.
    function erase(UIState memory u) internal pure {
        erase(u, false);
    }

    function erase(UIState memory u, bool automap) internal pure {
        VideoState memory video;
        RenderState memory viewState;
        HU_Stuff.HU_Erase(u.hud, video, viewState, automap);
    }

    function drawStatus(UIState memory u, GameContext memory c) internal view {
        drawStatus(u, c, false);
    }

    function drawStatus(UIState memory u, GameContext memory c, bool automap) internal view {
        STGraphics memory assets;
        ST_Stuff.ST_loadData(assets, c.resources.source, uint32(c.state.consoleplayer));
        bindStatusGraphics(u.status, assets);
        VideoState memory video;
        if (c.state.renderFramebuffer.length != 64000) c.state.renderFramebuffer = new bytes(64000);
        video.screens[0] = c.state.renderFramebuffer;
        video.screens[4] = new bytes(320 * 32);
        // The supported single-player screen4 is an immutable STBAR background.
        // Reconstitute that borrowed buffer for original differential widget restores.
        V_Video.V_DrawPatch(video, 0, 0, 4, assets.sbar);
        ST_Stuff.ST_Drawer(u.status, assets, video, c.state, c.definitions, u.fullscreen, u.refresh, automap);
        u.refresh = false;
    }

    function drawHUD(UIState memory u, ResourceView memory source, bytes memory pixels) internal view {
        drawHUD(u, source, pixels, false);
    }

    function drawHUD(UIState memory u, ResourceView memory source, bytes memory pixels, bool automap)
        internal
        view
    {
        bytes[] memory font = HU_Stuff.HU_Init(source);
        u.hud.title.font = font;
        for (uint256 i; i < u.hud.message.h; ++i) {
            u.hud.message.lines[i].font = font;
        }
        VideoState memory video;
        video.screens[0] = pixels;
        HU_Stuff.HU_Drawer(u.hud, video, automap);
        releaseGraphics(u);
    }

    /// @dev Same immutable UI borrowing boundary as ST/HU. Lifecycle counters stay
    /// in AM state; patch bytes are attached per call, never duplicated in storage.
    function automapPics(ResourceView memory source) internal view returns (bytes[10] memory nums) {
        for (uint256 i; i < 10; ++i) {
            bytes8 name = bytes8(abi.encodePacked("AMMNUM", bytes1(uint8(48 + i))));
            nums[i] = R_Data.W_CacheLumpNum(source, R_Data.W_GetNumForName(source, name));
        }
    }

    function drawAutomap(GameContext memory c, AutomapState memory am) internal view returns (bytes memory) {
        if (c.state.renderFramebuffer.length != 64000) c.state.renderFramebuffer = new bytes(64000);
        VideoState memory video;
        video.screens[0] = c.state.renderFramebuffer;
        AM_Map.AM_Drawer(am, DoomGame.automapWorld(c, am.player), video, automapPics(c.resources.source));
        return c.state.renderFramebuffer;
    }

    /// @custom:source d_main.c D_Display paused branch after HU_Drawer.
    /// @dev Both supported views have viewwindowx/y=0 and scaledviewwidth=320;
    /// retain the original hard-coded 68-pixel centering, including on Automap.
    function drawPause(GameContext memory c, bytes memory pixels) internal view {
        if (!c.state.paused) return;
        VideoState memory video;
        video.screens[0] = pixels;
        V_Video.V_DrawPatch(
            video,
            (320 - 68) / 2,
            4,
            0,
            R_Data.W_CacheLumpNum(c.resources.source, R_Data.W_GetNumForName(c.resources.source, "M_PAUSE"))
        );
    }

    /// @dev Patch/font pointers borrow authenticated immutable WAD data per call;
    /// all mutable module globals, text backing and widget history survive storage.
    function releaseGraphics(UIState memory u) internal pure {
        STGraphics memory empty;
        bindStatusGraphics(u.status, empty);
        u.hud.title.font = empty.faces;
        for (uint256 i; i < u.hud.message.h; ++i) {
            u.hud.message.lines[i].font = empty.faces;
        }
    }

    function bindStatusGraphics(STState memory s, STGraphics memory a) private pure {
        s.w_ready.p = a.tallnum;
        s.w_frags.p = a.tallnum;
        s.w_health.n.p = a.tallnum;
        s.w_health.p = a.tallpercent;
        s.w_armor.n.p = a.tallnum;
        s.w_armor.p = a.tallpercent;
        s.w_armsbg.p = a.armsbg;
        s.w_faces.p = a.faces;
        for (uint256 i; i < 6; ++i) {
            s.w_arms[i].p = a.arms[i];
        }
        for (uint256 i; i < 3; ++i) {
            s.w_keyboxes[i].p = a.keys;
        }
        for (uint256 i; i < 4; ++i) {
            s.w_ammo[i].p = a.shortnum;
            s.w_maxammo[i].p = a.shortnum;
        }
    }
}
