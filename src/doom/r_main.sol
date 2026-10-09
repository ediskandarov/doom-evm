// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;

import {R_Draw} from "./r_draw.sol";
import {M_Fixed} from "./m_fixed.sol";
import {Tables} from "./tables.sol";
import {RenderState} from "./r_state.sol";
import {Node, Seg, MapData} from "./r_defs.sol";
import {RenderContext} from "./r_render_state.sol";
import {RenderHooks} from "./r_render_hooks.sol";

/// @custom:source linuxdoom-1.10/r_main.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @dev Original global variables are fields in rs. See PHASE2-GEOMETRY.md for C domain boundaries.
library R_Main {
    error InvalidBSP();
    error InvalidViewSize();
    error UndefinedGeometry();

    /// @dev Camera/light inputs are already in rs, replacing original player/global indirection.
    /// Original NetUpdate calls are platform boundaries with no work in this static EVM frame.
    function R_RenderPlayerView(RenderContext memory ctx, RenderHooks memory hooks) internal view {
        RenderState memory rs = ctx.rs;
        R_SetupFrame(rs, rs.viewx, rs.viewy, rs.viewz, rs.viewangle, rs.extralight, rs.fixedcolormap);
        hooks.clearClipSegs(ctx);
        hooks.clearDrawSegs(ctx);
        hooks.clearPlanes(ctx);
        hooks.clearSprites(ctx);
        if (ctx.map.nodes.length > 32768) revert InvalidBSP();
        hooks.renderBSPNode(ctx, int32(uint32(ctx.map.nodes.length)) - 1);
        hooks.drawPlanes(ctx);
        hooks.drawMasked(ctx);
    }

    function R_PointOnSide(int32 x, int32 y, Node memory node) internal pure returns (uint32) {
        if (node.dx == 0) return x <= node.x ? (node.dy > 0 ? 1 : 0) : (node.dy < 0 ? 1 : 0);
        if (node.dy == 0) return y <= node.y ? (node.dx < 0 ? 1 : 0) : (node.dx > 0 ? 1 : 0);
        unchecked {
            int32 dx = x - node.x;
            int32 dy = y - node.y;
            if ((uint32(node.dy ^ node.dx ^ dx ^ dy) & 0x80000000) != 0) {
                return (uint32(node.dy ^ dx) & 0x80000000) != 0 ? 1 : 0;
            }
            int32 left = M_Fixed.FixedMul(node.dy >> 16, dx);
            int32 right = M_Fixed.FixedMul(dy, node.dx >> 16);
            return right < left ? 0 : 1;
        }
    }

    function R_PointOnSegSide(int32 x, int32 y, Seg memory seg, MapData memory map)
        internal
        pure
        returns (uint32)
    {
        // This local node is only a transport for the identical partition calculation.
        Node memory node;
        node.x = map.vertexes[seg.v1].x;
        node.y = map.vertexes[seg.v1].y;
        unchecked {
            node.dx = map.vertexes[seg.v2].x - node.x;
            node.dy = map.vertexes[seg.v2].y - node.y;
        }
        return R_PointOnSide(x, y, node);
    }

    function R_PointToAngle(RenderState memory rs, int32 x, int32 y) internal pure returns (uint32) {
        unchecked {
            x -= rs.viewx;
            y -= rs.viewy;
            // Original negation of INT_MIN is undefined. Reject rather than claim equality.
            if (x == type(int32).min || y == type(int32).min) revert UndefinedGeometry();
            if (x == 0 && y == 0) return 0;
            if (x >= 0) {
                if (y >= 0) {
                    if (x > y) return Tables.tantoangle(Tables.SlopeDiv(uint32(y), uint32(x)));
                    return Tables.ANG90 - 1 - Tables.tantoangle(Tables.SlopeDiv(uint32(x), uint32(y)));
                }
                y = -y;
                if (x > y) return 0 - Tables.tantoangle(Tables.SlopeDiv(uint32(y), uint32(x)));
                return Tables.ANG270 + Tables.tantoangle(Tables.SlopeDiv(uint32(x), uint32(y)));
            }
            x = -x;
            if (y >= 0) {
                if (x > y) {
                    return Tables.ANG180 - 1 - Tables.tantoangle(Tables.SlopeDiv(uint32(y), uint32(x)));
                }
                return Tables.ANG90 + Tables.tantoangle(Tables.SlopeDiv(uint32(x), uint32(y)));
            }
            y = -y;
            if (x > y) return Tables.ANG180 + Tables.tantoangle(Tables.SlopeDiv(uint32(y), uint32(x)));
            return Tables.ANG270 - 1 - Tables.tantoangle(Tables.SlopeDiv(uint32(x), uint32(y)));
        }
    }

    function R_PointToAngle2(RenderState memory rs, int32 x1, int32 y1, int32 x2, int32 y2)
        internal
        pure
        returns (uint32)
    {
        rs.viewx = x1;
        rs.viewy = y1;
        return R_PointToAngle(rs, x2, y2);
    }

    function R_PointToDist(RenderState memory rs, int32 x, int32 y) internal pure returns (int32) {
        int32 dx;
        int32 dy;
        unchecked {
            dx = x - rs.viewx;
            dy = y - rs.viewy;
        }
        if (dx == type(int32).min || dy == type(int32).min) revert UndefinedGeometry();
        if (dx < 0) dx = -dx;
        if (dy < 0) dy = -dy;
        if (dy > dx) (dx, dy) = (dy, dx);
        // Original (0,0) indexes tantoangle[67108863] after FixedDiv saturation: undefined.
        if (dx == 0) revert UndefinedGeometry();
        uint32 angle = (Tables.tantoangle(uint32(M_Fixed.FixedDiv(dy, dx)) >> Tables.DBITS) + Tables.ANG90)
            >> Tables.ANGLETOFINESHIFT;
        return M_Fixed.FixedDiv(dx, Tables.finesine(angle));
    }

    function R_PointInSubsector(int32 x, int32 y, MapData memory map) internal pure returns (uint32) {
        uint256 count = map.nodes.length;
        if (map.subsectors.length == 0 || count > 32768) revert InvalidBSP();
        if (count == 0) return 0;
        uint256 n = count - 1;
        uint256 steps;
        while ((n & 0x8000) == 0) {
            if (n >= count || steps++ >= count) revert InvalidBSP();
            Node memory node = map.nodes[n];
            n = node.children[R_PointOnSide(x, y, node)];
        }
        n &= 0x7fff;
        if (n >= map.subsectors.length) revert InvalidBSP();
        return uint32(n);
    }

    function R_ScaleFromGlobalAngle(
        RenderState memory rs,
        uint32 visangle,
        uint32 rw_normalangle,
        int32 rw_distance
    ) internal pure returns (int32 scale) {
        unchecked {
            // C stores these unsigned angle expressions in signed int and shifts arithmetically.
            // A negative result is an out-of-bounds original sine index, never a wrapped lookup.
            int32 anglea = int32(Tables.ANG90 + (visangle - rs.viewangle));
            int32 angleb = int32(Tables.ANG90 + (visangle - rw_normalangle));
            if (anglea < 0 || angleb < 0 || rs.detailshift > 1) revert UndefinedGeometry();
            int32 sinea = Tables.finesine(uint32(anglea) >> 19);
            int32 sineb = Tables.finesine(uint32(angleb) >> 19);
            int32 num = M_Fixed.FixedMul(rs.projection, sineb) << rs.detailshift;
            int32 den = M_Fixed.FixedMul(rw_distance, sinea);
            if (den > num >> 16) {
                scale = M_Fixed.FixedDiv(num, den);
                if (scale > 64 * 65536) scale = 64 * 65536;
                else if (scale < 256) scale = 256;
            } else {
                scale = 64 * 65536;
            }
        }
    }

    function R_InitTextureMapping(RenderState memory rs) internal pure {
        if (rs.width == 0 || rs.width > 320 || rs.centerxfrac != int32(uint32(rs.width / 2) * 65536)) {
            revert InvalidViewSize();
        }
        rs.viewangletox = new int32[](4096);
        rs.xtoviewangle = new uint32[](uint256(rs.width) + 1);
        int32 focal = M_Fixed.FixedDiv(rs.centerxfrac, Tables.finetangent(3072));
        for (uint256 i; i < 4096; ++i) {
            int32 tangent = Tables.finetangent(i);
            int32 t;
            if (tangent > 2 * 65536) {
                t = -1;
            } else if (tangent < -2 * 65536) {
                t = int32(uint32(rs.width)) + 1;
            } else {
                t = M_Fixed.FixedMul(tangent, focal);
                t = (rs.centerxfrac - t + 65535) >> 16;
                if (t < -1) t = -1;
                else if (t > int32(uint32(rs.width)) + 1) t = int32(uint32(rs.width)) + 1;
            }
            rs.viewangletox[i] = t;
        }
        for (uint256 x; x <= rs.width; ++x) {
            uint32 i;
            while (rs.viewangletox[i] > int32(uint32(x))) ++i;
            unchecked {
                rs.xtoviewangle[x] = (i << 19) - Tables.ANG90;
            }
        }
        for (uint256 i; i < 4096; ++i) {
            // Original t=FixedMul(...); t=centerx-t are dead assignments, without output effects.
            if (rs.viewangletox[i] == -1) {
                rs.viewangletox[i] = 0;
            } else if (rs.viewangletox[i] == int32(uint32(rs.width)) + 1) {
                rs.viewangletox[i] = int32(uint32(rs.width));
            }
        }
        rs.clipangle = rs.xtoviewangle[0];
    }

    function R_InitLightTables(RenderState memory rs) internal pure {
        rs.zlight = new bytes(16 * 128);
        for (int32 i; i < 16; ++i) {
            int32 startmap = ((15 - i) * 2) * 32 / 16;
            for (int32 j; j < 128; ++j) {
                int32 scale = M_Fixed.FixedDiv(160 * 65536, (j + 1) << 20) >> 12;
                int32 level = startmap - scale / 2;
                if (level < 0) level = 0;
                if (level >= 32) level = 31;
                rs.zlight[uint32(i * 128 + j)] = bytes1(uint8(uint32(level)));
            }
        }
    }

    function R_SetupFrame(
        RenderState memory rs,
        int32 x,
        int32 y,
        int32 z,
        uint32 angle,
        int32 extralight,
        int32 fixedcolormap
    ) internal pure {
        if (fixedcolormap < -1 || fixedcolormap >= 34) revert UndefinedGeometry();
        rs.viewx = x;
        rs.viewy = y;
        rs.viewz = z;
        rs.viewangle = angle;
        rs.extralight = extralight;
        rs.viewsin = Tables.finesine(angle >> 19);
        rs.viewcos = Tables.finecosine(angle >> 19);
        rs.fixedcolormap = fixedcolormap;
        rs.sscount = 0;
        if (fixedcolormap != -1) {
            if (rs.scalelightfixed.length != 48) rs.scalelightfixed = new bytes(48);
            for (uint256 i; i < 48; ++i) {
                rs.scalelightfixed[i] = bytes1(uint8(uint32(fixedcolormap)));
            }
        }
        unchecked {
            ++rs.framecount;
            ++rs.validcount;
        }
    }

    function R_ExecuteSetViewSize(RenderState memory rs, uint32 blocks, uint32 detail) internal pure {
        if (blocks < 3 || blocks > 11 || detail > 1) revert InvalidViewSize();
        rs.scaledviewwidth = uint16(blocks == 11 ? 320 : blocks * 32);
        rs.height = uint16(blocks == 11 ? 200 : (blocks * 168 / 10) & ~uint32(7));
        rs.detailshift = uint8(detail);
        rs.width = rs.scaledviewwidth >> detail;
        rs.centery = int32(uint32(rs.height / 2));
        rs.centerx = int32(uint32(rs.width / 2));
        rs.centerxfrac = rs.centerx << 16;
        rs.centeryfrac = rs.centery << 16;
        rs.projection = rs.centerxfrac;
        R_Draw.R_InitBuffer(rs, rs.scaledviewwidth, rs.height);
        R_InitTextureMapping(rs);
        rs.pspritescale = int32(uint32(rs.width) * 65536 / 320);
        rs.pspriteiscale = int32(uint32(65536 * 320) / rs.width);
        rs.screenheightarray = new int32[](rs.width);
        for (uint256 i; i < rs.width; ++i) {
            rs.screenheightarray[i] = int32(uint32(rs.height));
        }
        rs.yslope = new int32[](rs.height);
        for (int32 i; i < int32(uint32(rs.height)); ++i) {
            int32 dy = ((i - int32(uint32(rs.height / 2))) * 65536) + 32768;
            if (dy < 0) dy = -dy;
            rs.yslope[uint32(i)] = M_Fixed.FixedDiv(int32(uint32(rs.scaledviewwidth / 2) * 65536), dy);
        }
        rs.distscale = new int32[](rs.width);
        for (uint256 i; i < rs.width; ++i) {
            int32 cosadj = Tables.finecosine(rs.xtoviewangle[i] >> 19);
            if (cosadj < 0) cosadj = -cosadj;
            rs.distscale[i] = M_Fixed.FixedDiv(65536, cosadj);
        }
        rs.scalelight = new bytes(16 * 48);
        for (int32 i; i < 16; ++i) {
            int32 startmap = ((15 - i) * 2) * 32 / 16;
            for (int32 j; j < 48; ++j) {
                int32 level = startmap - j * 320 / int32(uint32(rs.scaledviewwidth)) / 2;
                if (level < 0) level = 0;
                if (level >= 32) level = 31;
                rs.scalelight[uint32(i * 48 + j)] = bytes1(uint8(uint32(level)));
            }
        }
    }
}
