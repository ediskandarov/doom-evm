// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {RenderState, DrawColumn, DrawSpan} from "./r_state.sol";

/// @custom:source linuxdoom-1.10/r_draw.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @notice Original drawing loops, with byte offsets replacing C pointers.
/// @dev Copyright (C) 1993-1996 by id Software, Inc. Signed accumulation follows
/// the pinned -fwrapv profile. Every source/destination dereference is bounded.
library R_Draw {
    error DrawBounds();

    function R_DrawColumn(RenderState memory rs, DrawColumn memory dc) internal pure {
        _column(rs, dc, false, false);
    }

    function R_DrawColumnLow(RenderState memory rs, DrawColumn memory dc) internal pure {
        _column(rs, dc, true, false);
    }

    function R_DrawTranslatedColumn(RenderState memory rs, DrawColumn memory dc) internal pure {
        _column(rs, dc, false, true);
    }

    function _column(RenderState memory rs, DrawColumn memory dc, bool low, bool translated) private pure {
        if (dc.yh < dc.yl) return;
        if (dc.yl < 0 || dc.yh >= int256(rs.ylookup.length) || dc.x < 0 || dc.colormap.length != 256) {
            revert DrawBounds();
        }
        if (translated && dc.translation.length != 256) revert DrawBounds();
        if (low) {
            if (dc.x > type(int32).max / 2) revert DrawBounds();
            dc.x *= 2; // Original changes dc_x, including on subsequent calls.
        }
        uint256 x = uint32(dc.x);
        if (x + (low ? 1 : 0) >= rs.columnofs.length) revert DrawBounds();
        uint256 dest = uint256(rs.ylookup[uint32(dc.yl)]) + rs.columnofs[x];
        uint256 dest2 = low ? uint256(rs.ylookup[uint32(dc.yl)]) + rs.columnofs[x + 1] : dest;
        uint256 count = uint256(int256(dc.yh) - dc.yl) + 1;
        if (
            dest + (count - 1) * 320 >= rs.framebuffer.length
                || dest2 + (count - 1) * 320 >= rs.framebuffer.length
        ) revert DrawBounds();
        int32 frac;
        unchecked {
            frac = dc.texturemid + (dc.yl - rs.centery) * dc.iscale;
        }
        for (uint256 i; i < count; ++i) {
            int256 index = int256(uint256(dc.sourceOffset))
                + (translated ? int256(frac >> 16) : int256((frac >> 16) & 127));
            if (index < 0) revert DrawBounds();
            uint8 color;
            if (uint256(index) < dc.source.length) {
                color = uint8(dc.source[uint256(index)]);
            } else {
                uint256 tailIndex = uint256(index) - dc.source.length;
                if (
                    tailIndex >= dc.sourceTail.length || tailIndex >= dc.sourceTailKnown.length
                        || dc.sourceTailKnown[tailIndex] != 0x01
                ) revert DrawBounds();
                color = uint8(dc.sourceTail[tailIndex]);
            }
            if (translated) color = uint8(dc.translation[color]);
            rs.framebuffer[dest] = dc.colormap[color];
            if (low) rs.framebuffer[dest2] = dc.colormap[color];
            dest += 320;
            dest2 += 320;
            unchecked {
                frac += dc.iscale;
            }
        }
    }

    function R_DrawFuzzColumn(RenderState memory rs, DrawColumn memory dc, bytes memory colormaps)
        internal
        pure
    {
        if (dc.yl == 0) dc.yl = 1;
        if (dc.yh == int32(uint32(rs.height)) - 1) dc.yh = int32(uint32(rs.height)) - 2;
        if (dc.yh < dc.yl) return;
        if (
            dc.yl < 0 || dc.yh >= int256(rs.ylookup.length) || dc.x < 0 || uint32(dc.x) >= rs.columnofs.length
                || colormaps.length < 7 * 256 || rs.fuzzpos >= 50
        ) revert DrawBounds();
        uint256 dest = uint256(rs.ylookup[uint32(dc.yl)]) + rs.columnofs[uint32(dc.x)];
        // Literal signs are retained visibly, independently checked against the native array.
        bytes memory signs =
            hex"0100010001010001010001010100010101000000000100000101010100010001010000010100000000010101010001010001";
        uint256 count = uint256(int256(dc.yh) - dc.yl) + 1;
        for (uint256 i; i < count; ++i) {
            int256 neighbor = int256(dest) + (signs[rs.fuzzpos] == 0x01 ? int256(320) : -int256(320));
            if (dest >= rs.framebuffer.length || neighbor < 0 || uint256(neighbor) >= rs.framebuffer.length) {
                revert DrawBounds();
            }
            rs.framebuffer[dest] = colormaps[6 * 256 + uint8(rs.framebuffer[uint256(neighbor)])];
            if (++rs.fuzzpos == 50) rs.fuzzpos = 0;
            dest += 320;
        }
    }

    function R_DrawSpan(RenderState memory rs, DrawSpan memory ds) internal pure {
        _span(rs, ds, false);
    }

    function R_DrawSpanLow(RenderState memory rs, DrawSpan memory ds) internal pure {
        _span(rs, ds, true);
    }

    function _span(RenderState memory rs, DrawSpan memory ds, bool low) private pure {
        if (
            ds.x1 < 0 || ds.x2 < ds.x1 || ds.y < 0 || uint32(ds.y) >= rs.ylookup.length
                || ds.source.length < 4096 || ds.colormap.length != 256
        ) revert DrawBounds();
        if (low) {
            if (ds.x2 > type(int32).max / 2) revert DrawBounds();
            ds.x1 *= 2;
            ds.x2 *= 2;
        }
        if (uint32(ds.x1) >= rs.columnofs.length) revert DrawBounds();
        uint256 dest = uint256(rs.ylookup[uint32(ds.y)]) + rs.columnofs[uint32(ds.x1)];
        // Preserve original low-detail bug: count is computed AFTER doubling endpoints.
        uint256 count = uint256(int256(ds.x2) - ds.x1) + 1;
        uint256 size = count * (low ? 2 : 1);
        if (dest > rs.framebuffer.length || size > rs.framebuffer.length - dest) revert DrawBounds();
        int32 xfrac = ds.xfrac;
        int32 yfrac = ds.yfrac;
        for (uint256 i; i < count; ++i) {
            uint256 spot = uint32(((yfrac >> 10) & 4032) + ((xfrac >> 16) & 63));
            bytes1 color = ds.colormap[uint8(ds.source[spot])];
            rs.framebuffer[dest++] = color;
            if (low) rs.framebuffer[dest++] = color;
            unchecked {
                xfrac += ds.xstep;
                yfrac += ds.ystep;
            }
        }
    }

    function R_InitBuffer(RenderState memory rs, uint32 width, uint32 height) internal pure {
        if (width == 0 || width > 320 || height == 0 || height > (width == 320 ? 200 : 168)) {
            revert DrawBounds();
        }
        rs.viewwindowx = int32((320 - width) >> 1);
        rs.columnofs = new uint32[](width);
        for (uint32 i; i < width; ++i) {
            rs.columnofs[i] = uint32(rs.viewwindowx) + i;
        }
        rs.viewwindowy = width == 320 ? int32(0) : int32((168 - height) >> 1);
        rs.ylookup = new uint32[](height);
        for (uint32 i; i < height; ++i) {
            rs.ylookup[i] = (i + uint32(rs.viewwindowy)) * 320;
        }
    }

    function R_InitTranslationTables() internal pure returns (bytes memory translations) {
        translations = new bytes(768);
        for (uint256 i; i < 256; ++i) {
            if (i >= 0x70 && i <= 0x7f) {
                translations[i] = bytes1(uint8(0x60 + (i & 15)));
                translations[i + 256] = bytes1(uint8(0x40 + (i & 15)));
                translations[i + 512] = bytes1(uint8(0x20 + (i & 15)));
            } else {
                translations[i] = translations[i + 256] = translations[i + 512] = bytes1(uint8(i));
            }
        }
    }

    function R_VideoErase(RenderState memory rs, bytes memory backscreen, uint32 ofs, uint32 count)
        internal
        pure
    {
        uint256 end = uint256(ofs) + count;
        if (end > rs.framebuffer.length || end > backscreen.length) revert DrawBounds();
        for (uint256 i = ofs; i < end; ++i) {
            rs.framebuffer[i] = backscreen[i];
        }
    }
}
