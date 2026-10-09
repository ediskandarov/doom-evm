// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {RenderContext, ClipRange, DrawSeg} from "./r_render_state.sol";
import {Node, Seg, Sector, Subsector} from "./r_defs.sol";
import {R_Main} from "./r_main.sol";
import {R_Plane} from "./r_plane.sol";
import {Tables} from "./tables.sol";

/// @custom:source linuxdoom-1.10/r_bsp.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @dev Memory callbacks retain original cross-module calls without circular imports.
library R_BSP {
    error BSPBounds();
    error BSPCycle();
    error ClipOverflow();
    uint32 private constant NULL = type(uint32).max;

    function R_ClearDrawSegs(RenderContext memory ctx) internal pure {
        // Original only rewinds ds_p: preserve scratch fields in existing entries on reuse.
        if (ctx.drawsegs.length != 256) ctx.drawsegs = new DrawSeg[](256);
        ctx.drawsegCount = 0;
    }

    function R_ClearClipSegs(RenderContext memory ctx) internal pure {
        if (ctx.rs.width == 0 || ctx.rs.width > 320) revert BSPBounds();
        if (ctx.solidsegs.length != 32) ctx.solidsegs = new ClipRange[](32);
        ctx.solidsegs[0].first = -0x7fffffff;
        ctx.solidsegs[0].last = -1;
        ctx.solidsegs[1].first = int32(uint32(ctx.rs.width));
        ctx.solidsegs[1].last = 0x7fffffff;
        ctx.solidsegCount = 2;
    }

    function _range(RenderContext memory ctx, int32 first, int32 last) private pure {
        if (
            first == type(int32).min || last < first || ctx.solidsegCount < 1 || ctx.solidsegCount > 32
                || ctx.solidsegs.length != 32
        ) revert BSPBounds();
    }

    function _storeWall(
        RenderContext memory ctx,
        int32 first,
        int32 last,
        function(RenderContext memory, int32, int32) internal view storeWall
    ) private view {
        storeWall(ctx, first, last);
    }

    function _copy(RenderContext memory ctx, uint32 dst, uint32 src) private pure {
        // C structure assignment copies fields; Solidity memory structure assignment aliases.
        ctx.solidsegs[dst].first = ctx.solidsegs[src].first;
        ctx.solidsegs[dst].last = ctx.solidsegs[src].last;
    }

    function R_ClipSolidWallSegment(
        RenderContext memory ctx,
        int32 first,
        int32 last,
        function(RenderContext memory, int32, int32) internal view storeWall
    ) internal view {
        _range(ctx, first, last);
        uint32 start;
        while (ctx.solidsegs[start].last < first - 1) if (++start >= ctx.solidsegCount) revert BSPBounds();
        if (first < ctx.solidsegs[start].first) {
            if (last < ctx.solidsegs[start].first - 1) {
                if (ctx.solidsegCount == 32) revert ClipOverflow();
                _storeWall(ctx, first, last, storeWall);
                uint32 insert = ctx.solidsegCount++;
                while (insert != start) {
                    _copy(ctx, insert, insert - 1);
                    --insert;
                }
                ctx.solidsegs[insert].first = first;
                ctx.solidsegs[insert].last = last;
                return;
            }
            _storeWall(ctx, first, ctx.solidsegs[start].first - 1, storeWall);
            ctx.solidsegs[start].first = first;
        }
        if (last <= ctx.solidsegs[start].last) return;
        uint32 next = start;
        while (true) {
            if (next + 1 >= ctx.solidsegCount) revert BSPBounds();
            if (last < ctx.solidsegs[next + 1].first - 1) {
                _storeWall(ctx, ctx.solidsegs[next].last + 1, last, storeWall);
                ctx.solidsegs[start].last = last;
                break;
            }
            _storeWall(ctx, ctx.solidsegs[next].last + 1, ctx.solidsegs[next + 1].first - 1, storeWall);
            ++next;
            if (last <= ctx.solidsegs[next].last) {
                ctx.solidsegs[start].last = ctx.solidsegs[next].last;
                break;
            }
        }
        if (next == start) return;
        // Preserve the original counted stale tail: while(next++ != newend)
        // copies the slot AT old newend and retains it inside the new count.
        // At count==32 this original read is outside solidsegs, hence rejected.
        while (next != ctx.solidsegCount) {
            ++next;
            ++start;
            if (next >= 32) revert ClipOverflow();
            _copy(ctx, start, next);
        }
        ctx.solidsegCount = start + 1;
    }

    function R_ClipPassWallSegment(
        RenderContext memory ctx,
        int32 first,
        int32 last,
        function(RenderContext memory, int32, int32) internal view storeWall
    ) internal view {
        _range(ctx, first, last);
        uint32 start;
        while (ctx.solidsegs[start].last < first - 1) if (++start >= ctx.solidsegCount) revert BSPBounds();
        if (first < ctx.solidsegs[start].first) {
            if (last < ctx.solidsegs[start].first - 1) {
                _storeWall(ctx, first, last, storeWall);
                return;
            }
            _storeWall(ctx, first, ctx.solidsegs[start].first - 1, storeWall);
        }
        if (last <= ctx.solidsegs[start].last) return;
        while (true) {
            if (start + 1 >= ctx.solidsegCount) revert BSPBounds();
            if (last < ctx.solidsegs[start + 1].first - 1) break;
            _storeWall(ctx, ctx.solidsegs[start].last + 1, ctx.solidsegs[start + 1].first - 1, storeWall);
            ++start;
            if (last <= ctx.solidsegs[start].last) return;
        }
        _storeWall(ctx, ctx.solidsegs[start].last + 1, last, storeWall);
    }

    function R_AddLine(
        RenderContext memory ctx,
        uint32 seg,
        function(RenderContext memory, int32, int32) internal view storeWall
    ) internal view {
        if (seg >= ctx.map.segs.length) revert BSPBounds();
        ctx.curline = seg;
        Seg memory line = ctx.map.segs[seg];
        uint32 angle1 =
            R_Main.R_PointToAngle(ctx.rs, ctx.map.vertexes[line.v1].x, ctx.map.vertexes[line.v1].y);
        uint32 angle2 =
            R_Main.R_PointToAngle(ctx.rs, ctx.map.vertexes[line.v2].x, ctx.map.vertexes[line.v2].y);
        unchecked {
            uint32 span = angle1 - angle2;
            if (span >= Tables.ANG180) return;
            ctx.wall.rw_angle1 = angle1;
            angle1 -= ctx.rs.viewangle;
            angle2 -= ctx.rs.viewangle;
            uint32 tspan = angle1 + ctx.rs.clipangle;
            if (tspan > 2 * ctx.rs.clipangle) {
                tspan -= 2 * ctx.rs.clipangle;
                if (tspan >= span) return;
                angle1 = ctx.rs.clipangle;
            }
            tspan = ctx.rs.clipangle - angle2;
            if (tspan > 2 * ctx.rs.clipangle) {
                tspan -= 2 * ctx.rs.clipangle;
                if (tspan >= span) return;
                angle2 = 0 - ctx.rs.clipangle;
            }
            angle1 = (angle1 + Tables.ANG90) >> 19;
            angle2 = (angle2 + Tables.ANG90) >> 19;
        }
        int32 x1 = ctx.rs.viewangletox[angle1];
        int32 x2 = ctx.rs.viewangletox[angle2];
        if (x1 == x2) return;
        ctx.backsector = line.backsector;
        if (ctx.backsector == NULL) {
            R_ClipSolidWallSegment(ctx, x1, x2 - 1, storeWall);
            return;
        }
        Sector memory back = ctx.map.sectors[ctx.backsector];
        Sector memory front = ctx.map.sectors[ctx.frontsector];
        if (back.ceilingheight <= front.floorheight || back.floorheight >= front.ceilingheight) {
            R_ClipSolidWallSegment(ctx, x1, x2 - 1, storeWall);
            return;
        }
        if (
            back.ceilingheight == front.ceilingheight && back.floorheight == front.floorheight
                && back.ceilingpic == front.ceilingpic && back.floorpic == front.floorpic
                && back.lightlevel == front.lightlevel && ctx.map.sides[line.sidedef].midtexture == 0
        ) return;
        R_ClipPassWallSegment(ctx, x1, x2 - 1, storeWall);
    }

    function R_CheckBBox(RenderContext memory ctx, int32[4] memory bbox) internal pure returns (bool) {
        uint32 boxx = ctx.rs.viewx <= bbox[2] ? 0 : ctx.rs.viewx < bbox[3] ? 1 : 2;
        uint32 boxy = ctx.rs.viewy >= bbox[0] ? 0 : ctx.rs.viewy > bbox[1] ? 1 : 2;
        uint32 boxpos = (boxy << 2) + boxx;
        if (boxpos == 5) return true;
        // Literal original checkcoord[12][4], packed one byte per coordinate.
        bytes memory coords =
            hex"030002010300020003010200000000000200020100000000030103000000000002000301020103010201030000000000";
        uint256 p = uint256(boxpos) * 4;
        uint32 angle1 = R_Main.R_PointToAngle(ctx.rs, bbox[uint8(coords[p])], bbox[uint8(coords[p + 1])]);
        uint32 angle2 = R_Main.R_PointToAngle(ctx.rs, bbox[uint8(coords[p + 2])], bbox[uint8(coords[p + 3])]);
        unchecked {
            angle1 -= ctx.rs.viewangle;
            angle2 -= ctx.rs.viewangle;
            uint32 span = angle1 - angle2;
            if (span >= Tables.ANG180) return true;
            uint32 tspan = angle1 + ctx.rs.clipangle;
            if (tspan > 2 * ctx.rs.clipangle) {
                tspan -= 2 * ctx.rs.clipangle;
                if (tspan >= span) return false;
                angle1 = ctx.rs.clipangle;
            }
            tspan = ctx.rs.clipangle - angle2;
            if (tspan > 2 * ctx.rs.clipangle) {
                tspan -= 2 * ctx.rs.clipangle;
                if (tspan >= span) return false;
                angle2 = 0 - ctx.rs.clipangle;
            }
            angle1 = (angle1 + Tables.ANG90) >> 19;
            angle2 = (angle2 + Tables.ANG90) >> 19;
        }
        int32 sx1 = ctx.rs.viewangletox[angle1];
        int32 sx2 = ctx.rs.viewangletox[angle2];
        if (sx1 == sx2) return false;
        --sx2;
        if (ctx.solidsegCount < 1 || ctx.solidsegCount > 32 || ctx.solidsegs.length != 32) {
            revert BSPBounds();
        }
        uint32 start;
        while (ctx.solidsegs[start].last < sx2) if (++start >= ctx.solidsegCount) revert BSPBounds();
        return !(sx1 >= ctx.solidsegs[start].first && sx2 <= ctx.solidsegs[start].last);
    }

    function R_Subsector(
        RenderContext memory ctx,
        uint32 num,
        function(RenderContext memory, int32, int32) internal view storeWall,
        function(RenderContext memory, uint32) internal view addSprites
    ) internal view {
        if (num >= ctx.map.subsectors.length) revert BSPBounds();
        unchecked {
            ++ctx.rs.sscount;
        }
        Subsector memory sub = ctx.map.subsectors[num];
        ctx.frontsector = sub.sector;
        Sector memory front = ctx.map.sectors[ctx.frontsector];
        if (front.floorheight < ctx.rs.viewz) {
            ctx.floorplane = R_Plane.R_FindPlane(ctx, front.floorheight, front.floorpic, front.lightlevel);
        } else {
            ctx.floorplane = NULL;
        }
        if (front.ceilingheight > ctx.rs.viewz || front.ceilingpic == ctx.skyflatnum) {
            ctx.ceilingplane =
                R_Plane.R_FindPlane(ctx, front.ceilingheight, front.ceilingpic, front.lightlevel);
        } else {
            ctx.ceilingplane = NULL;
        }
        addSprites(ctx, ctx.frontsector);
        if (sub.firstline > ctx.map.segs.length || sub.numlines > ctx.map.segs.length - sub.firstline) {
            revert BSPBounds();
        }
        for (uint32 i; i < sub.numlines; ++i) {
            R_AddLine(ctx, sub.firstline + i, storeWall);
        }
    }

    function R_RenderBSPNode(
        RenderContext memory ctx,
        int32 bspnum,
        function(RenderContext memory, int32, int32) internal view storeWall,
        function(RenderContext memory, uint32) internal view addSprites
    ) internal view {
        uint256 count = ctx.map.nodes.length;
        if (count > 32768) revert BSPBounds();
        bytes memory active = new bytes(count);
        // Original recursive enter/front/back/leave order, with an explicit EVM stack.
        // A valid path has at most count internal nodes followed by one leaf.
        int32[] memory work = new int32[](count + 1);
        uint8[] memory stage = new uint8[](count + 1);
        work[0] = bspnum;
        uint256 depth;
        while (true) {
            int32 current = work[depth];
            uint8 phase = stage[depth];
            if (phase == 0) {
                if (_enter(ctx, current, storeWall, addSprites, active)) {
                    if (depth == 0) break;
                    --depth;
                    continue;
                }
                Node memory bsp = ctx.map.nodes[uint32(current)];
                uint32 side = R_Main.R_PointOnSide(ctx.rs.viewx, ctx.rs.viewy, bsp);
                stage[depth] = uint8(side + 1);
                ++depth;
                work[depth] = int32(uint32(bsp.children[side]));
                stage[depth] = 0;
                continue;
            }
            if (phase == 1 || phase == 2) {
                Node memory bsp = ctx.map.nodes[uint32(current)];
                uint32 back = (uint32(phase) - 1) ^ 1;
                stage[depth] = 3;
                if (R_CheckBBox(ctx, bsp.bbox[back])) {
                    ++depth;
                    work[depth] = int32(uint32(bsp.children[back]));
                    stage[depth] = 0;
                    continue;
                }
            }
            active[uint32(current)] = 0;
            if (depth == 0) break;
            --depth;
        }
    }

    function _enter(
        RenderContext memory ctx,
        int32 bspnum,
        function(RenderContext memory, int32, int32) internal view storeWall,
        function(RenderContext memory, uint32) internal view addSprites,
        bytes memory active
    ) private view returns (bool leaf) {
        if ((uint32(bspnum) & 0x8000) != 0) {
            if (bspnum == -1) {
                R_Subsector(ctx, 0, storeWall, addSprites);
            } else {
                if (bspnum < 0 || uint32(bspnum) > 65535) revert BSPBounds();
                R_Subsector(ctx, uint32(bspnum) & 0x7fff, storeWall, addSprites);
            }
            return true;
        }
        if (bspnum < 0 || uint32(bspnum) >= ctx.map.nodes.length) revert BSPBounds();
        uint32 index = uint32(bspnum);
        if (active[index] != 0) revert BSPCycle();
        active[index] = 0x01;
        return false;
    }
}
