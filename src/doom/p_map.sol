// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {GameContext, Mobj, Intercept, GameConst as C} from "./p_game_state.sol";
import {Line} from "./r_defs.sol";
import {RenderState} from "./r_state.sol";
import {P_MapUtl as U} from "./p_maputl.sol";
import {M_Fixed as F} from "./m_fixed.sol";
import {M_Random} from "./m_random.sol";
import {P_Info} from "./p_info.sol";
import {R_Main} from "./r_main.sol";
import {Tables} from "./tables.sol";

/// @custom:source linuxdoom-1.10/p_map.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @dev Audio calls are presentation no-ops; every gameplay side effect remains synchronous.
library P_Map {
    error SpecialCrossOverflow();
    error InvalidSlideIntercept();

    function PIT_StompThing(GameContext memory c, uint32 id) internal view returns (bool) {
        unchecked {
            Mobj memory thing = c.state.mobjs[id];
            Mobj memory mover = c.state.mobjs[c.move.tmthing];
            if (thing.flags & C.MF_SHOOTABLE == 0) return true;
            int32 blockdist = thing.radius + mover.radius;
            if (U.abs(thing.x - c.move.tmx) >= blockdist || U.abs(thing.y - c.move.tmy) >= blockdist) {
                return true;
            }
            if (id == c.move.tmthing) return true;
            if (mover.player == C.NULL && c.state.gamemap != 30) return false;
            c.hooks.damageMobj(c, id, c.move.tmthing, c.move.tmthing, 10000);
            return true;
        }
    }

    function setCheck(GameContext memory c, uint32 id, int32 x, int32 y) private pure {
        unchecked {
            Mobj memory thing = c.state.mobjs[id];
            c.move.tmthing = id;
            c.move.tmflags = thing.flags;
            c.move.tmx = x;
            c.move.tmy = y;
            c.move.tmbbox[0] = y + thing.radius;
            c.move.tmbbox[1] = y - thing.radius;
            c.move.tmbbox[3] = x + thing.radius;
            c.move.tmbbox[2] = x - thing.radius;
            uint32 sub = R_Main.R_PointInSubsector(x, y, c.map);
            uint32 sec = c.map.subsectors[sub].sector;
            c.move.ceilingline = C.NULL;
            c.move.tmfloorz = c.map.sectors[sec].floorheight;
            c.move.tmdropoffz = c.move.tmfloorz;
            c.move.tmceilingz = c.map.sectors[sec].ceilingheight;
            ++c.state.validcount;
            c.move.numspechit = 0;
        }
    }

    function P_TeleportMove(GameContext memory c, uint32 id, int32 x, int32 y) internal view returns (bool) {
        unchecked {
            setCheck(c, id, x, y);
            int32 xl = (c.move.tmbbox[2] - c.state.blockmap.orgx - C.MAXRADIUS) >> 23;
            int32 xh = (c.move.tmbbox[3] - c.state.blockmap.orgx + C.MAXRADIUS) >> 23;
            int32 yl = (c.move.tmbbox[1] - c.state.blockmap.orgy - C.MAXRADIUS) >> 23;
            int32 yh = (c.move.tmbbox[0] - c.state.blockmap.orgy + C.MAXRADIUS) >> 23;
            for (int32 bx = xl; bx <= xh; bx++) {
                for (int32 by = yl; by <= yh; by++) {
                    if (!U.P_BlockThingsIterator(c, bx, by, PIT_StompThing)) return false;
                }
            }
            U.P_UnsetThingPosition(c, id);
            Mobj memory thing = c.state.mobjs[id];
            thing.floorz = c.move.tmfloorz;
            thing.ceilingz = c.move.tmceilingz;
            thing.x = x;
            thing.y = y;
            U.P_SetThingPosition(c, id);
            return true;
        }
    }

    function PIT_CheckLine(GameContext memory c, uint32 id) internal pure returns (bool) {
        unchecked {
            Line memory line = c.map.lines[id];
            int32[4] memory box = c.move.tmbbox;
            if (
                box[3] <= line.bbox[2] || box[2] >= line.bbox[3] || box[0] <= line.bbox[1]
                    || box[1] >= line.bbox[0]
            ) {
                return true;
            }
            if (U.P_BoxOnLineSide(box, line, c.map) != -1) return true;
            if (line.backsector == C.NULL) return false;
            Mobj memory thing = c.state.mobjs[c.move.tmthing];
            if (thing.flags & C.MF_MISSILE == 0) {
                if (line.flags & 1 != 0) return false;
                if (thing.player == C.NULL && line.flags & 2 != 0) return false;
            }
            U.P_LineOpening(c, id);
            if (c.move.opentop < c.move.tmceilingz) {
                c.move.tmceilingz = c.move.opentop;
                c.move.ceilingline = id;
            }
            if (c.move.openbottom > c.move.tmfloorz) c.move.tmfloorz = c.move.openbottom;
            if (c.move.lowfloor < c.move.tmdropoffz) c.move.tmdropoffz = c.move.lowfloor;
            if (line.special != 0) {
                if (c.move.numspechit >= 8) revert SpecialCrossOverflow();
                c.move.spechit[uint32(c.move.numspechit++)] = id;
            }
            return true;
        }
    }

    function PIT_CheckThing(GameContext memory c, uint32 id) internal view returns (bool) {
        unchecked {
            Mobj memory thing = c.state.mobjs[id];
            Mobj memory mover = c.state.mobjs[c.move.tmthing];
            if (thing.flags & (C.MF_SOLID | C.MF_SPECIAL | C.MF_SHOOTABLE) == 0) return true;
            int32 blockdist = thing.radius + mover.radius;
            if (U.abs(thing.x - c.move.tmx) >= blockdist || U.abs(thing.y - c.move.tmy) >= blockdist) {
                return true;
            }
            if (id == c.move.tmthing) return true;
            if (mover.flags & C.MF_SKULLFLY != 0) {
                int32 damage =
                    ((M_Random.P_Random(c.state) % 8) + 1) * c.definitions.mobjinfo[mover.mobjType].damage;
                c.hooks.damageMobj(c, id, c.move.tmthing, c.move.tmthing, damage);
                // Original tmthing is a shared global: nested death/sector callbacks may replace it.
                mover = c.state.mobjs[c.move.tmthing];
                mover.flags &= ~C.MF_SKULLFLY;
                mover.momx = 0;
                mover.momy = 0;
                mover.momz = 0;
                c.hooks
                    .setMobjState(
                        c, c.move.tmthing, uint32(c.definitions.mobjinfo[mover.mobjType].spawnstate)
                    );
                return false;
            }
            if (mover.flags & C.MF_MISSILE != 0) {
                if (mover.z > thing.z + thing.height || mover.z + mover.height < thing.z) return true;
                if (mover.target != C.NULL) {
                    uint32 kind = c.state.mobjs[mover.target].mobjType;
                    if (
                        kind == thing.mobjType
                            || (kind == P_Info.MT_KNIGHT && thing.mobjType == P_Info.MT_BRUISER)
                            || (kind == P_Info.MT_BRUISER && thing.mobjType == P_Info.MT_KNIGHT)
                    ) {
                        if (id == mover.target) return true;
                        if (thing.mobjType != P_Info.MT_PLAYER) return false;
                    }
                }
                if (thing.flags & C.MF_SHOOTABLE == 0) return thing.flags & C.MF_SOLID == 0;
                int32 damage =
                    ((M_Random.P_Random(c.state) % 8) + 1) * c.definitions.mobjinfo[mover.mobjType].damage;
                c.hooks.damageMobj(c, id, c.move.tmthing, mover.target, damage);
                return false;
            }
            if (thing.flags & C.MF_SPECIAL != 0) {
                bool solid = thing.flags & C.MF_SOLID != 0;
                if (c.move.tmflags & C.MF_PICKUP != 0) c.hooks.touchSpecialThing(c, id, c.move.tmthing);
                return !solid;
            }
            return thing.flags & C.MF_SOLID == 0;
        }
    }

    function P_CheckPosition(GameContext memory c, uint32 id, int32 x, int32 y) internal view returns (bool) {
        unchecked {
            setCheck(c, id, x, y);
            if (c.move.tmflags & C.MF_NOCLIP != 0) return true;
            int32 xl = (c.move.tmbbox[2] - c.state.blockmap.orgx - C.MAXRADIUS) >> 23;
            int32 xh = (c.move.tmbbox[3] - c.state.blockmap.orgx + C.MAXRADIUS) >> 23;
            int32 yl = (c.move.tmbbox[1] - c.state.blockmap.orgy - C.MAXRADIUS) >> 23;
            int32 yh = (c.move.tmbbox[0] - c.state.blockmap.orgy + C.MAXRADIUS) >> 23;
            for (int32 bx = xl; bx <= xh; bx++) {
                for (int32 by = yl; by <= yh; by++) {
                    if (!U.P_BlockThingsIterator(c, bx, by, PIT_CheckThing)) return false;
                }
            }
            xl = (c.move.tmbbox[2] - c.state.blockmap.orgx) >> 23;
            xh = (c.move.tmbbox[3] - c.state.blockmap.orgx) >> 23;
            yl = (c.move.tmbbox[1] - c.state.blockmap.orgy) >> 23;
            yh = (c.move.tmbbox[0] - c.state.blockmap.orgy) >> 23;
            for (int32 bx = xl; bx <= xh; bx++) {
                for (int32 by = yl; by <= yh; by++) {
                    if (!U.P_BlockLinesIterator(c, bx, by, PIT_CheckLine)) return false;
                }
            }
            return true;
        }
    }

    function P_TryMove(GameContext memory c, uint32 id, int32 x, int32 y) internal view returns (bool) {
        unchecked {
            c.move.floatok = false;
            if (!P_CheckPosition(c, id, x, y)) return false;
            Mobj memory thing = c.state.mobjs[id];
            if (thing.flags & C.MF_NOCLIP == 0) {
                if (c.move.tmceilingz - c.move.tmfloorz < thing.height) return false;
                c.move.floatok = true;
                if (thing.flags & C.MF_TELEPORT == 0 && c.move.tmceilingz - thing.z < thing.height) {
                    return false;
                }
                if (thing.flags & C.MF_TELEPORT == 0 && c.move.tmfloorz - thing.z > 24 * 65536) return false;
                if (
                    thing.flags & (C.MF_DROPOFF | C.MF_FLOAT) == 0
                        && c.move.tmfloorz - c.move.tmdropoffz > 24 * 65536
                ) {
                    return false;
                }
            }
            U.P_UnsetThingPosition(c, id);
            int32 oldx = thing.x;
            int32 oldy = thing.y;
            thing.floorz = c.move.tmfloorz;
            thing.ceilingz = c.move.tmceilingz;
            thing.x = x;
            thing.y = y;
            U.P_SetThingPosition(c, id);
            if (thing.flags & (C.MF_TELEPORT | C.MF_NOCLIP) == 0) {
                while (c.move.numspechit-- != 0) {
                    uint32 line = c.move.spechit[uint32(c.move.numspechit)];
                    int32 side = U.P_PointOnLineSide(thing.x, thing.y, c.map.lines[line], c.map);
                    int32 oldside = U.P_PointOnLineSide(oldx, oldy, c.map.lines[line], c.map);
                    if (side != oldside && c.map.lines[line].special != 0) {
                        c.hooks.crossSpecialLine(c, line, oldside, id);
                    }
                }
            }
            return true;
        }
    }

    function P_ThingHeightClip(GameContext memory c, uint32 id) internal view returns (bool) {
        unchecked {
            Mobj memory thing = c.state.mobjs[id];
            bool onfloor = thing.z == thing.floorz;
            P_CheckPosition(c, id, thing.x, thing.y);
            thing.floorz = c.move.tmfloorz;
            thing.ceilingz = c.move.tmceilingz;
            if (onfloor) thing.z = thing.floorz;
            else if (thing.z + thing.height > thing.ceilingz) thing.z = thing.ceilingz - thing.height;
            return thing.ceilingz - thing.floorz >= thing.height;
        }
    }

    function P_HitSlideLine(GameContext memory c, uint32 id) internal pure {
        unchecked {
            Line memory line = c.map.lines[id];
            if (line.slopetype == 0) {
                c.move.tmymove = 0;
                return;
            }
            if (line.slopetype == 1) {
                c.move.tmxmove = 0;
                return;
            }
            Mobj memory mo = c.state.mobjs[c.move.slidemo];
            int32 side = U.P_PointOnLineSide(mo.x, mo.y, line, c.map);
            RenderState memory rs;
            uint32 lineangle = R_Main.R_PointToAngle2(rs, 0, 0, line.dx, line.dy);
            if (side == 1) lineangle += Tables.ANG180;
            uint32 moveangle = R_Main.R_PointToAngle2(rs, 0, 0, c.move.tmxmove, c.move.tmymove);
            uint32 deltaangle = moveangle - lineangle;
            if (deltaangle > Tables.ANG180) deltaangle += Tables.ANG180;
            lineangle >>= 19;
            deltaangle >>= 19;
            int32 movelen = U.P_AproxDistance(c.move.tmxmove, c.move.tmymove);
            int32 newlen = F.FixedMul(movelen, Tables.finecosine(deltaangle));
            c.move.tmxmove = F.FixedMul(newlen, Tables.finecosine(lineangle));
            c.move.tmymove = F.FixedMul(newlen, Tables.finesine(lineangle));
        }
    }

    function PTR_SlideTraverse(GameContext memory c, Intercept memory hit) internal pure returns (bool) {
        unchecked {
            if (!hit.isaline) revert InvalidSlideIntercept();
            Line memory line = c.map.lines[hit.index];
            Mobj memory mo = c.state.mobjs[c.move.slidemo];
            if (line.flags & 4 == 0) {
                if (U.P_PointOnLineSide(mo.x, mo.y, line, c.map) != 0) return true;
            } else {
                U.P_LineOpening(c, hit.index);
                if (
                    c.move.openrange >= mo.height && c.move.opentop - mo.z >= mo.height
                        && c.move.openbottom - mo.z <= 24 * 65536
                ) return true;
            }
            if (hit.frac < c.move.bestslidefrac) {
                c.move.secondslidefrac = c.move.bestslidefrac;
                c.move.secondslideline = c.move.bestslideline;
                c.move.bestslidefrac = hit.frac;
                c.move.bestslideline = hit.index;
            }
            return false;
        }
    }

    function stairstep(GameContext memory c, uint32 id) private view {
        unchecked {
            Mobj memory mo = c.state.mobjs[id];
            if (!P_TryMove(c, id, mo.x, mo.y + mo.momy)) P_TryMove(c, id, mo.x + mo.momx, mo.y);
        }
    }

    function P_SlideMove(GameContext memory c, uint32 id) internal view {
        unchecked {
            c.move.slidemo = id;
            Mobj memory mo = c.state.mobjs[id];
            for (uint32 hitcount = 1; hitcount < 3; hitcount++) {
                int32 leadx = mo.momx > 0 ? mo.x + mo.radius : mo.x - mo.radius;
                int32 trailx = mo.momx > 0 ? mo.x - mo.radius : mo.x + mo.radius;
                int32 leady = mo.momy > 0 ? mo.y + mo.radius : mo.y - mo.radius;
                int32 traily = mo.momy > 0 ? mo.y - mo.radius : mo.y + mo.radius;
                c.move.bestslidefrac = 65537;
                U.P_PathTraverse(c, leadx, leady, leadx + mo.momx, leady + mo.momy, 1, PTR_SlideTraverse);
                U.P_PathTraverse(c, trailx, leady, trailx + mo.momx, leady + mo.momy, 1, PTR_SlideTraverse);
                U.P_PathTraverse(c, leadx, traily, leadx + mo.momx, traily + mo.momy, 1, PTR_SlideTraverse);
                if (c.move.bestslidefrac == 65537) {
                    stairstep(c, id);
                    return;
                }
                c.move.bestslidefrac -= 0x800;
                if (c.move.bestslidefrac > 0) {
                    int32 nx = F.FixedMul(mo.momx, c.move.bestslidefrac);
                    int32 ny = F.FixedMul(mo.momy, c.move.bestslidefrac);
                    if (!P_TryMove(c, id, mo.x + nx, mo.y + ny)) {
                        stairstep(c, id);
                        return;
                    }
                }
                c.move.bestslidefrac = 65536 - (c.move.bestslidefrac + 0x800);
                if (c.move.bestslidefrac > 65536) c.move.bestslidefrac = 65536;
                if (c.move.bestslidefrac <= 0) return;
                c.move.tmxmove = F.FixedMul(mo.momx, c.move.bestslidefrac);
                c.move.tmymove = F.FixedMul(mo.momy, c.move.bestslidefrac);
                P_HitSlideLine(c, c.move.bestslideline);
                mo.momx = c.move.tmxmove;
                mo.momy = c.move.tmymove;
                if (P_TryMove(c, id, mo.x + c.move.tmxmove, mo.y + c.move.tmymove)) return;
            }
            stairstep(c, id);
        }
    }

    function PTR_AimTraverse(GameContext memory c, Intercept memory hit) internal pure returns (bool) {
        unchecked {
            int32 dist = F.FixedMul(c.move.attackrange, hit.frac);
            if (hit.isaline) {
                Line memory line = c.map.lines[hit.index];
                if (line.flags & 4 == 0) return false;
                U.P_LineOpening(c, hit.index);
                if (c.move.openbottom >= c.move.opentop) return false;
                if (c.map.sectors[line.frontsector].floorheight != c.map.sectors[line.backsector].floorheight)
                {
                    int32 slope = F.FixedDiv(c.move.openbottom - c.move.shootz, dist);
                    if (slope > c.move.bottomslope) c.move.bottomslope = slope;
                }
                if (
                    c.map.sectors[line.frontsector].ceilingheight
                        != c.map.sectors[line.backsector].ceilingheight
                ) {
                    int32 slope = F.FixedDiv(c.move.opentop - c.move.shootz, dist);
                    if (slope < c.move.topslope) c.move.topslope = slope;
                }
                return c.move.topslope > c.move.bottomslope;
            }
            if (hit.index == c.move.shootthing) return true;
            Mobj memory th = c.state.mobjs[hit.index];
            if (th.flags & C.MF_SHOOTABLE == 0) return true;
            int32 top = F.FixedDiv(th.z + th.height - c.move.shootz, dist);
            if (top < c.move.bottomslope) return true;
            int32 bottom = F.FixedDiv(th.z - c.move.shootz, dist);
            if (bottom > c.move.topslope) return true;
            if (top > c.move.topslope) top = c.move.topslope;
            if (bottom < c.move.bottomslope) bottom = c.move.bottomslope;
            c.move.aimslope = (top + bottom) / 2;
            c.move.linetarget = hit.index;
            return false;
        }
    }

    function PTR_ShootTraverse(GameContext memory c, Intercept memory hit) internal view returns (bool) {
        unchecked {
            int32 dist;
            if (hit.isaline) {
                Line memory line = c.map.lines[hit.index];
                if (line.special != 0) c.hooks.shootSpecialLine(c, c.move.shootthing, hit.index);
                bool blocked = line.flags & 4 == 0;
                if (!blocked) {
                    U.P_LineOpening(c, hit.index);
                    // Original attackrange is read after the special-line callback.
                    dist = F.FixedMul(c.move.attackrange, hit.frac);
                    if (
                        c.map.sectors[line.frontsector].floorheight
                                != c.map.sectors[line.backsector].floorheight
                            && F.FixedDiv(c.move.openbottom - c.move.shootz, dist) > c.move.aimslope
                    ) blocked = true;
                    if (
                        !blocked
                            && c.map.sectors[line.frontsector].ceilingheight
                                != c.map.sectors[line.backsector].ceilingheight
                            && F.FixedDiv(c.move.opentop - c.move.shootz, dist) < c.move.aimslope
                    ) blocked = true;
                }
                if (!blocked) return true;
                int32 frac = hit.frac - F.FixedDiv(4 * 65536, c.move.attackrange);
                int32 x = c.path.trace.x + F.FixedMul(c.path.trace.dx, frac);
                int32 y = c.path.trace.y + F.FixedMul(c.path.trace.dy, frac);
                int32 z = c.move.shootz + F.FixedMul(c.move.aimslope, F.FixedMul(frac, c.move.attackrange));
                if (c.map.sectors[line.frontsector].ceilingpic == c.state.skyflatnum) {
                    if (z > c.map.sectors[line.frontsector].ceilingheight) return false;
                    if (
                        line.backsector != C.NULL
                            && c.map.sectors[line.backsector].ceilingpic == c.state.skyflatnum
                    ) return false;
                }
                c.hooks.spawnPuff(c, x, y, z);
                return false;
            }
            if (hit.index == c.move.shootthing) return true;
            Mobj memory th = c.state.mobjs[hit.index];
            if (th.flags & C.MF_SHOOTABLE == 0) return true;
            dist = F.FixedMul(c.move.attackrange, hit.frac);
            if (F.FixedDiv(th.z + th.height - c.move.shootz, dist) < c.move.aimslope) return true;
            if (F.FixedDiv(th.z - c.move.shootz, dist) > c.move.aimslope) return true;
            int32 frac = hit.frac - F.FixedDiv(10 * 65536, c.move.attackrange);
            int32 x = c.path.trace.x + F.FixedMul(c.path.trace.dx, frac);
            int32 y = c.path.trace.y + F.FixedMul(c.path.trace.dy, frac);
            int32 z = c.move.shootz + F.FixedMul(c.move.aimslope, F.FixedMul(frac, c.move.attackrange));
            if (th.flags & C.MF_NOBLOOD != 0) c.hooks.spawnPuff(c, x, y, z);
            else c.hooks.spawnBlood(c, x, y, z, c.move.la_damage);
            if (c.move.la_damage != 0) {
                c.hooks.damageMobj(c, hit.index, c.move.shootthing, c.move.shootthing, c.move.la_damage);
            }
            return false;
        }
    }

    function P_AimLineAttack(GameContext memory c, uint32 id, uint32 angle, int32 distance)
        internal
        view
        returns (int32)
    {
        unchecked {
            angle >>= 19;
            c.move.shootthing = id;
            Mobj memory t = c.state.mobjs[id];
            int32 x2 = t.x + (distance >> 16) * Tables.finecosine(angle);
            int32 y2 = t.y + (distance >> 16) * Tables.finesine(angle);
            c.move.shootz = t.z + (t.height >> 1) + 8 * 65536;
            c.move.topslope = 100 * 65536 / 160;
            c.move.bottomslope = -100 * 65536 / 160;
            c.move.attackrange = distance;
            c.move.linetarget = C.NULL;
            U.P_PathTraverse(c, t.x, t.y, x2, y2, 3, PTR_AimTraverse);
            return c.move.linetarget != C.NULL ? c.move.aimslope : int32(0);
        }
    }

    function P_LineAttack(
        GameContext memory c,
        uint32 id,
        uint32 angle,
        int32 distance,
        int32 slope,
        int32 damage
    ) internal view {
        unchecked {
            angle >>= 19;
            c.move.shootthing = id;
            c.move.la_damage = damage;
            Mobj memory t = c.state.mobjs[id];
            int32 x2 = t.x + (distance >> 16) * Tables.finecosine(angle);
            int32 y2 = t.y + (distance >> 16) * Tables.finesine(angle);
            c.move.shootz = t.z + (t.height >> 1) + 8 * 65536;
            c.move.attackrange = distance;
            c.move.aimslope = slope;
            U.P_PathTraverse(c, t.x, t.y, x2, y2, 3, PTR_ShootTraverse);
        }
    }

    function PTR_UseTraverse(GameContext memory c, Intercept memory hit) internal view returns (bool) {
        Line memory line = c.map.lines[hit.index];
        if (line.special == 0) {
            U.P_LineOpening(c, hit.index);
            return c.move.openrange > 0;
        }
        Mobj memory thing = c.state.mobjs[c.move.usething];
        int32 side = U.P_PointOnLineSide(thing.x, thing.y, line, c.map) == 1 ? int32(1) : int32(0);
        c.hooks.useSpecialLine(c, c.move.usething, hit.index, side);
        return false;
    }

    function P_UseLines(GameContext memory c, uint32 player) internal view {
        unchecked {
            c.move.usething = c.state.players[player].mo;
            Mobj memory thing = c.state.mobjs[c.move.usething];
            uint32 angle = thing.angle >> 19;
            int32 x2 = thing.x + 64 * Tables.finecosine(angle);
            int32 y2 = thing.y + 64 * Tables.finesine(angle);
            U.P_PathTraverse(c, thing.x, thing.y, x2, y2, 1, PTR_UseTraverse);
        }
    }

    function PIT_RadiusAttack(GameContext memory c, uint32 id) internal view returns (bool) {
        unchecked {
            Mobj memory thing = c.state.mobjs[id];
            Mobj memory spot = c.state.mobjs[c.move.bombspot];
            if (
                thing.flags & C.MF_SHOOTABLE == 0 || thing.mobjType == P_Info.MT_CYBORG
                    || thing.mobjType == P_Info.MT_SPIDER
            ) return true;
            int32 dx = U.abs(thing.x - spot.x);
            int32 dy = U.abs(thing.y - spot.y);
            int32 dist = ((dx > dy ? dx : dy) - thing.radius) >> 16;
            if (dist < 0) dist = 0;
            if (dist >= c.move.bombdamage) return true;
            if (c.hooks.checkSight(c, id, c.move.bombspot)) {
                c.hooks.damageMobj(c, id, c.move.bombspot, c.move.bombsource, c.move.bombdamage - dist);
            }
            return true;
        }
    }

    function P_RadiusAttack(GameContext memory c, uint32 spotid, uint32 source, int32 damage) internal view {
        unchecked {
            Mobj memory spot = c.state.mobjs[spotid];
            int32 dist = (damage + C.MAXRADIUS) << 16;
            int32 yh = (spot.y + dist - c.state.blockmap.orgy) >> 23;
            int32 yl = (spot.y - dist - c.state.blockmap.orgy) >> 23;
            int32 xh = (spot.x + dist - c.state.blockmap.orgx) >> 23;
            int32 xl = (spot.x - dist - c.state.blockmap.orgx) >> 23;
            c.move.bombspot = spotid;
            c.move.bombsource = source;
            c.move.bombdamage = damage;
            for (int32 y = yl; y <= yh; y++) {
                for (int32 x = xl; x <= xh; x++) {
                    U.P_BlockThingsIterator(c, x, y, PIT_RadiusAttack);
                }
            }
        }
    }

    function PIT_ChangeSector(GameContext memory c, uint32 id) internal view returns (bool) {
        unchecked {
            if (P_ThingHeightClip(c, id)) return true;
            Mobj memory thing = c.state.mobjs[id];
            if (thing.health <= 0) {
                c.hooks.setMobjState(c, id, P_Info.S_GIBS);
                thing.flags &= ~C.MF_SOLID;
                thing.height = 0;
                thing.radius = 0;
                return true;
            }
            if (thing.flags & C.MF_DROPPED != 0) {
                c.hooks.removeMobj(c, id);
                return true;
            }
            if (thing.flags & C.MF_SHOOTABLE == 0) return true;
            c.move.nofit = true;
            if (c.move.crushchange && c.state.leveltime & 3 == 0) {
                c.hooks.damageMobj(c, id, C.NULL, C.NULL, 10);
                uint32 mo =
                    c.hooks.spawnMobj(c, thing.x, thing.y, thing.z + thing.height / 2, P_Info.MT_BLOOD);
                int32 r1 = M_Random.P_Random(c.state);
                int32 r2 = M_Random.P_Random(c.state);
                c.state.mobjs[mo].momx = (r1 - r2) << 12;
                r1 = M_Random.P_Random(c.state);
                r2 = M_Random.P_Random(c.state);
                c.state.mobjs[mo].momy = (r1 - r2) << 12;
            }
            return true;
        }
    }

    function P_ChangeSector(GameContext memory c, uint32 sector, bool crunch) internal view returns (bool) {
        c.move.nofit = false;
        c.move.crushchange = crunch;
        int32[4] memory box = c.state.sectors[sector].blockbox;
        for (int32 x = box[2]; x <= box[3]; x++) {
            for (int32 y = box[1]; y <= box[0]; y++) {
                U.P_BlockThingsIterator(c, x, y, PIT_ChangeSector);
            }
        }
        return c.move.nofit;
    }
}
