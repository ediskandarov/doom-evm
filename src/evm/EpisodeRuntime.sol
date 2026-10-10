// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {GameContext, PlayerState} from "../doom/p_game_state.sol";
import {GameflowState, GameflowHooks, G_Game} from "../doom/g_game.sol";
import {P_Info} from "../doom/p_info.sol";
import {P_Setup} from "../doom/p_setup.sol";
import {P_Tick} from "../doom/p_tick.sol";
import {Z_Zone} from "../doom/z_zone.sol";
import {R_Data} from "../doom/r_data.sol";
import {ST_Stuff} from "../doom/st_stuff.sol";
import {ST_Cheats, CheatState} from "../doom/st_cheats.sol";
import {HU_Stuff} from "../doom/hu_stuff.sol";
import {AM_Map} from "../doom/am_map.sol";
import {AutomapState} from "../doom/am_map_types.sol";
import {WI_Stuff} from "../doom/wi_stuff.sol";
import {WiState, WiStart, WiInput, WiGraphics} from "../doom/wi_stuff_types.sol";
import {F_Finale, FinaleState} from "../doom/f_finale.sol";
import {VideoState} from "../doom/v_video_types.sol";
import {DoomGame} from "./DoomGame.sol";
import {DoomUI, UIState} from "./DoomUI.sol";
import {InputProtocol, InputRuntimeState} from "./InputProtocol.sol";

struct EpisodeState {
    WiState wi;
    FinaleState finale;
    int32[] fastTics;
    int32[3] projectileSpeeds;
    int32 displayedGamestate;
}

/// @dev Ephemeral callback payload. Never persisted in gameplay or accepted from a host.
struct EpisodeAux {
    UIState ui;
    AutomapState automap;
    CheatState cheats;
    WiState wi;
    FinaleState finale;
    uint256 gamekeydown;
}

/// @notice Bind the existing original G_Ticker to persistent UI/WI/finale consumers.
library EpisodeRuntime {
    function restoreDifficulty(GameContext memory c, EpisodeState memory e) internal pure {
        for (uint256 i; i < e.fastTics.length; ++i) {
            c.definitions.states[P_Info.S_SARG_RUN1 + i].tics = e.fastTics[i];
        }
        c.definitions.mobjinfo[P_Info.MT_BRUISERSHOT].speed = e.projectileSpeeds[0];
        c.definitions.mobjinfo[P_Info.MT_HEADSHOT].speed = e.projectileSpeeds[1];
        c.definitions.mobjinfo[P_Info.MT_TROOPSHOT].speed = e.projectileSpeeds[2];
    }

    function saveDifficulty(GameContext memory c, EpisodeState memory e) internal pure {
        e.fastTics = new int32[](P_Info.S_SARG_PAIN2 - P_Info.S_SARG_RUN1 + 1);
        for (uint256 i; i < e.fastTics.length; ++i) {
            e.fastTics[i] = c.definitions.states[P_Info.S_SARG_RUN1 + i].tics;
        }
        e.projectileSpeeds[0] = c.definitions.mobjinfo[P_Info.MT_BRUISERSHOT].speed;
        e.projectileSpeeds[1] = c.definitions.mobjinfo[P_Info.MT_HEADSHOT].speed;
        e.projectileSpeeds[2] = c.definitions.mobjinfo[P_Info.MT_TROOPSHOT].speed;
    }

    function tick(
        GameContext memory c,
        InputRuntimeState memory s,
        UIState memory u,
        EpisodeState memory e,
        bytes memory events
    ) internal view {
        restoreDifficulty(c, e);
        InputProtocol.respond(s, c, u, events);
        // Build before setup clears keys. G_Ticker copies this command after actions.
        EpisodeAux memory a = EpisodeAux(u, s.automap, s.cheats, e.wi, e.finale, s.gamekeydown);
        c.adapterData = abi.encode(a);
        c.playerUIEnabled = true;
        c.hooks.startPlayerUI = startPlayerUI;
        G_Game.G_Ticker(c, s.flow, hooks(), InputProtocol.build(s, c));
        ++c.state.gametic;
        a = abi.decode(c.adapterData, (EpisodeAux));
        // Explicit field copies retain the caller's struct aliases.
        s.automap = a.automap;
        s.cheats = a.cheats;
        s.gamekeydown = a.gamekeydown;
        u.enabled = a.ui.enabled;
        u.fullscreen = a.ui.fullscreen;
        u.refresh = a.ui.refresh;
        u.status = a.ui.status;
        u.hud = a.ui.hud;
        e.wi = a.wi;
        e.finale = a.finale;
        saveDifficulty(c, e);
    }

    function hooks() private pure returns (GameflowHooks memory h) {
        h.setupLevel = setupLevel;
        h.checkHeap = checkHeap;
        h.flatNumForName = flat;
        h.textureNumForName = texture;
        h.levelTicker = levelTicker;
        h.statusTicker = statusTicker;
        h.automapTicker = automapTicker;
        h.hudTicker = hudTicker;
        h.automapStop = automapStop;
        h.intermissionStart = intermissionStart;
        h.intermissionTicker = intermissionTicker;
        h.finaleStart = finaleStart;
        h.finaleTicker = finaleTicker;
    }

    function setupLevel(GameContext memory c, GameflowState memory f) private view {
        f.wminfo.maxfrags = 0;
        f.wminfo.partime = 180;
        P_Setup.P_SetupLevel(c, c.state.gameepisode, c.state.gamemap, 0, c.state.gameskill);
        c.map = c.state.map;
        c.resources.nativeZone = c.state.nativeZone;
        EpisodeAux memory a = abi.decode(c.adapterData, (EpisodeAux));
        a.gamekeydown = 0;
        // G_InitNew clears automapactive without AM_Stop; preserve AM's source
        // statics, with its level-change reset on the next original AM_Start.
        a.automap.active = false;
        a.automap.viewactive = true;
        c.adapterData = abi.encode(a);
    }

    function startPlayerUI(GameContext memory c, uint32) private view {
        EpisodeAux memory a = abi.decode(c.adapterData, (EpisodeAux));
        DoomUI.restart(a.ui, c);
        c.adapterData = abi.encode(a);
    }

    function checkHeap(GameContext memory c, GameflowState memory) private pure {
        Z_Zone.Z_CheckHeap(c.state.nativeZone);
    }

    function flat(GameContext memory c, bytes8 name) private pure returns (uint32) {
        return R_Data.R_FlatNumForName(c.resources, name);
    }

    function texture(GameContext memory c, bytes8 name) private pure returns (uint32) {
        return R_Data.R_TextureNumForName(c.resources, name);
    }

    function levelTicker(GameContext memory c, GameflowState memory) private view {
        P_Tick.P_Ticker(c);
    }

    function statusTicker(GameContext memory c, GameflowState memory) private pure {
        EpisodeAux memory a = abi.decode(c.adapterData, (EpisodeAux));
        ST_Stuff.ST_Ticker(a.ui.status, c.state, c.definitions);
        c.adapterData = abi.encode(a);
    }

    function automapTicker(GameContext memory c, GameflowState memory) private pure {
        EpisodeAux memory a = abi.decode(c.adapterData, (EpisodeAux));
        if (a.automap.active) AM_Map.AM_Ticker(a.automap, DoomGame.automapWorld(c, a.automap.player));
        c.adapterData = abi.encode(a);
    }

    function hudTicker(GameContext memory c, GameflowState memory) private pure {
        EpisodeAux memory a = abi.decode(c.adapterData, (EpisodeAux));
        HU_Stuff.HU_Ticker(a.ui.hud, c.state.players[0], true);
        a.automap.message = c.state.players[a.automap.player].message;
        c.adapterData = abi.encode(a);
    }

    function automapStop(GameContext memory c, GameflowState memory f) private view {
        EpisodeAux memory a = abi.decode(c.adapterData, (EpisodeAux));
        AM_Map.AM_Stop(a.automap);
        ST_Stuff.ST_Responder(a.ui.status, a.automap.notification[0], a.automap.notification[1]);
        ST_Cheats.ST_Responder(
            c, f, a.cheats, uint8(uint32(a.automap.notification[0])), a.automap.notification[1]
        );
        f.automapactive = false;
        c.adapterData = abi.encode(a);
    }

    function wiInput(GameContext memory c) private pure returns (WiInput memory p) {
        p.gamemode = c.state.gamemode;
        p.playeringame = c.state.playeringame;
        p.rndindex = c.state.rndindex;
        for (uint256 i; i < 4; ++i) {
            p.buttons[i] = c.state.players[i].cmd.buttons;
            p.attackdown[i] = c.state.players[i].attackdown;
            p.usedown[i] = c.state.players[i].usedown;
        }
    }

    function commitInput(GameContext memory c, WiInput memory p) private pure {
        c.state.rndindex = p.rndindex;
        for (uint256 i; i < 4; ++i) {
            c.state.players[i].attackdown = p.attackdown[i];
            c.state.players[i].usedown = p.usedown[i];
        }
    }

    function intermissionStart(GameContext memory c, GameflowState memory f) private view {
        EpisodeAux memory a = abi.decode(c.adapterData, (EpisodeAux));
        // Field-compatible independent wbstartstruct_t ports: copy, never alias host state.
        WiStart memory w = abi.decode(abi.encode(f.wminfo), (WiStart));
        WiInput memory p = wiInput(c);
        WiGraphics memory assets;
        VideoState memory v;
        v.screens[1] = new bytes(64000);
        WI_Stuff.WI_Start(a.wi, w, p, assets, v, c.resources.source);
        f.wminfo.maxkills = w.maxkills;
        f.wminfo.maxitems = w.maxitems;
        f.wminfo.maxsecret = w.maxsecret;
        commitInput(c, p);
        c.adapterData = abi.encode(a);
    }

    function intermissionTicker(GameContext memory c, GameflowState memory f) private pure {
        EpisodeAux memory a = abi.decode(c.adapterData, (EpisodeAux));
        WiInput memory p = wiInput(c);
        WI_Stuff.WI_Ticker(a.wi, p);
        commitInput(c, p);
        if (a.wi.worldDoneRequested) G_Game.G_WorldDone(c.state, f);
        c.adapterData = abi.encode(a);
    }

    function finaleStart(GameContext memory c, GameflowState memory f) private pure {
        EpisodeAux memory a = abi.decode(c.adapterData, (EpisodeAux));
        F_Finale.F_StartFinale(c, f, a.finale);
        c.adapterData = abi.encode(a);
    }

    function finaleTicker(GameContext memory c, GameflowState memory f) private pure {
        EpisodeAux memory a = abi.decode(c.adapterData, (EpisodeAux));
        F_Finale.F_Ticker(a.finale, f);
        c.adapterData = abi.encode(a);
    }

    function draw(GameContext memory c, InputRuntimeState memory s, UIState memory u, EpisodeState memory e)
        internal
        view
        returns (bytes memory pixels)
    {
        if (c.state.renderFramebuffer.length != 64000) c.state.renderFramebuffer = new bytes(64000);
        if (c.state.gamestate == 0) {
            DoomUI.erase(u, s.automap.active);
            if (s.automap.active) pixels = DoomUI.drawAutomap(c, s.automap);
            DoomUI.drawStatus(u, c, s.automap.active);
            if (!s.automap.active) pixels = DoomGame.render(c, u.fullscreen ? 11 : 10);
            DoomUI.drawHUD(u, c.resources.source, pixels, s.automap.active);
        } else {
            if (e.displayedGamestate != c.state.gamestate) DoomUI.basePalette(u, c.resources.source);
            VideoState memory v;
            v.screens[0] = c.state.renderFramebuffer;
            if (c.state.gamestate == 1 && !e.wi.worldDoneRequested) {
                WiGraphics memory assets;
                v.screens[1] = new bytes(64000);
                WI_Stuff.WI_loadData(assets, v, c.resources.source);
                WI_Stuff.WI_Drawer(e.wi, assets, v);
            } else if (c.state.gamestate == 2) {
                F_Finale.F_Drawer(e.finale, c.resources.source, v, c.state.gamemode);
            }
            // WI_End frees native assets: retain the last EVM framebuffer at that boundary.
            pixels = v.screens[0];
        }
        e.displayedGamestate = c.state.gamestate;
        DoomUI.drawPause(c, pixels);
    }
}
