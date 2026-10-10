// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;

import {VideoState} from "./v_video_types.sol";
import {R_Data} from "./r_data.sol";
import {ResourceView} from "./r_data_types.sol";
import {V_Video as V} from "./v_video.sol";

// Original pointer-to-value/on inputs are supplied at each update. Patch arrays
// and widget history retain their original memory identity in the ST context.
struct STNumber {
    int32 x;
    int32 y;
    int32 width;
    int32 oldnum;
    int32 data;
    bytes[] p;
}

struct STPercent {
    STNumber n;
    bytes p;
}

struct STMultIcon {
    int32 x;
    int32 y;
    int32 oldinum;
    bytes[] p;
}

struct STBinIcon {
    int32 x;
    int32 y;
    bool oldval;
    bytes p;
}

/// @custom:source linuxdoom-1.10/st_lib.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
library ST_Lib {
    error WidgetBounds();

    function STlib_init(ResourceView memory source) internal view returns (bytes memory sttminus) {
        return R_Data.W_CacheLumpNum(source, R_Data.W_GetNumForName(source, "STTMINUS"));
    }

    function STlib_initNum(STNumber memory n, int32 x, int32 y, bytes[] memory pl, int32 width)
        internal
        pure
    {
        n.x = x;
        n.y = y;
        n.oldnum = 0;
        n.width = width;
        n.p = pl;
    }

    function STlib_drawNum(VideoState memory v, STNumber memory n, int32 num, bytes memory sttminus)
        internal
        pure
    {
        int32 numdigits = n.width;
        int32 w = SHORT(n.p[0], 0);
        int32 h = SHORT(n.p[0], 2);
        n.oldnum = num;
        bool neg = num < 0;
        if (neg) {
            if (numdigits == 2 && num < -9) num = -9;
            else if (numdigits == 3 && num < -99) num = -99;
            // INT_MIN negation and invalid widths are outside the defined C domain.
            if (num == type(int32).min) revert WidgetBounds();
            num = -num;
        }
        if (n.y < 168 || numdigits < 0) revert WidgetBounds();
        int32 x = n.x - numdigits * w;
        V.V_CopyRect(v, x, n.y - 168, 4, w * numdigits, h, x, n.y, 0);
        if (num == 1994) return;
        x = n.x;
        if (num == 0) V.V_DrawPatch(v, x - w, n.y, 0, n.p[0]);
        while (num != 0 && numdigits-- != 0) {
            x -= w;
            V.V_DrawPatch(v, x, n.y, 0, n.p[uint32(num % 10)]);
            num /= 10;
        }
        if (neg) V.V_DrawPatch(v, x - 8, n.y, 0, sttminus);
    }

    function STlib_updateNum(
        VideoState memory v,
        STNumber memory n,
        int32 num,
        bool on,
        bool,
        bytes memory minus
    ) internal pure {
        // Original redraws numbers even when unchanged and refresh is false.
        if (on) STlib_drawNum(v, n, num, minus);
    }

    function STlib_initPercent(STPercent memory p, int32 x, int32 y, bytes[] memory pl, bytes memory percent)
        internal
        pure
    {
        STlib_initNum(p.n, x, y, pl, 3);
        p.p = percent;
    }

    function STlib_updatePercent(
        VideoState memory v,
        STPercent memory per,
        int32 num,
        bool on,
        bool refresh,
        bytes memory minus
    ) internal pure {
        if (refresh && on) V.V_DrawPatch(v, per.n.x, per.n.y, 0, per.p);
        STlib_updateNum(v, per.n, num, on, refresh, minus);
    }

    function STlib_initMultIcon(STMultIcon memory i, int32 x, int32 y, bytes[] memory il) internal pure {
        i.x = x;
        i.y = y;
        i.oldinum = -1;
        i.p = il;
    }

    function STlib_updateMultIcon(
        VideoState memory v,
        STMultIcon memory mi,
        int32 inum,
        bool on,
        bool refresh
    ) internal pure {
        if (on && (mi.oldinum != inum || refresh) && inum != -1) {
            if (mi.oldinum != -1) _restore(v, mi.x, mi.y, mi.p[uint32(mi.oldinum)]);
            V.V_DrawPatch(v, mi.x, mi.y, 0, mi.p[uint32(inum)]);
            mi.oldinum = inum;
        }
        // Original -1 neither erases the previous icon nor changes oldinum.
    }

    function STlib_initBinIcon(STBinIcon memory b, int32 x, int32 y, bytes memory p) internal pure {
        b.x = x;
        b.y = y;
        b.oldval = false;
        b.p = p;
    }

    function STlib_updateBinIcon(VideoState memory v, STBinIcon memory bi, bool val, bool on, bool refresh)
        internal
        pure
    {
        if (on && (bi.oldval != val || refresh)) {
            // Original validates the restore rectangle even on the draw branch.
            if (bi.y - SHORT(bi.p, 6) < 168) revert WidgetBounds();
            if (val) V.V_DrawPatch(v, bi.x, bi.y, 0, bi.p);
            else _restore(v, bi.x, bi.y, bi.p);
            bi.oldval = val;
        }
    }

    function _restore(VideoState memory v, int32 px, int32 py, bytes memory p) private pure {
        int32 x = px - SHORT(p, 4);
        int32 y = py - SHORT(p, 6);
        if (y < 168) revert WidgetBounds();
        V.V_CopyRect(v, x, y - 168, 4, SHORT(p, 0), SHORT(p, 2), x, y, 0);
    }

    function SHORT(bytes memory p, uint256 at) internal pure returns (int32) {
        if (p.length < at + 2) revert V.MalformedPatch();
        return int32(int16(uint16(uint8(p[at])) | uint16(uint8(p[at + 1])) << 8));
    }
}
