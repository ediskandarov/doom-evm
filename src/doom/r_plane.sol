// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;

import {RenderContext, Visplane} from "./r_render_state.sol";
import {M_Fixed} from "./m_fixed.sol";
import {Tables} from "./tables.sol";

/// @custom:source linuxdoom-1.10/r_plane.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @notice Batch 2B plane construction. Floor/ceiling drawing is added at the 2C gate.
library R_Plane {
    error PlaneOverflow();
    error PlaneBounds();

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
        ctx.visplanes = new Visplane[](128);
        ctx.visplaneCount = 0;
        ctx.openingCount = 0;
        ctx.floorplane = type(uint32).max;
        ctx.ceilingplane = type(uint32).max;
        ctx.plane.cachedheight = new int32[](200);
        ctx.plane.cacheddistance = new int32[](200);
        ctx.plane.cachedxstep = new int32[](200);
        ctx.plane.cachedystep = new int32[](200);
        ctx.plane.spanstart = new int32[](200);
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
        pl.top = new bytes(322);
        pl.bottom = new bytes(322);
        for (uint256 x; x < 322; ++x) {
            pl.top[x] = 0xff;
        }
    }
}
