// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;

import {VideoState} from "./v_video_types.sol";
import {V_Video} from "./v_video.sol";
import {RenderState} from "./r_state.sol";
import {R_Draw} from "./r_draw.sol";

struct HuTextLine {
    int32 x;
    int32 y;
    bytes[] font;
    uint8 startchar;
    bytes text; // 81 bytes, including the original trailing NUL
    uint32 len;
    uint32 needsupdate;
}

struct HuSText {
    HuTextLine[4] lines;
    uint32 h;
    uint32 cl;
    bool on; // value of the original boolean pointer
    bool laston;
}

/// @custom:source linuxdoom-1.10/hu_lib.c and hu_lib.h at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @dev Input/chat widgets are intentionally excluded. Fonts are unmodified WAD patches.
library HU_Lib {
    error InvalidTextWidget();

    function HUlib_init() internal pure {}

    function HUlib_clearTextLine(HuTextLine memory t) internal pure {
        t.len = 0;
        if (t.text.length != 81) t.text = new bytes(81);
        t.text[0] = 0;
        t.needsupdate = 1;
    }

    function HUlib_initTextLine(HuTextLine memory t, int32 x, int32 y, bytes[] memory f, uint8 sc)
        internal
        pure
    {
        if (sc > 95 || f.length < 96 - uint256(sc)) revert InvalidTextWidget();
        t.x = x;
        t.y = y;
        t.font = f;
        t.startchar = sc;
        HUlib_clearTextLine(t);
    }

    function HUlib_addCharToTextLine(HuTextLine memory t, bytes1 ch) internal pure returns (bool) {
        if (t.len == 80) return false;
        t.text[t.len++] = ch;
        t.text[t.len] = 0;
        t.needsupdate = 4;
        return true;
    }

    function HUlib_delCharFromTextLine(HuTextLine memory t) internal pure returns (bool) {
        if (t.len == 0) return false;
        t.text[--t.len] = 0;
        t.needsupdate = 4;
        return true;
    }

    function patchShort(bytes memory p, uint256 at) internal pure returns (int32) {
        if (p.length < at + 2) revert InvalidTextWidget();
        return int32(int16(uint16(uint8(p[at])) | uint16(uint8(p[at + 1])) << 8));
    }

    function HUlib_drawTextLine(HuTextLine memory l, VideoState memory v, bool cursor) internal pure {
        int32 x = l.x;
        for (uint256 i; i < l.len; ++i) {
            uint8 c = uint8(l.text[i]);
            // Original C locale ASCII toupper. Extended signed-char inputs are outside its defined domain.
            if (c >= 97 && c <= 122) c -= 32;
            if (c != 32 && c >= l.startchar && c <= 95) {
                bytes memory glyph = l.font[c - l.startchar];
                int32 w = patchShort(glyph, 0);
                if (int64(x) + w > 320) break;
                V_Video.V_DrawPatchDirect(v, x, l.y, 0, glyph);
                x += w;
            } else {
                x += 4;
                if (x >= 320) break;
            }
        }
        bytes memory underscore = l.font[95 - l.startchar];
        if (cursor && int64(x) + patchShort(underscore, 0) <= 320) {
            V_Video.V_DrawPatchDirect(v, x, l.y, 0, underscore);
        }
    }

    function HUlib_eraseTextLine(
        HuTextLine memory l,
        VideoState memory v,
        RenderState memory rs,
        bool automap
    ) internal pure {
        if (!automap && rs.viewwindowx != 0 && l.needsupdate != 0) {
            int32 lh = patchShort(l.font[0], 2) + 1;
            // R_VideoErase reads screen1 and writes screen0 without dirty-box updates.
            rs.framebuffer = v.screens[0];
            for (int32 y = l.y; y < l.y + lh; ++y) {
                if (y < 0 || y >= 200 || rs.viewwindowx < 0) revert InvalidTextWidget();
                uint32 offset = uint32(y) * 320;
                if (y < rs.viewwindowy || y >= rs.viewwindowy + int32(uint32(rs.height))) {
                    R_Draw.R_VideoErase(rs, v.screens[1], offset, 320);
                } else {
                    R_Draw.R_VideoErase(rs, v.screens[1], offset, uint32(rs.viewwindowx));
                    R_Draw.R_VideoErase(
                        rs, v.screens[1], offset + uint32(rs.viewwindowx) + rs.width, uint32(rs.viewwindowx)
                    );
                }
            }
        }
        // Native decrements even when automap or full-screen prevents erasure.
        if (l.needsupdate != 0) --l.needsupdate;
    }

    function HUlib_initSText(HuSText memory s, int32 x, int32 y, uint32 h, bytes[] memory f, uint8 sc)
        internal
        pure
    {
        if (h == 0 || h > 4) revert InvalidTextWidget();
        s.h = h;
        s.laston = true;
        s.cl = 0;
        for (uint32 i; i < h; ++i) {
            HUlib_initTextLine(s.lines[i], x, y - int32(i) * (patchShort(f[0], 2) + 1), f, sc);
        }
    }

    function HUlib_addLineToSText(HuSText memory s) internal pure {
        if (++s.cl == s.h) s.cl = 0;
        HUlib_clearTextLine(s.lines[s.cl]);
        for (uint32 i; i < s.h; ++i) {
            s.lines[i].needsupdate = 4;
        }
    }

    function HUlib_addMessageToSText(HuSText memory s, bytes memory prefix, bytes memory msg) internal pure {
        HUlib_addLineToSText(s);
        for (uint256 i; i < prefix.length && prefix[i] != 0; ++i) {
            HUlib_addCharToTextLine(s.lines[s.cl], prefix[i]);
        }
        for (uint256 i; i < msg.length && msg[i] != 0; ++i) {
            HUlib_addCharToTextLine(s.lines[s.cl], msg[i]);
        }
    }

    function HUlib_drawSText(HuSText memory s, VideoState memory v) internal pure {
        if (!s.on) return;
        for (uint32 i; i < s.h; ++i) {
            uint32 idx = (s.cl + s.h - i) % s.h;
            HUlib_drawTextLine(s.lines[idx], v, false);
        }
    }

    function HUlib_eraseSText(HuSText memory s, VideoState memory v, RenderState memory rs, bool automap)
        internal
        pure
    {
        for (uint32 i; i < s.h; ++i) {
            if (s.laston && !s.on) s.lines[i].needsupdate = 4;
            HUlib_eraseTextLine(s.lines[i], v, rs, automap);
        }
        s.laston = s.on;
    }
}
