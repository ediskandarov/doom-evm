// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;

import {VideoState} from "./v_video_types.sol";
import {M_BBox} from "./m_bbox.sol";

/// @custom:source linuxdoom-1.10/v_video.c, v_video.h at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @notice Original 320x200 indexed-byte drawing, with the original RANGECHECK policy.
/// @dev No scaling, palette conversion, tall-patch extension or edge clipping in original V_DrawPatch.
/// Malformed/physical out-of-buffer accesses and undefined overlapping memcpy are rejected.
library V_Video {
    error VideoBounds();
    error MalformedPatch();
    error OverlappingCopy();

    function V_Init(VideoState memory v) internal pure {
        for (uint256 i; i < 4; ++i) {
            v.screens[i] = new bytes(320 * 200);
        }
        // Original leaves screens[4] and dirtybox alone. Fresh EVM buffers are zero initialized.
    }

    function V_MarkRect(VideoState memory v, int32 x, int32 y, int32 width, int32 height) internal pure {
        M_BBox.M_AddToBox(v.dirtybox, x, y);
        unchecked {
            M_BBox.M_AddToBox(v.dirtybox, x + width - 1, y + height - 1);
        }
    }

    function V_CopyRect(
        VideoState memory v,
        int32 srcx,
        int32 srcy,
        int32 srcscrn,
        int32 width,
        int32 height,
        int32 destx,
        int32 desty,
        int32 destscrn
    ) internal pure {
        _rect(srcx, srcy, width, height, srcscrn);
        _rect(destx, desty, width, height, destscrn);
        V_MarkRect(v, destx, desty, width, height);
        bytes memory src = v.screens[uint32(srcscrn)];
        bytes memory dest = v.screens[uint32(destscrn)];
        uint256 s = uint32(srcy) * 320 + uint32(srcx);
        uint256 d = uint32(desty) * 320 + uint32(destx);
        for (int32 row; row < height; ++row) {
            _copy(dest, d, src, s, uint32(width));
            s += 320;
            d += 320;
        }
    }

    function V_DrawPatch(VideoState memory v, int32 x, int32 y, int32 scrn, bytes memory patch)
        internal
        pure
    {
        _patch(v, x, y, scrn, patch, false);
    }

    function V_DrawPatchFlipped(VideoState memory v, int32 x, int32 y, int32 scrn, bytes memory patch)
        internal
        pure
    {
        _patch(v, x, y, scrn, patch, true);
    }

    function V_DrawPatchDirect(VideoState memory v, int32 x, int32 y, int32 scrn, bytes memory patch)
        internal
        pure
    {
        V_DrawPatch(v, x, y, scrn, patch);
    }

    function _short(bytes memory patch, uint256 at) private pure returns (int32) {
        return int32(int16(uint16(uint8(patch[at])) | (uint16(uint8(patch[at + 1])) << 8)));
    }

    function _patch(VideoState memory v, int32 x, int32 y, int32 scrn, bytes memory patch, bool flipped)
        private
        pure
    {
        if (patch.length < 8) revert MalformedPatch();
        int32 width = _short(patch, 0);
        int32 height = _short(patch, 2);
        if (width < 0 || height < 0 || 8 + uint32(width) * 4 > patch.length) revert MalformedPatch();
        unchecked {
            y -= _short(patch, 6);
            x -= _short(patch, 4);
        }
        // Native RANGECHECK ignores normal patches but aborts flipped patches at invalid origins.
        if (!_inRect(x, y, width, height, scrn)) {
            if (flipped) revert VideoBounds();
            return;
        }
        if (scrn == 0) V_MarkRect(v, x, y, width, height);
        bytes memory dest = v.screens[uint32(scrn)];
        uint256 desttop = uint32(y) * 320 + uint32(x);
        for (int32 col; col < width; ++col) {
            uint256 at = 8 + uint32(flipped ? width - 1 - col : col) * 4;
            uint256 column = uint8(patch[at]) | (uint256(uint8(patch[at + 1])) << 8)
                | (uint256(uint8(patch[at + 2])) << 16) | (uint256(uint8(patch[at + 3])) << 24);
            if (column < 8 + uint32(width) * 4) revert MalformedPatch();
            while (true) {
                if (column >= patch.length) revert MalformedPatch();
                uint256 top = uint8(patch[column]);
                if (top == 255) break;
                if (column + 4 > patch.length) revert MalformedPatch();
                uint256 count = uint8(patch[column + 1]);
                if (column + count + 4 > patch.length || top + count > uint32(height)) {
                    revert MalformedPatch();
                }
                uint256 d = desttop + top * 320;
                if (count != 0 && d + (count - 1) * 320 >= dest.length) revert VideoBounds();
                uint256 source = column + 3;
                for (uint256 i; i < count; ++i) {
                    dest[d] = patch[source++];
                    d += 320;
                }
                column += count + 4;
            }
            ++desttop;
        }
    }

    function V_DrawBlock(
        VideoState memory v,
        int32 x,
        int32 y,
        int32 scrn,
        int32 width,
        int32 height,
        bytes memory src
    ) internal pure {
        _rect(x, y, width, height, scrn);
        V_MarkRect(v, x, y, width, height);
        bytes memory dest = v.screens[uint32(scrn)];
        uint256 d = uint32(y) * 320 + uint32(x);
        uint256 s;
        for (int32 row; row < height; ++row) {
            _copy(dest, d, src, s, uint32(width));
            s += uint32(width);
            d += 320;
        }
    }

    function V_GetBlock(
        VideoState memory v,
        int32 x,
        int32 y,
        int32 scrn,
        int32 width,
        int32 height,
        bytes memory dest
    ) internal pure {
        _rect(x, y, width, height, scrn);
        bytes memory src = v.screens[uint32(scrn)];
        uint256 s = uint32(y) * 320 + uint32(x);
        uint256 d;
        for (int32 row; row < height; ++row) {
            _copy(dest, d, src, s, uint32(width));
            s += 320;
            d += uint32(width);
        }
    }

    function _inRect(int32 x, int32 y, int32 width, int32 height, int32 scrn) private pure returns (bool) {
        return x >= 0 && y >= 0 && width >= 0 && height >= 0 && int64(x) + width <= 320
            && int64(y) + height <= 200 && scrn >= 0 && scrn <= 4;
    }

    function _rect(int32 x, int32 y, int32 width, int32 height, int32 scrn) private pure {
        if (!_inRect(x, y, width, height, scrn)) revert VideoBounds();
    }

    function _copy(bytes memory dest, uint256 d, bytes memory src, uint256 s, uint256 n) private pure {
        if (n == 0) return;
        if (d > dest.length || n > dest.length - d || s > src.length || n > src.length - s) {
            revert VideoBounds();
        }
        uint256 dp;
        uint256 sp;
        assembly ("memory-safe") {
            dp := add(add(dest, 32), d)
            sp := add(add(src, 32), s)
        }
        if (dp != sp && dp < sp + n && sp < dp + n) revert OverlappingCopy();
        // Original row memcpy: both Solidity allocations checked above, exactly n bytes,
        // no header/padding access. Defined disjoint rows retain source-to-destination order.
        assembly ("memory-safe") { mcopy(dp, sp, n) }
    }
}
