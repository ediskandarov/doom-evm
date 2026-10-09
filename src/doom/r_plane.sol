// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;

import {RenderContext, Visplane} from "./r_render_state.sol";
import {M_Fixed} from "./m_fixed.sol";
import {R_Data} from "./r_data.sol";
import {ColumnView} from "./r_data_types.sol";
import {R_Draw} from "./r_draw.sol";
import {Tables} from "./tables.sol";
import {Z_ZoneBacking} from "./z_zone_backing.sol";

/// @custom:source linuxdoom-1.10/r_plane.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @notice Original visplane construction, span mapping and sky/floor/ceiling drawing.
library R_Plane {
    error PlaneOverflow();
    error PlaneBounds();

    /// @custom:source R_InitPlanes (empty in the original).
    function R_InitPlanes() internal pure {}

    function R_ClearPlanes(RenderContext memory ctx) internal pure {
        uint256 width = ctx.rs.width;
        if (width == 0 || width > 320 || ctx.rs.height == 0 || ctx.rs.height > 200) revert PlaneBounds();
        ctx.floorclip = new int32[](width);
        ctx.ceilingclip = new int32[](width);
        ctx.negonearray = new int32[](width);
        for (uint256 i; i < width; ++i) {
            ctx.floorclip[i] = int32(uint32(ctx.rs.height));
            ctx.ceilingclip[i] = -1;
            ctx.negonearray[i] = -1;
        }
        if (ctx.visplanes.length != 128) ctx.visplanes = new Visplane[](128);
        ctx.visplaneCount = 0;
        ctx.openingCount = 0;
        ctx.floorplane = type(uint32).max;
        ctx.ceilingplane = type(uint32).max;
        // Only cachedheight is cleared by the C memset. Other caches and span starts survive frames.
        if (ctx.plane.cachedheight.length != 200) {
            ctx.plane.cachedheight = new int32[](200);
        } else {
            for (uint256 y; y < 200; ++y) {
                ctx.plane.cachedheight[y] = 0;
            }
        }
        if (ctx.plane.cacheddistance.length != 200) ctx.plane.cacheddistance = new int32[](200);
        if (ctx.plane.cachedxstep.length != 200) ctx.plane.cachedxstep = new int32[](200);
        if (ctx.plane.cachedystep.length != 200) ctx.plane.cachedystep = new int32[](200);
        if (ctx.plane.spanstart.length != 200) ctx.plane.spanstart = new int32[](200);
        uint32 angle;
        unchecked {
            angle = (ctx.rs.viewangle - Tables.ANG90) >> Tables.ANGLETOFINESHIFT;
        }
        ctx.plane.basexscale = M_Fixed.FixedDiv(Tables.finecosine(angle), ctx.rs.centerxfrac);
        ctx.plane.baseyscale = -M_Fixed.FixedDiv(Tables.finesine(angle), ctx.rs.centerxfrac);
    }

    function R_FindPlane(RenderContext memory ctx, int32 height, uint32 picnum, int16 lightlevel)
        internal
        pure
        returns (uint32)
    {
        if (picnum == ctx.skyflatnum) {
            height = 0;
            lightlevel = 0;
        }
        for (uint32 i; i < ctx.visplaneCount; ++i) {
            Visplane memory check = ctx.visplanes[i];
            if (height == check.height && picnum == check.picnum && lightlevel == check.lightlevel) return i;
        }
        return _newPlane(ctx, height, picnum, lightlevel, 320, -1);
    }

    function R_CheckPlane(RenderContext memory ctx, uint32 plane, int32 start, int32 stop)
        internal
        pure
        returns (uint32)
    {
        if (plane >= ctx.visplaneCount || start < 0 || start > stop || stop >= int32(uint32(ctx.rs.width))) revert PlaneBounds();
        Visplane memory pl = ctx.visplanes[plane];
        int32 intrl = start < pl.minx ? pl.minx : start;
        int32 unionl = start < pl.minx ? start : pl.minx;
        int32 intrh = stop > pl.maxx ? pl.maxx : stop;
        int32 unionh = stop > pl.maxx ? stop : pl.maxx;
        int32 x = intrl;
        for (; x <= intrh; ++x) {
            if (pl.top[uint32(x + 1)] != 0xff) break;
        }
        if (x > intrh) {
            pl.minx = unionl;
            pl.maxx = unionh;
            return plane;
        }
        // Original R_CheckPlane lacks the overflow check present in R_FindPlane.
        // Reject before allocating beyond the original fixed-capacity plane array.
        return _newPlane(ctx, pl.height, pl.picnum, pl.lightlevel, start, stop);
    }

    function _newPlane(
        RenderContext memory ctx,
        int32 height,
        uint32 picnum,
        int16 lightlevel,
        int32 minx,
        int32 maxx
    ) private pure returns (uint32 index) {
        if (ctx.visplaneCount >= 128 || ctx.visplanes.length != 128) revert PlaneOverflow();
        index = ctx.visplaneCount++;
        Visplane memory pl = ctx.visplanes[index];
        pl.height = height;
        pl.picnum = picnum;
        pl.lightlevel = lightlevel;
        pl.minx = minx;
        pl.maxx = maxx;
        if (pl.top.length != 322) pl.top = new bytes(322);
        if (pl.bottom.length != 322) pl.bottom = new bytes(322);
        // Original memset covers only top[320], leaving pads and bottom untouched.
        for (uint256 x = 1; x <= 320; ++x) {
            pl.top[x] = 0xff;
        }
    }

    function R_MapPlane(RenderContext memory ctx, int32 y, int32 x1, int32 x2) internal view {
        if (
            y < 0 || y >= int32(uint32(ctx.rs.height)) || x1 < 0 || x2 < x1
                || x2 >= int32(uint32(ctx.rs.width))
        ) revert PlaneBounds();
        uint32 row = uint32(y);
        int32 distance;
        if (ctx.plane.planeheight != ctx.plane.cachedheight[row]) {
            ctx.plane.cachedheight[row] = ctx.plane.planeheight;
            distance = M_Fixed.FixedMul(ctx.plane.planeheight, ctx.rs.yslope[row]);
            ctx.plane.cacheddistance[row] = distance;
            ctx.ds.xstep = M_Fixed.FixedMul(distance, ctx.plane.basexscale);
            ctx.ds.ystep = M_Fixed.FixedMul(distance, ctx.plane.baseyscale);
            ctx.plane.cachedxstep[row] = ctx.ds.xstep;
            ctx.plane.cachedystep[row] = ctx.ds.ystep;
        } else {
            distance = ctx.plane.cacheddistance[row];
            ctx.ds.xstep = ctx.plane.cachedxstep[row];
            ctx.ds.ystep = ctx.plane.cachedystep[row];
        }
        int32 length = M_Fixed.FixedMul(distance, ctx.rs.distscale[uint32(x1)]);
        uint32 angle;
        unchecked {
            angle = (ctx.rs.viewangle + ctx.rs.xtoviewangle[uint32(x1)]) >> Tables.ANGLETOFINESHIFT;
            ctx.ds.xfrac = ctx.rs.viewx + M_Fixed.FixedMul(Tables.finecosine(angle), length);
            ctx.ds.yfrac = -ctx.rs.viewy - M_Fixed.FixedMul(Tables.finesine(angle), length);
        }
        uint32 cmap;
        if (ctx.rs.fixedcolormap >= 0) {
            cmap = uint32(ctx.rs.fixedcolormap);
        } else {
            // C assigns the arithmetic signed shift to unsigned before clamping.
            uint32 index = uint32(distance >> 20);
            if (index >= 128) index = 127;
            if (ctx.plane.light < 0 || ctx.plane.light >= 16) revert PlaneBounds();
            cmap = uint8(ctx.rs.zlight[uint32(ctx.plane.light) * 128 + index]);
        }
        ctx.ds.colormap = R_Data.R_GetColormap(ctx.resources, cmap);
        ctx.ds.y = y;
        ctx.ds.x1 = x1;
        ctx.ds.x2 = x2;
        if (ctx.rs.detailshift == 0) R_Draw.R_DrawSpan(ctx.rs, ctx.ds);
        else R_Draw.R_DrawSpanLow(ctx.rs, ctx.ds);
    }

    function R_MakeSpans(RenderContext memory ctx, int32 x, int32 t1, int32 b1, int32 t2, int32 b2)
        internal
        view
    {
        if (x < 0 || x > int32(uint32(ctx.rs.width))) revert PlaneBounds();
        while (t1 < t2 && t1 <= b1) {
            _row(ctx, t1);
            R_MapPlane(ctx, t1, ctx.plane.spanstart[uint32(t1)], x - 1);
            ++t1;
        }
        while (b1 > b2 && b1 >= t1) {
            _row(ctx, b1);
            R_MapPlane(ctx, b1, ctx.plane.spanstart[uint32(b1)], x - 1);
            --b1;
        }
        while (t2 < t1 && t2 <= b2) {
            _row(ctx, t2);
            ctx.plane.spanstart[uint32(t2)] = x;
            ++t2;
        }
        while (b2 > b1 && b2 >= t2) {
            _row(ctx, b2);
            ctx.plane.spanstart[uint32(b2)] = x;
            --b2;
        }
    }

    function _row(RenderContext memory ctx, int32 y) private pure {
        if (y < 0 || y >= int32(uint32(ctx.rs.height))) revert PlaneBounds();
    }

    function R_DrawPlanes(RenderContext memory ctx) internal view {
        if (ctx.visplaneCount > 128 || ctx.visplaneCount > ctx.visplanes.length) revert PlaneOverflow();
        for (uint32 i; i < ctx.visplaneCount; ++i) {
            Visplane memory pl = ctx.visplanes[i];
            if (pl.minx > pl.maxx) continue;
            if (
                pl.minx < 0 || pl.maxx >= int32(uint32(ctx.rs.width)) || pl.top.length != 322
                    || pl.bottom.length != 322
            ) revert PlaneBounds();
            if (pl.picnum == ctx.skyflatnum) {
                ctx.dc.iscale = ctx.rs.pspriteiscale >> ctx.rs.detailshift;
                ctx.dc.colormap = R_Data.R_GetColormap(ctx.resources, 0);
                ctx.dc.texturemid = ctx.skytexturemid;
                for (int32 x = pl.minx; x <= pl.maxx; ++x) {
                    ctx.dc.yl = int32(uint32(uint8(pl.top[uint32(x + 1)])));
                    ctx.dc.yh = int32(uint32(uint8(pl.bottom[uint32(x + 1)])));
                    if (ctx.dc.yl <= ctx.dc.yh) {
                        uint32 angle;
                        unchecked {
                            angle = (ctx.rs.viewangle + ctx.rs.xtoviewangle[uint32(x)]) >> 22;
                        }
                        ctx.dc.x = x;
                        ColumnView memory column =
                            R_Data.R_GetColumn(ctx.resources, ctx.skytexture, int32(angle));
                        ctx.dc.source = column.data;
                        ctx.dc.sourceOffset = column.offset;
                        Z_ZoneBacking.bindColumn(ctx.resources, ctx.dc, ctx.resources.currentColumnZoneBlock);
                        if (ctx.rs.detailshift == 0) R_Draw.R_DrawColumn(ctx.rs, ctx.dc);
                        else R_Draw.R_DrawColumnLow(ctx.rs, ctx.dc);
                    }
                }
                continue;
            }
            uint32 flat = ctx.resources.flattranslation[pl.picnum];
            ctx.ds.source = R_Data.R_GetFlat(ctx.resources, flat);
            int32 height;
            unchecked {
                height = pl.height - ctx.rs.viewz;
            }
            // abs(INT_MIN) is undefined in C, not a valid wrapped absolute value.
            if (height == type(int32).min) revert PlaneBounds();
            ctx.plane.planeheight = height < 0 ? -height : height;
            unchecked {
                ctx.plane.light = (int32(pl.lightlevel) >> 4) + ctx.rs.extralight;
            }
            if (ctx.plane.light >= 16) ctx.plane.light = 15;
            if (ctx.plane.light < 0) ctx.plane.light = 0;
            pl.top[uint32(pl.maxx + 2)] = 0xff;
            pl.top[uint32(pl.minx)] = 0xff;
            for (int32 x = pl.minx; x <= pl.maxx + 1; ++x) {
                R_MakeSpans(
                    ctx,
                    x,
                    int32(uint32(uint8(pl.top[uint32(x)]))),
                    int32(uint32(uint8(pl.bottom[uint32(x)]))),
                    int32(uint32(uint8(pl.top[uint32(x + 1)]))),
                    int32(uint32(uint8(pl.bottom[uint32(x + 1)])))
                );
            }
            R_Data.releaseFlat(ctx.resources, flat);
        }
    }
}
