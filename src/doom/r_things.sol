// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {RenderContext, DrawSeg} from "./r_render_state.sol";
import {SpriteFrame, SpriteDef, SpriteBuild, RenderThing, VisSprite, PSprite} from "./r_sprite_state.sol";
import {ColumnView} from "./r_data_types.sol";
import {R_Data} from "./r_data.sol";
import {R_Main} from "./r_main.sol";
import {R_Draw} from "./r_draw.sol";
import {M_Fixed} from "./m_fixed.sol";

/// @custom:source linuxdoom-1.10/r_things.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @dev int32 accumulation follows the pinned -fwrapv profile; invalid source addresses reject.
library R_Things {
    error SpriteDefinition();
    error SpriteBounds();
    error UndefinedSpriteDomain();

    function R_InstallSpriteLump(
        RenderContext memory c,
        SpriteBuild memory b,
        uint32 lump,
        uint32 frame,
        uint32 rotation,
        bool flipped
    ) internal pure {
        if (frame >= 29 || rotation > 8) revert SpriteDefinition();
        if (int32(frame) > b.maxframe) b.maxframe = int32(frame);
        SpriteFrame memory f = b.temp[frame];
        int16 relative = int16(int32(lump) - int32(c.resources.firstspritelump));
        if (rotation == 0) {
            if (f.rotate == 0 || f.rotate == 1) revert SpriteDefinition();
            f.rotate = 0;
            for (uint256 r; r < 8; ++r) {
                f.lump[r] = relative;
                f.flip[r] = flipped ? 1 : 0;
            }
            return;
        }
        if (f.rotate == 0) revert SpriteDefinition();
        f.rotate = 1;
        --rotation;
        if (f.lump[rotation] != -1) revert SpriteDefinition();
        f.lump[rotation] = relative;
        f.flip[rotation] = flipped ? 1 : 0;
    }

    function R_InitSpriteDefs(RenderContext memory c, bytes memory names) internal pure {
        if (names.length % 4 != 0) revert SpriteDefinition();
        uint256 count = names.length / 4;
        if (count == 0) return;
        c.sprite.definitions = new SpriteDef[](count);
        SpriteBuild memory b;
        for (uint256 i; i < count; ++i) {
            b.name = bytes4(
                uint32(uint8(names[i * 4])) << 24 | uint32(uint8(names[i * 4 + 1])) << 16
                    | uint32(uint8(names[i * 4 + 2])) << 8 | uint32(uint8(names[i * 4 + 3]))
            );
            b.maxframe = -1;
            for (uint256 f; f < 29; ++f) {
                b.temp[f].rotate = -1;
                for (uint256 r; r < 8; ++r) {
                    b.temp[f].lump[r] = -1;
                    b.temp[f].flip[r] = 255;
                }
            }
            uint32 end = c.resources.firstspritelump + c.resources.numspritelumps;
            for (uint32 l = c.resources.firstspritelump; l < end; ++l) {
                bytes8 name = c.resources.source.lumps[l].name;
                if (bytes4(name) != b.name) continue;
                uint32 patched = c.sprite.modifiedgame ? R_Data.W_GetNumForName(c.resources.source, name) : l;
                if (uint8(name[4]) < 65 || uint8(name[5]) < 48) revert SpriteDefinition();
                R_InstallSpriteLump(c, b, patched, uint8(name[4]) - 65, uint8(name[5]) - 48, false);
                if (name[6] != 0) {
                    if (uint8(name[6]) < 65 || uint8(name[7]) < 48) revert SpriteDefinition();
                    R_InstallSpriteLump(c, b, l, uint8(name[6]) - 65, uint8(name[7]) - 48, true);
                }
            }
            if (b.maxframe == -1) continue;
            uint256 frames = uint32(b.maxframe) + 1;
            c.sprite.definitions[i].frames = new SpriteFrame[](frames);
            for (uint256 f; f < frames; ++f) {
                if (b.temp[f].rotate == -1) revert SpriteDefinition();
                SpriteFrame memory dest = c.sprite.definitions[i].frames[f];
                dest.rotate = b.temp[f].rotate;
                for (uint256 r; r < 8; ++r) {
                    if (dest.rotate == 1 && b.temp[f].lump[r] == -1) revert SpriteDefinition();
                    dest.lump[r] = b.temp[f].lump[r];
                    dest.flip[r] = b.temp[f].flip[r];
                }
            }
        }
    }

    function R_InitSprites(RenderContext memory c, bytes memory names) internal pure {
        if (c.negonearray.length != 320) c.negonearray = new int32[](320);
        for (uint256 i; i < 320; ++i) {
            c.negonearray[i] = -1;
        }
        R_InitSpriteDefs(c, names);
    }

    function R_ClearSprites(RenderContext memory c) internal pure {
        if (c.sprite.vissprites.length != 128) c.sprite.vissprites = new VisSprite[](128);
        c.sprite.visspriteCount = 0;
    }

    function R_NewVisSprite(RenderContext memory c) internal pure returns (VisSprite memory v) {
        if (c.sprite.visspriteCount == 128) return c.sprite.overflowSprite;
        return c.sprite.vissprites[c.sprite.visspriteCount++];
    }

    function abs(int32 n) private pure returns (int32) {
        if (n == type(int32).min) revert UndefinedSpriteDomain();
        return n < 0 ? -n : n;
    }

    function light(RenderContext memory c, int32 row, int32 index) private pure returns (int32) {
        if (index < 0 || index >= 48 || row < 0 || row >= 16) revert SpriteBounds();
        return int32(uint32(uint8(c.rs.scalelight[uint32(row) * 48 + uint32(index)])));
    }

    function setLight(RenderContext memory c, uint32 sector) private pure {
        int32 n;
        unchecked {
            n = (int32(c.map.sectors[sector].lightlevel) >> 4) + c.rs.extralight;
        }
        c.sprite.light = n < 0 ? int32(0) : n >= 16 ? int32(15) : n;
    }

    function R_ProjectSprite(RenderContext memory c, uint32 index) internal pure {
        RenderThing memory t = c.sprite.things[index];
        unchecked {
            int32 tr_x = t.x - c.rs.viewx;
            int32 tr_y = t.y - c.rs.viewy;
            int32 tz = M_Fixed.FixedMul(tr_x, c.rs.viewcos) - (-M_Fixed.FixedMul(tr_y, c.rs.viewsin));
            if (tz < 4 * 65536) return;
            int32 scale = M_Fixed.FixedDiv(c.rs.projection, tz);
            int32 tx = -(M_Fixed.FixedMul(tr_y, c.rs.viewcos) - M_Fixed.FixedMul(tr_x, c.rs.viewsin));
            if (abs(tx) > (tz << 2)) return;
            SpriteFrame memory f = c.sprite.definitions[t.sprite].frames[t.frame & 0x7fff];
            uint32 rot =
                f.rotate != 0 ? (R_Main.R_PointToAngle(c.rs, t.x, t.y) - t.angle + 0x90000000) >> 29 : 0;
            int32 lump = f.lump[rot];
            if (lump < 0) revert SpriteBounds();
            bool flip = f.flip[rot] != 0;
            uint32 l = uint32(lump);
            tx -= c.resources.spriteoffset[l];
            int32 x1 = (c.rs.centerxfrac + M_Fixed.FixedMul(tx, scale)) >> 16;
            if (x1 > int32(uint32(c.rs.width))) return;
            tx += c.resources.spritewidth[l];
            int32 x2 = ((c.rs.centerxfrac + M_Fixed.FixedMul(tx, scale)) >> 16) - 1;
            if (x2 < 0) return;
            VisSprite memory v = R_NewVisSprite(c);
            v.mobjflags = t.flags;
            v.scale = scale << c.rs.detailshift;
            v.gx = t.x;
            v.gy = t.y;
            v.gz = t.z;
            v.gzt = t.z + c.resources.spritetopoffset[l];
            v.texturemid = v.gzt - c.rs.viewz;
            v.x1 = x1 < 0 ? int32(0) : x1;
            v.x2 = x2 >= int32(uint32(c.rs.width)) ? int32(uint32(c.rs.width)) - 1 : x2;
            int32 iscale = M_Fixed.FixedDiv(65536, scale);
            v.startfrac = flip ? c.resources.spritewidth[l] - 1 : int32(0);
            v.xiscale = flip ? -iscale : iscale;
            if (v.x1 > x1) v.startfrac += v.xiscale * (v.x1 - x1);
            v.patch = lump;
            if (t.flags & 0x40000 != 0) {
                v.colormap = -1;
            } else if (c.rs.fixedcolormap != -1) {
                v.colormap = c.rs.fixedcolormap;
            } else if (t.frame & 0x8000 != 0) {
                v.colormap = 0;
            } else {
                int32 n = scale >> (12 - c.rs.detailshift);
                if (n >= 48) n = 47;
                v.colormap = light(c, c.sprite.light, n);
            }
        }
    }

    function R_AddSprites(RenderContext memory c, uint32 sector) internal pure {
        if (c.sectorValidcount[sector] == c.rs.validcount) return;
        c.sectorValidcount[sector] = c.rs.validcount;
        setLight(c, sector);
        uint32 t = c.sprite.sectorHeads[sector];
        uint256 seen;
        while (t != type(uint32).max) {
            if (++seen > c.sprite.things.length) revert SpriteBounds();
            R_ProjectSprite(c, t);
            t = c.sprite.things[t].next;
        }
    }

    function R_SortVisSprites(RenderContext memory c) internal pure {
        uint256 count = c.sprite.visspriteCount;
        c.sprite.sortedOrder = new uint32[](count);
        bool[] memory used = new bool[](count);
        for (uint256 i; i < count; ++i) {
            int32 bestscale = type(int32).max;
            uint32 best = type(uint32).max;
            for (uint32 j; j < count; ++j) {
                if (!used[j] && c.sprite.vissprites[j].scale < bestscale) {
                    bestscale = c.sprite.vissprites[j].scale;
                    best = j;
                }
            }
            if (best == type(uint32).max) revert UndefinedSpriteDomain();
            used[best] = true;
            c.sprite.sortedOrder[i] = best;
        }
    }

    function patchLump(RenderContext memory c, uint32 lump) private view returns (bytes memory data) {
        if (c.resources.lumpcache.length != c.resources.source.lumps.length) revert SpriteBounds();
        data = c.resources.lumpcache[lump];
        if (data.length == 0) {
            data = R_Data.W_CacheLumpNum(c.resources.source, lump);
            c.resources.lumpcache[lump] = data;
        }
    }

    function le32(bytes memory data, uint256 p) private pure returns (uint32 v) {
        if (p + 4 > data.length) revert SpriteBounds();
        for (uint256 j; j < 4; ++j) {
            v |= uint32(uint8(data[p + j])) << uint32(j * 8);
        }
    }

    function drawColumn(RenderContext memory c) private pure {
        if (c.sprite.columnMode == 1) R_Draw.R_DrawFuzzColumn(c.rs, c.dc, c.resources.colormaps);
        else if (c.sprite.columnMode == 2) R_Draw.R_DrawTranslatedColumn(c.rs, c.dc);
        else if (c.rs.detailshift != 0) R_Draw.R_DrawColumnLow(c.rs, c.dc);
        else R_Draw.R_DrawColumn(c.rs, c.dc);
    }

    function R_DrawMaskedColumn(RenderContext memory c, ColumnView memory post) internal pure {
        int32 base = c.dc.texturemid;
        uint256 p = post.offset;
        for (;;) {
            if (p >= post.data.length) revert SpriteBounds();
            uint8 top = uint8(post.data[p]);
            if (top == 255) break;
            if (p + 3 > post.data.length) revert SpriteBounds();
            uint8 len = uint8(post.data[p + 1]);
            if (p + uint256(len) + 4 > post.data.length) revert SpriteBounds();
            unchecked {
                int32 topscreen = c.sprite.sprtopscreen + c.sprite.spryscale * int32(uint32(top));
                int32 bottomscreen = topscreen + c.sprite.spryscale * int32(uint32(len));
                c.dc.yl = (topscreen + 65535) >> 16;
                c.dc.yh = (bottomscreen - 1) >> 16;
                if (c.dc.x < 0) revert SpriteBounds();
                uint32 x = uint32(c.dc.x);
                if (c.dc.yh >= c.sprite.mfloorclip[x]) c.dc.yh = c.sprite.mfloorclip[x] - 1;
                if (c.dc.yl <= c.sprite.mceilingclip[x]) c.dc.yl = c.sprite.mceilingclip[x] + 1;
                if (c.dc.yl <= c.dc.yh) {
                    c.dc.source = post.data;
                    c.dc.sourceOffset = uint32(p + 3);
                    c.dc.texturemid = base - (int32(uint32(top)) << 16);
                    drawColumn(c);
                }
            }
            p += uint256(len) + 4;
        }
        c.dc.texturemid = base;
    }

    function R_DrawVisSprite(RenderContext memory c, VisSprite memory v, int32, int32) internal view {
        if (v.patch < 0) revert SpriteBounds();
        bytes memory patch = patchLump(c, uint32(v.patch) + c.resources.firstspritelump);
        if (patch.length < 8) revert SpriteBounds();
        if (v.colormap == -1) {
            c.sprite.columnMode = 1;
        } else {
            if (v.colormap < 0) revert SpriteBounds();
            c.dc.colormap = R_Data.R_GetColormap(c.resources, uint32(v.colormap));
            if (v.mobjflags & 0xc000000 != 0) {
                c.sprite.columnMode = 2;
                if (c.sprite.translationtables.length == 0) {
                    c.sprite.translationtables = R_Draw.R_InitTranslationTables();
                }
                uint256 start = ((v.mobjflags & 0xc000000) >> 18) - 256;
                c.dc.translation = new bytes(256);
                for (uint256 i; i < 256; ++i) {
                    c.dc.translation[i] = c.sprite.translationtables[start + i];
                }
            }
        }
        c.dc.iscale = abs(v.xiscale) >> c.rs.detailshift;
        c.dc.texturemid = v.texturemid;
        int32 frac = v.startfrac;
        c.sprite.spryscale = v.scale;
        unchecked {
            c.sprite.sprtopscreen = c.rs.centeryfrac - M_Fixed.FixedMul(c.dc.texturemid, c.sprite.spryscale);
        }
        c.dc.x = v.x1;
        while (c.dc.x <= v.x2) {
            int32 column = frac >> 16;
            int32 width = int16(uint16(uint8(patch[0])) | uint16(uint8(patch[1])) << 8);
            if (column < 0 || column >= width) revert SpriteBounds();
            R_DrawMaskedColumn(c, ColumnView(patch, le32(patch, 8 + uint32(column) * 4)));
            unchecked {
                ++c.dc.x;
                frac += v.xiscale;
            }
        }
        c.sprite.columnMode = 0;
    }

    function R_DrawPSprite(RenderContext memory c, uint32 position) internal view {
        PSprite memory p = c.sprite.psprites[position];
        SpriteFrame memory f = c.sprite.definitions[p.sprite].frames[p.frame & 0x7fff];
        if (f.lump[0] < 0) revert SpriteBounds();
        uint32 l = uint32(int32(f.lump[0]));
        bool flip = f.flip[0] != 0;
        unchecked {
            int32 tx = p.sx - 160 * 65536 - c.resources.spriteoffset[l];
            int32 x1 = (c.rs.centerxfrac + M_Fixed.FixedMul(tx, c.rs.pspritescale)) >> 16;
            if (x1 > int32(uint32(c.rs.width))) return;
            tx += c.resources.spritewidth[l];
            int32 x2 = ((c.rs.centerxfrac + M_Fixed.FixedMul(tx, c.rs.pspritescale)) >> 16) - 1;
            if (x2 < 0) return;
            VisSprite memory v;
            v.texturemid = 100 * 65536 + 32768 - (p.sy - c.resources.spritetopoffset[l]);
            v.x1 = x1 < 0 ? int32(0) : x1;
            v.x2 = x2 >= int32(uint32(c.rs.width)) ? int32(uint32(c.rs.width)) - 1 : x2;
            v.scale = c.rs.pspritescale << c.rs.detailshift;
            v.xiscale = flip ? -c.rs.pspriteiscale : c.rs.pspriteiscale;
            v.startfrac = flip ? c.resources.spritewidth[l] - 1 : int32(0);
            if (v.x1 > x1) v.startfrac += v.xiscale * (v.x1 - x1);
            v.patch = int32(l);
            if (c.sprite.invisibility > 128 || c.sprite.invisibility & 8 != 0) v.colormap = -1;
            else if (c.rs.fixedcolormap != -1) v.colormap = c.rs.fixedcolormap;
            else if (p.frame & 0x8000 != 0) v.colormap = 0;
            else v.colormap = light(c, c.sprite.light, 47);
            R_DrawVisSprite(c, v, v.x1, v.x2);
        }
    }

    function R_DrawPlayerSprites(RenderContext memory c) internal view {
        setLight(c, c.sprite.playerSector);
        c.sprite.mfloorclip = c.rs.screenheightarray;
        c.sprite.mceilingclip = c.negonearray;
        for (uint32 i; i < 2; ++i) {
            if (c.sprite.psprites[i].active) R_DrawPSprite(c, i);
        }
    }

    function R_DrawSprite(
        RenderContext memory c,
        uint32 index,
        function(RenderContext memory, uint32, int32, int32) internal view maskedRange
    ) internal view {
        VisSprite memory v = c.sprite.vissprites[index];
        int32[] memory bottom = new int32[](320);
        int32[] memory top = new int32[](320);
        for (int32 x = v.x1; x <= v.x2; ++x) {
            bottom[uint32(x)] = -2;
            top[uint32(x)] = -2;
        }
        for (uint32 i = c.drawsegCount; i > 0;) {
            --i;
            DrawSeg memory d = c.drawsegs[i];
            if (d.x1 > v.x2 || d.x2 < v.x1 || (d.silhouette == 0 && d.maskedtexturecol.length == 0)) {
                continue;
            }
            int32 r1 = d.x1 < v.x1 ? v.x1 : d.x1;
            int32 r2 = d.x2 > v.x2 ? v.x2 : d.x2;
            int32 low = d.scale1 > d.scale2 ? d.scale2 : d.scale1;
            int32 scale = d.scale1 > d.scale2 ? d.scale1 : d.scale2;
            if (
                scale < v.scale
                    || (low < v.scale
                        && R_Main.R_PointOnSegSide(v.gx, v.gy, c.map.segs[d.curline], c.map) == 0)
            ) {
                if (d.maskedtexturecol.length != 0) maskedRange(c, i, r1, r2);
                continue;
            }
            uint8 silhouette = d.silhouette;
            if (v.gz >= d.bsilheight) silhouette &= ~uint8(1);
            if (v.gzt <= d.tsilheight) silhouette &= ~uint8(2);
            for (int32 x = r1; x <= r2; ++x) {
                uint32 u = uint32(x);
                if (silhouette & 1 != 0 && bottom[u] == -2) bottom[u] = int16(d.sprbottomclip[u]);
                if (silhouette & 2 != 0 && top[u] == -2) top[u] = int16(d.sprtopclip[u]);
            }
        }
        for (int32 x = v.x1; x <= v.x2; ++x) {
            if (bottom[uint32(x)] == -2) bottom[uint32(x)] = int32(uint32(c.rs.height));
            if (top[uint32(x)] == -2) top[uint32(x)] = -1;
        }
        c.sprite.mfloorclip = bottom;
        c.sprite.mceilingclip = top;
        R_DrawVisSprite(c, v, v.x1, v.x2);
    }

    function R_DrawMasked(
        RenderContext memory c,
        function(RenderContext memory, uint32, int32, int32) internal view maskedRange
    ) internal view {
        R_SortVisSprites(c);
        for (uint256 i; i < c.sprite.sortedOrder.length; ++i) {
            R_DrawSprite(c, c.sprite.sortedOrder[i], maskedRange);
        }
        for (uint32 i = c.drawsegCount; i > 0;) {
            --i;
            if (c.drawsegs[i].maskedtexturecol.length != 0) {
                maskedRange(c, i, c.drawsegs[i].x1, c.drawsegs[i].x2);
            }
        }
        if (c.sprite.viewangleoffset == 0) R_DrawPlayerSprites(c);
    }
}
