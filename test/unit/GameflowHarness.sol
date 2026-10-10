// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {G_Game, GameflowState, GameflowHooks} from "../../src/doom/g_game.sol";
import {
    GameContext,
    GameState,
    Player,
    PlayerState,
    Mobj,
    StateDef,
    MobjInfo,
    GameConst
} from "../../src/doom/p_game_state.sol";
import {Ticcmd} from "../../src/doom/d_ticcmd.sol";
import {P_Tick} from "../../src/doom/p_tick.sol";
import {P_User} from "../../src/doom/p_user.sol";

/// @dev Boundary doubles mirror native host.c. Never used by production.
contract GameflowHarness {
    function observe(GameContext memory c, uint32 id) internal pure {
        c.state.brainTargets[c.state.brainTargetOn++] = id;
    }
    function noOp(GameContext memory, GameflowState memory) internal pure {}

    function heap(GameContext memory c, GameflowState memory) internal pure {
        observe(c, 3);
    }

    function stopMap(GameContext memory c, GameflowState memory f) internal pure {
        observe(c, 4);
        f.automapactive = false;
    }

    function startWI(GameContext memory c, GameflowState memory) internal pure {
        observe(c, 5);
    }

    function startFinale(GameContext memory c, GameflowState memory f) internal pure {
        observe(c, 6);
        c.state.gameaction = 0;
        c.state.gamestate = 2;
        f.viewactive = false;
        f.automapactive = false;
    }

    function st(GameContext memory c, GameflowState memory) internal pure {
        observe(c, 7);
    }

    function am(GameContext memory c, GameflowState memory) internal pure {
        observe(c, 8);
    }

    function hu(GameContext memory c, GameflowState memory) internal pure {
        observe(c, 9);
    }

    function wi(GameContext memory c, GameflowState memory) internal pure {
        observe(c, 10);
    }

    function finale(GameContext memory c, GameflowState memory) internal pure {
        observe(c, 11);
    }

    function psprites(GameContext memory c, uint32) internal pure {
        observe(c, 16);
    }

    function specials(GameContext memory c) internal pure {
        observe(c, 14);
    }

    function respawn(GameContext memory c) internal pure {
        observe(c, 15);
    }

    function thinker(GameContext memory c, uint32) internal pure {
        observe(c, 13);
    }

    function playerThink(GameContext memory c, uint32 id) internal view {
        observe(c, 12);
        if (c.state.players[id].playerstate == PlayerState.dead) P_User.P_DeathThink(c, id);
        else if (c.state.players[id].cmd.buttons & 128 != 0) c.state.players[id].cmd.buttons = 0;
    }

    function ticker(GameContext memory c, GameflowState memory) internal view {
        observe(c, 1);
        // A single observing thinker makes P_RunThinkers visible in the call trace.
        P_Tick.P_Ticker(c);
    }

    function flat(GameContext memory c, bytes8 name) internal pure returns (uint32) {
        require(name == "F_SKY1");
        observe(c, 20);
        return 3;
    }

    function texture(GameContext memory c, bytes8 name) internal pure returns (uint32) {
        if (name == "SKY3") {
            observe(c, 23);
            return 9;
        }
        require(name == "SKY1");
        observe(c, 21);
        return 7;
    }

    function setupLevel(GameContext memory c, GameflowState memory) internal pure {
        observe(c, 2);
        c.state.leveltime = 0;
        c.state.totalkills = 0;
        c.state.totalitems = 0;
        c.state.totalsecret = 0;
        for (uint32 i; i < 4; ++i) {
            c.state.players[i].killcount = 0;
            c.state.players[i].itemcount = 0;
            c.state.players[i].secretcount = 0;
        }
        c.state.players[0].viewz = 1;
        for (uint32 i; i < 4; ++i) {
            if (c.state.playeringame[i]) {
                if (c.state.players[i].playerstate == PlayerState.reborn) G_Game.G_PlayerReborn(c.state, i);
                c.state.players[i].mo = i;
                c.state.players[i].playerstate = PlayerState.live;
            }
        }
    }

    function hooks() internal pure returns (GameflowHooks memory h) {
        h.setupLevel = setupLevel;
        h.checkHeap = heap;
        h.levelTicker = ticker;
        h.statusTicker = st;
        h.automapTicker = am;
        h.hudTicker = hu;
        h.automapStop = stopMap;
        h.intermissionStart = startWI;
        h.intermissionTicker = wi;
        h.finaleStart = startFinale;
        h.finaleTicker = finale;
        h.flatNumForName = flat;
        h.textureNumForName = texture;
    }

    function context(int32 map, uint32 flags)
        internal
        pure
        returns (GameContext memory c, GameflowState memory f)
    {
        GameState memory s = c.state;
        s.gameepisode = 1;
        s.gamemap = map;
        s.gamemode = flags & 64 != 0 ? int32(0) : (flags & 32768 != 0 ? int32(1) : int32(3));
        s.gameskill = 2;
        s.gamestate = flags & 1024 != 0 ? int32(1) : (flags & 2048 != 0 ? int32(2) : int32(0));
        s.gameaction = flags & 16384 != 0 ? int32(6) : int32(0);
        s.gametic = 128;
        s.leveltime = 315;
        s.totalkills = 20;
        s.totalitems = 21;
        s.totalsecret = 22;
        s.displayplayer = 3;
        s.prndindex = 77;
        s.rndindex = 88;
        s.skyflatnum = 3;
        s.skytexture = 7;
        s.input.turnheld = 9;
        s.paused = flags & 4 != 0;
        s.menuactive = flags & 8 != 0;
        f.automapactive = flags & 2 != 0;
        f.viewactive = true;
        f.usergame = true;
        s.fastparm = flags & 16 != 0;
        f.respawnparm = flags & 32 != 0;
        s.nomonsters = true;
        f.sendpause = true;
        s.secretExit = flags & 1 != 0;
        f.deferredSkill = 3;
        f.deferredEpisode = 1;
        f.deferredMap = 7;
        f.levelstarttic = 5;
        f.initialized = true;
        s.playeringame[0] = true;
        s.mobjs = new Mobj[](4);
        s.mobjCount = 4;
        for (uint32 i; i < 4; ++i) {
            Player memory p = s.players[i];
            p.mo = i;
            p.attacker = GameConst.NULL;
            p.health = 91 + int32(i);
            p.armorpoints = 30;
            p.armortype = 2;
            p.viewheight = 41 * 65536;
            p.viewz = flags & 4096 != 0 ? int32(1) : int32(41 * 65536);
            p.deltaviewheight = 123;
            p.backpack = true;
            p.readyweapon = 2;
            p.pendingweapon = 10;
            p.attackdown = 1;
            p.cheats = 2;
            p.refire = 3;
            p.killcount = 4 + int32(i);
            p.itemcount = 5 + int32(i);
            p.secretcount = 6 + int32(i);
            p.damagecount = 7;
            p.bonuscount = 8;
            p.extralight = 2;
            p.fixedcolormap = 3;
            p.colormap = 4;
            p.message = "sentinel";
            p.didsecret = flags & 512 != 0;
            s.mobjs[i].flags = GameConst.MF_SHADOW | GameConst.MF_SOLID;
            s.mobjs[i].ceilingz = 128 * 65536;
            s.mobjs[i].allocated = true;
            p.cmd = Ticcmd(3, -4, 5, -6, 7, 8);
            for (uint32 j; j < 6; ++j) {
                p.powers[j] = 10 + int32(j);
                p.cards[j] = true;
            }
            for (uint32 j; j < 4; ++j) {
                p.frags[j] = int32(i * 10 + j + 1);
                p.ammo[j] = 40 + int32(j);
                p.maxammo[j] = 200 + int32(j);
            }
            for (uint32 j; j < 9; ++j) {
                p.weaponowned[j] = true;
            }
            for (uint32 j; j < 2; ++j) {
                p.psprites[j].state = 10 + j;
                p.psprites[j].tics = 9;
                p.psprites[j].sx = 123;
                p.psprites[j].sy = 456;
            }
            f.wminfo.plyr[i].score = 100 + int32(i);
        }
        if (flags & 128 != 0) s.players[0].playerstate = PlayerState.dead;
        if (flags & 256 != 0) s.players[0].playerstate = PlayerState.reborn;
        c.definitions.states = new StateDef[](967);
        c.definitions.mobjinfo = new MobjInfo[](137);
        for (uint32 i = 477; i <= 489; ++i) {
            c.definitions.states[i].tics = int32(i % 5 + 1);
        }
        c.definitions.mobjinfo[16].speed = 15 * 65536;
        c.definitions.mobjinfo[31].speed = 10 * 65536;
        c.definitions.mobjinfo[32].speed = 10 * 65536;
        bind(c);
    }

    function bind(GameContext memory c) internal pure {
        c.map = c.state.map;
        c.move = c.state.move;
        c.path = c.state.path;
        c.state.brainTargets = new uint32[](1024);
        c.state.brainTargetOn = 0;
        c.hooks.playerThink = playerThink;
        c.hooks.movePsprites = psprites;
        c.hooks.updateSpecials = specials;
        c.hooks.respawnSpecials = respawn;
        c.hooks.thinkerDispatch = thinker;
        P_Tick.P_InitThinkers(c.state);
        // Dedicated test thinker: one dispatch per unpaused world tic.
        P_Tick.P_AddThinker(c.state, GameflowHarnessKind(), 0);
    }

    function GameflowHarnessKind() private pure returns (ThinkerKind) {
        return ThinkerKind.glow;
    }

    function tick(
        GameContext memory c,
        GameflowState memory f,
        GameflowHooks memory h,
        uint8 buttons,
        int8 forward
    ) internal view {
        G_Game.G_Ticker(c, f, h, Ticcmd(forward, -2, 320, -5, 65, buttons));
        ++c.state.gametic;
    }

    function run(
        GameContext memory c,
        GameflowState memory f,
        uint32 op,
        int32 map,
        uint32 flags,
        int32 skill,
        int32 episode,
        uint8 buttons
    ) internal view {
        GameflowHooks memory h = hooks();
        if (op == 0) {
            G_Game.G_InitNew(c, f, h, skill, episode, map);
        } else if (op == 1) {
            G_Game.G_DeferedInitNew(c.state, f, skill, episode, map);
            tick(c, f, h, buttons, 12);
        } else if (op == 2) {
            G_Game.G_DoLoadLevel(c, f, h);
        } else if (op == 3) {
            if (flags & 1 != 0) G_Game.G_SecretExitLevel(c);
            else G_Game.G_ExitLevel(c.state);
            tick(c, f, h, buttons, 12);
        } else if (op == 4) {
            G_Game.G_DoCompleted(c, f, h);
        } else if (op == 5) {
            G_Game.G_DoCompleted(c, f, h);
            G_Game.G_WorldDone(c.state, f);
            tick(c, f, h, buttons, 12);
        } else if (op == 6) {
            tick(c, f, h, buttons, flags & 8192 != 0 ? int8(51) : int8(12));
        } else if (op == 7) {
            tick(c, f, h, buttons, 12);
            tick(c, f, h, 0, 12);
            tick(c, f, h, 0, 12);
        } else if (op == 8) {
            G_Game.G_InitNew(c, f, h, 4, 1, 1);
            G_Game.G_InitNew(c, f, h, 4, 1, 1);
            G_Game.G_InitNew(c, f, h, 2, 1, 1);
        } else if (op == 9) {
            G_Game.G_InitNew(c, f, h, 2, 1, 1);
            G_Game.G_InitNew(c, f, h, 2, 1, 1);
        } else if (op == 10) {
            G_Game.G_InitPlayer(c.state, 0);
        } else {
            revert("operation");
        }
    }
}
import {ThinkerKind} from "../../src/doom/p_game_state.sol";
