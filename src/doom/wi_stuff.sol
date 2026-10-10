// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;

import {WiState, WiStart, WiInput, WiGraphics} from "./wi_stuff_types.sol";
import {VideoState} from "./v_video_types.sol";
import {V_Video as V} from "./v_video.sol";
import {M_Random} from "./m_random.sol";
import {R_Data} from "./r_data.sol";
import {ResourceView} from "./r_data_types.sol";

/// @custom:source linuxdoom-1.10/wi_stuff.c cursor a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @notice Original single-player Episode One intermission. No world or production adapter dependency.
/// @dev Global/pointer context adaptation, borrowed immutable graphics, explicit G_WorldDone signal.
/// Audio is excluded. Other episodes, netgame and commercial paths are outside this module's domain.
library WI_Stuff {
    error UnsupportedIntermission();
    error InvalidIntermissionState();
    error UndefinedNativeDomain();

    function _profile(WiInput memory p) private pure {
        if (
            (p.gamemode != 0 && p.gamemode != 1 && p.gamemode != 3) || !p.playeringame[0] || p.playeringame[1]
                || p.playeringame[2] || p.playeringame[3] || p.rndindex > 255
        ) {
            revert UnsupportedIntermission();
        }
    }

    function _active(WiState memory s) private pure {
        if (!s.started || s.worldDoneRequested || s.state < -1 || s.state > 1) {
            revert InvalidIntermissionState();
        }
    }

    function _random(WiInput memory p) private pure returns (int32) {
        // Original M_Random, with the independent miscellaneous index supplied explicitly.
        p.rndindex = (p.rndindex + 1) & 255;
        return int32(uint32(M_Random.value(p.rndindex)));
    }

    function _short(bytes memory patch, uint256 cursor) private pure returns (int32) {
        if (patch.length < cursor + 2) revert V.MalformedPatch();
        return int32(int16(uint16(uint8(patch[cursor])) | (uint16(uint8(patch[cursor + 1])) << 8)));
    }

    function WI_Responder(int32, int32) internal pure returns (bool) {
        return false;
    }

    function WI_initVariables(WiState memory s, WiStart memory w) internal pure {
        if (w.epsd != 0 || w.pnum != 0 || w.last < 0 || w.last > 8 || w.next < 0 || w.next > 8) {
            revert UnsupportedIntermission();
        }
        if (w.maxkills < 0 || w.maxitems < 0 || w.maxsecret < 0 || w.partime < 0) {
            revert UndefinedNativeDomain();
        }
        for (uint256 i; i < 4; ++i) {
            // Exclude original signed numerator overflow; no invented wrapping goldens.
            if (
                w.plyr[i].skills < 0 || w.plyr[i].skills > type(int32).max / 100 || w.plyr[i].sitems < 0
                    || w.plyr[i].sitems > type(int32).max / 100 || w.plyr[i].ssecret < 0
                    || w.plyr[i].ssecret > type(int32).max / 100 || w.plyr[i].stime < 0
            ) revert UndefinedNativeDomain();
        }
        s.wbs = w; // original wbs pointer alias: normalization is visible through w
        s.acceleratestage = 0;
        s.cnt = 0;
        s.bcnt = 0;
        s.firstrefresh = 1;
        s.me = w.pnum;
        if (w.maxkills == 0) w.maxkills = 1;
        if (w.maxitems == 0) w.maxitems = 1;
        if (w.maxsecret == 0) w.maxsecret = 1;
        s.started = true;
        s.worldDoneRequested = false;
        // Original does not reset snl_pointeron or player latches here.
    }

    function WI_Start(
        WiState memory s,
        WiStart memory w,
        WiInput memory p,
        WiGraphics memory a,
        VideoState memory v,
        ResourceView memory source
    ) internal view {
        _profile(p);
        WI_initVariables(s, w);
        WI_loadData(a, v, source);
        WI_initStats(s, p);
    }

    function _load(ResourceView memory source, bytes8 name) private view returns (bytes memory) {
        return R_Data.W_CacheLumpNum(source, R_Data.W_GetNumForName(source, name));
    }

    function _digit(uint256 n) private pure returns (bytes1) {
        return bytes1(uint8(48 + n));
    }

    function WI_loadData(WiGraphics memory a, VideoState memory v, ResourceView memory source) internal view {
        // Original E1 lookup order, including original unused single-player dependencies.
        a.bg = _load(source, "WIMAP0");
        V.V_DrawPatch(v, 0, 0, 1, a.bg);
        for (uint256 i; i < 9; ++i) {
            a.lnames[i] = _load(source, bytes8(abi.encodePacked("WILV0", _digit(i))));
        }
        a.yah[0] = _load(source, "WIURH0");
        a.yah[1] = _load(source, "WIURH1");
        a.splat = _load(source, "WISPLAT");
        for (uint256 j; j < 10; ++j) {
            for (uint256 i; i < 3; ++i) {
                a.anims[j * 3 + i] =
                    _load(source, bytes8(abi.encodePacked("WIA00", _digit(j), "0", _digit(i))));
            }
        }
        a.wiminus = _load(source, "WIMINUS");
        for (uint256 i; i < 10; ++i) {
            a.num[i] = _load(source, bytes8(abi.encodePacked("WINUM", _digit(i))));
        }
        a.percent = _load(source, "WIPCNT");
        a.finished = _load(source, "WIF");
        a.entering = _load(source, "WIENTER");
        a.kills = _load(source, "WIOSTK");
        a.secret = _load(source, "WIOSTS");
        a.sp_secret = _load(source, "WISCRT2");
        a.items = _load(source, "WIOSTI"); // original French single-player path selects this too
        a.frags = _load(source, "WIFRGS");
        a.colon = _load(source, "WICOLON");
        a.time = _load(source, "WITIME");
        a.sucks = _load(source, "WISUCKS");
        a.par = _load(source, "WIPAR");
        a.killers = _load(source, "WIKILRS");
        a.victims = _load(source, "WIVCTMS");
        a.total = _load(source, "WIMSTT");
        a.star = _load(source, "STFST01");
        a.bstar = _load(source, "STFDEAD0");
        for (uint256 i; i < 4; ++i) {
            a.p[i] = _load(source, bytes8(abi.encodePacked("STPB", _digit(i))));
            a.bp[i] = _load(source, bytes8(abi.encodePacked("WIBP", _digit(i + 1))));
        }
    }

    function WI_unloadData() internal pure {
        // Host/context adaptation: graphics borrow immutable bytes. No native zone-tag claim.
    }

    function WI_End(WiState memory s) internal pure {
        WI_unloadData();
        // Preserve the WI_End -> G_WorldDone boundary without selecting/loading a level.
        s.worldDoneRequested = true;
    }

    function WI_initAnimatedBack(WiState memory s, WiInput memory p) internal pure {
        for (uint256 i; i < 10; ++i) {
            s.animCtr[i] = -1;
            s.animNexttic[i] = s.bcnt + 1 + (_random(p) % 11); // TICRATE/3, ANIM_ALWAYS
        }
    }

    function WI_updateAnimatedBack(WiState memory s) internal pure {
        for (uint256 i; i < 10; ++i) {
            if (s.bcnt == s.animNexttic[i]) {
                if (++s.animCtr[i] >= 3) s.animCtr[i] = 0;
                s.animNexttic[i] = s.bcnt + 11;
            }
        }
    }

    function WI_drawAnimatedBack(WiState memory, WiGraphics memory, VideoState memory) internal pure {
        // Preserve pinned C's `if (commercial) return;`: enum constant commercial == 2.
        // Timers and M_Random consumption still execute in the original functions above.
        return;
    }

    function WI_initStats(WiState memory s, WiInput memory p) internal pure {
        s.state = 0;
        s.acceleratestage = 0;
        s.sp_state = 1;
        s.cnt_kills[0] = -1;
        s.cnt_items[0] = -1;
        s.cnt_secret[0] = -1;
        s.cnt_time = -1;
        s.cnt_par = -1;
        s.cnt_pause = 35;
        WI_initAnimatedBack(s, p);
    }

    function WI_updateStats(WiState memory s, WiInput memory p) internal pure {
        WI_updateAnimatedBack(s);
        if (s.acceleratestage != 0 && s.sp_state != 10) {
            s.acceleratestage = 0;
            s.cnt_kills[0] = (s.wbs.plyr[uint32(s.me)].skills * 100) / s.wbs.maxkills;
            s.cnt_items[0] = (s.wbs.plyr[uint32(s.me)].sitems * 100) / s.wbs.maxitems;
            s.cnt_secret[0] = (s.wbs.plyr[uint32(s.me)].ssecret * 100) / s.wbs.maxsecret;
            s.cnt_time = s.wbs.plyr[uint32(s.me)].stime / 35;
            s.cnt_par = s.wbs.partime / 35;
            s.sp_state = 10;
        }
        if (s.sp_state == 2) {
            s.cnt_kills[0] += 2;
            if (s.cnt_kills[0] >= (s.wbs.plyr[uint32(s.me)].skills * 100) / s.wbs.maxkills) {
                s.cnt_kills[0] = (s.wbs.plyr[uint32(s.me)].skills * 100) / s.wbs.maxkills;
                s.sp_state++;
            }
        } else if (s.sp_state == 4) {
            s.cnt_items[0] += 2;
            if (s.cnt_items[0] >= (s.wbs.plyr[uint32(s.me)].sitems * 100) / s.wbs.maxitems) {
                s.cnt_items[0] = (s.wbs.plyr[uint32(s.me)].sitems * 100) / s.wbs.maxitems;
                s.sp_state++;
            }
        } else if (s.sp_state == 6) {
            s.cnt_secret[0] += 2;
            if (s.cnt_secret[0] >= (s.wbs.plyr[uint32(s.me)].ssecret * 100) / s.wbs.maxsecret) {
                s.cnt_secret[0] = (s.wbs.plyr[uint32(s.me)].ssecret * 100) / s.wbs.maxsecret;
                s.sp_state++;
            }
        } else if (s.sp_state == 8) {
            s.cnt_time += 3;
            if (s.cnt_time >= s.wbs.plyr[uint32(s.me)].stime / 35) {
                s.cnt_time = s.wbs.plyr[uint32(s.me)].stime / 35;
            }
            s.cnt_par += 3;
            if (s.cnt_par >= s.wbs.partime / 35) {
                s.cnt_par = s.wbs.partime / 35;
                if (s.cnt_time >= s.wbs.plyr[uint32(s.me)].stime / 35) s.sp_state++;
            }
        } else if (s.sp_state == 10) {
            if (s.acceleratestage != 0) WI_initShowNextLoc(s, p);
        } else if ((s.sp_state & 1) != 0) {
            if (--s.cnt_pause == 0) {
                s.sp_state++;
                s.cnt_pause = 35;
            }
        }
    }

    function WI_initShowNextLoc(WiState memory s, WiInput memory p) internal pure {
        s.state = 1;
        s.acceleratestage = 0;
        s.cnt = 4 * 35;
        WI_initAnimatedBack(s, p);
    }

    function WI_updateShowNextLoc(WiState memory s) internal pure {
        WI_updateAnimatedBack(s);
        if (--s.cnt == 0 || s.acceleratestage != 0) WI_initNoState(s);
        else s.snl_pointeron = (s.cnt & 31) < 20;
    }

    function WI_initNoState(WiState memory s) internal pure {
        s.state = -1;
        s.acceleratestage = 0;
        s.cnt = 10;
    }

    function WI_updateNoState(WiState memory s) internal pure {
        WI_updateAnimatedBack(s);
        if (--s.cnt == 0) WI_End(s);
    }

    function WI_checkForAccelerate(WiState memory s, WiInput memory p) internal pure {
        for (uint256 i; i < 4; ++i) {
            if (p.playeringame[i]) {
                if ((p.buttons[i] & 1) != 0) {
                    if (p.attackdown[i] == 0) s.acceleratestage = 1;
                    p.attackdown[i] = 1;
                } else {
                    p.attackdown[i] = 0;
                }
                if ((p.buttons[i] & 2) != 0) {
                    if (p.usedown[i] == 0) s.acceleratestage = 1;
                    p.usedown[i] = 1;
                } else {
                    p.usedown[i] = 0;
                }
            }
        }
    }

    function WI_Ticker(WiState memory s, WiInput memory p) internal pure {
        _profile(p);
        _active(s);
        if (s.bcnt > type(int32).max - 12) revert UndefinedNativeDomain();
        s.bcnt++;
        WI_checkForAccelerate(s, p);
        if (s.state == 0) WI_updateStats(s, p);
        else if (s.state == 1) WI_updateShowNextLoc(s);
        else WI_updateNoState(s);
    }

    function WI_slamBackground(VideoState memory v) internal pure {
        // Same complete memcpy and dirty rectangle; existing bounded video copy.
        V.V_CopyRect(v, 0, 0, 1, 320, 200, 0, 0, 0);
    }

    function WI_drawLF(WiState memory s, WiGraphics memory a, VideoState memory v) internal pure {
        int32 y = 2;
        bytes memory title = a.lnames[uint32(s.wbs.last)];
        V.V_DrawPatch(v, (320 - _short(title, 0)) / 2, y, 0, title);
        y += (5 * _short(title, 2)) / 4;
        V.V_DrawPatch(v, (320 - _short(a.finished, 0)) / 2, y, 0, a.finished);
    }

    function WI_drawEL(WiState memory s, WiGraphics memory a, VideoState memory v) internal pure {
        int32 y = 2;
        V.V_DrawPatch(v, (320 - _short(a.entering, 0)) / 2, y, 0, a.entering);
        bytes memory title = a.lnames[uint32(s.wbs.next)];
        y += (5 * _short(title, 2)) / 4; // original uses next title height
        V.V_DrawPatch(v, (320 - _short(title, 0)) / 2, y, 0, title);
    }

    function WI_drawOnLnode(int32 n, bytes[] memory candidates, VideoState memory v) internal pure {
        if (n < 0 || n > 8 || candidates.length == 0 || candidates.length > 2) {
            revert UnsupportedIntermission();
        }
        int32[9] memory xs = [int32(185), 148, 69, 209, 116, 166, 71, 135, 71];
        int32[9] memory ys = [int32(164), 143, 122, 102, 89, 55, 56, 29, 24];
        uint256 i;
        bool fits;
        do {
            if (i >= candidates.length) revert UndefinedNativeDomain(); // &splat has one pointer in C
            int32 left = xs[uint32(n)] - _short(candidates[i], 4);
            int32 top = ys[uint32(n)] - _short(candidates[i], 6);
            int32 right = left + _short(candidates[i], 0);
            int32 bottom = top + _short(candidates[i], 2);
            if (left >= 0 && right < 320 && top >= 0 && bottom < 200) fits = true;
            else i++;
        } while (!fits && i != 2);
        if (fits && i < 2) V.V_DrawPatch(v, xs[uint32(n)], ys[uint32(n)], 0, candidates[i]);
        // Original printf on two failed candidates is non-graphical diagnostics only.
    }

    function WI_drawNum(WiGraphics memory a, VideoState memory v, int32 x, int32 y, int32 n, int32 digits)
        internal
        pure
        returns (int32)
    {
        int32 fontwidth = _short(a.num[0], 0);
        if (digits < 0) {
            if (n == 0) {
                digits = 1;
            } else {
                digits = 0;
                int32 temp = n;
                while (temp != 0) {
                    temp /= 10;
                    digits++;
                }
            }
        }
        bool neg = n < 0;
        if (n == type(int32).min) revert UndefinedNativeDomain();
        if (neg) n = -n;
        if (n == 1994) return 0;
        while (digits != 0) {
            digits--;
            x -= fontwidth;
            V.V_DrawPatch(v, x, y, 0, a.num[uint32(n % 10)]);
            n /= 10;
        }
        if (neg) {
            x -= 8;
            V.V_DrawPatch(v, x, y, 0, a.wiminus);
        }
        return x;
    }

    function WI_drawPercent(WiGraphics memory a, VideoState memory v, int32 x, int32 y, int32 p)
        internal
        pure
    {
        if (p < 0) return;
        V.V_DrawPatch(v, x, y, 0, a.percent);
        WI_drawNum(a, v, x, y, p, -1);
    }

    function WI_drawTime(WiGraphics memory a, VideoState memory v, int32 x, int32 y, int32 t) internal pure {
        if (t < 0) return;
        if (t <= 61 * 59) {
            int32 div = 1;
            do {
                int32 n = (t / div) % 60;
                x = WI_drawNum(a, v, x, y, n, 2) - _short(a.colon, 0);
                div *= 60;
                if (div == 60 || t / div != 0) V.V_DrawPatch(v, x, y, 0, a.colon);
            } while (t / div != 0);
        } else {
            V.V_DrawPatch(v, x - _short(a.sucks, 0), y, 0, a.sucks);
        }
    }

    function WI_drawStats(WiState memory s, WiGraphics memory a, VideoState memory v) internal pure {
        int32 lh = (3 * _short(a.num[0], 2)) / 2;
        WI_slamBackground(v);
        WI_drawAnimatedBack(s, a, v);
        WI_drawLF(s, a, v);
        V.V_DrawPatch(v, 50, 50, 0, a.kills);
        WI_drawPercent(a, v, 270, 50, s.cnt_kills[0]);
        V.V_DrawPatch(v, 50, 50 + lh, 0, a.items);
        WI_drawPercent(a, v, 270, 50 + lh, s.cnt_items[0]);
        V.V_DrawPatch(v, 50, 50 + 2 * lh, 0, a.sp_secret);
        WI_drawPercent(a, v, 270, 50 + 2 * lh, s.cnt_secret[0]);
        V.V_DrawPatch(v, 16, 168, 0, a.time);
        WI_drawTime(a, v, 144, 168, s.cnt_time);
        V.V_DrawPatch(v, 176, 168, 0, a.par);
        WI_drawTime(a, v, 304, 168, s.cnt_par);
    }

    function WI_drawShowNextLoc(WiState memory s, WiGraphics memory a, VideoState memory v) internal pure {
        WI_slamBackground(v);
        WI_drawAnimatedBack(s, a, v);
        int32 last = s.wbs.last == 8 ? s.wbs.next - 1 : s.wbs.last;
        bytes[] memory splats = new bytes[](1);
        splats[0] = a.splat;
        for (int32 i; i <= last; ++i) {
            WI_drawOnLnode(i, splats, v);
        }
        if (s.wbs.didsecret) WI_drawOnLnode(8, splats, v);
        if (s.snl_pointeron) {
            bytes[] memory yah = new bytes[](2);
            yah[0] = a.yah[0];
            yah[1] = a.yah[1];
            WI_drawOnLnode(s.wbs.next, yah, v);
        }
        WI_drawEL(s, a, v);
    }

    function WI_drawNoState(WiState memory s, WiGraphics memory a, VideoState memory v) internal pure {
        s.snl_pointeron = true;
        WI_drawShowNextLoc(s, a, v);
    }

    function WI_Drawer(WiState memory s, WiGraphics memory a, VideoState memory v) internal pure {
        // Original WI_End frees lnames. Drawing afterwards is outside its defined domain.
        _active(s);
        if (s.state == 0) WI_drawStats(s, a, v);
        else if (s.state == 1) WI_drawShowNextLoc(s, a, v);
        else WI_drawNoState(s, a, v);
    }
}
