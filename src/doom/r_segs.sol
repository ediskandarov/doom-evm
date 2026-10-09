// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {RenderContext, WallState, DrawSeg, Visplane} from "./r_render_state.sol";
import {Seg, Side, Line, Sector, Vertex} from "./r_defs.sol";
import {ColumnView} from "./r_data_types.sol";
import {M_Fixed} from "./m_fixed.sol";
import {Tables} from "./tables.sol";
import {R_Main} from "./r_main.sol";
import {R_Data} from "./r_data.sol";
import {R_Draw} from "./r_draw.sol";
import {R_Plane} from "./r_plane.sol";
import {Z_ZoneBacking} from "./z_zone_backing.sol";

/// @custom:source linuxdoom-1.10/r_segs.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
library R_Segs {
    error WallBounds();
    error UndefinedWallAngle();
    error OpeningOverflow();
    uint32 private constant NULL = type(uint32).max;

    function _short(int32 v) private pure returns (int32) {
        return int32(int16(v));
    }

    function _open(RenderContext memory c, uint32 count) private pure returns (int32[] memory data) {
        if (uint256(c.openingCount) + count > 320 * 64) revert OpeningOverflow();
        c.openingCount += count;
        data = new int32[](c.rs.width);
    }

    function _height(RenderContext memory c, uint32 texture) private pure returns (int32) {
        return int32(uint32(c.resources.textures[texture].height) << 16);
    }

    function _column(RenderContext memory c, uint32 texture, int32 column) private view {
        ColumnView memory source = R_Data.R_GetColumn(c.resources, texture, column);
        c.dc.source = source.data;
        c.dc.sourceOffset = source.offset;
        Z_ZoneBacking.bindColumn(c.resources, c.dc, c.resources.currentColumnZoneBlock);
        if (c.rs.detailshift == 0) R_Draw.R_DrawColumn(c.rs, c.dc);
        else R_Draw.R_DrawColumnLow(c.rs, c.dc);
    }

    /// @notice Original masked-wall pass, invoked during sprite clipping and final backdrawing.
    function R_RenderMaskedSegRange(
        RenderContext memory c,
        uint32 drawseg,
        int32 x1,
        int32 x2,
        function(RenderContext memory, ColumnView memory) internal view drawMaskedColumn
    ) internal view {
        if (drawseg >= c.drawsegCount || drawseg >= c.drawsegs.length) {
            revert WallBounds();
        }
        DrawSeg memory ds = c.drawsegs[drawseg];
        if (
            x1 <= x2
                && (x1 < 0
                    || x2 >= int32(uint32(c.rs.width))
                    || x1 < ds.x1
                    || x2 > ds.x2
                    || ds.maskedtexturecol.length != c.rs.width)
        ) revert WallBounds();
        c.curline = ds.curline;
        Seg memory seg = c.map.segs[c.curline];
        c.frontsector = seg.frontsector;
        c.backsector = seg.backsector;
        if (c.backsector == NULL) revert WallBounds();
        Sector memory front = c.map.sectors[c.frontsector];
        Sector memory back = c.map.sectors[c.backsector];
        Side memory side = c.map.sides[seg.sidedef];
        uint32 texnum = c.resources.texturetranslation[side.midtexture];
        unchecked {
            int32 lightnum = (int32(front.lightlevel) >> 4) + c.rs.extralight;
            Vertex memory v1 = c.map.vertexes[seg.v1];
            Vertex memory v2 = c.map.vertexes[seg.v2];
            if (v1.y == v2.y) --lightnum;
            else if (v1.x == v2.x) ++lightnum;
            c.wall.lightnum = lightnum < 0 ? int32(0) : lightnum >= 16 ? int32(15) : lightnum;
            c.wall.rw_scalestep = ds.scalestep;
            c.sprite.spryscale = ds.scale1 + (x1 - ds.x1) * c.wall.rw_scalestep;
            c.sprite.mfloorclip = ds.sprbottomclip;
            c.sprite.mceilingclip = ds.sprtopclip;
            if (c.map.lines[seg.linedef].flags & 16 != 0) {
                c.dc.texturemid = front.floorheight > back.floorheight ? front.floorheight : back.floorheight;
                c.dc.texturemid = c.dc.texturemid + _height(c, texnum) - c.rs.viewz;
            } else {
                c.dc.texturemid =
                    front.ceilingheight < back.ceilingheight ? front.ceilingheight : back.ceilingheight;
                c.dc.texturemid -= c.rs.viewz;
            }
            c.dc.texturemid += side.rowoffset;
            if (c.rs.fixedcolormap != -1) {
                c.dc.colormap = R_Data.R_GetColormap(c.resources, uint32(c.rs.fixedcolormap));
            }
            for (c.dc.x = x1; c.dc.x <= x2; ++c.dc.x) {
                uint32 x = uint32(c.dc.x);
                if (ds.maskedtexturecol[x] != 32767) {
                    if (c.rs.fixedcolormap == -1) {
                        uint32 index = uint32(c.sprite.spryscale >> 12);
                        if (index >= 48) index = 47;
                        c.dc.colormap = R_Data.R_GetColormap(
                            c.resources, uint8(c.rs.scalelight[uint32(c.wall.lightnum) * 48 + index])
                        );
                    }
                    c.sprite.sprtopscreen =
                        c.rs.centeryfrac - M_Fixed.FixedMul(c.dc.texturemid, c.sprite.spryscale);
                    if (c.sprite.spryscale == 0) revert WallBounds();
                    c.dc.iscale = int32(type(uint32).max / uint32(c.sprite.spryscale));
                    ColumnView memory post = R_Data.R_GetColumn(c.resources, texnum, ds.maskedtexturecol[x]);
                    if (post.offset < 3) revert WallBounds();
                    post.offset -= 3;
                    if (post.offset >= post.data.length) revert WallBounds();
                    drawMaskedColumn(c, post);
                    // Deliberately use dc_x after the callback, as the original does.
                    ds.maskedtexturecol[uint32(c.dc.x)] = 32767;
                }
                c.sprite.spryscale += c.wall.rw_scalestep;
            }
        }
    }

    function R_RenderSegLoop(RenderContext memory c) internal view {
        WallState memory w = c.wall;
        unchecked {
            for (; w.rw_x < w.rw_stopx; ++w.rw_x) {
                uint32 x = uint32(w.rw_x);
                int32 yl = (w.topfrac + 4095) >> 12;
                if (yl < c.ceilingclip[x] + 1) yl = c.ceilingclip[x] + 1;
                if (w.markceiling) {
                    int32 top = c.ceilingclip[x] + 1;
                    int32 bottom = yl - 1;
                    if (bottom >= c.floorclip[x]) bottom = c.floorclip[x] - 1;
                    if (top <= bottom) {
                        Visplane memory p = c.visplanes[c.ceilingplane];
                        p.top[x + 1] = bytes1(uint8(uint32(top)));
                        p.bottom[x + 1] = bytes1(uint8(uint32(bottom)));
                    }
                }
                int32 yh = w.bottomfrac >> 12;
                if (yh >= c.floorclip[x]) yh = c.floorclip[x] - 1;
                if (w.markfloor) {
                    int32 top = yh + 1;
                    int32 bottom = c.floorclip[x] - 1;
                    if (top <= c.ceilingclip[x]) top = c.ceilingclip[x] + 1;
                    if (top <= bottom) {
                        Visplane memory p = c.visplanes[c.floorplane];
                        p.top[x + 1] = bytes1(uint8(uint32(top)));
                        p.bottom[x + 1] = bytes1(uint8(uint32(bottom)));
                    }
                }
                int32 texturecolumn;
                if (w.segtextured) {
                    uint32 angle = (w.rw_centerangle + c.rs.xtoviewangle[x]) >> 19;
                    texturecolumn = w.rw_offset - M_Fixed.FixedMul(Tables.finetangent(angle), w.rw_distance);
                    texturecolumn >>= 16;
                    uint32 index = uint32(w.rw_scale >> 12);
                    if (index >= 48) index = 47;
                    uint32 cmap = c.rs.fixedcolormap != -1
                        ? uint8(c.rs.scalelightfixed[index])
                        : uint8(c.rs.scalelight[uint32(w.lightnum) * 48 + index]);
                    c.dc.colormap = R_Data.R_GetColormap(c.resources, cmap);
                    c.dc.x = w.rw_x;
                    c.dc.iscale = int32(type(uint32).max / uint32(w.rw_scale));
                }
                if (w.midtexture != 0) {
                    c.dc.yl = yl;
                    c.dc.yh = yh;
                    c.dc.texturemid = w.rw_midtexturemid;
                    _column(c, w.midtexture, texturecolumn);
                    c.ceilingclip[x] = _short(int32(uint32(c.rs.height)));
                    c.floorclip[x] = -1;
                } else {
                    if (w.toptexture != 0) {
                        int32 mid = w.pixhigh >> 12;
                        w.pixhigh += w.pixhighstep;
                        if (mid >= c.floorclip[x]) mid = c.floorclip[x] - 1;
                        if (mid >= yl) {
                            c.dc.yl = yl;
                            c.dc.yh = mid;
                            c.dc.texturemid = w.rw_toptexturemid;
                            _column(c, w.toptexture, texturecolumn);
                            c.ceilingclip[x] = _short(mid);
                        } else {
                            c.ceilingclip[x] = _short(yl - 1);
                        }
                    } else if (w.markceiling) {
                        c.ceilingclip[x] = _short(yl - 1);
                    }
                    if (w.bottomtexture != 0) {
                        int32 mid = (w.pixlow + 4095) >> 12;
                        w.pixlow += w.pixlowstep;
                        if (mid <= c.ceilingclip[x]) mid = c.ceilingclip[x] + 1;
                        if (mid <= yh) {
                            c.dc.yl = mid;
                            c.dc.yh = yh;
                            c.dc.texturemid = w.rw_bottomtexturemid;
                            _column(c, w.bottomtexture, texturecolumn);
                            c.floorclip[x] = _short(mid);
                        } else {
                            c.floorclip[x] = _short(yh + 1);
                        }
                    } else if (w.markfloor) {
                        c.floorclip[x] = _short(yh + 1);
                    }
                    if (w.maskedtexture) {
                        c.drawsegs[c.drawsegCount].maskedtexturecol[x] = _short(texturecolumn);
                    }
                }
                w.rw_scale += w.rw_scalestep;
                w.topfrac += w.topstep;
                w.bottomfrac += w.bottomstep;
            }
        }
    }

    function R_StoreWallRange(RenderContext memory c, int32 start, int32 stop) internal view {
        if (c.drawsegCount == 256) return;
        if (
            c.drawsegCount > 256 || c.drawsegs.length != 256 || start < 0 || stop < start
                || stop >= int32(uint32(c.rs.width))
        ) revert WallBounds();
        WallState memory w = c.wall;
        DrawSeg memory ds = c.drawsegs[c.drawsegCount];
        Seg memory seg = c.map.segs[c.curline];
        Side memory side = c.map.sides[seg.sidedef];
        Line memory line = c.map.lines[seg.linedef];
        Sector memory front = c.map.sectors[c.frontsector];
        Vertex memory v1 = c.map.vertexes[seg.v1];
        Vertex memory v2 = c.map.vertexes[seg.v2];
        unchecked {
            line.flags |= 256; // ML_MAPPED: frame-memory automap visibility mutation.
            w.rw_normalangle = seg.angle + Tables.ANG90;
            int32 difference = int32(w.rw_normalangle - w.rw_angle1);
            if (difference == type(int32).min) revert UndefinedWallAngle();
            uint32 offsetangle = uint32(difference < 0 ? -difference : difference);
            if (offsetangle > Tables.ANG90) offsetangle = Tables.ANG90;
            uint32 distangle = Tables.ANG90 - offsetangle;
            int32 hyp = R_Main.R_PointToDist(c.rs, v1.x, v1.y);
            int32 sineval = Tables.finesine(distangle >> 19);
            w.rw_distance = M_Fixed.FixedMul(hyp, sineval);
            ds.x1 = w.rw_x = start;
            ds.x2 = stop;
            ds.curline = c.curline;
            w.rw_stopx = stop + 1;
            ds.scale1 = w.rw_scale = R_Main.R_ScaleFromGlobalAngle(
                c.rs, c.rs.viewangle + c.rs.xtoviewangle[uint32(start)], w.rw_normalangle, w.rw_distance
            );
            if (stop > start) {
                ds.scale2 = R_Main.R_ScaleFromGlobalAngle(
                    c.rs, c.rs.viewangle + c.rs.xtoviewangle[uint32(stop)], w.rw_normalangle, w.rw_distance
                );
                ds.scalestep = w.rw_scalestep = (ds.scale2 - w.rw_scale) / (stop - start);
            } else {
                ds.scale2 = ds.scale1; // Original leaves BOTH scalestep globals unchanged.
            }
            w.worldtop = front.ceilingheight - c.rs.viewz;
            w.worldbottom = front.floorheight - c.rs.viewz;
            w.midtexture = 0;
            w.toptexture = 0;
            w.bottomtexture = 0;
            w.maskedtexture = false;
            ds.maskedtexturecol = new int32[](0);
            if (c.backsector == NULL) {
                w.midtexture = c.resources.texturetranslation[side.midtexture];
                w.markfloor = w.markceiling = true;
                w.rw_midtexturemid = line.flags & 16 != 0
                    ? front.floorheight + _height(c, side.midtexture) - c.rs.viewz
                    : w.worldtop;
                w.rw_midtexturemid += side.rowoffset;
                ds.silhouette = 3;
                ds.sprtopclip = c.rs.screenheightarray;
                ds.sprbottomclip = c.negonearray;
                ds.bsilheight = type(int32).max;
                ds.tsilheight = type(int32).min;
            } else {
                Sector memory back = c.map.sectors[c.backsector];
                ds.sprtopclip = new int32[](0);
                ds.sprbottomclip = new int32[](0);
                ds.silhouette = 0;
                if (front.floorheight > back.floorheight) {
                    ds.silhouette = 1;
                    ds.bsilheight = front.floorheight;
                } else if (back.floorheight > c.rs.viewz) {
                    ds.silhouette = 1;
                    ds.bsilheight = type(int32).max;
                }
                if (front.ceilingheight < back.ceilingheight) {
                    ds.silhouette |= 2;
                    ds.tsilheight = front.ceilingheight;
                } else if (back.ceilingheight < c.rs.viewz) {
                    ds.silhouette |= 2;
                    ds.tsilheight = type(int32).min;
                }
                if (back.ceilingheight <= front.floorheight) {
                    ds.sprbottomclip = c.negonearray;
                    ds.bsilheight = type(int32).max;
                    ds.silhouette |= 1;
                }
                if (back.floorheight >= front.ceilingheight) {
                    ds.sprtopclip = c.rs.screenheightarray;
                    ds.tsilheight = type(int32).min;
                    ds.silhouette |= 2;
                }
                w.worldhigh = back.ceilingheight - c.rs.viewz;
                w.worldlow = back.floorheight - c.rs.viewz;
                if (front.ceilingpic == c.skyflatnum && back.ceilingpic == c.skyflatnum) {
                    w.worldtop = w.worldhigh;
                }
                w.markfloor = w.worldlow != w.worldbottom || back.floorpic != front.floorpic
                    || back.lightlevel != front.lightlevel;
                w.markceiling = w.worldhigh != w.worldtop || back.ceilingpic != front.ceilingpic
                    || back.lightlevel != front.lightlevel;
                if (back.ceilingheight <= front.floorheight || back.floorheight >= front.ceilingheight) {
                    w.markceiling = w.markfloor = true;
                }
                if (w.worldhigh < w.worldtop) {
                    w.toptexture = c.resources.texturetranslation[side.toptexture];
                    w.rw_toptexturemid = line.flags & 8 != 0
                        ? w.worldtop
                        : back.ceilingheight + _height(c, side.toptexture) - c.rs.viewz;
                }
                if (w.worldlow > w.worldbottom) {
                    w.bottomtexture = c.resources.texturetranslation[side.bottomtexture];
                    w.rw_bottomtexturemid = line.flags & 16 != 0 ? w.worldtop : w.worldlow;
                }
                w.rw_toptexturemid += side.rowoffset;
                w.rw_bottomtexturemid += side.rowoffset;
                if (side.midtexture != 0) {
                    w.maskedtexture = true;
                    ds.maskedtexturecol = _open(c, uint32(w.rw_stopx - w.rw_x));
                }
            }
            w.segtextured = w.midtexture != 0 || w.toptexture != 0 || w.bottomtexture != 0 || w.maskedtexture;
            if (w.segtextured) {
                offsetangle = w.rw_normalangle - w.rw_angle1;
                if (offsetangle > Tables.ANG180) offsetangle = 0 - offsetangle;
                if (offsetangle > Tables.ANG90) offsetangle = Tables.ANG90;
                sineval = Tables.finesine(offsetangle >> 19);
                w.rw_offset = M_Fixed.FixedMul(hyp, sineval);
                if (w.rw_normalangle - w.rw_angle1 < Tables.ANG180) w.rw_offset = -w.rw_offset;
                w.rw_offset += side.textureoffset + seg.offset;
                w.rw_centerangle = Tables.ANG90 + c.rs.viewangle - w.rw_normalangle;
                if (c.rs.fixedcolormap == -1) {
                    int32 lightnum = (int32(front.lightlevel) >> 4) + c.rs.extralight;
                    if (v1.y == v2.y) --lightnum;
                    else if (v1.x == v2.x) ++lightnum;
                    w.lightnum = lightnum < 0 ? int32(0) : lightnum >= 16 ? int32(15) : lightnum;
                }
            }
            if (front.floorheight >= c.rs.viewz) w.markfloor = false;
            if (front.ceilingheight <= c.rs.viewz && front.ceilingpic != c.skyflatnum) w.markceiling = false;
            w.worldtop >>= 4;
            w.worldbottom >>= 4;
            w.topstep = -M_Fixed.FixedMul(w.rw_scalestep, w.worldtop);
            w.topfrac = (c.rs.centeryfrac >> 4) - M_Fixed.FixedMul(w.worldtop, w.rw_scale);
            w.bottomstep = -M_Fixed.FixedMul(w.rw_scalestep, w.worldbottom);
            w.bottomfrac = (c.rs.centeryfrac >> 4) - M_Fixed.FixedMul(w.worldbottom, w.rw_scale);
            if (c.backsector != NULL) {
                w.worldhigh >>= 4;
                w.worldlow >>= 4;
                if (w.worldhigh < w.worldtop) {
                    w.pixhigh = (c.rs.centeryfrac >> 4) - M_Fixed.FixedMul(w.worldhigh, w.rw_scale);
                    w.pixhighstep = -M_Fixed.FixedMul(w.rw_scalestep, w.worldhigh);
                }
                if (w.worldlow > w.worldbottom) {
                    w.pixlow = (c.rs.centeryfrac >> 4) - M_Fixed.FixedMul(w.worldlow, w.rw_scale);
                    w.pixlowstep = -M_Fixed.FixedMul(w.rw_scalestep, w.worldlow);
                }
            }
            if (w.markceiling) {
                c.ceilingplane = R_Plane.R_CheckPlane(c, c.ceilingplane, w.rw_x, w.rw_stopx - 1);
            }
            if (w.markfloor) c.floorplane = R_Plane.R_CheckPlane(c, c.floorplane, w.rw_x, w.rw_stopx - 1);
            R_RenderSegLoop(c);
            if (((ds.silhouette & 2) != 0 || w.maskedtexture) && ds.sprtopclip.length == 0) {
                ds.sprtopclip = _open(c, uint32(w.rw_stopx - start));
                for (int32 x = start; x < w.rw_stopx; ++x) {
                    ds.sprtopclip[uint32(x)] = _short(c.ceilingclip[uint32(x)]);
                }
            }
            if (((ds.silhouette & 1) != 0 || w.maskedtexture) && ds.sprbottomclip.length == 0) {
                ds.sprbottomclip = _open(c, uint32(w.rw_stopx - start));
                for (int32 x = start; x < w.rw_stopx; ++x) {
                    ds.sprbottomclip[uint32(x)] = _short(c.floorclip[uint32(x)]);
                }
            }
            if (w.maskedtexture && (ds.silhouette & 2) == 0) {
                ds.silhouette |= 2;
                ds.tsilheight = type(int32).min;
            }
            if (w.maskedtexture && (ds.silhouette & 1) == 0) {
                ds.silhouette |= 1;
                ds.bsilheight = type(int32).max;
            }
            ++c.drawsegCount;
        }
    }
}
