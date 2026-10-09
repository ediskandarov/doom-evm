// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {GameContext, Mobj, DivLine} from "./p_game_state.sol";
import {Line, Node, Seg, Subsector, Sector, Vertex} from "./r_defs.sol";
import {P_MapUtl} from "./p_maputl.sol";
import {M_Fixed as F} from "./m_fixed.sol";

/// @custom:source linuxdoom-1.10/p_sight.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
library P_Sight {
    error InvalidSightBSP();
    error InvalidRejectMatrix();

    function P_DivlineSide(int32 x, int32 y, DivLine memory node) internal pure returns (int32) {
        unchecked {
            if (node.dx == 0) {
                if (x == node.x) return 2;
                return (x <= node.x ? node.dy > 0 : node.dy < 0) ? int32(1) : int32(0);
            }
            // Original compares x with node.y in the horizontal on-line shortcut.
            if (node.dy == 0) {
                if (x == node.y) return 2;
                return (y <= node.y ? node.dx < 0 : node.dx > 0) ? int32(1) : int32(0);
            }
            int32 dx = x - node.x;
            int32 dy = y - node.y;
            int32 left = (node.dy >> 16) * (dx >> 16);
            int32 right = (dy >> 16) * (node.dx >> 16);
            if (right < left) return 0;
            if (left == right) return 2;
            return 1;
        }
    }

    function P_InterceptVector2(DivLine memory v2, DivLine memory v1) internal pure returns (int32) {
        return P_MapUtl.P_InterceptVector(v2, v1);
    }

    function P_CrossSubsector(GameContext memory c, uint32 num) internal pure returns (bool) {
        unchecked {
            if (num >= c.map.subsectors.length) revert InvalidSightBSP();
            Subsector memory sub = c.map.subsectors[num];
            for (uint32 p = sub.firstline; p < sub.firstline + sub.numlines; p++) {
                Seg memory seg = c.map.segs[p];
                Line memory line = c.map.lines[seg.linedef];
                if (c.state.lineValidcount[seg.linedef] == c.state.validcount) continue;
                c.state.lineValidcount[seg.linedef] = c.state.validcount;
                Vertex memory v1 = c.map.vertexes[line.v1];
                Vertex memory v2 = c.map.vertexes[line.v2];
                int32 s1 = P_DivlineSide(v1.x, v1.y, c.move.strace);
                int32 s2 = P_DivlineSide(v2.x, v2.y, c.move.strace);
                if (s1 == s2) continue;
                DivLine memory divl = DivLine(v1.x, v1.y, v2.x - v1.x, v2.y - v1.y);
                s1 = P_DivlineSide(c.move.strace.x, c.move.strace.y, divl);
                s2 = P_DivlineSide(c.move.t2x, c.move.t2y, divl);
                if (s1 == s2) continue;
                if (line.flags & 4 == 0) return false;
                Sector memory front = c.map.sectors[seg.frontsector];
                Sector memory back = c.map.sectors[seg.backsector];
                if (front.floorheight == back.floorheight && front.ceilingheight == back.ceilingheight) continue;
                int32 top = front.ceilingheight < back.ceilingheight
                    ? front.ceilingheight
                    : back.ceilingheight;
                int32 bottom = front.floorheight > back.floorheight ? front.floorheight : back.floorheight;
                if (bottom >= top) return false;
                int32 frac = P_InterceptVector2(c.move.strace, divl);
                if (front.floorheight != back.floorheight) {
                    int32 slope = F.FixedDiv(bottom - c.move.sightzstart, frac);
                    if (slope > c.move.bottomslope) c.move.bottomslope = slope;
                }
                if (front.ceilingheight != back.ceilingheight) {
                    int32 slope = F.FixedDiv(top - c.move.sightzstart, frac);
                    if (slope < c.move.topslope) c.move.topslope = slope;
                }
                if (c.move.topslope <= c.move.bottomslope) return false;
            }
            return true;
        }
    }

    function P_CrossBSPNode(GameContext memory c, int32 bspnum) internal pure returns (bool) {
        return cross(c, bspnum, 0);
    }

    function cross(GameContext memory c, int32 bspnum, uint32 depth) private pure returns (bool) {
        if (bspnum & 0x8000 != 0) return P_CrossSubsector(
            c, bspnum == -1 ? uint32(0) : uint32(bspnum) & 0xffff7fff
        );
        if (bspnum < 0 || uint32(bspnum) >= c.map.nodes.length || depth > c.map.nodes.length) revert InvalidSightBSP();
        Node memory bsp = c.map.nodes[uint32(bspnum)];
        DivLine memory dl = DivLine(bsp.x, bsp.y, bsp.dx, bsp.dy);
        int32 side = P_DivlineSide(c.move.strace.x, c.move.strace.y, dl);
        if (side == 2) side = 0;
        if (!cross(c, int32(uint32(bsp.children[uint32(side)])), depth + 1)) return false;
        if (side == P_DivlineSide(c.move.t2x, c.move.t2y, dl)) return true;
        return cross(c, int32(uint32(bsp.children[uint32(side) ^ 1])), depth + 1);
    }

    function P_CheckSight(GameContext memory c, uint32 id1, uint32 id2) internal pure returns (bool) {
        unchecked {
            Mobj memory t1 = c.state.mobjs[id1];
            Mobj memory t2 = c.state.mobjs[id2];
            uint32 s1 = c.map.subsectors[t1.subsector].sector;
            uint32 s2 = c.map.subsectors[t2.subsector].sector;
            uint256 pnum = uint256(s1) * c.map.sectors.length + s2;
            uint256 bytenum = pnum >> 3;
            if (bytenum >= c.state.rejectmatrix.length) revert InvalidRejectMatrix();
            if (uint8(c.state.rejectmatrix[bytenum]) & (1 << (pnum & 7)) != 0) {
                ++c.move.sightcounts[0];
                return false;
            }
            ++c.move.sightcounts[1];
            ++c.state.validcount;
            c.move.sightzstart = t1.z + t1.height - (t1.height >> 2);
            c.move.topslope = t2.z + t2.height - c.move.sightzstart;
            c.move.bottomslope = t2.z - c.move.sightzstart;
            c.move.strace = DivLine(t1.x, t1.y, t2.x - t1.x, t2.y - t1.y);
            c.move.t2x = t2.x;
            c.move.t2y = t2.y;
            return P_CrossBSPNode(c, int32(uint32(c.map.nodes.length)) - 1);
        }
    }
}
