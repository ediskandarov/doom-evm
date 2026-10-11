// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;

import {M_Random} from "./m_random.sol";
import {VideoState} from "./v_video_types.sol";
import {V_Video} from "./v_video.sol";

/// @dev Original f_wipe.c globals; owned buffers replace C pointers/zone allocations.
struct WipeState {
    bool go;
    bytes wipe_scr_start;
    bytes wipe_scr_end;
    bytes wipe_scr;
    int32[] y;
    uint32 rndindex;
}

/// @custom:source linuxdoom-1.10/f_wipe.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @dev D_Display's 320x200 melt only. No color-transform or arbitrary rectangles.
library F_Wipe {
    error InvalidWipe();

    function copy(bytes memory src) private pure returns (bytes memory dest) {
        dest = new bytes(src.length);
        for (uint256 i; i < src.length; ++i) {
            dest[i] = src[i];
        }
    }

    function wipe_StartScreen(WipeState memory s, VideoState memory v) internal pure {
        if (s.go || v.screens[0].length != 64000) revert InvalidWipe();
        // I_ReadScreen copies, never aliases the actively drawn framebuffer.
        s.wipe_scr_start = copy(v.screens[0]);
    }

    function wipe_EndScreen(WipeState memory s, VideoState memory v) internal pure {
        if (s.go || s.wipe_scr_start.length != 64000 || v.screens[0].length != 64000) {
            revert InvalidWipe();
        }
        s.wipe_scr_end = copy(v.screens[0]);
        v.screens[0] = copy(s.wipe_scr_start);
        s.wipe_scr = v.screens[0];
    }

    function wipe_shittyColMajorXform(bytes memory array) internal pure {
        if (array.length != 64000) revert InvalidWipe();
        bytes memory dest = new bytes(64000);
        for (uint256 y; y < 200; ++y) {
            for (uint256 x; x < 160; ++x) {
                uint256 from = (y * 160 + x) * 2;
                uint256 to = (x * 200 + y) * 2;
                // A short is copied bit-for-bit: no endian-dependent numeric operation.
                dest[to] = array[from];
                dest[to + 1] = array[from + 1];
            }
        }
        for (uint256 i; i < 64000; ++i) {
            array[i] = dest[i];
        }
    }

    function random(WipeState memory s) private pure returns (int32) {
        s.rndindex = (s.rndindex + 1) & 255;
        return int32(uint32(M_Random.value(s.rndindex)));
    }

    function wipe_initMelt(WipeState memory s) internal pure {
        s.wipe_scr = copy(s.wipe_scr_start);
        wipe_shittyColMajorXform(s.wipe_scr_start);
        wipe_shittyColMajorXform(s.wipe_scr_end);
        s.y = new int32[](320);
        s.y[0] = -(random(s) % 16);
        // Original initializes width entries although doMelt uses width/2.
        for (uint256 i = 1; i < 320; ++i) {
            int32 r = (random(s) % 3) - 1;
            s.y[i] = s.y[i - 1] + r;
            if (s.y[i] > 0) s.y[i] = 0;
            else if (s.y[i] == -16) s.y[i] = -15;
        }
    }

    function wipe_doMelt(WipeState memory s, uint32 ticks) internal pure returns (bool done) {
        done = true;
        while (ticks != 0) {
            --ticks;
            for (uint256 i; i < 160; ++i) {
                if (s.y[i] < 0) {
                    ++s.y[i];
                    done = false;
                } else if (s.y[i] < 200) {
                    int32 dy = s.y[i] < 16 ? s.y[i] + 1 : int32(8);
                    if (s.y[i] + dy >= 200) dy = 200 - s.y[i];
                    uint256 src = (i * 200 + uint32(s.y[i])) * 2;
                    uint256 dest = uint32(s.y[i]) * 320 + i * 2;
                    for (int32 j = dy; j != 0; --j) {
                        s.wipe_scr[dest] = s.wipe_scr_end[src];
                        s.wipe_scr[dest + 1] = s.wipe_scr_end[src + 1];
                        src += 2;
                        dest += 320;
                    }
                    s.y[i] += dy;
                    src = i * 400;
                    dest = uint32(s.y[i]) * 320 + i * 2;
                    for (int32 j = 200 - s.y[i]; j != 0; --j) {
                        s.wipe_scr[dest] = s.wipe_scr_start[src];
                        s.wipe_scr[dest + 1] = s.wipe_scr_start[src + 1];
                        src += 2;
                        dest += 320;
                    }
                    done = false;
                }
            }
        }
    }

    function wipe_exitMelt(WipeState memory s) internal pure {
        s.y = new int32[](0); // Z_Free: release context-owned y, leave screen buffers.
    }

    function wipe_ScreenWipe(WipeState memory s, VideoState memory v, uint32 ticks)
        internal
        pure
        returns (bool)
    {
        if (ticks == 0 || ticks > 200 || s.wipe_scr_start.length != 64000 || s.wipe_scr_end.length != 64000) {
            revert InvalidWipe();
        }
        if (!s.go) {
            s.go = true;
            wipe_initMelt(s);
        }
        V_Video.V_MarkRect(v, 0, 0, 320, 200);
        bool rc = wipe_doMelt(s, ticks);
        v.screens[0] = s.wipe_scr;
        if (rc) {
            s.go = false;
            wipe_exitMelt(s);
        }
        return !s.go;
    }
}
