// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {GameContext, Mobj, DivLine, Intercept, GameConst as C} from "./p_game_state.sol";
import {MapData, Line, Vertex} from "./r_defs.sol";
import {M_Fixed as F} from "./m_fixed.sol";
import {R_Main} from "./r_main.sol";

/// @custom:source linuxdoom-1.10/p_maputl.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
library P_MapUtl {
    error UndefinedMapArithmetic();
    error InvalidBlockMap();
    error InterceptOverflow();

    function abs(int32 v) internal pure returns (int32) {
        if (v == type(int32).min) revert UndefinedMapArithmetic();
        return v < 0 ? -v : v;
    }

    function P_AproxDistance(int32 dx, int32 dy) internal pure returns (int32) {
        unchecked {
            dx = abs(dx);
            dy = abs(dy);
            return dx < dy ? dx + dy - (dx >> 1) : dx + dy - (dy >> 1);
        }
    }

    function P_PointOnLineSide(int32 x, int32 y, Line memory line, MapData memory map)
        internal
        pure
        returns (int32)
    {
        unchecked {
            Vertex memory v = map.vertexes[line.v1];
            if (line.dx == 0) return (x <= v.x ? line.dy > 0 : line.dy < 0) ? int32(1) : int32(0);
            if (line.dy == 0) return (y <= v.y ? line.dx < 0 : line.dx > 0) ? int32(1) : int32(0);
            int32 dx = x - v.x;
            int32 dy = y - v.y;
            return F.FixedMul(dy, line.dx >> 16) < F.FixedMul(line.dy >> 16, dx) ? int32(0) : int32(1);
        }
    }

    function P_BoxOnLineSide(int32[4] memory box, Line memory line, MapData memory map)
        internal
        pure
        returns (int32)
    {
        int32 p1;
        int32 p2;
        Vertex memory v = map.vertexes[line.v1];
        if (line.slopetype == 0) {
            p1 = box[0] > v.y ? int32(1) : int32(0);
            p2 = box[1] > v.y ? int32(1) : int32(0);
            if (line.dx < 0) {
                p1 ^= 1;
                p2 ^= 1;
            }
        } else if (line.slopetype == 1) {
            p1 = box[3] < v.x ? int32(1) : int32(0);
            p2 = box[2] < v.x ? int32(1) : int32(0);
            if (line.dy < 0) {
                p1 ^= 1;
                p2 ^= 1;
            }
        } else if (line.slopetype == 2) {
            p1 = P_PointOnLineSide(box[2], box[0], line, map);
            p2 = P_PointOnLineSide(box[3], box[1], line, map);
        } else if (line.slopetype == 3) {
            p1 = P_PointOnLineSide(box[3], box[0], line, map);
            p2 = P_PointOnLineSide(box[2], box[1], line, map);
        } else {
            revert UndefinedMapArithmetic();
        }
        return p1 == p2 ? p1 : int32(-1);
    }

    function P_PointOnDivlineSide(int32 x, int32 y, DivLine memory line) internal pure returns (int32) {
        unchecked {
            if (line.dx == 0) return (x <= line.x ? line.dy > 0 : line.dy < 0) ? int32(1) : int32(0);
            if (line.dy == 0) return (y <= line.y ? line.dx < 0 : line.dx > 0) ? int32(1) : int32(0);
            int32 dx = x - line.x;
            int32 dy = y - line.y;
            if ((line.dy ^ line.dx ^ dx ^ dy) < 0) return (line.dy ^ dx) < 0 ? int32(1) : int32(0);
            return F.FixedMul(dy >> 8, line.dx >> 8) < F.FixedMul(line.dy >> 8, dx >> 8) ? int32(0) : int32(1);
        }
    }

    function P_MakeDivline(Line memory line, MapData memory map) internal pure returns (DivLine memory dl) {
        dl.x = map.vertexes[line.v1].x;
        dl.y = map.vertexes[line.v1].y;
        dl.dx = line.dx;
        dl.dy = line.dy;
    }

    function P_InterceptVector(DivLine memory v2, DivLine memory v1) internal pure returns (int32) {
        unchecked {
            int32 den = F.FixedMul(v1.dy >> 8, v2.dx) - F.FixedMul(v1.dx >> 8, v2.dy);
            if (den == 0) return 0;
            int32 num = F.FixedMul((v1.x - v2.x) >> 8, v1.dy) + F.FixedMul((v2.y - v1.y) >> 8, v1.dx);
            return F.FixedDiv(num, den);
        }
    }

    function P_LineOpening(GameContext memory c, uint32 id) internal pure {
        unchecked {
            Line memory line = c.map.lines[id];
            if (line.sidenum[1] == C.NULL) {
                c.move.openrange = 0;
                return;
            }
            int32 ff = c.map.sectors[line.frontsector].floorheight;
            int32 bf = c.map.sectors[line.backsector].floorheight;
            int32 fc = c.map.sectors[line.frontsector].ceilingheight;
            int32 bc = c.map.sectors[line.backsector].ceilingheight;
            c.move.opentop = fc < bc ? fc : bc;
            if (ff > bf) {
                c.move.openbottom = ff;
                c.move.lowfloor = bf;
            } else {
                c.move.openbottom = bf;
                c.move.lowfloor = ff;
            }
            c.move.openrange = c.move.opentop - c.move.openbottom;
        }
    }

    function P_UnsetThingPosition(GameContext memory c, uint32 id) internal pure {
        unchecked {
            Mobj memory t = c.state.mobjs[id];
            if (t.flags & C.MF_NOSECTOR == 0) {
                if (t.snext != C.NULL) c.state.mobjs[t.snext].sprev = t.sprev;
                if (t.sprev != C.NULL) c.state.mobjs[t.sprev].snext = t.snext;
                else c.state.sectors[c.map.subsectors[t.subsector].sector].thinglist = t.snext;
            }
            if (t.flags & C.MF_NOBLOCKMAP == 0) {
                if (t.bnext != C.NULL) c.state.mobjs[t.bnext].bprev = t.bprev;
                if (t.bprev != C.NULL) {
                    c.state.mobjs[t.bprev].bnext = t.bnext;
                } else {
                    int32 bx = (t.x - c.state.blockmap.orgx) >> 23;
                    int32 by = (t.y - c.state.blockmap.orgy) >> 23;
                    if (inBlock(c, bx, by)) {
                        c.state.blockmap.heads[uint32(by * c.state.blockmap.width + bx)] = t.bnext;
                    }
                }
            }
        }
    }

    function P_SetThingPosition(GameContext memory c, uint32 id) internal pure {
        unchecked {
            Mobj memory t = c.state.mobjs[id];
            t.subsector = R_Main.R_PointInSubsector(t.x, t.y, c.map);
            if (t.flags & C.MF_NOSECTOR == 0) {
                uint32 sec = c.map.subsectors[t.subsector].sector;
                t.sprev = C.NULL;
                t.snext = c.state.sectors[sec].thinglist;
                if (t.snext != C.NULL) c.state.mobjs[t.snext].sprev = id;
                c.state.sectors[sec].thinglist = id;
            }
            if (t.flags & C.MF_NOBLOCKMAP == 0) {
                int32 bx = (t.x - c.state.blockmap.orgx) >> 23;
                int32 by = (t.y - c.state.blockmap.orgy) >> 23;
                if (inBlock(c, bx, by)) {
                    uint32 block = uint32(by * c.state.blockmap.width + bx);
                    t.bprev = C.NULL;
                    t.bnext = c.state.blockmap.heads[block];
                    if (t.bnext != C.NULL) c.state.mobjs[t.bnext].bprev = id;
                    c.state.blockmap.heads[block] = id;
                } else {
                    t.bnext = C.NULL;
                    t.bprev = C.NULL;
                }
            }
        }
    }

    function inBlock(GameContext memory c, int32 x, int32 y) internal pure returns (bool) {
        return x >= 0 && y >= 0 && x < c.state.blockmap.width && y < c.state.blockmap.height;
    }

    function P_BlockLinesIterator(
        GameContext memory c,
        int32 x,
        int32 y,
        function(GameContext memory, uint32) internal view returns (bool) func
    ) internal view returns (bool) {
        if (!inBlock(c, x, y)) {
            return true;
        }
        int32 offset = int32(c.state.blockmap.lump[uint32(y * c.state.blockmap.width + x) + 4]);
        if (offset < 0) revert InvalidBlockMap();
        for (uint32 p = uint32(offset);; p++) {
            if (p >= c.state.blockmap.lump.length) revert InvalidBlockMap();
            int16 raw = c.state.blockmap.lump[p];
            if (raw == -1) break;
            if (raw < 0 || uint32(uint16(raw)) >= c.map.lines.length) revert InvalidBlockMap();
            uint32 id = uint32(uint16(raw));
            if (c.state.lineValidcount[id] == c.state.validcount) continue;
            c.state.lineValidcount[id] = c.state.validcount;
            if (!func(c, id)) return false;
        }
        return true;
    }

    function P_BlockThingsIterator(
        GameContext memory c,
        int32 x,
        int32 y,
        function(GameContext memory, uint32) internal view returns (bool) func
    ) internal view returns (bool) {
        if (!inBlock(c, x, y)) {
            return true;
        }
        uint32 id = c.state.blockmap.heads[uint32(y * c.state.blockmap.width + x)];
        while (id != C.NULL) {
            if (!func(c, id)) return false;
            id = c.state.mobjs[id].bnext;
        }
        return true;
    }

    function addIntercept(GameContext memory c, int32 frac, bool line, uint32 id) internal pure {
        if (c.path.count >= 128) revert InterceptOverflow();
        c.path.intercepts[c.path.count++] = Intercept(frac, line, id);
    }

    function PIT_AddLineIntercepts(GameContext memory c, uint32 id) internal pure returns (bool) {
        unchecked {
            Line memory line = c.map.lines[id];
            DivLine memory trace = c.path.trace;
            int32 s1;
            int32 s2;
            if (
                trace.dx > 16 * 65536 || trace.dy > 16 * 65536 || trace.dx < -16 * 65536
                    || trace.dy < -16 * 65536
            ) {
                s1 = P_PointOnDivlineSide(c.map.vertexes[line.v1].x, c.map.vertexes[line.v1].y, trace);
                s2 = P_PointOnDivlineSide(c.map.vertexes[line.v2].x, c.map.vertexes[line.v2].y, trace);
            } else {
                s1 = P_PointOnLineSide(trace.x, trace.y, line, c.map);
                s2 = P_PointOnLineSide(trace.x + trace.dx, trace.y + trace.dy, line, c.map);
            }
            if (s1 == s2) return true;
            int32 frac = P_InterceptVector(trace, P_MakeDivline(line, c.map));
            if (frac < 0) return true;
            if (c.path.earlyout && frac < 65536 && line.backsector == C.NULL) return false;
            addIntercept(c, frac, true, id);
            return true;
        }
    }

    function PIT_AddThingIntercepts(GameContext memory c, uint32 id) internal pure returns (bool) {
        unchecked {
            Mobj memory t = c.state.mobjs[id];
            DivLine memory dl;
            int32 x1 = t.x - t.radius;
            int32 x2 = t.x + t.radius;
            int32 y1;
            int32 y2;
            if ((c.path.trace.dx ^ c.path.trace.dy) > 0) {
                y1 = t.y + t.radius;
                y2 = t.y - t.radius;
            } else {
                y1 = t.y - t.radius;
                y2 = t.y + t.radius;
            }
            if (P_PointOnDivlineSide(x1, y1, c.path.trace) == P_PointOnDivlineSide(x2, y2, c.path.trace)) {
                return true;
            }
            dl = DivLine(x1, y1, x2 - x1, y2 - y1);
            int32 frac = P_InterceptVector(c.path.trace, dl);
            if (frac >= 0) addIntercept(c, frac, false, id);
            return true;
        }
    }

    function P_TraverseIntercepts(
        GameContext memory c,
        function(GameContext memory, Intercept memory) internal view returns (bool) func,
        int32 maxfrac
    ) internal view returns (bool) {
        for (uint32 count = c.path.count; count > 0; count--) {
            int32 dist = type(int32).max;
            uint32 at = C.NULL;
            for (uint32 p; p < c.path.count; p++) {
                if (c.path.intercepts[p].frac < dist) {
                    dist = c.path.intercepts[p].frac;
                    at = p;
                }
            }
            if (dist > maxfrac) return true;
            if (at == C.NULL) revert UndefinedMapArithmetic();
            if (!func(c, c.path.intercepts[at])) return false;
            c.path.intercepts[at].frac = type(int32).max;
        }
        return true;
    }

    /// @dev Original P_PathTraverse local variables. Each call owns a fresh allocation;
    /// nested traversal callbacks cannot alias this work with persisted path globals.
    struct PathTraverseWork {
        int32 xt1;
        int32 yt1;
        int32 xt2;
        int32 yt2;
        int32 mapxstep;
        int32 mapystep;
        int32 stepFraction;
        int32 ystep;
        int32 xstep;
        int32 yintercept;
        int32 xintercept;
        int32 mapx;
        int32 mapy;
    }

    function P_PathTraverse(
        GameContext memory c,
        int32 x1,
        int32 y1,
        int32 x2,
        int32 y2,
        int32 flags,
        function(GameContext memory, Intercept memory) internal view returns (bool) trav
    ) internal view returns (bool) {
        PathTraverseWork memory work;
        unchecked {
            c.path.earlyout = flags & 4 != 0;
            ++c.state.validcount;
            c.path.count = 0;
            if (((x1 - c.state.blockmap.orgx) & (128 * 65536 - 1)) == 0) x1 += 65536;
            if (((y1 - c.state.blockmap.orgy) & (128 * 65536 - 1)) == 0) y1 += 65536;
            c.path.trace = DivLine(x1, y1, x2 - x1, y2 - y1);
            x1 -= c.state.blockmap.orgx;
            y1 -= c.state.blockmap.orgy;
            work.xt1 = x1 >> 23;
            work.yt1 = y1 >> 23;
            x2 -= c.state.blockmap.orgx;
            y2 -= c.state.blockmap.orgy;
            work.xt2 = x2 >> 23;
            work.yt2 = y2 >> 23;

            if (work.xt2 > work.xt1) {
                work.mapxstep = 1;
                work.stepFraction = 65536 - ((x1 >> 7) & 65535);
                work.ystep = F.FixedDiv(y2 - y1, abs(x2 - x1));
            } else if (work.xt2 < work.xt1) {
                work.mapxstep = -1;
                work.stepFraction = (x1 >> 7) & 65535;
                work.ystep = F.FixedDiv(y2 - y1, abs(x2 - x1));
            } else {
                work.stepFraction = 65536;
                work.ystep = 256 * 65536;
            }
            work.yintercept = (y1 >> 7) + F.FixedMul(work.stepFraction, work.ystep);
            if (work.yt2 > work.yt1) {
                work.mapystep = 1;
                work.stepFraction = 65536 - ((y1 >> 7) & 65535);
                work.xstep = F.FixedDiv(x2 - x1, abs(y2 - y1));
            } else if (work.yt2 < work.yt1) {
                work.mapystep = -1;
                work.stepFraction = (y1 >> 7) & 65535;
                work.xstep = F.FixedDiv(x2 - x1, abs(y2 - y1));
            } else {
                work.stepFraction = 65536;
                work.xstep = 256 * 65536;
            }
            work.xintercept = (x1 >> 7) + F.FixedMul(work.stepFraction, work.xstep);
            work.mapx = work.xt1;
            work.mapy = work.yt1;
            for (uint32 count; count < 64; count++) {
                if (flags & 1 != 0 && !P_BlockLinesIterator(c, work.mapx, work.mapy, PIT_AddLineIntercepts)) {
                    return false;
                }
                if (flags & 2 != 0 && !P_BlockThingsIterator(c, work.mapx, work.mapy, PIT_AddThingIntercepts))
                {
                    return false;
                }
                if (work.mapx == work.xt2 && work.mapy == work.yt2) break;
                if (work.yintercept >> 16 == work.mapy) {
                    work.yintercept += work.ystep;
                    work.mapx += work.mapxstep;
                } else if (work.xintercept >> 16 == work.mapx) {
                    work.xintercept += work.xstep;
                    work.mapy += work.mapystep;
                }
            }
            return P_TraverseIntercepts(c, trav, 65536);
        }
    }
}
