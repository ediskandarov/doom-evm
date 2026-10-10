// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {GameContext} from "./p_game_state.sol";
import {GameflowState} from "./g_game.sol";
import {ResourceView} from "./r_data_types.sol";
import {R_Data} from "./r_data.sol";
import {HU_Stuff} from "./hu_stuff.sol";
import {V_Video} from "./v_video.sol";
import {VideoState} from "./v_video_types.sol";

struct FinaleState {
    int32 finalestage;
    int32 finalecount;
    bool started;
}

/// @custom:source linuxdoom-1.10/f_finale.c active Episode One branches.
library F_Finale {
    error UnsupportedFinale();

    function text() internal pure returns (bytes memory) {
        return bytes(
            "Once you beat the big badasses and\nclean out the moon base you're supposed\nto win, aren't you? Aren't you? Where's\nyour fat reward and ticket home? What\nthe hell is this? It's not supposed to\nend this way!\n\nIt stinks like rotten meat, but looks\nlike the lost Deimos base.  Looks like\nyou're stuck on The Shores of Hell.\nThe only way out is through.\n\nTo continue the DOOM experience, play\nThe Shores of Hell and its amazing\nsequel, Inferno!\n"
        );
    }

    function F_StartFinale(GameContext memory c, GameflowState memory f, FinaleState memory s) internal pure {
        if (
            c.state.gameepisode != 1
                || (c.state.gamemode != 0 && c.state.gamemode != 1 && c.state.gamemode != 3)
        ) revert UnsupportedFinale();
        c.state.gameaction = 0;
        c.state.gamestate = 2;
        f.viewactive = false;
        f.automapactive = false;
        s.finalestage = 0;
        s.finalecount = 0;
        s.started = true;
    }

    function F_Responder(FinaleState memory s) internal pure returns (bool) {
        if (!s.started || s.finalestage == 2) revert UnsupportedFinale();
        return false;
    }

    function F_Ticker(FinaleState memory s, GameflowState memory f) internal pure {
        if (!s.started || s.finalestage < 0 || s.finalestage > 1 || s.finalecount == type(int32).max) {
            revert UnsupportedFinale();
        }
        ++s.finalecount;
        if (s.finalestage == 0 && s.finalecount > int32(uint32(text().length)) * 3 + 250) {
            s.finalecount = 0;
            s.finalestage = 1;
            f.wipegamestate = -1;
        }
    }

    function F_TextWrite(FinaleState memory s, ResourceView memory source, VideoState memory v)
        internal
        view
    {
        bytes memory flat = R_Data.W_CacheLumpNum(source, R_Data.W_GetNumForName(source, "FLOOR4_8"));
        if (flat.length != 4096 || v.screens[0].length != 64000) revert UnsupportedFinale();
        for (uint256 y; y < 200; ++y) {
            for (uint256 x; x < 320; ++x) {
                v.screens[0][y * 320 + x] = flat[((y & 63) << 6) + (x & 63)];
            }
        }
        V_Video.V_MarkRect(v, 0, 0, 320, 200);
        int32 cx = 10;
        int32 cy = 10;
        int32 count = (s.finalecount - 10) / 3;
        if (count < 0) count = 0;
        bytes memory message = text();
        bytes[] memory font = HU_Stuff.HU_Init(source);
        uint256 at;
        for (; count != 0; --count) {
            if (at == message.length) break;
            uint8 ch = uint8(message[at++]);
            if (ch == 10) {
                cx = 10;
                cy += 11;
                continue;
            }
            if (ch >= 97 && ch <= 122) ch -= 32;
            int32 glyph = int32(uint32(ch)) - 33;
            // Original tests c>HU_FONTSIZE; c==HU_FONTSIZE is an undefined read.
            if (glyph < 0 || glyph > 63) {
                cx += 4;
                continue;
            }
            if (glyph == 63) revert UnsupportedFinale();
            bytes memory patch = font[uint32(glyph)];
            int32 width = int32(int16(uint16(uint8(patch[0])) | uint16(uint8(patch[1])) << 8));
            if (cx + width > 320) break;
            V_Video.V_DrawPatch(v, cx, cy, 0, patch);
            cx += width;
        }
    }

    function F_Drawer(FinaleState memory s, ResourceView memory source, VideoState memory v, int32 mode)
        internal
        view
    {
        if (!s.started || s.finalestage < 0 || s.finalestage > 1) revert UnsupportedFinale();
        if (s.finalestage == 0) {
            F_TextWrite(s, source, v);
        } else {
            V_Video.V_DrawPatch(
                v,
                0,
                0,
                0,
                R_Data.W_CacheLumpNum(
                    source, R_Data.W_GetNumForName(source, mode == 3 ? bytes8("CREDIT") : bytes8("HELP2"))
                )
            );
        }
    }
}
