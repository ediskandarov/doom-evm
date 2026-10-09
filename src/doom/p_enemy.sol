// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {
    GameContext,
    GameConst as C,
    Mobj,
    MobjInfo,
    Player,
    ThinkerKind,
    FloorType,
    DoorType
} from "./p_game_state.sol";
import {Line} from "./r_defs.sol";
import {RenderState} from "./r_state.sol";
import {R_Main} from "./r_main.sol";
import {Tables as T} from "./tables.sol";
import {M_Fixed as F} from "./m_fixed.sol";
import {M_Random as RNG} from "./m_random.sol";
import {P_MapUtl as U} from "./p_maputl.sol";
import {P_Info as I} from "./p_info.sol";

/// @custom:source linuxdoom-1.10/p_enemy.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @dev Sound hardware omitted; original P_Random draws selecting sounds remain. All actor loops follow original thinker/block order.
library P_Enemy {
    error WeirdMoveDirection();
    error MissingChaseTarget();
    error UndefinedAIState();
    error BrainTargetOverflow();
    error UnknownEnemyAction(uint32 action);
    int32 internal constant DI_NODIR = 8;
    uint32 internal constant FATSPREAD = T.ANG90 / 8;
    uint32 internal constant TRACEANGLE = 0x0c000000;
    int32 internal constant SKULLSPEED = 20 * 65536;

    struct VileSearch {
        uint32 corpsehit;
        uint32 vileobj;
        int32 viletryx;
        int32 viletryy;
    }

    function xspeed(int32 dir) internal pure returns (int32) {
        int32[8] memory v = [int32(65536), 47000, 0, -47000, -65536, -47000, 0, 47000];
        if (dir < 0 || dir >= 8) revert WeirdMoveDirection();
        return v[uint32(dir)];
    }

    function yspeed(int32 dir) internal pure returns (int32) {
        int32[8] memory v = [int32(0), 47000, 65536, 47000, 0, -47000, -65536, -47000];
        if (dir < 0 || dir >= 8) revert WeirdMoveDirection();
        return v[uint32(dir)];
    }

    function opposite(int32 dir) internal pure returns (int32) {
        if (dir < 0 || dir > 8) revert WeirdMoveDirection();
        return dir == 8 ? int32(8) : (dir + 4) % 8;
    }

    function angleTo(Mobj memory actor, Mobj memory dest) private pure returns (uint32) {
        RenderState memory rs;
        return R_Main.R_PointToAngle2(rs, actor.x, actor.y, dest.x, dest.y);
    }

    function jitter(GameContext memory c, uint32 shift) private pure returns (uint32) {
        int32 first = RNG.P_Random(c.state);
        int32 second = RNG.P_Random(c.state);
        unchecked {
            return uint32((first - second) << shift);
        }
    }

    function activeMobj(GameContext memory c, uint32 thinker) private pure returns (bool) {
        return c.state.thinkers[thinker].kind == ThinkerKind.mobj
            && c.state.thinkers[thinker].status == C.THINKER_ACTIVE;
    }

    function info(GameContext memory c, uint32 id) private pure returns (MobjInfo memory) {
        return c.definitions.mobjinfo[c.state.mobjs[id].mobjType];
    }

    function P_RecursiveSound(GameContext memory c, uint32 sec, int32 soundblocks) internal pure {
        unchecked {
            if (
                c.state.sectors[sec].validcount == c.state.validcount
                    && c.state.sectors[sec].soundtraversed <= soundblocks + 1
            ) return;
            c.state.sectors[sec].validcount = c.state.validcount;
            c.state.sectors[sec].soundtraversed = soundblocks + 1;
            c.state.sectors[sec].soundtarget = c.move.soundtarget;
            for (uint256 i; i < c.state.sectors[sec].lines.length; i++) {
                uint32 lid = c.state.sectors[sec].lines[i];
                Line memory line = c.map.lines[lid];
                if ((line.flags & 4) == 0) continue;
                U.P_LineOpening(c, lid);
                if (c.move.openrange <= 0) continue;
                uint32 other = c.map.sides[line.sidenum[0]].sector == sec
                    ? c.map.sides[line.sidenum[1]].sector
                    : c.map.sides[line.sidenum[0]].sector;
                if ((line.flags & 64) != 0) {
                    if (soundblocks == 0) P_RecursiveSound(c, other, 1);
                } else {
                    P_RecursiveSound(c, other, soundblocks);
                }
            }
        }
    }

    function P_NoiseAlert(GameContext memory c, uint32 target, uint32 emitter) internal pure {
        c.move.soundtarget = target;
        unchecked {
            c.state.validcount++;
        }
        P_RecursiveSound(c, c.map.subsectors[c.state.mobjs[emitter].subsector].sector, 0);
    }

    function P_CheckMeleeRange(GameContext memory c, uint32 id) internal view returns (bool) {
        Mobj memory actor = c.state.mobjs[id];
        if (actor.target == C.NULL) return false;
        Mobj memory pl = c.state.mobjs[actor.target];
        unchecked {
            if (
                U.P_AproxDistance(pl.x - actor.x, pl.y - actor.y)
                    >= C.MELEERANGE - 20 * 65536 + c.definitions.mobjinfo[pl.mobjType].radius
            ) return false;
        }
        return c.hooks.checkSight(c, id, actor.target);
    }

    function P_CheckMissileRange(GameContext memory c, uint32 id) internal view returns (bool) {
        Mobj memory actor = c.state.mobjs[id];
        if (!c.hooks.checkSight(c, id, actor.target)) return false;
        if ((actor.flags & C.MF_JUSTHIT) != 0) {
            actor.flags &= ~C.MF_JUSTHIT;
            return true;
        }
        if (actor.reactiontime != 0) return false;
        unchecked {
            Mobj memory target = c.state.mobjs[actor.target];
            int32 dist = U.P_AproxDistance(actor.x - target.x, actor.y - target.y) - 64 * 65536;
            if (info(c, id).meleestate == 0) dist -= 128 * 65536;
            dist >>= 16;
            if (actor.mobjType == I.MT_VILE && dist > 14 * 64) return false;
            if (actor.mobjType == I.MT_UNDEAD) {
                if (dist < 196) return false;
                dist >>= 1;
            }
            if (
                actor.mobjType == I.MT_CYBORG || actor.mobjType == I.MT_SPIDER || actor.mobjType == I.MT_SKULL
            ) {
                dist >>= 1;
            }
            if (dist > 200) dist = 200;
            if (actor.mobjType == I.MT_CYBORG && dist > 160) dist = 160;
            return RNG.P_Random(c.state) >= dist;
        }
    }

    function P_Move(GameContext memory c, uint32 id) internal view returns (bool) {
        Mobj memory actor = c.state.mobjs[id];
        if (actor.movedir == DI_NODIR) return false;
        unchecked {
            int32 tx = actor.x + info(c, id).speed * xspeed(actor.movedir);
            int32 ty = actor.y + info(c, id).speed * yspeed(actor.movedir);
            if (!c.hooks.tryMove(c, id, tx, ty)) {
                if ((actor.flags & C.MF_FLOAT) != 0 && c.move.floatok) {
                    if (actor.z < c.move.tmfloorz) actor.z += C.FLOATSPEED;
                    else actor.z -= C.FLOATSPEED;
                    actor.flags |= C.MF_INFLOAT;
                    return true;
                }
                if (c.move.numspechit == 0) return false;
                actor.movedir = DI_NODIR;
                bool good;
                // Original postfix test decrements numspechit even on the final zero test.
                while (c.move.numspechit-- != 0) {
                    if (c.hooks.useSpecialLine(c, id, c.move.spechit[uint32(c.move.numspechit)], 0)) {
                        good = true;
                    }
                }
                return good;
            }
            actor.flags &= ~C.MF_INFLOAT;
            if ((actor.flags & C.MF_FLOAT) == 0) actor.z = actor.floorz;
            return true;
        }
    }

    function P_TryWalk(GameContext memory c, uint32 id) internal view returns (bool) {
        if (!P_Move(c, id)) return false;
        c.state.mobjs[id].movecount = RNG.P_Random(c.state) & 15;
        return true;
    }

    function P_NewChaseDir(GameContext memory c, uint32 id) internal view {
        Mobj memory actor = c.state.mobjs[id];
        if (actor.target == C.NULL) revert MissingChaseTarget();
        unchecked {
            int32 olddir = actor.movedir;
            int32 turnaround = opposite(olddir);
            Mobj memory target = c.state.mobjs[actor.target];
            int32 dx = target.x - actor.x;
            int32 dy = target.y - actor.y;
            int32 d1 = dx > 10 * 65536 ? int32(0) : (dx < -10 * 65536 ? int32(4) : DI_NODIR);
            int32 d2 = dy < -10 * 65536 ? int32(6) : (dy > 10 * 65536 ? int32(2) : DI_NODIR);
            if (d1 != DI_NODIR && d2 != DI_NODIR) {
                int32[4] memory diags = [int32(3), 1, 5, 7];
                actor.movedir = diags[(dy < 0 ? 2 : 0) + (dx > 0 ? 1 : 0)];
                if (actor.movedir != turnaround && P_TryWalk(c, id)) return;
            }
            if (RNG.P_Random(c.state) > 200 || U.abs(dy) > U.abs(dx)) (d1, d2) = (d2, d1);
            if (d1 == turnaround) d1 = DI_NODIR;
            if (d2 == turnaround) d2 = DI_NODIR;
            if (d1 != DI_NODIR) {
                actor.movedir = d1;
                if (P_TryWalk(c, id)) return;
            }
            if (d2 != DI_NODIR) {
                actor.movedir = d2;
                if (P_TryWalk(c, id)) return;
            }
            if (olddir != DI_NODIR) {
                actor.movedir = olddir;
                if (P_TryWalk(c, id)) return;
            }
            if ((RNG.P_Random(c.state) & 1) != 0) {
                for (int32 d; d <= 7; d++) {
                    if (d != turnaround) {
                        actor.movedir = d;
                        if (P_TryWalk(c, id)) return;
                    }
                }
            } else {
                for (int32 d = 7; d != -1; d--) {
                    if (d != turnaround) {
                        actor.movedir = d;
                        if (P_TryWalk(c, id)) return;
                    }
                }
            }
            if (turnaround != DI_NODIR) {
                actor.movedir = turnaround;
                if (P_TryWalk(c, id)) return;
            }
            actor.movedir = DI_NODIR;
        }
    }

    function P_LookForPlayers(GameContext memory c, uint32 id, bool allaround) internal view returns (bool) {
        Mobj memory actor = c.state.mobjs[id];
        uint32 count;
        int32 stop = (actor.lastlook - 1) & 3;
        bool any;
        for (uint32 i; i < 4; i++) {
            if (c.state.playeringame[i]) any = true;
        }
        if (!any || actor.lastlook < 0 || actor.lastlook > 3) revert UndefinedAIState();
        for (;; actor.lastlook = (actor.lastlook + 1) & 3) {
            if (!c.state.playeringame[uint32(actor.lastlook)]) continue;
            if (count++ == 2 || actor.lastlook == stop) return false;
            Player memory player = c.state.players[uint32(actor.lastlook)];
            if (player.health <= 0) continue;
            if (!c.hooks.checkSight(c, id, player.mo)) continue;
            if (!allaround) {
                Mobj memory pl = c.state.mobjs[player.mo];
                uint32 an;
                unchecked {
                    an = angleTo(actor, pl) - actor.angle;
                    if (
                        an > T.ANG90 && an < T.ANG270
                            && U.P_AproxDistance(pl.x - actor.x, pl.y - actor.y) > C.MELEERANGE
                    ) continue;
                }
            }
            actor.target = player.mo;
            return true;
        }
        return false;
    }

    function allSameDead(GameContext memory c, uint32 id) private pure returns (bool) {
        Mobj memory actor = c.state.mobjs[id];
        for (uint32 th = c.state.thinkers[0].next; th != 0; th = c.state.thinkers[th].next) {
            if (!activeMobj(c, th)) continue;
            uint32 other = c.state.thinkers[th].payload;
            if (
                other != id && c.state.mobjs[other].mobjType == actor.mobjType
                    && c.state.mobjs[other].health > 0
            ) {
                return false;
            }
        }
        return true;
    }

    function A_KeenDie(GameContext memory c, uint32 id) internal view {
        A_Fall(c, id);
        if (allSameDead(c, id)) c.hooks.bossDoDoor(c, 666, DoorType.open);
    }

    function A_Look(GameContext memory c, uint32 id) internal view {
        Mobj memory actor = c.state.mobjs[id];
        actor.threshold = 0;
        uint32 target = c.state.sectors[c.map.subsectors[actor.subsector].sector].soundtarget;
        bool seen;
        if (target != C.NULL && (c.state.mobjs[target].flags & C.MF_SHOOTABLE) != 0) {
            actor.target = target;
            seen = (actor.flags & C.MF_AMBUSH) == 0 || c.hooks.checkSight(c, id, target);
        }
        if (!seen && !P_LookForPlayers(c, id, false)) return;
        int32 sound = info(c, id).seesound;
        if (sound >= 36 && sound <= 38) RNG.P_Random(c.state);
        else if (sound == 39 || sound == 40) RNG.P_Random(c.state);
        c.hooks.setMobjState(c, id, uint32(info(c, id).seestate));
    }

    function A_Chase(GameContext memory c, uint32 id) internal view {
        Mobj memory actor = c.state.mobjs[id];
        unchecked {
            if (actor.reactiontime != 0) actor.reactiontime--;
            if (actor.threshold != 0) {
                if (actor.target == C.NULL || c.state.mobjs[actor.target].health <= 0) actor.threshold = 0;
                else actor.threshold--;
            }
            if (actor.movedir < 8) {
                actor.angle &= 0xe0000000;
                int32 delta = int32(actor.angle - uint32(actor.movedir << 29));
                if (delta > 0) actor.angle -= T.ANG45;
                else if (delta < 0) actor.angle += T.ANG45;
            }
            if (actor.target == C.NULL || (c.state.mobjs[actor.target].flags & C.MF_SHOOTABLE) == 0) {
                if (P_LookForPlayers(c, id, true)) return;
                c.hooks.setMobjState(c, id, uint32(info(c, id).spawnstate));
                return;
            }
            if ((actor.flags & C.MF_JUSTATTACKED) != 0) {
                actor.flags &= ~C.MF_JUSTATTACKED;
                if (c.state.gameskill != 4 && !c.state.fastparm) P_NewChaseDir(c, id);
                return;
            }
            MobjInfo memory def = info(c, id);
            if (def.meleestate != 0 && P_CheckMeleeRange(c, id)) {
                c.hooks.setMobjState(c, id, uint32(def.meleestate));
                return;
            }
            if (
                def.missilestate != 0 && !(c.state.gameskill < 4 && !c.state.fastparm && actor.movecount != 0)
                    && P_CheckMissileRange(c, id)
            ) {
                c.hooks.setMobjState(c, id, uint32(def.missilestate));
                actor.flags |= C.MF_JUSTATTACKED;
                return;
            }
            if (
                c.state.netgame && actor.threshold == 0 && !c.hooks.checkSight(c, id, actor.target)
                    && P_LookForPlayers(c, id, true)
            ) return;
            if (--actor.movecount < 0 || !P_Move(c, id)) P_NewChaseDir(c, id);
            if (def.activesound != 0) RNG.P_Random(c.state); // original sound test consumes its draw even with disabled sound device.
        }
    }

    function A_FaceTarget(GameContext memory c, uint32 id) internal pure {
        Mobj memory actor = c.state.mobjs[id];
        if (actor.target == C.NULL) return;
        actor.flags &= ~C.MF_AMBUSH;
        actor.angle = angleTo(actor, c.state.mobjs[actor.target]);
        unchecked {
            if ((c.state.mobjs[actor.target].flags & C.MF_SHADOW) != 0) actor.angle += jitter(c, 21);
        }
    }

    function hitscan(GameContext memory c, uint32 id, uint32 count) private view {
        Mobj memory actor = c.state.mobjs[id];
        if (actor.target == C.NULL) return;
        A_FaceTarget(c, id);
        uint32 base = actor.angle;
        int32 slope = c.hooks.aimLineAttack(c, id, base, C.MISSILERANGE);
        for (uint32 i; i < count; i++) {
            uint32 angle;
            unchecked {
                angle = base + jitter(c, 20);
            }
            int32 damage = (RNG.P_Random(c.state) % 5 + 1) * 3;
            c.hooks.lineAttack(c, id, angle, C.MISSILERANGE, slope, damage);
        }
    }

    function A_PosAttack(GameContext memory c, uint32 id) internal view {
        hitscan(c, id, 1);
    }

    function A_SPosAttack(GameContext memory c, uint32 id) internal view {
        hitscan(c, id, 3);
    }

    function A_CPosAttack(GameContext memory c, uint32 id) internal view {
        hitscan(c, id, 1);
    }

    function refire(GameContext memory c, uint32 id, int32 limit) private view {
        A_FaceTarget(c, id);
        if (RNG.P_Random(c.state) < limit) return;
        Mobj memory actor = c.state.mobjs[id];
        if (
            actor.target == C.NULL || c.state.mobjs[actor.target].health <= 0
                || !c.hooks.checkSight(c, id, actor.target)
        ) c.hooks.setMobjState(c, id, uint32(info(c, id).seestate));
    }

    function A_CPosRefire(GameContext memory c, uint32 id) internal view {
        refire(c, id, 40);
    }

    function A_SpidRefire(GameContext memory c, uint32 id) internal view {
        refire(c, id, 10);
    }

    function A_BspiAttack(GameContext memory c, uint32 id) internal view {
        if (c.state.mobjs[id].target == C.NULL) return;
        A_FaceTarget(c, id);
        c.hooks.spawnMissile(c, id, c.state.mobjs[id].target, I.MT_ARACHPLAZ);
    }

    function A_TroopAttack(GameContext memory c, uint32 id) internal view {
        Mobj memory actor = c.state.mobjs[id];
        if (actor.target == C.NULL) return;
        A_FaceTarget(c, id);
        if (P_CheckMeleeRange(c, id)) {
            c.hooks.damageMobj(c, actor.target, id, id, (RNG.P_Random(c.state) % 8 + 1) * 3);
            return;
        }
        c.hooks.spawnMissile(c, id, actor.target, I.MT_TROOPSHOT);
    }

    function A_SargAttack(GameContext memory c, uint32 id) internal view {
        if (c.state.mobjs[id].target == C.NULL) return;
        A_FaceTarget(c, id);
        if (P_CheckMeleeRange(c, id)) {
            c.hooks.damageMobj(c, c.state.mobjs[id].target, id, id, (RNG.P_Random(c.state) % 10 + 1) * 4);
        }
    }

    function A_HeadAttack(GameContext memory c, uint32 id) internal view {
        Mobj memory actor = c.state.mobjs[id];
        if (actor.target == C.NULL) return;
        A_FaceTarget(c, id);
        if (P_CheckMeleeRange(c, id)) {
            c.hooks.damageMobj(c, actor.target, id, id, (RNG.P_Random(c.state) % 6 + 1) * 10);
            return;
        }
        c.hooks.spawnMissile(c, id, actor.target, I.MT_HEADSHOT);
    }

    function A_CyberAttack(GameContext memory c, uint32 id) internal view {
        if (c.state.mobjs[id].target == C.NULL) return;
        A_FaceTarget(c, id);
        c.hooks.spawnMissile(c, id, c.state.mobjs[id].target, I.MT_ROCKET);
    }

    function A_BruisAttack(GameContext memory c, uint32 id) internal view {
        Mobj memory actor = c.state.mobjs[id];
        if (actor.target == C.NULL) return;
        if (P_CheckMeleeRange(c, id)) {
            c.hooks.damageMobj(c, actor.target, id, id, (RNG.P_Random(c.state) % 8 + 1) * 10);
            return;
        }
        c.hooks.spawnMissile(c, id, actor.target, I.MT_BRUISERSHOT);
    }

    function A_SkelMissile(GameContext memory c, uint32 id) internal view {
        Mobj memory actor = c.state.mobjs[id];
        if (actor.target == C.NULL) return;
        A_FaceTarget(c, id);
        unchecked {
            actor.z += 16 * 65536;
            uint32 missile = c.hooks.spawnMissile(c, id, actor.target, I.MT_TRACER);
            actor.z -= 16 * 65536;
            Mobj memory mo = c.state.mobjs[missile];
            mo.x += mo.momx;
            mo.y += mo.momy;
            mo.tracer = actor.target;
        }
    }

    function A_Tracer(GameContext memory c, uint32 id) internal view {
        if ((c.state.gametic & 3) != 0) return;
        Mobj memory actor = c.state.mobjs[id];
        c.hooks.spawnPuff(c, actor.x, actor.y, actor.z);
        unchecked {
            uint32 smoke =
                c.hooks.spawnMobj(c, actor.x - actor.momx, actor.y - actor.momy, actor.z, I.MT_SMOKE);
            Mobj memory th = c.state.mobjs[smoke];
            th.momz = 65536;
            th.tics -= RNG.P_Random(c.state) & 3;
            if (th.tics < 1) th.tics = 1;
            if (actor.tracer == C.NULL || c.state.mobjs[actor.tracer].health <= 0) return;
            Mobj memory dest = c.state.mobjs[actor.tracer];
            uint32 exact = angleTo(actor, dest);
            if (exact != actor.angle) {
                if (exact - actor.angle > T.ANG180) {
                    actor.angle -= TRACEANGLE;
                    if (exact - actor.angle < T.ANG180) actor.angle = exact;
                } else {
                    actor.angle += TRACEANGLE;
                    if (exact - actor.angle > T.ANG180) actor.angle = exact;
                }
            }
            int32 speed = info(c, id).speed;
            actor.momx = F.FixedMul(speed, T.finecosine(actor.angle >> 19));
            actor.momy = F.FixedMul(speed, T.finesine(actor.angle >> 19));
            if (speed == 0) revert UndefinedAIState();
            int32 dist = U.P_AproxDistance(dest.x - actor.x, dest.y - actor.y) / speed;
            if (dist < 1) dist = 1;
            int32 slope = (dest.z + 40 * 65536 - actor.z) / dist;
            if (slope < actor.momz) actor.momz -= 65536 / 8;
            else actor.momz += 65536 / 8;
        }
    }

    function A_SkelWhoosh(GameContext memory c, uint32 id) internal pure {
        if (c.state.mobjs[id].target != C.NULL) A_FaceTarget(c, id);
    }

    function A_SkelFist(GameContext memory c, uint32 id) internal view {
        if (c.state.mobjs[id].target == C.NULL) return;
        A_FaceTarget(c, id);
        if (P_CheckMeleeRange(c, id)) {
            c.hooks.damageMobj(c, c.state.mobjs[id].target, id, id, (RNG.P_Random(c.state) % 10 + 1) * 6);
        }
    }

    function PIT_VileCheck(GameContext memory c, VileSearch memory search, uint32 id)
        internal
        view
        returns (bool)
    {
        Mobj memory thing = c.state.mobjs[id];
        if ((thing.flags & C.MF_CORPSE) == 0 || thing.tics != -1 || info(c, id).raisestate == int32(I.S_NULL))
        {
            return true;
        }
        unchecked {
            int32 maxdist = info(c, id).radius + c.definitions.mobjinfo[I.MT_VILE].radius;
            if (U.abs(thing.x - search.viletryx) > maxdist || U.abs(thing.y - search.viletryy) > maxdist) {
                return true;
            }
            search.corpsehit = id;
            thing.momx = 0;
            thing.momy = 0;
            thing.height <<= 2;
            bool fits = c.hooks.checkPosition(c, id, thing.x, thing.y);
            thing.height >>= 2;
            return !fits;
        }
    }

    function vileBlock(GameContext memory c, VileSearch memory search, int32 bx, int32 by)
        private
        view
        returns (bool)
    {
        if (bx < 0 || by < 0 || bx >= c.state.blockmap.width || by >= c.state.blockmap.height) {
            return true;
        }
        uint32 id = c.state.blockmap.heads[uint32(by * c.state.blockmap.width + bx)];
        while (id != C.NULL) {
            if (!PIT_VileCheck(c, search, id)) return false;
            id = c.state.mobjs[id].bnext;
        }
        return true;
    }

    function A_VileChase(GameContext memory c, uint32 id) internal view {
        Mobj memory actor = c.state.mobjs[id];
        unchecked {
            if (actor.movedir != DI_NODIR) {
                VileSearch memory search;
                search.vileobj = id;
                search.corpsehit = C.NULL;
                search.viletryx = actor.x + info(c, id).speed * xspeed(actor.movedir);
                search.viletryy = actor.y + info(c, id).speed * yspeed(actor.movedir);
                int32 xl = (search.viletryx - c.state.blockmap.orgx - C.MAXRADIUS * 2) >> 23;
                int32 xh = (search.viletryx - c.state.blockmap.orgx + C.MAXRADIUS * 2) >> 23;
                int32 yl = (search.viletryy - c.state.blockmap.orgy - C.MAXRADIUS * 2) >> 23;
                int32 yh = (search.viletryy - c.state.blockmap.orgy + C.MAXRADIUS * 2) >> 23;
                for (int32 bx = xl; bx <= xh; bx++) {
                    for (int32 by = yl; by <= yh; by++) {
                        if (!vileBlock(c, search, bx, by)) {
                            uint32 temp = actor.target;
                            actor.target = search.corpsehit;
                            A_FaceTarget(c, id);
                            actor.target = temp;
                            c.hooks.setMobjState(c, id, I.S_VILE_HEAL1);
                            MobjInfo memory def = info(c, search.corpsehit);
                            c.hooks.setMobjState(c, search.corpsehit, uint32(def.raisestate));
                            Mobj memory corpse = c.state.mobjs[search.corpsehit];
                            corpse.height <<= 2;
                            corpse.flags = uint32(def.flags);
                            corpse.health = def.spawnhealth;
                            corpse.target = C.NULL;
                            return;
                        }
                    }
                }
            }
        }
        A_Chase(c, id);
    }
    function A_VileStart(GameContext memory, uint32) internal pure {}

    function A_StartFire(GameContext memory c, uint32 id) internal view {
        A_Fire(c, id);
    }

    function A_FireCrackle(GameContext memory c, uint32 id) internal view {
        A_Fire(c, id);
    }

    function A_Fire(GameContext memory c, uint32 id) internal view {
        Mobj memory actor = c.state.mobjs[id];
        if (actor.tracer == C.NULL) return;
        Mobj memory dest = c.state.mobjs[actor.tracer];
        if (!c.hooks.checkSight(c, actor.target, actor.tracer)) return;
        U.P_UnsetThingPosition(c, id);
        unchecked {
            actor.x = dest.x + F.FixedMul(24 * 65536, T.finecosine(dest.angle >> 19));
            actor.y = dest.y + F.FixedMul(24 * 65536, T.finesine(dest.angle >> 19));
        }
        actor.z = dest.z;
        U.P_SetThingPosition(c, id);
    }

    function A_VileTarget(GameContext memory c, uint32 id) internal view {
        Mobj memory actor = c.state.mobjs[id];
        if (actor.target == C.NULL) return;
        A_FaceTarget(c, id);
        Mobj memory target = c.state.mobjs[actor.target];
        // Original deliberately retained typo: target.x is passed for both x and y, then A_Fire repositions.
        uint32 fog = c.hooks.spawnMobj(c, target.x, target.x, target.z, I.MT_FIRE);
        actor.tracer = fog;
        c.state.mobjs[fog].target = id;
        c.state.mobjs[fog].tracer = actor.target;
        A_Fire(c, fog);
    }

    function A_VileAttack(GameContext memory c, uint32 id) internal view {
        Mobj memory actor = c.state.mobjs[id];
        if (actor.target == C.NULL) return;
        A_FaceTarget(c, id);
        if (!c.hooks.checkSight(c, id, actor.target)) return;
        c.hooks.damageMobj(c, actor.target, id, id, 20);
        int32 mass = info(c, actor.target).mass;
        if (mass == 0) revert UndefinedAIState();
        c.state.mobjs[actor.target].momz = 1000 * 65536 / mass;
        if (actor.tracer == C.NULL) return;
        Mobj memory fire = c.state.mobjs[actor.tracer];
        Mobj memory target = c.state.mobjs[actor.target];
        unchecked {
            fire.x = target.x - F.FixedMul(24 * 65536, T.finecosine(actor.angle >> 19));
            fire.y = target.y - F.FixedMul(24 * 65536, T.finesine(actor.angle >> 19));
        }
        c.hooks.radiusAttack(c, actor.tracer, id, 70);
    }

    function A_FatRaise(GameContext memory c, uint32 id) internal pure {
        A_FaceTarget(c, id);
    }

    function fatReaim(GameContext memory c, uint32 id) private pure {
        Mobj memory mo = c.state.mobjs[id];
        int32 speed = info(c, id).speed;
        mo.momx = F.FixedMul(speed, T.finecosine(mo.angle >> 19));
        mo.momy = F.FixedMul(speed, T.finesine(mo.angle >> 19));
    }

    function A_FatAttack1(GameContext memory c, uint32 id) internal view {
        A_FaceTarget(c, id);
        unchecked {
            c.state.mobjs[id].angle += FATSPREAD;
            c.hooks.spawnMissile(c, id, c.state.mobjs[id].target, I.MT_FATSHOT);
            uint32 missile = c.hooks.spawnMissile(c, id, c.state.mobjs[id].target, I.MT_FATSHOT);
            c.state.mobjs[missile].angle += FATSPREAD;
            fatReaim(c, missile);
        }
    }

    function A_FatAttack2(GameContext memory c, uint32 id) internal view {
        A_FaceTarget(c, id);
        unchecked {
            c.state.mobjs[id].angle -= FATSPREAD;
            c.hooks.spawnMissile(c, id, c.state.mobjs[id].target, I.MT_FATSHOT);
            uint32 missile = c.hooks.spawnMissile(c, id, c.state.mobjs[id].target, I.MT_FATSHOT);
            c.state.mobjs[missile].angle -= FATSPREAD * 2;
            fatReaim(c, missile);
        }
    }

    function A_FatAttack3(GameContext memory c, uint32 id) internal view {
        A_FaceTarget(c, id);
        unchecked {
            uint32 missile = c.hooks.spawnMissile(c, id, c.state.mobjs[id].target, I.MT_FATSHOT);
            c.state.mobjs[missile].angle -= FATSPREAD / 2;
            fatReaim(c, missile);
            missile = c.hooks.spawnMissile(c, id, c.state.mobjs[id].target, I.MT_FATSHOT);
            c.state.mobjs[missile].angle += FATSPREAD / 2;
            fatReaim(c, missile);
        }
    }

    function A_SkullAttack(GameContext memory c, uint32 id) internal pure {
        Mobj memory actor = c.state.mobjs[id];
        if (actor.target == C.NULL) return;
        Mobj memory dest = c.state.mobjs[actor.target];
        actor.flags |= C.MF_SKULLFLY;
        A_FaceTarget(c, id);
        actor.momx = F.FixedMul(SKULLSPEED, T.finecosine(actor.angle >> 19));
        actor.momy = F.FixedMul(SKULLSPEED, T.finesine(actor.angle >> 19));
        unchecked {
            int32 dist = U.P_AproxDistance(dest.x - actor.x, dest.y - actor.y) / SKULLSPEED;
            if (dist < 1) dist = 1;
            actor.momz = (dest.z + (dest.height >> 1) - actor.z) / dist;
        }
    }

    function A_PainShootSkull(GameContext memory c, uint32 id, uint32 angle) internal view {
        uint32 count;
        for (uint32 th = c.state.thinkers[0].next; th != 0; th = c.state.thinkers[th].next) {
            if (activeMobj(c, th) && c.state.mobjs[c.state.thinkers[th].payload].mobjType == I.MT_SKULL) {
                count++;
            }
        }
        if (count > 20) return;
        Mobj memory actor = c.state.mobjs[id];
        unchecked {
            int32 prestep =
                4 * 65536 + 3 * (info(c, id).radius + c.definitions.mobjinfo[I.MT_SKULL].radius) / 2;
            uint32 skull = c.hooks
                .spawnMobj(
                    c,
                    actor.x + F.FixedMul(prestep, T.finecosine(angle >> 19)),
                    actor.y + F.FixedMul(prestep, T.finesine(angle >> 19)),
                    actor.z + 8 * 65536,
                    I.MT_SKULL
                );
            if (!c.hooks.tryMove(c, skull, c.state.mobjs[skull].x, c.state.mobjs[skull].y)) {
                c.hooks.damageMobj(c, skull, id, id, 10000);
                return;
            }
            c.state.mobjs[skull].target = actor.target;
            A_SkullAttack(c, skull);
        }
    }

    function A_PainAttack(GameContext memory c, uint32 id) internal view {
        if (c.state.mobjs[id].target == C.NULL) return;
        A_FaceTarget(c, id);
        A_PainShootSkull(c, id, c.state.mobjs[id].angle);
    }

    function A_PainDie(GameContext memory c, uint32 id) internal view {
        A_Fall(c, id);
        unchecked {
            A_PainShootSkull(c, id, c.state.mobjs[id].angle + T.ANG90);
            A_PainShootSkull(c, id, c.state.mobjs[id].angle + T.ANG180);
            A_PainShootSkull(c, id, c.state.mobjs[id].angle + T.ANG270);
        }
    }

    function A_Scream(GameContext memory c, uint32 id) internal pure {
        int32 sound = info(c, id).deathsound;
        if (sound >= 59 && sound <= 61) RNG.P_Random(c.state);
        else if (sound == 62 || sound == 63) RNG.P_Random(c.state);
    }
    function A_XScream(GameContext memory, uint32) internal pure {}
    function A_Pain(GameContext memory, uint32) internal pure {}

    function A_Fall(GameContext memory c, uint32 id) internal pure {
        c.state.mobjs[id].flags &= ~C.MF_SOLID;
    }

    function A_Explode(GameContext memory c, uint32 id) internal view {
        c.hooks.radiusAttack(c, id, c.state.mobjs[id].target, 128);
    }

    function A_BossDeath(GameContext memory c, uint32 id) internal view {
        uint32 kind = c.state.mobjs[id].mobjType;
        if (c.state.gamemode == 2) {
            if (c.state.gamemap != 7 || (kind != I.MT_FATSO && kind != I.MT_BABY)) return;
        } else {
            int32 episode = c.state.gameepisode;
            int32 map = c.state.gamemap;
            if (episode == 1) {
                if (map != 8 || kind != I.MT_BRUISER) return;
            } else if (episode == 2) {
                if (map != 8 || kind != I.MT_CYBORG) return;
            } else if (episode == 3) {
                if (map != 8 || kind != I.MT_SPIDER) return;
            } else if (episode == 4) {
                if (map == 6) {
                    if (kind != I.MT_CYBORG) return;
                } else if (map == 8) {
                    if (kind != I.MT_SPIDER) return;
                } else {
                    return;
                }
            } else if (map != 8) {
                return;
            }
        }
        bool alive;
        for (uint32 i; i < 4; i++) {
            if (c.state.playeringame[i] && c.state.players[i].health > 0) {
                alive = true;
                break;
            }
        }
        if (!alive || !allSameDead(c, id)) return;
        if (c.state.gamemode == 2) {
            if (kind == I.MT_FATSO) {
                c.hooks.bossDoFloor(c, 666, FloorType.lowerFloorToLowest);
                return;
            }
            if (kind == I.MT_BABY) {
                c.hooks.bossDoFloor(c, 667, FloorType.raiseToTexture);
                return;
            }
        } else {
            if (c.state.gameepisode == 1 || (c.state.gameepisode == 4 && c.state.gamemap == 8)) {
                c.hooks.bossDoFloor(c, 666, FloorType.lowerFloorToLowest);
                return;
            }
            if (c.state.gameepisode == 4 && c.state.gamemap == 6) {
                c.hooks.bossDoDoor(c, 666, DoorType.blazeOpen);
                return;
            }
        }
        c.hooks.exitLevel(c);
    }

    function A_Hoof(GameContext memory c, uint32 id) internal view {
        A_Chase(c, id);
    }

    function A_Metal(GameContext memory c, uint32 id) internal view {
        A_Chase(c, id);
    }

    function A_BabyMetal(GameContext memory c, uint32 id) internal view {
        A_Chase(c, id);
    }
    function A_OpenShotgun2(GameContext memory, uint32, uint32) internal pure {}
    function A_LoadShotgun2(GameContext memory, uint32, uint32) internal pure {}

    function A_CloseShotgun2(GameContext memory c, uint32 player, uint32 psprite) internal view {
        c.hooks.actionPSprite(c, I.A_ReFire, player, psprite);
    }

    function A_BrainAwake(GameContext memory c, uint32) internal pure {
        uint32[32] memory targets;
        uint32 count;
        c.state.brainTargetOn = 0;
        for (uint32 th = c.state.thinkers[0].next; th != 0; th = c.state.thinkers[th].next) {
            if (activeMobj(c, th)) {
                uint32 id = c.state.thinkers[th].payload;
                if (c.state.mobjs[id].mobjType == I.MT_BOSSTARGET) {
                    if (count == 32) revert BrainTargetOverflow();
                    targets[count++] = id;
                }
            }
        }
        c.state.brainTargets = new uint32[](count);
        for (uint32 i; i < count; i++) {
            c.state.brainTargets[i] = targets[i];
        }
    }
    function A_BrainPain(GameContext memory, uint32) internal pure {}

    function A_BrainScream(GameContext memory c, uint32 id) internal view {
        Mobj memory mo = c.state.mobjs[id];
        unchecked {
            for (int32 x = mo.x - 196 * 65536; x < mo.x + 320 * 65536; x += 65536 * 8) {
                int32 z = 128 + RNG.P_Random(c.state) * 2 * 65536;
                uint32 rocket = c.hooks.spawnMobj(c, x, mo.y - 320 * 65536, z, I.MT_ROCKET);
                c.state.mobjs[rocket].momz = RNG.P_Random(c.state) * 512;
                c.hooks.setMobjState(c, rocket, I.S_BRAINEXPLODE1);
                c.state.mobjs[rocket].tics -= RNG.P_Random(c.state) & 7;
                if (c.state.mobjs[rocket].tics < 1) c.state.mobjs[rocket].tics = 1;
            }
        }
    }

    function A_BrainExplode(GameContext memory c, uint32 id) internal view {
        Mobj memory mo = c.state.mobjs[id];
        unchecked {
            int32 first = RNG.P_Random(c.state);
            int32 second = RNG.P_Random(c.state);
            int32 x = mo.x + (first - second) * 2048;
            int32 z = 128 + RNG.P_Random(c.state) * 2 * 65536;
            uint32 rocket = c.hooks.spawnMobj(c, x, mo.y, z, I.MT_ROCKET);
            c.state.mobjs[rocket].momz = RNG.P_Random(c.state) * 512;
            c.hooks.setMobjState(c, rocket, I.S_BRAINEXPLODE1);
            c.state.mobjs[rocket].tics -= RNG.P_Random(c.state) & 7;
            if (c.state.mobjs[rocket].tics < 1) c.state.mobjs[rocket].tics = 1;
        }
    }

    function A_BrainDie(GameContext memory c, uint32) internal view {
        c.hooks.exitLevel(c);
    }

    function A_BrainSpit(GameContext memory c, uint32 id) internal view {
        c.state.brainEasy ^= 1;
        if (c.state.gameskill <= 1 && c.state.brainEasy == 0) return;
        if (c.state.brainTargets.length == 0 || c.state.brainTargetOn >= c.state.brainTargets.length) {
            revert UndefinedAIState();
        }
        uint32 target = c.state.brainTargets[c.state.brainTargetOn];
        c.state.brainTargetOn = uint32((c.state.brainTargetOn + 1) % c.state.brainTargets.length);
        uint32 cube = c.hooks.spawnMissile(c, id, target, I.MT_SPAWNSHOT);
        Mobj memory mo = c.state.mobjs[cube];
        mo.target = target;
        int32 stateTics = c.definitions.states[mo.state].tics;
        if (mo.momy == 0 || stateTics == 0) revert UndefinedAIState();
        unchecked {
            mo.reactiontime = ((c.state.mobjs[target].y - c.state.mobjs[id].y) / mo.momy) / stateTics;
        }
    }

    function A_SpawnSound(GameContext memory c, uint32 id) internal view {
        A_SpawnFly(c, id);
    }

    function A_SpawnFly(GameContext memory c, uint32 id) internal view {
        Mobj memory mo = c.state.mobjs[id];
        unchecked {
            if (--mo.reactiontime != 0) return;
        }
        Mobj memory target = c.state.mobjs[mo.target];
        c.hooks.spawnMobj(c, target.x, target.y, target.z, I.MT_SPAWNFIRE);
        int32 r = RNG.P_Random(c.state);
        uint32 kind;
        if (r < 50) kind = I.MT_TROOP;
        else if (r < 90) kind = I.MT_SERGEANT;
        else if (r < 120) kind = I.MT_SHADOWS;
        else if (r < 130) kind = I.MT_PAIN;
        else if (r < 160) kind = I.MT_HEAD;
        else if (r < 162) kind = I.MT_VILE;
        else if (r < 172) kind = I.MT_UNDEAD;
        else if (r < 192) kind = I.MT_BABY;
        else if (r < 222) kind = I.MT_FATSO;
        else if (r < 246) kind = I.MT_KNIGHT;
        else kind = I.MT_BRUISER;
        uint32 spawn = c.hooks.spawnMobj(c, target.x, target.y, target.z, kind);
        if (P_LookForPlayers(c, spawn, true)) {
            c.hooks.setMobjState(c, spawn, uint32(info(c, spawn).seestate));
        }
        c.hooks.teleportMove(c, spawn, c.state.mobjs[spawn].x, c.state.mobjs[spawn].y);
        c.hooks.removeMobj(c, id);
    }
    function A_PlayerScream(GameContext memory, uint32) internal pure {}

    function action(GameContext memory c, uint32 actionId, uint32 id) internal view {
        if (actionId == I.A_KeenDie) {
            A_KeenDie(c, id);
            return;
        }
        if (actionId == I.A_Look) {
            A_Look(c, id);
            return;
        }
        if (actionId == I.A_Chase) {
            A_Chase(c, id);
            return;
        }
        if (actionId == I.A_FaceTarget) {
            A_FaceTarget(c, id);
            return;
        }
        if (actionId == I.A_PosAttack) {
            A_PosAttack(c, id);
            return;
        }
        if (actionId == I.A_SPosAttack) {
            A_SPosAttack(c, id);
            return;
        }
        if (actionId == I.A_CPosAttack) {
            A_CPosAttack(c, id);
            return;
        }
        if (actionId == I.A_CPosRefire) {
            A_CPosRefire(c, id);
            return;
        }
        if (actionId == I.A_SpidRefire) {
            A_SpidRefire(c, id);
            return;
        }
        if (actionId == I.A_BspiAttack) {
            A_BspiAttack(c, id);
            return;
        }
        if (actionId == I.A_TroopAttack) {
            A_TroopAttack(c, id);
            return;
        }
        if (actionId == I.A_SargAttack) {
            A_SargAttack(c, id);
            return;
        }
        if (actionId == I.A_HeadAttack) {
            A_HeadAttack(c, id);
            return;
        }
        if (actionId == I.A_CyberAttack) {
            A_CyberAttack(c, id);
            return;
        }
        if (actionId == I.A_BruisAttack) {
            A_BruisAttack(c, id);
            return;
        }
        if (actionId == I.A_SkelMissile) {
            A_SkelMissile(c, id);
            return;
        }
        if (actionId == I.A_Tracer) {
            A_Tracer(c, id);
            return;
        }
        if (actionId == I.A_SkelWhoosh) {
            A_SkelWhoosh(c, id);
            return;
        }
        if (actionId == I.A_SkelFist) {
            A_SkelFist(c, id);
            return;
        }
        if (actionId == I.A_VileChase) {
            A_VileChase(c, id);
            return;
        }
        if (actionId == I.A_VileStart) {
            A_VileStart(c, id);
            return;
        }
        if (actionId == I.A_StartFire) {
            A_StartFire(c, id);
            return;
        }
        if (actionId == I.A_FireCrackle) {
            A_FireCrackle(c, id);
            return;
        }
        if (actionId == I.A_Fire) {
            A_Fire(c, id);
            return;
        }
        if (actionId == I.A_VileTarget) {
            A_VileTarget(c, id);
            return;
        }
        if (actionId == I.A_VileAttack) {
            A_VileAttack(c, id);
            return;
        }
        if (actionId == I.A_FatRaise) {
            A_FatRaise(c, id);
            return;
        }
        if (actionId == I.A_FatAttack1) {
            A_FatAttack1(c, id);
            return;
        }
        if (actionId == I.A_FatAttack2) {
            A_FatAttack2(c, id);
            return;
        }
        if (actionId == I.A_FatAttack3) {
            A_FatAttack3(c, id);
            return;
        }
        if (actionId == I.A_SkullAttack) {
            A_SkullAttack(c, id);
            return;
        }
        if (actionId == I.A_PainAttack) {
            A_PainAttack(c, id);
            return;
        }
        if (actionId == I.A_PainDie) {
            A_PainDie(c, id);
            return;
        }
        if (actionId == I.A_Scream) {
            A_Scream(c, id);
            return;
        }
        if (actionId == I.A_XScream) {
            A_XScream(c, id);
            return;
        }
        if (actionId == I.A_Pain) {
            A_Pain(c, id);
            return;
        }
        if (actionId == I.A_Fall) {
            A_Fall(c, id);
            return;
        }
        if (actionId == I.A_Explode) {
            A_Explode(c, id);
            return;
        }
        if (actionId == I.A_BossDeath) {
            A_BossDeath(c, id);
            return;
        }
        if (actionId == I.A_Hoof) {
            A_Hoof(c, id);
            return;
        }
        if (actionId == I.A_Metal) {
            A_Metal(c, id);
            return;
        }
        if (actionId == I.A_BabyMetal) {
            A_BabyMetal(c, id);
            return;
        }
        if (actionId == I.A_BrainAwake) {
            A_BrainAwake(c, id);
            return;
        }
        if (actionId == I.A_BrainPain) {
            A_BrainPain(c, id);
            return;
        }
        if (actionId == I.A_BrainScream) {
            A_BrainScream(c, id);
            return;
        }
        if (actionId == I.A_BrainExplode) {
            A_BrainExplode(c, id);
            return;
        }
        if (actionId == I.A_BrainDie) {
            A_BrainDie(c, id);
            return;
        }
        if (actionId == I.A_BrainSpit) {
            A_BrainSpit(c, id);
            return;
        }
        if (actionId == I.A_SpawnSound) {
            A_SpawnSound(c, id);
            return;
        }
        if (actionId == I.A_SpawnFly) {
            A_SpawnFly(c, id);
            return;
        }
        if (actionId == I.A_PlayerScream) {
            A_PlayerScream(c, id);
            return;
        }
        revert UnknownEnemyAction(actionId);
    }
}
