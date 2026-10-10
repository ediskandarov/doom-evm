// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {GameContext} from "../doom/p_game_state.sol";
import {ResourceView} from "../doom/r_data_types.sol";
import {RenderState} from "../doom/r_state.sol";
import {ST_Stuff, STState, STGraphics} from "../doom/st_stuff.sol";
import {HU_Stuff, HudState} from "../doom/hu_stuff.sol";
import {V_Video} from "../doom/v_video.sol";
import {VideoState} from "../doom/v_video_types.sol";

/// @dev Consumer globals only. Original widget/face/message algorithms remain in ST_* and HU_*.
struct UIState {
    bool enabled;
    bool fullscreen;
    bool refresh;
    STState status;
    HudState hud;
}

library DoomUI {
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

    /// @dev D_Display erases HUD before R_RenderPlayerView. Both supported views
    /// have viewwindowx=0, so original HU_Erase updates history without border copies.
    function erase(UIState memory u) internal pure {
        VideoState memory video;
        RenderState memory viewState;
        HU_Stuff.HU_Erase(u.hud, video, viewState, false);
    }

    function drawStatus(UIState memory u, GameContext memory c) internal view {
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
        ST_Stuff.ST_Drawer(u.status, assets, video, c.state, c.definitions, u.fullscreen, u.refresh, false);
        u.refresh = false;
    }

    function drawHUD(UIState memory u, ResourceView memory source, bytes memory pixels) internal view {
        bytes[] memory font = HU_Stuff.HU_Init(source);
        u.hud.title.font = font;
        for (uint256 i; i < u.hud.message.h; ++i) {
            u.hud.message.lines[i].font = font;
        }
        VideoState memory video;
        video.screens[0] = pixels;
        HU_Stuff.HU_Drawer(u.hud, video, false);
        releaseGraphics(u);
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
