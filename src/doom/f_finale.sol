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
    int32 commercialMap; // 0 retains existing Episode One; commercial finale map selects original text/flat.
}

/// @custom:source linuxdoom-1.10/f_finale.c active Episode One and commercial text branches; cast remains excluded.
library F_Finale {
    error UnsupportedFinale();

    function text() internal pure returns (bytes memory) {
        return bytes(
            "Once you beat the big badasses and\nclean out the moon base you're supposed\nto win, aren't you? Aren't you? Where's\nyour fat reward and ticket home? What\nthe hell is this? It's not supposed to\nend this way!\n\nIt stinks like rotten meat, but looks\nlike the lost Deimos base.  Looks like\nyou're stuck on The Shores of Hell.\nThe only way out is through.\n\nTo continue the DOOM experience, play\nThe Shores of Hell and its amazing\nsequel, Inferno!\n"
        );
    }

    /// @custom:source d_englsh.h C1TEXT–C6TEXT; f_finale.c commercial switch.
    function text(FinaleState memory s) internal pure returns (bytes memory) {
        if (s.commercialMap == 0) return text();
        if (s.commercialMap == 6) return bytes("YOU HAVE ENTERED DEEPLY INTO THE INFESTED\nSTARPORT. BUT SOMETHING IS WRONG. THE\nMONSTERS HAVE BROUGHT THEIR OWN REALITY\nWITH THEM, AND THE STARPORT'S TECHNOLOGY\nIS BEING SUBVERTED BY THEIR PRESENCE.\n\nAHEAD, YOU SEE AN OUTPOST OF HELL, A\nFORTIFIED ZONE. IF YOU CAN GET PAST IT,\nYOU CAN PENETRATE INTO THE HAUNTED HEART\nOF THE STARBASE AND FIND THE CONTROLLING\nSWITCH WHICH HOLDS EARTH'S POPULATION\nHOSTAGE.");
        if (s.commercialMap == 11) return bytes("YOU HAVE WON! YOUR VICTORY HAS ENABLED\nHUMANKIND TO EVACUATE EARTH AND ESCAPE\nTHE NIGHTMARE.  NOW YOU ARE THE ONLY\nHUMAN LEFT ON THE FACE OF THE PLANET.\nCANNIBAL MUTATIONS, CARNIVOROUS ALIENS,\nAND EVIL SPIRITS ARE YOUR ONLY NEIGHBORS.\nYOU SIT BACK AND WAIT FOR DEATH, CONTENT\nTHAT YOU HAVE SAVED YOUR SPECIES.\n\nBUT THEN, EARTH CONTROL BEAMS DOWN A\nMESSAGE FROM SPACE: \"SENSORS HAVE LOCATED\nTHE SOURCE OF THE ALIEN INVASION. IF YOU\nGO THERE, YOU MAY BE ABLE TO BLOCK THEIR\nENTRY.  THE ALIEN BASE IS IN THE HEART OF\nYOUR OWN HOME CITY, NOT FAR FROM THE\nSTARPORT.\" SLOWLY AND PAINFULLY YOU GET\nUP AND RETURN TO THE FRAY.");
        if (s.commercialMap == 20) return bytes("YOU ARE AT THE CORRUPT HEART OF THE CITY,\nSURROUNDED BY THE CORPSES OF YOUR ENEMIES.\nYOU SEE NO WAY TO DESTROY THE CREATURES'\nENTRYWAY ON THIS SIDE, SO YOU CLENCH YOUR\nTEETH AND PLUNGE THROUGH IT.\n\nTHERE MUST BE A WAY TO CLOSE IT ON THE\nOTHER SIDE. WHAT DO YOU CARE IF YOU'VE\nGOT TO GO THROUGH HELL TO GET TO IT?");
        if (s.commercialMap == 30) return bytes("THE HORRENDOUS VISAGE OF THE BIGGEST\nDEMON YOU'VE EVER SEEN CRUMBLES BEFORE\nYOU, AFTER YOU PUMP YOUR ROCKETS INTO\nHIS EXPOSED BRAIN. THE MONSTER SHRIVELS\nUP AND DIES, ITS THRASHING LIMBS\nDEVASTATING UNTOLD MILES OF HELL'S\nSURFACE.\n\nYOU'VE DONE IT. THE INVASION IS OVER.\nEARTH IS SAVED. HELL IS A WRECK. YOU\nWONDER WHERE BAD FOLKS WILL GO WHEN THEY\nDIE, NOW. WIPING THE SWEAT FROM YOUR\nFOREHEAD YOU BEGIN THE LONG TREK BACK\nHOME. REBUILDING EARTH OUGHT TO BE A\nLOT MORE FUN THAN RUINING IT WAS.\n");
        if (s.commercialMap == 15) return bytes("CONGRATULATIONS, YOU'VE FOUND THE SECRET\nLEVEL! LOOKS LIKE IT'S BEEN BUILT BY\nHUMANS, RATHER THAN DEMONS. YOU WONDER\nWHO THE INMATES OF THIS CORNER OF HELL\nWILL BE.");
        if (s.commercialMap == 31) return bytes("CONGRATULATIONS, YOU'VE FOUND THE\nSUPER SECRET LEVEL!  YOU'D BETTER\nBLAZE THROUGH THIS ONE!\n");
        revert UnsupportedFinale();
    }

    function flat(FinaleState memory s) private pure returns (bytes8) {
        if (s.commercialMap == 0) return "FLOOR4_8";
        if (s.commercialMap == 6) return "SLIME16";
        if (s.commercialMap == 11) return "RROCK14";
        if (s.commercialMap == 20) return "RROCK07";
        if (s.commercialMap == 30) return "RROCK17";
        if (s.commercialMap == 15) return "RROCK13";
        if (s.commercialMap == 31) return "RROCK19";
        revert UnsupportedFinale();
    }

    function F_StartFinale(GameContext memory c, GameflowState memory f, FinaleState memory s) internal pure {
        if (
            c.state.gameepisode != 1
                || (c.state.gamemode != 0 && c.state.gamemode != 1 && c.state.gamemode != 2 && c.state.gamemode != 3)
        ) revert UnsupportedFinale();
        s.commercialMap = c.state.gamemode == 2 ? c.state.gamemap : int32(0);
        if (s.commercialMap != 0) text(s); // reject undefined original default text pointer.
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

    /// @dev Original commercial button skip. MAP30 cast remains outside the supported domain.
    function F_Ticker(GameContext memory c, FinaleState memory s, GameflowState memory f) internal pure {
        if (c.state.gamemode != 2) { F_Ticker(s, f); return; }
        if (!s.started || s.finalestage != 0 || s.finalecount == type(int32).max) revert UnsupportedFinale();
        if (s.finalecount > 50) {
            for (uint256 i; i < 4; ++i) {
                if (c.state.players[i].cmd.buttons != 0) {
                    if (s.commercialMap == 30) revert UnsupportedFinale(); // F_StartCast is not ported.
                    c.state.gameaction = 8;
                    break;
                }
            }
        }
        ++s.finalecount;
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
        bytes memory flat = R_Data.W_CacheLumpNum(source, R_Data.W_GetNumForName(source, flat(s)));
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
        bytes memory message = text(s);
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
