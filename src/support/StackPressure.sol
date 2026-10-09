// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

// Shape study: linuxdoom-1.10/r_segs.c, R_StoreWallRange, upstream
// a77dfb96cb91780ca334d0d4cfd86957558007e0. NOT a renderer or a C-equivalent port.
// Original renderer copyright (C) 1993-1996 id Software, Inc.
// Dependencies below are deliberately synthetic, with no WAD, trig, or pixel output.
contract StackPressure {
    struct Scene {
        bool backsector;
        bool sky;
        bool dontPegTop;
        bool dontPegBottom;
        bool fixedColormap;
        int256 frontFloor;
        int256 frontCeiling;
        int256 backFloor;
        int256 backCeiling;
        int256 viewz;
        int256 rowoffset;
        int256 textureoffset;
        int256 angle;
        int256 lightlevel;
        int256 extralight;
        int256 orientation; // -1 horizontal, +1 vertical, 0 diagonal
        uint256 midtexture;
        uint256 toptexture;
        uint256 bottomtexture;
        uint256 drawsegCount;
    }

    // Stand-in for original per-frame globals/drawseg; no shared engine schema changes.
    struct Trace {
        uint256 columns;
        uint256 silhouette;
        uint256 openings;
        uint256 planeChecks;
        uint256 tiers; // 1 middle, 2 upper, 4 lower, 8 masked
        bool markfloor;
        bool markceiling;
        bool mapped;
        int256 texturemid;
        int256 toptexturemid;
        int256 bottomtexturemid;
        int256 distance;
        int256 offset;
        int256 light;
        int256 scalestep;
        int256 topstep;
        int256 bottomstep;
        int256 pixhighstep;
        int256 pixlowstep;
        int256 finalscale;
        int256 finaltop;
        int256 finalbottom;
        int256 finalhigh;
        int256 finallow;
        int256 checksum;
    }

    /// @dev Original locals remain locals. Some source globals are locals here to stress liveness.
    /// @dev Bounded toy integers deliberately avoid claiming Phase 1 fixed-point semantics.
    function R_StoreWallRange(Scene memory s, uint256 start, uint256 stop)
        public
        pure
        returns (Trace memory t)
    {
        if (s.drawsegCount >= 256) return t;
        require(start <= stop && stop < 320, "range");
        t.mapped = true;
        int256 offsetangle = s.angle < 0 ? -s.angle : s.angle;
        if (offsetangle > 90) offsetangle = 90;
        int256 distangle = 90 - offsetangle;
        int256 hyp = R_PointToDistStub(s.textureoffset, s.rowoffset);
        int256 sineval = FineSineStub(distangle);
        t.distance = MulStub(hyp, sineval);
        int256 rw_scale = R_ScaleFromGlobalAngleStub(s.angle, start);
        int256 scale2 = rw_scale;
        int256 rw_scalestep = 0;
        if (stop > start) {
            scale2 = R_ScaleFromGlobalAngleStub(s.angle, stop);
            rw_scalestep = (scale2 - rw_scale) / int256(stop - start);
        }
        int256 worldtop = s.frontCeiling - s.viewz;
        int256 worldbottom = s.frontFloor - s.viewz;
        int256 worldhigh = 0;
        int256 worldlow = 0;
        uint256 midtexture = 0;
        uint256 toptexture = 0;
        uint256 bottomtexture = 0;
        bool maskedtexture = false;
        bool markfloor;
        bool markceiling;
        int256 vtop = 0;
        if (!s.backsector) {
            midtexture = s.midtexture;
            markfloor = true;
            markceiling = true;
            if (s.dontPegBottom) {
                vtop = s.frontFloor + TextureHeightStub(midtexture);
                t.texturemid = vtop - s.viewz;
            } else {
                t.texturemid = worldtop;
            }
            t.texturemid += s.rowoffset;
            t.silhouette = 3;
        } else {
            if (s.frontFloor > s.backFloor || s.backFloor > s.viewz) t.silhouette = 1;
            if (s.frontCeiling < s.backCeiling || s.backCeiling < s.viewz) t.silhouette |= 2;
            if (s.backCeiling <= s.frontFloor) t.silhouette |= 1;
            if (s.backFloor >= s.frontCeiling) t.silhouette |= 2;
            worldhigh = s.backCeiling - s.viewz;
            worldlow = s.backFloor - s.viewz;
            if (s.sky) worldtop = worldhigh;
            markfloor = worldlow != worldbottom;
            markceiling = worldhigh != worldtop;
            if (s.backCeiling <= s.frontFloor || s.backFloor >= s.frontCeiling) {
                markfloor = true;
                markceiling = true;
            }
            if (worldhigh < worldtop) {
                toptexture = s.toptexture;
                if (s.dontPegTop) {
                    t.toptexturemid = worldtop;
                } else {
                    vtop = s.backCeiling + TextureHeightStub(toptexture);
                    t.toptexturemid = vtop - s.viewz;
                }
            }
            if (worldlow > worldbottom) {
                bottomtexture = s.bottomtexture;
                t.bottomtexturemid = s.dontPegBottom ? worldtop : worldlow;
            }
            t.toptexturemid += s.rowoffset;
            t.bottomtexturemid += s.rowoffset;
            if (s.midtexture != 0) {
                maskedtexture = true;
                t.openings += stop - start + 1;
            }
        }
        bool segtextured = midtexture != 0 || toptexture != 0 || bottomtexture != 0 || maskedtexture;
        if (segtextured) {
            sineval = FineSineStub(offsetangle);
            t.offset = MulStub(hyp, sineval);
            if (s.angle < 180) t.offset = -t.offset;
            t.offset += s.textureoffset;
            if (!s.fixedColormap) {
                int256 lightnum = (s.lightlevel >> 4) + s.extralight + s.orientation;
                t.light = lightnum < 0 ? int256(0) : (lightnum >= 16 ? int256(15) : lightnum);
            }
        }
        if (s.frontFloor >= s.viewz) markfloor = false;
        if (s.frontCeiling <= s.viewz && !s.sky) markceiling = false;
        worldtop >>= 4;
        worldbottom >>= 4;
        int256 topstep = -MulStub(rw_scalestep, worldtop);
        int256 bottomstep = -MulStub(rw_scalestep, worldbottom);
        int256 topfrac = 100 - MulStub(worldtop, rw_scale);
        int256 bottomfrac = 100 - MulStub(worldbottom, rw_scale);
        int256 pixhigh = 0;
        int256 pixlow = 0;
        int256 pixhighstep = 0;
        int256 pixlowstep = 0;
        if (s.backsector) {
            worldhigh >>= 4;
            worldlow >>= 4;
            if (worldhigh < worldtop) {
                pixhigh = 100 - MulStub(worldhigh, rw_scale);
                pixhighstep = -MulStub(rw_scalestep, worldhigh);
            }
            if (worldlow > worldbottom) {
                pixlow = 100 - MulStub(worldlow, rw_scale);
                pixlowstep = -MulStub(rw_scalestep, worldlow);
            }
        }
        if (markceiling) t.planeChecks += R_CheckPlaneStub(start, stop);
        if (markfloor) t.planeChecks += R_CheckPlaneStub(start, stop);
        t.tiers = (midtexture != 0 ? 1 : 0) | (toptexture != 0 ? 2 : 0) | (bottomtexture != 0 ? 4 : 0)
            | (maskedtexture ? 8 : 0);
        // R_RenderSegLoop dependency stub: retain column and edge recurrence, no pixel drawing.
        for (uint256 rw_x = start; rw_x <= stop; ++rw_x) {
            if (segtextured) t.checksum += rw_scale + t.offset + int256(rw_x) + t.light;
            if (midtexture != 0) {
                t.checksum += t.texturemid;
            } else {
                if (toptexture != 0) {
                    t.checksum += pixhigh + t.toptexturemid;
                    pixhigh += pixhighstep;
                }
                if (bottomtexture != 0) {
                    t.checksum += pixlow + t.bottomtexturemid;
                    pixlow += pixlowstep;
                }
                if (maskedtexture) t.checksum += int256(rw_x);
            }
            rw_scale += rw_scalestep;
            topfrac += topstep;
            bottomfrac += bottomstep;
            ++t.columns;
        }
        // Abstract clip-copy allocation counts, with no C pointer arithmetic or clip buffers.
        if (s.backsector) {
            if ((t.silhouette & 2 != 0) || maskedtexture) t.openings += t.columns;
            if ((t.silhouette & 1 != 0) || maskedtexture) t.openings += t.columns;
        }
        if (maskedtexture) t.silhouette |= 3;
        t.markfloor = markfloor;
        t.markceiling = markceiling;
        t.scalestep = rw_scalestep;
        t.topstep = topstep;
        t.bottomstep = bottomstep;
        t.pixhighstep = pixhighstep;
        t.pixlowstep = pixlowstep;
        t.finalscale = rw_scale;
        t.finaltop = topfrac;
        t.finalbottom = bottomfrac;
        t.finalhigh = pixhigh;
        t.finallow = pixlow;
    }

    function R_PointToDistStub(int256 x, int256 y) internal pure returns (int256) {
        return 16 + (x < 0 ? -x : x) + (y < 0 ? -y : y);
    }

    function FineSineStub(int256 angle) internal pure returns (int256) {
        return 1 + angle / 30;
    }

    function R_ScaleFromGlobalAngleStub(int256 angle, uint256 x) internal pure returns (int256) {
        return 16 + int256(x) + (angle < 0 ? -angle : angle) / 30;
    }

    function TextureHeightStub(uint256 id) internal pure returns (int256) {
        return 64 + int256(id);
    }

    function MulStub(int256 a, int256 b) internal pure returns (int256) {
        return a * b;
    }

    function R_CheckPlaneStub(uint256 start, uint256 stop) internal pure returns (uint256) {
        require(stop >= start, "plane range");
        return 1;
    }
}
