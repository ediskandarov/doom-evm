// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
// Copyright (C) 1993-1996 by id Software, Inc.
import {Ticcmd, GameInputState, KeyboardInput} from "./d_ticcmd.sol";
import {GameContext, GameState, Player, PlayerState, GameConst} from "./p_game_state.sol";
import {R_Data} from "./r_data.sol";
import {P_Info} from "./p_info.sol";

/// @custom:source linuxdoom-1.10/d_player.h wbplayerstruct_t, wbstartstruct_t
struct GameflowPlayerStats {
    bool inGame;
    int32 skills;
    int32 sitems;
    int32 ssecret;
    int32 stime;
    int32[4] frags;
    int32 score;
}

struct GameflowIntermission {
    int32 epsd;
    bool didsecret;
    int32 last;
    int32 next;
    int32 maxkills;
    int32 maxitems;
    int32 maxsecret;
    int32 maxfrags;
    int32 partime;
    int32 pnum;
    GameflowPlayerStats[4] plyr;
}

/// @dev Supplemental original globals, owned here until integration wires persistence.
/// No callbacks/pointers in this struct: persist alongside GameState, atomically.
struct GameflowState {
    int32 deferredSkill;
    int32 deferredEpisode;
    int32 deferredMap;
    bool sendpause;
    bool usergame;
    bool viewactive;
    bool automapactive;
    bool respawnparm;
    uint64 levelstarttic;
    int32 wipegamestate;
    KeyboardInput keys;
    GameflowIntermission wminfo;
    bool initialized; // adapter guard; set only after synchronous level setup succeeds
}

/// @dev Original cross-module boundaries. Rebind after storage load; never persist.
/// setupLevel must finish P_SetupLevel for the requested state episode/map/skill.
/// finaleStart must perform F_StartFinale's state changes; graphics are out of scope.
struct GameflowHooks {
    function(GameContext memory, GameflowState memory) internal view setupLevel;
    function(GameContext memory, GameflowState memory) internal view checkHeap;
    function(GameContext memory, GameflowState memory) internal view levelTicker;
    function(GameContext memory, GameflowState memory) internal view statusTicker;
    function(GameContext memory, GameflowState memory) internal view automapTicker;
    function(GameContext memory, GameflowState memory) internal view hudTicker;
    function(GameContext memory, GameflowState memory) internal view automapStop;
    function(GameContext memory, GameflowState memory) internal view intermissionStart;
    function(GameContext memory, GameflowState memory) internal view intermissionTicker;
    function(GameContext memory, GameflowState memory) internal view finaleStart;
    function(GameContext memory, GameflowState memory) internal view finaleTicker;
    function(GameContext memory, bytes8) internal view returns (uint32) flatNumForName;
    function(GameContext memory, bytes8) internal view returns (uint32) textureNumForName;
}

library G_Game {
    error InvalidTurnState(int32 turnheld);
    error InvalidWeaponRequest(uint8 request);
    error UnsupportedGameflowProfile();
    error InvalidGameflowTransition(int32 gamestate, int32 gameaction);
    error IncompleteLevelSetup();

    // Original d_event.h gameaction_t and doomdef.h gamestate_t values.
    int32 internal constant GA_NOTHING = 0;
    int32 internal constant GA_LOADLEVEL = 1;
    int32 internal constant GA_NEWGAME = 2;
    int32 internal constant GA_COMPLETED = 6;
    int32 internal constant GA_VICTORY = 7;
    int32 internal constant GA_WORLDDONE = 8;
    int32 internal constant GS_LEVEL = 0;
    int32 internal constant GS_INTERMISSION = 1;
    int32 internal constant GS_FINALE = 2;

    function singlePlayer(GameState memory s) private pure {
        if (
            s.netgame || s.deathmatch != 0 || s.demoplayback || s.consoleplayer != 0 || !s.playeringame[0]
                || s.playeringame[1] || s.playeringame[2] || s.playeringame[3]
        ) {
            revert UnsupportedGameflowProfile();
        }
    }

    function episodeOne(GameState memory s) private pure {
        if (
            (s.gamemode != 0 && s.gamemode != 1 && s.gamemode != 3) || s.gameepisode != 1 || s.gamemap < 1
                || s.gamemap > 9
        ) {
            revert UnsupportedGameflowProfile();
        }
    }

    function active(GameState memory s, GameflowState memory f, int32 expected) private pure {
        singlePlayer(s);
        episodeOne(s);
        if (!f.initialized || s.gamestate != expected) {
            revert InvalidGameflowTransition(s.gamestate, s.gameaction);
        }
    }

    /// @custom:source linuxdoom-1.10/g_game.c G_Responder KEY_PAUSE branch
    function G_RequestPause(GameflowState memory f) internal pure {
        f.sendpause = true;
    }

    /// @custom:source linuxdoom-1.10/g_game.c G_BuildTiccmd sendpause branch
    function G_BuildTiccmd(GameState memory s, GameflowState memory f)
        internal
        pure
        returns (Ticcmd memory cmd)
    {
        cmd = G_BuildTiccmd(s.input, f.keys);
        if (f.sendpause) {
            f.sendpause = false;
            cmd.buttons = 128 | 1; // BT_SPECIAL | BTS_PAUSE replaces other buttons
        }
    }

    /// @custom:source linuxdoom-1.10/g_game.c G_DeferedInitNew
    function G_DeferedInitNew(
        GameState memory s,
        GameflowState memory f,
        int32 skill,
        int32 episode,
        int32 map
    ) internal pure {
        f.deferredSkill = skill;
        f.deferredEpisode = episode;
        f.deferredMap = map;
        s.gameaction = GA_NEWGAME;
    }

    /// @custom:source linuxdoom-1.10/g_game.c G_DoNewGame
    function G_DoNewGame(GameContext memory c, GameflowState memory f, GameflowHooks memory h) internal view {
        c.state.demoplayback = false;
        c.state.netgame = false;
        c.state.deathmatch = 0;
        c.state.playeringame[1] = false;
        c.state.playeringame[2] = false;
        c.state.playeringame[3] = false;
        f.respawnparm = false;
        c.state.fastparm = false;
        c.state.nomonsters = false;
        c.state.consoleplayer = 0;
        G_InitNew(c, f, h, f.deferredSkill, f.deferredEpisode, f.deferredMap);
        c.state.gameaction = GA_NOTHING;
    }

    /// @custom:source linuxdoom-1.10/g_game.c G_InitNew
    function G_InitNew(
        GameContext memory c,
        GameflowState memory f,
        GameflowHooks memory h,
        int32 skill,
        int32 episode,
        int32 map
    ) internal view {
        singlePlayer(c.state);
        c.state.paused = false; // S_ResumeSound omitted, no sound profile
        if (skill > 4) skill = 4;
        if (episode < 1) episode = 1;
        if (c.state.gamemode == 3) {
            if (episode > 4) episode = 4;
        } else if (c.state.gamemode == 0) {
            if (episode > 1) episode = 1;
        } else {
            if (episode > 3) episode = 3;
        }
        if (map < 1) map = 1;
        if (map > 9 && c.state.gamemode != 2) map = 9;
        if (
            skill < 0 || episode != 1
                || (c.state.gamemode != 0 && c.state.gamemode != 1 && c.state.gamemode != 3)
        ) {
            revert UnsupportedGameflowProfile();
        }
        c.state.prndindex = 0;
        c.state.rndindex = 0; // M_ClearRandom
        c.state.respawnmonsters = skill == 4 || f.respawnparm;
        // Deliberately retain original repeated -fast halving and nightmare exit rules.
        if (c.state.fastparm || (skill == 4 && c.state.gameskill != 4)) {
            for (uint32 i = P_Info.S_SARG_RUN1; i <= P_Info.S_SARG_PAIN2; ++i) {
                c.definitions.states[i].tics >>= 1;
            }
            c.definitions.mobjinfo[P_Info.MT_BRUISERSHOT].speed = 20 * 65536;
            c.definitions.mobjinfo[P_Info.MT_HEADSHOT].speed = 20 * 65536;
            c.definitions.mobjinfo[P_Info.MT_TROOPSHOT].speed = 20 * 65536;
        } else if (skill != 4 && c.state.gameskill == 4) {
            for (uint32 i = P_Info.S_SARG_RUN1; i <= P_Info.S_SARG_PAIN2; ++i) {
                c.definitions.states[i].tics <<= 1;
            }
            c.definitions.mobjinfo[P_Info.MT_BRUISERSHOT].speed = 15 * 65536;
            c.definitions.mobjinfo[P_Info.MT_HEADSHOT].speed = 10 * 65536;
            c.definitions.mobjinfo[P_Info.MT_TROOPSHOT].speed = 10 * 65536;
        }
        for (uint32 i; i < 4; ++i) {
            c.state.players[i].playerstate = PlayerState.reborn;
        }
        f.usergame = true;
        c.state.paused = false;
        c.state.demoplayback = false;
        f.automapactive = false;
        f.viewactive = true;
        c.state.gameepisode = episode;
        c.state.gamemap = map;
        c.state.gameskill = skill;
        c.state.skytexture = h.textureNumForName(c, "SKY1");
        G_DoLoadLevel(c, f, h);
    }

    /// @custom:source linuxdoom-1.10/g_game.c G_DoLoadLevel
    function G_DoLoadLevel(GameContext memory c, GameflowState memory f, GameflowHooks memory h)
        internal
        view
    {
        singlePlayer(c.state);
        episodeOne(c.state);
        f.initialized = false;
        c.state.skyflatnum = h.flatNumForName(c, "F_SKY1");
        // Original compares gamemode to GameMission_t pack_plut (3), also retail.
        // Preserve that cross-enum comparison and lookup order, even in Episode One.
        if (c.state.gamemode == 3) {
            c.state.skytexture = h.textureNumForName(c, "SKY3");
            c.state.skytexture = h.textureNumForName(c, "SKY1");
        }
        f.levelstarttic = c.state.gametic;
        if (f.wipegamestate == GS_LEVEL) f.wipegamestate = -1;
        c.state.gamestate = GS_LEVEL;
        for (uint32 i; i < 4; ++i) {
            if (c.state.playeringame[i] && c.state.players[i].playerstate == PlayerState.dead) {
                c.state.players[i].playerstate = PlayerState.reborn;
            }
            for (uint32 j; j < 4; ++j) {
                c.state.players[i].frags[j] = 0;
            }
        }
        h.setupLevel(c, f);
        c.state.displayplayer = c.state.consoleplayer;
        c.state.gameaction = GA_NOTHING;
        h.checkHeap(c, f);
        KeyboardInput memory cleared;
        f.keys = cleared;
        f.sendpause = false;
        c.state.paused = false;
        // G_DoLoadLevel never resets turnheld or RNG. P_SetupLevel owns leveltime/stats.
        uint32 mo = c.state.players[0].mo;
        if (
            c.state.players[0].playerstate != PlayerState.live || mo >= c.state.mobjCount
                || mo >= c.state.mobjs.length || !c.state.mobjs[mo].allocated
        ) revert IncompleteLevelSetup();
        f.initialized = true;
    }

    /// @custom:source linuxdoom-1.10/g_game.c G_DoReborn single-player branch
    function G_DoReborn(GameState memory s, uint32) internal pure {
        singlePlayer(s);
        s.gameaction = GA_LOADLEVEL;
    }

    /// @custom:source linuxdoom-1.10/g_game.c G_InitPlayer
    function G_InitPlayer(GameState memory s, uint32 playerId) internal pure {
        G_PlayerReborn(s, playerId);
    }

    /// @custom:source linuxdoom-1.10/g_game.c G_PlayerFinishLevel
    function G_PlayerFinishLevel(GameState memory s, uint32 playerId) internal pure {
        Player memory p = s.players[playerId];
        for (uint32 i; i < 6; ++i) {
            p.powers[i] = 0;
            p.cards[i] = false;
        }
        s.mobjs[p.mo].flags &= ~GameConst.MF_SHADOW;
        p.extralight = 0;
        p.fixedcolormap = 0;
        p.damagecount = 0;
        p.bonuscount = 0;
    }

    /// @custom:source linuxdoom-1.10/g_game.c G_DoCompleted Episode One branch
    function G_DoCompleted(GameContext memory c, GameflowState memory f, GameflowHooks memory h)
        internal
        view
    {
        active(c.state, f, GS_LEVEL);
        c.state.gameaction = GA_NOTHING;
        for (uint32 i; i < 4; ++i) {
            if (c.state.playeringame[i]) G_PlayerFinishLevel(c.state, i);
        }
        if (f.automapactive) h.automapStop(c, f);
        if (c.state.gamemap == 8) {
            c.state.gameaction = GA_VICTORY;
            return;
        }
        if (c.state.gamemap == 9) {
            for (uint32 i; i < 4; ++i) {
                c.state.players[i].didsecret = true;
            }
        }
        GameflowIntermission memory w = f.wminfo;
        w.didsecret = c.state.players[0].didsecret;
        w.epsd = c.state.gameepisode - 1;
        w.last = c.state.gamemap - 1;
        w.next = c.state.secretExit ? int32(8) : (c.state.gamemap == 9 ? int32(3) : c.state.gamemap);
        w.maxkills = c.state.totalkills;
        w.maxitems = c.state.totalitems;
        w.maxsecret = c.state.totalsecret;
        w.maxfrags = 0;
        int32[10] memory pars = [int32(0), 30, 75, 120, 90, 165, 180, 180, 30, 165];
        w.partime = 35 * pars[uint32(c.state.gamemap)];
        w.pnum = c.state.consoleplayer;
        for (uint32 i; i < 4; ++i) {
            w.plyr[i].inGame = c.state.playeringame[i];
            w.plyr[i].skills = c.state.players[i].killcount;
            w.plyr[i].sitems = c.state.players[i].itemcount;
            w.plyr[i].ssecret = c.state.players[i].secretcount;
            w.plyr[i].stime = c.state.leveltime;
            // memcpy, not a Solidity memory-array alias; score remains unchanged.
            for (uint32 j; j < 4; ++j) {
                w.plyr[i].frags[j] = c.state.players[i].frags[j];
            }
        }
        c.state.gamestate = GS_INTERMISSION;
        f.viewactive = false;
        f.automapactive = false;
        h.intermissionStart(c, f);
    }

    /// @custom:source linuxdoom-1.10/g_game.c G_WorldDone Episode One branch
    function G_WorldDone(GameState memory s, GameflowState memory f) internal pure {
        active(s, f, GS_INTERMISSION);
        s.gameaction = GA_WORLDDONE;
        if (s.secretExit) s.players[0].didsecret = true;
    }

    /// @custom:source linuxdoom-1.10/g_game.c G_DoWorldDone
    function G_DoWorldDone(GameContext memory c, GameflowState memory f, GameflowHooks memory h)
        internal
        view
    {
        active(c.state, f, GS_INTERMISSION);
        if (f.wminfo.next < 0 || f.wminfo.next > 8) {
            revert InvalidGameflowTransition(c.state.gamestate, c.state.gameaction);
        }
        c.state.gamestate = GS_LEVEL;
        c.state.gamemap = f.wminfo.next + 1;
        G_DoLoadLevel(c, f, h);
        c.state.gameaction = GA_NOTHING;
        f.viewactive = true;
    }

    /// @custom:source linuxdoom-1.10/g_game.c G_Ticker single-player, ticdup=1
    /// @dev Caller supplies the command already built for this tic and advances gametic
    /// once AFTER return (original d_net.c outer loop), including paused tics.
    function G_Ticker(GameContext memory c, GameflowState memory f, GameflowHooks memory h, Ticcmd memory cmd)
        internal
        view
    {
        singlePlayer(c.state);
        if (!f.initialized && c.state.gameaction != GA_NEWGAME && c.state.gameaction != GA_LOADLEVEL) {
            revert InvalidGameflowTransition(c.state.gamestate, c.state.gameaction);
        }
        // This order matters: reborn overrides a previously queued action, as in C.
        for (uint32 i; i < 4; ++i) {
            if (c.state.playeringame[i] && c.state.players[i].playerstate == PlayerState.reborn) {
                G_DoReborn(c.state, i);
            }
        }
        while (c.state.gameaction != GA_NOTHING) {
            int32 action = c.state.gameaction;
            if (action == GA_LOADLEVEL) {
                G_DoLoadLevel(c, f, h);
            } else if (action == GA_NEWGAME) {
                G_DoNewGame(c, f, h);
            } else if (action == GA_COMPLETED) {
                G_DoCompleted(c, f, h);
            } else if (action == GA_VICTORY) {
                active(c.state, f, GS_LEVEL);
                h.finaleStart(c, f);
                if (c.state.gameaction != GA_NOTHING || c.state.gamestate != GS_FINALE) {
                    revert InvalidGameflowTransition(c.state.gamestate, c.state.gameaction);
                }
            } else if (action == GA_WORLDDONE) {
                G_DoWorldDone(c, f, h);
            } else {
                revert InvalidGameflowTransition(c.state.gamestate, action);
            }
        }
        episodeOne(c.state);
        // memcpy: the player's P_PlayerThink may clear special buttons, not the caller's command.
        c.state.players[0].cmd =
            Ticcmd(cmd.forwardmove, cmd.sidemove, cmd.angleturn, cmd.consistancy, cmd.chatchar, cmd.buttons);
        if (cmd.forwardmove > 50 && (c.state.gametic & 31) == 0 && ((c.state.gametic >> 5) & 3) == 0) {
            c.state.players[0].message = "Green:  is turbo!";
        }
        if ((cmd.buttons & 128) != 0) {
            if ((cmd.buttons & 3) == 1) c.state.paused = !c.state.paused;
            else if ((cmd.buttons & 3) == 2) revert UnsupportedGameflowProfile(); // saves excluded
        }
        if (c.state.gamestate == GS_LEVEL) {
            h.levelTicker(c, f);
            h.statusTicker(c, f);
            h.automapTicker(c, f);
            h.hudTicker(c, f);
        } else if (c.state.gamestate == GS_INTERMISSION) {
            h.intermissionTicker(c, f);
        } else if (c.state.gamestate == GS_FINALE) {
            h.finaleTicker(c, f);
        } else {
            revert InvalidGameflowTransition(c.state.gamestate, c.state.gameaction);
        }
    }

    /// @custom:source linuxdoom-1.10/g_game.c G_ExitLevel
    function G_ExitLevel(GameState memory state) internal pure {
        state.secretExit = false;
        state.gameaction = 6; // d_event.h ga_completed
    }

    /// @custom:source linuxdoom-1.10/g_game.c G_SecretExitLevel
    function G_SecretExitLevel(GameContext memory c) internal pure {
        c.state.secretExit =
        !(c.state.gamemode == 2 && R_Data.W_CheckNumForName(c.resources.source, "MAP31") < 0);
        c.state.gameaction = 6;
    }

    /// @custom:source linuxdoom-1.10/g_game.c G_PlayerReborn
    function G_PlayerReborn(GameState memory state, uint32 playerId) internal pure {
        Player memory old = state.players[playerId];
        Player memory fresh;
        // Original memcpy preserves these statistics across the memset.
        for (uint256 i; i < 4; ++i) {
            fresh.frags[i] = old.frags[i];
        }
        fresh.killcount = old.killcount;
        fresh.itemcount = old.itemcount;
        fresh.secretcount = old.secretcount;
        fresh.mo = GameConst.NULL;
        fresh.attacker = GameConst.NULL;
        fresh.psprites[0].state = GameConst.NULL;
        fresh.psprites[1].state = GameConst.NULL;
        fresh.usedown = 1;
        fresh.attackdown = 1;
        fresh.playerstate = PlayerState.live;
        fresh.health = 100;
        fresh.readyweapon = 1;
        fresh.pendingweapon = 1;
        fresh.weaponowned[0] = true;
        fresh.weaponowned[1] = true;
        fresh.ammo[0] = 50;
        fresh.maxammo = [int32(200), int32(50), int32(300), int32(50)];
        state.players[playerId] = fresh;
    }

    // Original g_game.c G_BuildTiccmd, declared keyboard profile: zero base command,
    // ticdup=1, single player, no chat/mouse/joystick/save/pause. See INPUT_PROTOCOL.md.
    // Unused original double-click clocks are omitted because device buttons stay zero.
    function G_BuildTiccmd(GameInputState memory state, KeyboardInput memory keys)
        internal
        pure
        returns (Ticcmd memory cmd)
    {
        if (keys.weaponRequest > 9) revert InvalidWeaponRequest(keys.weaponRequest);
        if (state.turnheld < 0) revert InvalidTurnState(state.turnheld);
        bool strafe = keys.strafe;
        uint256 speed = keys.speed ? 1 : 0;
        if (keys.right || keys.left) {
            if (state.turnheld == type(int32).max) revert InvalidTurnState(state.turnheld);
            ++state.turnheld;
        } else {
            state.turnheld = 0;
        }
        uint256 tspeed = state.turnheld < 6 ? 2 : speed;
        int32 side;
        int32 forward;
        int32 sideStep = speed == 0 ? int32(24) : int32(40);
        int16 turnStep = tspeed == 2 ? int16(320) : (tspeed == 0 ? int16(640) : int16(1280));
        if (strafe) {
            if (keys.right) side += sideStep;
            if (keys.left) side -= sideStep;
        } else {
            if (keys.right) cmd.angleturn -= turnStep;
            if (keys.left) cmd.angleturn += turnStep;
        }
        int32 forwardStep = speed == 0 ? int32(25) : int32(50);
        if (keys.up) forward += forwardStep;
        if (keys.down) forward -= forwardStep;
        if (keys.straferight) side += sideStep;
        if (keys.strafeleft) side -= sideStep;
        if (keys.fire) cmd.buttons |= 1; // BT_ATTACK
        if (keys.use) cmd.buttons |= 2; // BT_USE: held, not edge-detected here.
        // The original loop scans i < NUMWEAPONS-1: digit 9 is ignored.
        // Fist/chainsaw and shotgun/supershotgun resolution belongs to P_PlayerThink.
        if (keys.weaponRequest >= 1 && keys.weaponRequest <= 8) {
            cmd.buttons |= 4; // BT_CHANGE
            cmd.buttons |= (keys.weaponRequest - 1) << 3; // BT_WEAPONSHIFT
        }
        if (forward > 50) forward = 50;
        else if (forward < -50) forward = -50;
        if (side > 50) side = 50;
        else if (side < -50) side = -50;
        cmd.forwardmove += int8(forward);
        cmd.sidemove += int8(side);
    }
}
