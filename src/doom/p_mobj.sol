// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;

import {
    GameContext,
    GameConst,
    Player,
    PlayerState,
    Mobj,
    MobjInfo,
    StateDef,
    ThinkerKind
} from "./p_game_state.sol";
import {MapThing} from "./r_defs.sol";
import {RenderState} from "./r_state.sol";
import {M_Fixed} from "./m_fixed.sol";
import {M_Random} from "./m_random.sol";
import {P_Info} from "./p_info.sol";
import {P_Heap} from "./p_heap.sol";
import {P_Tick} from "./p_tick.sol";
import {P_MapUtl} from "./p_maputl.sol";
import {R_Main} from "./r_main.sol";
import {Tables} from "./tables.sol";
import {G_Game} from "./g_game.sol";

/// @custom:source linuxdoom-1.10/p_mobj.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @dev Sound-device calls are omitted; gameplay noise propagation is a separate original call.
library P_Mobj {
    error UnknownMapThing(int16 kind);
    error InvalidMissileSpeed();

    function P_SetMobjState(GameContext memory c, uint32 id, uint32 state) internal view returns (bool) {
        Mobj memory mo = c.state.mobjs[id];
        do {
            if (state == P_Info.S_NULL) {
                mo.state = GameConst.NULL;
                P_RemoveMobj(c, id);
                return false;
            }
            StateDef memory st = c.definitions.states[state];
            mo.state = state;
            mo.tics = st.tics;
            mo.sprite = st.sprite;
            mo.frame = st.frame;
            if (st.action != 0) c.hooks.actionMobj(c, st.action, id);
            state = st.nextstate;
        } while (mo.tics == 0);
        return true;
    }

    function P_ExplodeMissile(GameContext memory c, uint32 id) internal view {
        Mobj memory mo = c.state.mobjs[id];
        mo.momx = 0;
        mo.momy = 0;
        mo.momz = 0;
        P_SetMobjState(c, id, uint32(c.definitions.mobjinfo[mo.mobjType].deathstate));
        unchecked {
            mo.tics -= M_Random.P_Random(c.state) & 3;
        }
        if (mo.tics < 1) mo.tics = 1;
        mo.flags &= ~GameConst.MF_MISSILE;
    }

    function P_XYMovement(GameContext memory c, uint32 id) internal view {
        Mobj memory mo = c.state.mobjs[id];
        if (mo.momx == 0 && mo.momy == 0) {
            if ((mo.flags & GameConst.MF_SKULLFLY) != 0) {
                mo.flags &= ~GameConst.MF_SKULLFLY;
                mo.momx = 0;
                mo.momy = 0;
                mo.momz = 0;
                P_SetMobjState(c, id, uint32(c.definitions.mobjinfo[mo.mobjType].spawnstate));
            }
            return;
        }
        uint32 playerId = mo.player;
        if (mo.momx > GameConst.MAXMOVE) mo.momx = GameConst.MAXMOVE;
        else if (mo.momx < -GameConst.MAXMOVE) mo.momx = -GameConst.MAXMOVE;
        if (mo.momy > GameConst.MAXMOVE) mo.momy = GameConst.MAXMOVE;
        else if (mo.momy < -GameConst.MAXMOVE) mo.momy = -GameConst.MAXMOVE;
        int32 xmove = mo.momx;
        int32 ymove = mo.momy;
        unchecked {
            do {
                int32 ptryx;
                int32 ptryy;
                // Original asymmetry: only large positive moves trigger subdivision.
                if (xmove > GameConst.MAXMOVE / 2 || ymove > GameConst.MAXMOVE / 2) {
                    ptryx = mo.x + xmove / 2;
                    ptryy = mo.y + ymove / 2;
                    xmove >>= 1;
                    ymove >>= 1;
                } else {
                    ptryx = mo.x + xmove;
                    ptryy = mo.y + ymove;
                    xmove = 0;
                    ymove = 0;
                }
                if (!c.hooks.tryMove(c, id, ptryx, ptryy)) {
                    if (mo.player != GameConst.NULL) {
                        c.hooks.slideMove(c, id);
                    } else if ((mo.flags & GameConst.MF_MISSILE) != 0) {
                        uint32 ceilingline = c.move.ceilingline;
                        if (ceilingline != GameConst.NULL) {
                            uint32 back = c.map.lines[ceilingline].backsector;
                            if (
                                back != GameConst.NULL && c.map.sectors[back].ceilingpic == c.state.skyflatnum
                            ) {
                                P_RemoveMobj(c, id);
                                return;
                            }
                        }
                        P_ExplodeMissile(c, id);
                    } else {
                        mo.momx = 0;
                        mo.momy = 0;
                    }
                }
            } while (xmove != 0 || ymove != 0);
            if (
                playerId != GameConst.NULL
                    && (c.state.players[playerId].cheats & GameConst.CF_NOMOMENTUM) != 0
            ) {
                mo.momx = 0;
                mo.momy = 0;
                return;
            }
            if ((mo.flags & (GameConst.MF_MISSILE | GameConst.MF_SKULLFLY)) != 0) return;
            if (mo.z > mo.floorz) return;
            if ((mo.flags & GameConst.MF_CORPSE) != 0) {
                if (
                    mo.momx > 65536 / 4 || mo.momx < -65536 / 4 || mo.momy > 65536 / 4 || mo.momy < -65536 / 4
                ) {
                    if (mo.floorz != c.map.sectors[c.map.subsectors[mo.subsector].sector].floorheight) {
                        return;
                    }
                }
            }
            if (
                mo.momx > -0x1000 && mo.momx < 0x1000 && mo.momy > -0x1000 && mo.momy < 0x1000
                    && (playerId == GameConst.NULL
                        || (c.state.players[playerId].cmd.forwardmove == 0
                            && c.state.players[playerId].cmd.sidemove == 0))
            ) {
                if (
                    playerId != GameConst.NULL
                        && uint32(c.state.mobjs[c.state.players[playerId].mo].state - P_Info.S_PLAY_RUN1) < 4
                ) {
                    P_SetMobjState(c, c.state.players[playerId].mo, P_Info.S_PLAY);
                }
                mo.momx = 0;
                mo.momy = 0;
            } else {
                mo.momx = M_Fixed.FixedMul(mo.momx, 0xe800);
                mo.momy = M_Fixed.FixedMul(mo.momy, 0xe800);
            }
        }
    }

    function P_ZMovement(GameContext memory c, uint32 id) internal view {
        Mobj memory mo = c.state.mobjs[id];
        unchecked {
            if (mo.player != GameConst.NULL && mo.z < mo.floorz) {
                Player memory player = c.state.players[mo.player];
                player.viewheight -= mo.floorz - mo.z;
                player.deltaviewheight = (GameConst.VIEWHEIGHT - player.viewheight) >> 3;
            }
            mo.z += mo.momz;
            if ((mo.flags & GameConst.MF_FLOAT) != 0 && mo.target != GameConst.NULL) {
                if ((mo.flags & (GameConst.MF_SKULLFLY | GameConst.MF_INFLOAT)) == 0) {
                    Mobj memory target = c.state.mobjs[mo.target];
                    int32 dist = P_MapUtl.P_AproxDistance(mo.x - target.x, mo.y - target.y);
                    int32 delta = (target.z + (mo.height >> 1)) - mo.z;
                    if (delta < 0 && dist < -(delta * 3)) mo.z -= GameConst.FLOATSPEED;
                    else if (delta > 0 && dist < delta * 3) mo.z += GameConst.FLOATSPEED;
                }
            }
            if (mo.z <= mo.floorz) {
                if ((mo.flags & GameConst.MF_SKULLFLY) != 0) mo.momz = -mo.momz;
                if (mo.momz < 0) {
                    if (mo.player != GameConst.NULL && mo.momz < -GameConst.GRAVITY * 8) {
                        c.state.players[mo.player].deltaviewheight = mo.momz >> 3;
                    }
                    mo.momz = 0;
                }
                mo.z = mo.floorz;
                if ((mo.flags & GameConst.MF_MISSILE) != 0 && (mo.flags & GameConst.MF_NOCLIP) == 0) {
                    P_ExplodeMissile(c, id);
                    return;
                }
            } else if ((mo.flags & GameConst.MF_NOGRAVITY) == 0) {
                if (mo.momz == 0) mo.momz = -GameConst.GRAVITY * 2;
                else mo.momz -= GameConst.GRAVITY;
            }
            if (mo.z + mo.height > mo.ceilingz) {
                if (mo.momz > 0) mo.momz = 0;
                mo.z = mo.ceilingz - mo.height;
                if ((mo.flags & GameConst.MF_SKULLFLY) != 0) mo.momz = -mo.momz;
                if ((mo.flags & GameConst.MF_MISSILE) != 0 && (mo.flags & GameConst.MF_NOCLIP) == 0) {
                    P_ExplodeMissile(c, id);
                    return;
                }
            }
        }
    }

    function P_NightmareRespawn(GameContext memory c, uint32 id) internal view {
        Mobj memory old = c.state.mobjs[id];
        int32 x = int32(old.spawnpoint.x) * 65536;
        int32 y = int32(old.spawnpoint.y) * 65536;
        if (!c.hooks.checkPosition(c, id, x, y)) return;
        P_SpawnMobj(
            c, old.x, old.y, c.map.sectors[c.map.subsectors[old.subsector].sector].floorheight, P_Info.MT_TFOG
        );
        uint32 ss = R_Main.R_PointInSubsector(x, y, c.map);
        P_SpawnMobj(c, x, y, c.map.sectors[c.map.subsectors[ss].sector].floorheight, P_Info.MT_TFOG);
        int32 z = (uint32(c.definitions.mobjinfo[old.mobjType].flags) & GameConst.MF_SPAWNCEILING) != 0
            ? GameConst.ONCEILINGZ
            : GameConst.ONFLOORZ;
        uint32 freshId = P_SpawnMobj(c, x, y, z, old.mobjType);
        Mobj memory fresh = c.state.mobjs[freshId];
        fresh.spawnpoint = old.spawnpoint;
        unchecked {
            fresh.angle = Tables.ANG45 * uint32(int32(old.spawnpoint.angle) / 45);
        }
        if ((old.spawnpoint.options & 8) != 0) fresh.flags |= GameConst.MF_AMBUSH;
        fresh.reactiontime = 18;
        P_RemoveMobj(c, id);
    }

    function P_MobjThinker(GameContext memory c, uint32 id) internal view {
        Mobj memory mo = c.state.mobjs[id];
        if (mo.momx != 0 || mo.momy != 0 || (mo.flags & GameConst.MF_SKULLFLY) != 0) {
            P_XYMovement(c, id);
            if (c.state.thinkers[mo.thinker].status == GameConst.THINKER_REMOVE) return;
        }
        if (mo.z != mo.floorz || mo.momz != 0) {
            P_ZMovement(c, id);
            if (c.state.thinkers[mo.thinker].status == GameConst.THINKER_REMOVE) return;
        }
        unchecked {
            if (mo.tics != -1) {
                --mo.tics;
                if (mo.tics == 0 && !P_SetMobjState(c, id, c.definitions.states[mo.state].nextstate)) return;
            } else {
                if ((mo.flags & GameConst.MF_COUNTKILL) == 0 || !c.state.respawnmonsters) return;
                ++mo.movecount;
                if (mo.movecount < 12 * 35 || (c.state.leveltime & 31) != 0 || M_Random.P_Random(c.state) > 4)
                {
                    return;
                }
                P_NightmareRespawn(c, id);
            }
        }
    }

    function P_SpawnMobj(GameContext memory c, int32 x, int32 y, int32 z, uint32 kind)
        internal
        pure
        returns (uint32 id)
    {
        id = P_Heap.allocateMobj(c.state);
        Mobj memory mo = c.state.mobjs[id];
        MobjInfo memory info = c.definitions.mobjinfo[kind];
        mo.mobjType = kind;
        mo.x = x;
        mo.y = y;
        mo.radius = info.radius;
        mo.height = info.height;
        mo.flags = uint32(info.flags);
        mo.health = info.spawnhealth;
        mo.target = GameConst.NULL;
        mo.tracer = GameConst.NULL;
        mo.player = GameConst.NULL;
        mo.snext = GameConst.NULL;
        mo.sprev = GameConst.NULL;
        mo.bnext = GameConst.NULL;
        mo.bprev = GameConst.NULL;
        mo.allocated = true;
        if (c.state.gameskill != 4) mo.reactiontime = info.reactiontime;
        mo.lastlook = M_Random.P_Random(c.state) % 4;
        // Spawn copies the initial state without calling its action.
        mo.state = uint32(info.spawnstate);
        StateDef memory st = c.definitions.states[mo.state];
        mo.tics = st.tics;
        mo.sprite = st.sprite;
        mo.frame = st.frame;
        P_MapUtl.P_SetThingPosition(c, id);
        uint32 sector = c.map.subsectors[mo.subsector].sector;
        mo.floorz = c.map.sectors[sector].floorheight;
        mo.ceilingz = c.map.sectors[sector].ceilingheight;
        if (z == GameConst.ONFLOORZ) {
            mo.z = mo.floorz;
        } else if (z == GameConst.ONCEILINGZ) {
            unchecked {
                mo.z = mo.ceilingz - info.height;
            }
        } else {
            mo.z = z;
        }
        mo.thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.mobj, id);
    }

    function P_RemoveMobj(GameContext memory c, uint32 id) internal pure {
        Mobj memory mo = c.state.mobjs[id];
        if (
            (mo.flags & GameConst.MF_SPECIAL) != 0 && (mo.flags & GameConst.MF_DROPPED) == 0
                && mo.mobjType != P_Info.MT_INV && mo.mobjType != P_Info.MT_INS
        ) {
            c.state.itemrespawnque[c.state.iquehead] = mo.spawnpoint;
            c.state.itemrespawntime[c.state.iquehead] = c.state.leveltime;
            c.state.iquehead = (c.state.iquehead + 1) & 127;
            if (c.state.iquehead == c.state.iquetail) c.state.iquetail = (c.state.iquetail + 1) & 127;
        }
        P_MapUtl.P_UnsetThingPosition(c, id);
        P_Tick.P_RemoveThinker(c.state, mo.thinker);
    }

    function P_RespawnSpecials(GameContext memory c) internal pure {
        if (c.state.deathmatch != 2 || c.state.iquehead == c.state.iquetail) return;
        unchecked {
            if (c.state.leveltime - c.state.itemrespawntime[c.state.iquetail] < 30 * 35) return;
        }
        MapThing memory thing = c.state.itemrespawnque[c.state.iquetail];
        int32 x = int32(thing.x) * 65536;
        int32 y = int32(thing.y) * 65536;
        uint32 ss = R_Main.R_PointInSubsector(x, y, c.map);
        P_SpawnMobj(c, x, y, c.map.sectors[c.map.subsectors[ss].sector].floorheight, P_Info.MT_IFOG);
        uint32 kind = findType(c, thing.thingType);
        int32 z = (uint32(c.definitions.mobjinfo[kind].flags) & GameConst.MF_SPAWNCEILING) != 0
            ? GameConst.ONCEILINGZ
            : GameConst.ONFLOORZ;
        uint32 id = P_SpawnMobj(c, x, y, z, kind);
        c.state.mobjs[id].spawnpoint = thing;
        unchecked {
            c.state.mobjs[id].angle = Tables.ANG45 * uint32(int32(thing.angle) / 45);
        }
        c.state.iquetail = (c.state.iquetail + 1) & 127;
    }

    function P_SpawnPlayer(GameContext memory c, MapThing memory thing) internal view {
        if (thing.thingType < 1 || thing.thingType > 4) revert UnknownMapThing(thing.thingType);
        uint32 playerId = uint32(int32(thing.thingType) - 1);
        if (!c.state.playeringame[playerId]) return;
        if (c.state.players[playerId].playerstate == PlayerState.reborn) {
            G_Game.G_PlayerReborn(c.state, playerId);
        }
        Player memory player = c.state.players[playerId];
        uint32 id = P_SpawnMobj(
            c, int32(thing.x) * 65536, int32(thing.y) * 65536, GameConst.ONFLOORZ, P_Info.MT_PLAYER
        );
        Mobj memory mo = c.state.mobjs[id];
        if (thing.thingType > 1) mo.flags |= playerId << GameConst.MF_TRANSSHIFT;
        unchecked {
            mo.angle = Tables.ANG45 * uint32(int32(thing.angle) / 45);
        }
        mo.player = playerId;
        mo.health = player.health;
        player.mo = id;
        player.playerstate = PlayerState.live;
        player.refire = 0;
        player.message = "";
        player.damagecount = 0;
        player.bonuscount = 0;
        player.extralight = 0;
        player.fixedcolormap = 0;
        player.viewheight = GameConst.VIEWHEIGHT;
        c.hooks.setupPsprites(c, playerId);
        if (c.state.deathmatch != 0) {
            for (uint32 i; i < 6; ++i) {
                player.cards[i] = true;
            }
        }
        // Original console-player ST_Start/HU_Start boundary; legacy hosts opt out.
        if (c.playerUIEnabled && playerId == uint32(c.state.consoleplayer)) {
            c.hooks.startPlayerUI(c, playerId);
        }
    }

    function findType(GameContext memory c, int16 doomednum) private pure returns (uint32) {
        for (uint32 i; i < c.definitions.mobjinfo.length; ++i) {
            if (c.definitions.mobjinfo[i].doomednum == doomednum) return i;
        }
        revert UnknownMapThing(doomednum);
    }

    function P_SpawnMapThing(GameContext memory c, MapThing memory thing) internal view {
        if (thing.thingType == 11) {
            if (c.state.deathmatchStartCount < 10) {
                c.state.deathmatchstarts[c.state.deathmatchStartCount++] = thing;
            }
            return;
        }
        if (thing.thingType <= 4) {
            if (thing.thingType < 1) revert UnknownMapThing(thing.thingType);
            c.state.playerstarts[uint32(int32(thing.thingType) - 1)] = thing;
            if (c.state.deathmatch == 0) P_SpawnPlayer(c, thing);
            return;
        }
        if (!c.state.netgame && (thing.options & 16) != 0) return;
        int32 bit = c.state.gameskill == 0
            ? int32(1)
            : (c.state.gameskill == 4 ? int32(4) : int32(1) << uint32(c.state.gameskill - 1));
        if ((int32(thing.options) & bit) == 0) return;
        uint32 kind = findType(c, thing.thingType);
        uint32 flags = uint32(c.definitions.mobjinfo[kind].flags);
        if (c.state.deathmatch != 0 && (flags & GameConst.MF_NOTDMATCH) != 0) return;
        if (c.state.nomonsters && (kind == P_Info.MT_SKULL || (flags & GameConst.MF_COUNTKILL) != 0)) return;
        int32 z = (flags & GameConst.MF_SPAWNCEILING) != 0 ? GameConst.ONCEILINGZ : GameConst.ONFLOORZ;
        uint32 id = P_SpawnMobj(c, int32(thing.x) * 65536, int32(thing.y) * 65536, z, kind);
        Mobj memory mo = c.state.mobjs[id];
        mo.spawnpoint = thing;
        if (mo.tics > 0) mo.tics = 1 + M_Random.P_Random(c.state) % mo.tics;
        if ((mo.flags & GameConst.MF_COUNTKILL) != 0) ++c.state.totalkills;
        if ((mo.flags & GameConst.MF_COUNTITEM) != 0) ++c.state.totalitems;
        unchecked {
            mo.angle = Tables.ANG45 * uint32(int32(thing.angle) / 45);
        }
        if ((thing.options & 8) != 0) mo.flags |= GameConst.MF_AMBUSH;
    }

    function P_SpawnPuff(GameContext memory c, int32 x, int32 y, int32 z) internal view {
        int32 first = M_Random.P_Random(c.state);
        int32 second = M_Random.P_Random(c.state);
        unchecked {
            z += (first - second) << 10;
        }
        uint32 id = P_SpawnMobj(c, x, y, z, P_Info.MT_PUFF);
        Mobj memory mo = c.state.mobjs[id];
        mo.momz = 65536;
        unchecked {
            mo.tics -= M_Random.P_Random(c.state) & 3;
        }
        if (mo.tics < 1) mo.tics = 1;
        if (c.move.attackrange == GameConst.MELEERANGE) P_SetMobjState(c, id, P_Info.S_PUFF3);
    }

    function P_SpawnBlood(GameContext memory c, int32 x, int32 y, int32 z, int32 damage) internal view {
        int32 first = M_Random.P_Random(c.state);
        int32 second = M_Random.P_Random(c.state);
        unchecked {
            z += (first - second) << 10;
        }
        uint32 id = P_SpawnMobj(c, x, y, z, P_Info.MT_BLOOD);
        Mobj memory mo = c.state.mobjs[id];
        mo.momz = 2 * 65536;
        unchecked {
            mo.tics -= M_Random.P_Random(c.state) & 3;
        }
        if (mo.tics < 1) mo.tics = 1;
        if (damage <= 12 && damage >= 9) P_SetMobjState(c, id, P_Info.S_BLOOD2);
        else if (damage < 9) P_SetMobjState(c, id, P_Info.S_BLOOD3);
    }

    function P_CheckMissileSpawn(GameContext memory c, uint32 id) internal view {
        Mobj memory mo = c.state.mobjs[id];
        unchecked {
            mo.tics -= M_Random.P_Random(c.state) & 3;
            if (mo.tics < 1) mo.tics = 1;
            mo.x += mo.momx >> 1;
            mo.y += mo.momy >> 1;
            mo.z += mo.momz >> 1;
        }
        if (!c.hooks.tryMove(c, id, mo.x, mo.y)) P_ExplodeMissile(c, id);
    }

    function P_SpawnMissile(GameContext memory c, uint32 sourceId, uint32 destId, uint32 kind)
        internal
        view
        returns (uint32 id)
    {
        Mobj memory source = c.state.mobjs[sourceId];
        Mobj memory dest = c.state.mobjs[destId];
        int32 z;
        unchecked {
            z = source.z + 32 * 65536;
        }
        id = P_SpawnMobj(c, source.x, source.y, z, kind);
        Mobj memory mo = c.state.mobjs[id];
        mo.target = sourceId;
        RenderState memory geometry;
        uint32 angle = R_Main.R_PointToAngle2(geometry, source.x, source.y, dest.x, dest.y);
        unchecked {
            if ((dest.flags & GameConst.MF_SHADOW) != 0) {
                int32 first = M_Random.P_Random(c.state);
                int32 second = M_Random.P_Random(c.state);
                angle += uint32((first - second) << 20);
            }
            mo.angle = angle;
            int32 speed = c.definitions.mobjinfo[kind].speed;
            if (speed == 0) revert InvalidMissileSpeed();
            mo.momx = M_Fixed.FixedMul(speed, Tables.finecosine(angle >> 19));
            mo.momy = M_Fixed.FixedMul(speed, Tables.finesine(angle >> 19));
            int32 distance = P_MapUtl.P_AproxDistance(dest.x - source.x, dest.y - source.y) / speed;
            if (distance < 1) distance = 1;
            mo.momz = (dest.z - source.z) / distance;
        }
        P_CheckMissileSpawn(c, id);
    }

    function P_SpawnPlayerMissile(GameContext memory c, uint32 sourceId, uint32 kind) internal view {
        Mobj memory source = c.state.mobjs[sourceId];
        uint32 angle = source.angle;
        int32 slope = c.hooks.aimLineAttack(c, sourceId, angle, 16 * 64 * 65536);
        unchecked {
            if (c.move.linetarget == GameConst.NULL) {
                angle += 1 << 26;
                slope = c.hooks.aimLineAttack(c, sourceId, angle, 16 * 64 * 65536);
                if (c.move.linetarget == GameConst.NULL) {
                    angle -= 2 << 26;
                    slope = c.hooks.aimLineAttack(c, sourceId, angle, 16 * 64 * 65536);
                }
                if (c.move.linetarget == GameConst.NULL) {
                    angle = source.angle;
                    slope = 0;
                }
            }
            uint32 id = P_SpawnMobj(c, source.x, source.y, source.z + 32 * 65536, kind);
            Mobj memory mo = c.state.mobjs[id];
            mo.target = sourceId;
            mo.angle = angle;
            int32 speed = c.definitions.mobjinfo[kind].speed;
            mo.momx = M_Fixed.FixedMul(speed, Tables.finecosine(angle >> 19));
            mo.momy = M_Fixed.FixedMul(speed, Tables.finesine(angle >> 19));
            mo.momz = M_Fixed.FixedMul(speed, slope);
            P_CheckMissileSpawn(c, id);
        }
    }
}
