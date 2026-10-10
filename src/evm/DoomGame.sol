// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {
    GameContext,
    GameState,
    GameConst,
    PlayerState,
    ThinkerKind,
    DoorType,
    FloorType
} from "../doom/p_game_state.sol";
import {ResourceView} from "../doom/r_data_types.sol";
import {RenderContext} from "../doom/r_render_state.sol";
import {RenderThing, PSprite} from "../doom/r_sprite_state.sol";
import {Ticcmd} from "../doom/d_ticcmd.sol";
import {P_Info} from "../doom/p_info.sol";
import {Info, InfoData} from "../doom/info.sol";
import {R_Data} from "../doom/r_data.sol";
import {R_Main} from "../doom/r_main.sol";
import {R_Things} from "../doom/r_things.sol";
import {P_Setup} from "../doom/p_setup.sol";
import {P_Tick} from "../doom/p_tick.sol";
import {P_User} from "../doom/p_user.sol";
import {P_Mobj} from "../doom/p_mobj.sol";
import {P_Map} from "../doom/p_map.sol";
import {P_Sight} from "../doom/p_sight.sol";
import {P_Pspr} from "../doom/p_pspr.sol";
import {P_Inter} from "../doom/p_inter.sol";
import {P_Enemy} from "../doom/p_enemy.sol";
import {P_Spec} from "../doom/p_spec.sol";
import {P_Switch} from "../doom/p_switch.sol";
import {P_Doors} from "../doom/p_doors.sol";
import {P_Floor} from "../doom/p_floor.sol";
import {P_Ceilng} from "../doom/p_ceilng.sol";
import {P_Plats} from "../doom/p_plats.sol";
import {P_Lights} from "../doom/p_lights.sol";
import {G_Game} from "../doom/g_game.sol";
import {DoomRenderer} from "./DoomRenderer.sol";
import {DoomZoneStartup} from "./DoomZoneStartup.sol";
import {ZoneState} from "../doom/z_zone_types.sol";
import {Z_Zone} from "../doom/z_zone.sol";

/// @notice Integrator adapter for original gameplay, persistent globals and renderer projection.
/// @dev No world decisions or pixels are accepted from a host. Hooks are internal calls only.
library DoomGame {
    error InvalidThinkerKind();
    error InvalidGameplayState();

    function hooks(GameContext memory c) private pure {
        c.hooks.tryMove = P_Map.P_TryMove;
        c.hooks.checkPosition = P_Map.P_CheckPosition;
        c.hooks.teleportMove = P_Map.P_TeleportMove;
        c.hooks.slideMove = P_Map.P_SlideMove;
        c.hooks.checkSight = P_Sight.P_CheckSight;
        c.hooks.aimLineAttack = P_Map.P_AimLineAttack;
        c.hooks.lineAttack = P_Map.P_LineAttack;
        c.hooks.radiusAttack = P_Map.P_RadiusAttack;
        c.hooks.useLines = P_Map.P_UseLines;
        c.hooks.changeSector = P_Map.P_ChangeSector;
        c.hooks.spawnMobj = P_Mobj.P_SpawnMobj;
        c.hooks.removeMobj = P_Mobj.P_RemoveMobj;
        c.hooks.setMobjState = P_Mobj.P_SetMobjState;
        c.hooks.spawnPuff = P_Mobj.P_SpawnPuff;
        c.hooks.spawnBlood = P_Mobj.P_SpawnBlood;
        c.hooks.spawnMissile = P_Mobj.P_SpawnMissile;
        c.hooks.spawnPlayerMissile = P_Mobj.P_SpawnPlayerMissile;
        c.hooks.damageMobj = P_Inter.P_DamageMobj;
        c.hooks.touchSpecialThing = P_Inter.P_TouchSpecialThing;
        c.hooks.actionMobj = actionMobj;
        c.hooks.actionPSprite = actionPSprite;
        c.hooks.playerThink = P_User.P_PlayerThink;
        c.hooks.movePsprites = P_Pspr.P_MovePsprites;
        c.hooks.setupPsprites = P_Pspr.P_SetupPsprites;
        c.hooks.dropWeapon = P_Pspr.P_DropWeapon;
        c.hooks.respawnSpecials = P_Mobj.P_RespawnSpecials;
        c.hooks.crossSpecialLine = P_Spec.P_CrossSpecialLine;
        c.hooks.useSpecialLine = P_Switch.P_UseSpecialLine;
        c.hooks.shootSpecialLine = P_Spec.P_ShootSpecialLine;
        c.hooks.playerSpecialSector = P_Spec.P_PlayerInSpecialSector;
        c.hooks.updateSpecials = P_Spec.P_UpdateSpecials;
        c.hooks.spawnSpecials = P_Spec.P_SpawnSpecials;
        c.hooks.noiseAlert = P_Enemy.P_NoiseAlert;
        c.hooks.thinkerDispatch = thinker;
        c.hooks.bossDoFloor = bossFloor;
        c.hooks.bossDoDoor = bossDoor;
        c.hooks.exitLevel = exitLevel;
    }

    function aliases(GameContext memory c) private pure {
        c.map = c.state.map;
        c.move = c.state.move;
        c.path = c.state.path;
        c.resources.texturetranslation = c.state.texturetranslation;
        c.resources.flattranslation = c.state.flattranslation;
        c.resources.nativeZone = c.state.nativeZone;
    }

    /// @dev Original R_Init/R_InitSprites allocation phase precedes G_InitNew.
    /// No gameplay state, RNG, command, tic or frame is consumed by preparation.
    function prepareZone(ResourceView memory source) internal view returns (ZoneState memory zone) {
        RenderContext memory renderer;
        renderer.resources = R_Data.R_InitDataLazy(source);
        R_Things.R_InitSprites(renderer, Info.load().spriteNames);
        zone =
            Z_Zone.Z_Init(64 * 1024 * 1024, uint32(source.lumps.length + renderer.resources.textures.length));
        DoomZoneStartup.replay(zone, renderer.resources, renderer.sprite.definitions);
    }

    /// @dev Original G_InitNew profile: retail E1M1, medium skill, one player, deterministic seed.
    function initialize(ResourceView memory source, bool nomonsters)
        internal
        view
        returns (GameContext memory c)
    {
        ZoneState memory disabled;
        return initializeWithZone(source, nomonsters, disabled);
    }

    function initializeWithZone(ResourceView memory source, bool nomonsters, ZoneState memory zone)
        internal
        view
        returns (GameContext memory c)
    {
        c.resources = R_Data.R_InitDataLazy(source);
        c.state.nativeZone = zone;
        initializeContext(c, nomonsters);
    }

    /// @notice Original resource preparation and level initialization in one call.
    /// @dev Decode resources once, then replay R_Init/R_InitSprites before G_InitNew.
    /// No native allocation tape, prepared world or pixels enter the engine.
    function initializeNative(ResourceView memory source, bool nomonsters)
        internal
        view
        returns (GameContext memory c)
    {
        return initializeNativeWithPolicy(source, nomonsters, false);
    }

    /// @dev Explicit local-platform zone initialization; original allocation and
    /// renderer algorithms remain unchanged. Strict callers retain false.
    function initializeNativeWithPolicy(ResourceView memory source, bool nomonsters, bool initializeZone)
        internal
        view
        returns (GameContext memory c)
    {
        c.resources = R_Data.R_InitDataLazy(source);
        RenderContext memory renderer;
        renderer.resources = c.resources;
        R_Things.R_InitSprites(renderer, Info.load().spriteNames);
        c.state.nativeZone =
            Z_Zone.Z_Init(64 * 1024 * 1024, uint32(source.lumps.length + c.resources.textures.length));
        c.state.nativeZone.deterministicInitialization = initializeZone;
        DoomZoneStartup.replay(c.state.nativeZone, c.resources, renderer.sprite.definitions);
        initializeContext(c, nomonsters);
    }

    function initializeContext(GameContext memory c, bool nomonsters) private view {
        c.definitions = P_Info.load();
        c.state.gameskill = 2;
        c.state.gamemode = 3;
        c.state.gameepisode = 1;
        c.state.gamemap = 1;
        c.state.nomonsters = nomonsters;
        c.state.playeringame[0] = true;
        for (uint32 i; i < 4; ++i) {
            c.state.players[i].playerstate = PlayerState.reborn;
            c.state.players[i].mo = GameConst.NULL;
            c.state.players[i].attacker = GameConst.NULL;
            c.state.players[i].psprites[0].state = GameConst.NULL;
            c.state.players[i].psprites[1].state = GameConst.NULL;
        }
        c.state.texturetranslation = c.resources.texturetranslation;
        c.state.flattranslation = c.resources.flattranslation;
        c.state.skyflatnum = R_Data.R_FlatNumForName(c.resources, "F_SKY1");
        c.state.skytexture = R_Data.R_TextureNumForName(c.resources, "SKY1");
        c.state.validcount = 1; // original r_main.c initialization, shared by gameplay and renderer
        c.state.move.tmthing = GameConst.NULL;
        c.state.move.ceilingline = GameConst.NULL;
        c.state.move.bestslideline = GameConst.NULL;
        c.state.move.secondslideline = GameConst.NULL;
        c.state.move.slidemo = GameConst.NULL;
        c.state.move.linetarget = GameConst.NULL;
        c.state.move.shootthing = GameConst.NULL;
        c.state.move.usething = GameConst.NULL;
        c.state.move.bombspot = GameConst.NULL;
        c.state.move.bombsource = GameConst.NULL;
        c.state.move.soundtarget = GameConst.NULL;
        aliases(c);
        hooks(c);
        P_Setup.P_Init(c);
        P_Setup.P_SetupLevel(c, 1, 1, 0, 2);
    }

    function load(ResourceView memory source, GameState memory state)
        internal
        view
        returns (GameContext memory c)
    {
        c.state = state;
        c.resources = R_Data.R_InitDataLazy(source);
        c.definitions = P_Info.load();
        aliases(c);
        hooks(c);
    }

    function tick(GameContext memory c, Ticcmd memory cmd) internal view {
        c.state.players[uint32(c.state.consoleplayer)].cmd = cmd;
        P_Tick.P_Ticker(c);
        ++c.state.gametic; // original outer loop, independent of whether P_Ticker paused
    }

    function render(GameContext memory c) internal view returns (bytes memory pixels) {
        RenderContext memory r;
        r.map = c.map;
        r.resources = c.resources;
        r.skyflatnum = c.state.skyflatnum;
        r.skytexture = c.state.skytexture;
        r.skytexturemid = 100 * 65536;
        if (c.state.renderFramebuffer.length != 64000) c.state.renderFramebuffer = new bytes(64000);
        r.rs.framebuffer = c.state.renderFramebuffer;
        r.rs.validcount = c.state.validcount;
        r.rs.framecount = c.state.renderFramecount;
        r.rs.fuzzpos = c.state.renderFuzzpos;
        r.wall = c.state.renderWall;
        r.plane = c.state.renderPlane;
        R_Main.R_InitLightTables(r.rs);
        R_Main.R_ExecuteSetViewSize(r.rs, 11, 0);
        InfoData memory info = Info.load();
        R_Things.R_InitSprites(r, info.spriteNames);
        r.sectorValidcount = new uint32[](c.state.sectors.length);
        r.sprite.sectorHeads = new uint32[](c.state.sectors.length);
        for (uint32 i; i < c.state.sectors.length; ++i) {
            r.sectorValidcount[i] = c.state.sectors[i].validcount;
            r.sprite.sectorHeads[i] = c.state.sectors[i].thinglist;
        }
        r.sprite.things = new RenderThing[](c.state.mobjCount);
        for (uint32 i; i < c.state.mobjCount; ++i) {
            r.sprite.things[i] = RenderThing(
                c.state.mobjs[i].x,
                c.state.mobjs[i].y,
                c.state.mobjs[i].z,
                c.state.mobjs[i].angle,
                c.state.mobjs[i].sprite,
                c.state.mobjs[i].frame,
                c.state.mobjs[i].flags,
                c.map.subsectors[c.state.mobjs[i].subsector].sector,
                c.state.mobjs[i].snext
            );
        }
        uint32 player = uint32(c.state.displayplayer);
        uint32 mo = c.state.players[player].mo;
        if (mo == GameConst.NULL || mo >= c.state.mobjCount) revert InvalidGameplayState();
        r.rs.viewx = c.state.mobjs[mo].x;
        r.rs.viewy = c.state.mobjs[mo].y;
        r.rs.viewz = c.state.players[player].viewz;
        r.rs.viewangle = c.state.mobjs[mo].angle;
        r.rs.extralight = c.state.players[player].extralight;
        r.rs.fixedcolormap =
            c.state.players[player].fixedcolormap == 0 ? int32(-1) : c.state.players[player].fixedcolormap;
        r.sprite.playerSector = c.map.subsectors[c.state.mobjs[mo].subsector].sector;
        r.sprite.invisibility = c.state.players[player].powers[2];
        for (uint32 i; i < 2; ++i) {
            uint32 state = c.state.players[player].psprites[i].state;
            if (state != GameConst.NULL) {
                r.sprite.psprites[i] = PSprite(
                    true,
                    c.definitions.states[state].sprite,
                    c.definitions.states[state].frame,
                    c.state.players[player].psprites[i].sx,
                    c.state.players[player].psprites[i].sy
                );
            }
        }
        DoomRenderer.render(r);
        c.state.validcount = r.rs.validcount;
        c.state.renderFramecount = r.rs.framecount;
        c.state.renderFuzzpos = r.rs.fuzzpos;
        c.state.renderWall = r.wall;
        c.state.renderPlane = r.plane;
        for (uint32 i; i < c.state.sectors.length; ++i) {
            c.state.sectors[i].validcount = r.sectorValidcount[i];
        }
        pixels = r.rs.framebuffer;
    }

    function thinker(GameContext memory c, uint32 id) private view {
        ThinkerKind kind = c.state.thinkers[id].kind;
        uint32 payload = c.state.thinkers[id].payload;
        if (kind == ThinkerKind.mobj) P_Mobj.P_MobjThinker(c, payload);
        else if (kind == ThinkerKind.door) P_Doors.T_VerticalDoor(c, payload);
        else if (kind == ThinkerKind.floor) P_Floor.T_MoveFloor(c, payload);
        else if (kind == ThinkerKind.ceiling) P_Ceilng.T_MoveCeiling(c, payload);
        else if (kind == ThinkerKind.plat) P_Plats.T_PlatRaise(c, payload);
        else if (kind == ThinkerKind.fireFlicker) P_Lights.T_FireFlicker(c, payload);
        else if (kind == ThinkerKind.lightFlash) P_Lights.T_LightFlash(c, payload);
        else if (kind == ThinkerKind.strobe) P_Lights.T_StrobeFlash(c, payload);
        else if (kind == ThinkerKind.glow) P_Lights.T_Glow(c, payload);
        else revert InvalidThinkerKind();
    }

    function actionMobj(GameContext memory c, uint32 action, uint32 actor) private view {
        if (action == P_Info.A_BFGSpray) P_Pspr.A_BFGSpray(c, actor);
        else P_Enemy.action(c, action, actor);
    }

    function actionPSprite(GameContext memory c, uint32 action, uint32 player, uint32 slot) private view {
        if (action == P_Info.A_OpenShotgun2) P_Enemy.A_OpenShotgun2(c, player, slot);
        else if (action == P_Info.A_LoadShotgun2) P_Enemy.A_LoadShotgun2(c, player, slot);
        else if (action == P_Info.A_CloseShotgun2) P_Enemy.A_CloseShotgun2(c, player, slot);
        else P_Pspr.actionPSprite(c, action, player, slot);
    }

    function bossFloor(GameContext memory c, int32 tag, FloorType kind) private view returns (bool) {
        return P_Floor.EV_DoFloorTag(c, tag, kind) != 0;
    }

    function bossDoor(GameContext memory c, int32 tag, DoorType kind) private pure returns (bool) {
        return P_Doors.EV_DoDoorTag(c, tag, kind) != 0;
    }

    function exitLevel(GameContext memory c) private pure {
        G_Game.G_ExitLevel(c.state);
    }
}
