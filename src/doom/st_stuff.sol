// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;

import {ST_Lib as L, STNumber, STPercent, STMultIcon, STBinIcon} from "./st_lib.sol";
import {V_Video as V} from "./v_video.sol";
import {VideoState} from "./v_video_types.sol";
import {GameState, GameDefinitions, GameConst, Player, Mobj} from "./p_game_state.sol";
import {M_Random} from "./m_random.sol";
import {R_Main} from "./r_main.sol";
import {RenderState} from "./r_state.sol";
import {ResourceView} from "./r_data_types.sol";
import {R_Data} from "./r_data.sol";

struct STGraphics {
    bytes sbar;
    bytes[] tallnum;
    bytes tallpercent;
    bytes[] shortnum;
    bytes[] keys;
    bytes[] faces;
    bytes faceback;
    bytes armsbg;
    bytes[][6] arms;
    bytes sttminus;
    bytes playpal;
}

// Consumer-owned context: retain between tics/draws and across level restarts.
// In particular C function statics priority/lastattackdown/pain cache and the
// global facecount are NOT reset by ST_Start.
struct STState {
    bool initialized;
    bool st_stopped;
    bool st_firsttime;
    bool st_statusbaron;
    bool st_chat;
    bool st_oldchat;
    bool st_cursoron;
    bool st_notdeathmatch;
    bool st_armson;
    bool st_fragson;
    int32 st_chatstate;
    int32 st_gamestate;
    int32 st_msgcounter;
    uint32 st_clock;
    uint32 player;
    int32 st_fragscount;
    int32 st_oldhealth;
    bool[9] oldweaponsowned;
    int32 st_facecount;
    int32 st_faceindex;
    int32[3] keyboxes;
    int32 st_randomnumber;
    int32 priority;
    int32 lastattackdown;
    int32 painOldhealth;
    int32 lastcalc;
    int32 st_palette;
    bytes paletteRGB;
    uint32 paletteRevision;
    uint8 usegamma;
    int32 readyammo;
    STNumber w_ready;
    STNumber w_frags;
    STPercent w_health;
    STPercent w_armor;
    STBinIcon w_armsbg;
    STMultIcon[6] w_arms;
    STMultIcon w_faces;
    STMultIcon[3] w_keyboxes;
    STNumber[4] w_ammo;
    STNumber[4] w_maxammo;
}

/// @custom:source linuxdoom-1.10/st_stuff.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
library ST_Stuff {
    error StatusDomain();

    function ST_Init(
        STState memory s,
        VideoState memory v,
        STGraphics memory a,
        ResourceView memory source,
        uint32 consoleplayer
    ) internal view {
        ST_loadData(a, source, consoleplayer);
        v.screens[4] = new bytes(320 * 32);
        // C static initializers, once per engine lifetime, not once per level.
        if (!s.initialized) {
            s.initialized = true;
            s.st_stopped = true;
            s.st_oldhealth = -1;
            s.lastattackdown = -1;
            s.painOldhealth = -1;
        }
    }

    function _load(ResourceView memory r, bytes8 name) private view returns (bytes memory) {
        return R_Data.W_CacheLumpNum(r, R_Data.W_GetNumForName(r, name));
    }

    function _digit(uint256 i) private pure returns (bytes1) {
        return bytes1(uint8(48 + i));
    }

    function ST_loadData(STGraphics memory a, ResourceView memory r, uint32 consoleplayer) internal view {
        a.playpal = _load(r, "PLAYPAL");
        ST_loadGraphics(a, r, consoleplayer);
    }

    function ST_loadGraphics(STGraphics memory a, ResourceView memory r, uint32 consoleplayer) internal view {
        if (consoleplayer >= 4) revert StatusDomain();
        a.tallnum = new bytes[](10);
        a.shortnum = new bytes[](10);
        for (uint256 i; i < 10; ++i) {
            a.tallnum[i] = _load(r, bytes8(abi.encodePacked("STTNUM", _digit(i))));
            a.shortnum[i] = _load(r, bytes8(abi.encodePacked("STYSNUM", _digit(i))));
        }
        a.tallpercent = _load(r, "STTPRCNT");
        a.keys = new bytes[](6);
        for (uint256 i; i < 6; ++i) {
            a.keys[i] = _load(r, bytes8(abi.encodePacked("STKEYS", _digit(i))));
        }
        a.armsbg = _load(r, "STARMS");
        for (uint256 i; i < 6; ++i) {
            a.arms[i] = new bytes[](2);
            a.arms[i][0] = _load(r, bytes8(abi.encodePacked("STGNUM", _digit(i + 2))));
            a.arms[i][1] = a.shortnum[i + 2];
        }
        a.faceback = _load(r, bytes8(abi.encodePacked("STFB", _digit(consoleplayer))));
        a.sbar = _load(r, "STBAR");
        a.faces = new bytes[](42);
        uint256 f;
        for (uint256 i; i < 5; ++i) {
            for (uint256 j; j < 3; ++j) {
                a.faces[f++] = _load(r, bytes8(abi.encodePacked("STFST", _digit(i), _digit(j))));
            }
            a.faces[f++] = _load(r, bytes8(abi.encodePacked("STFTR", _digit(i), "0")));
            a.faces[f++] = _load(r, bytes8(abi.encodePacked("STFTL", _digit(i), "0")));
            a.faces[f++] = _load(r, bytes8(abi.encodePacked("STFOUCH", _digit(i))));
            a.faces[f++] = _load(r, bytes8(abi.encodePacked("STFEVL", _digit(i))));
            a.faces[f++] = _load(r, bytes8(abi.encodePacked("STFKILL", _digit(i))));
        }
        a.faces[f++] = _load(r, "STFGOD0");
        a.faces[f] = _load(r, "STFDEAD0");
        a.sttminus = L.STlib_init(r);
    }

    function ST_initData(STState memory s, GameState memory g) internal pure {
        if (!s.initialized || g.consoleplayer < 0 || g.consoleplayer >= 4) revert StatusDomain();
        s.player = uint32(g.consoleplayer);
        s.st_firsttime = true;
        s.st_clock = 0;
        s.st_chatstate = 0;
        s.st_gamestate = 1;
        s.st_statusbaron = true;
        s.st_oldchat = false;
        s.st_chat = false;
        s.st_cursoron = false;
        s.st_faceindex = 0;
        s.st_palette = -1;
        s.st_oldhealth = -1;
        for (uint256 i; i < 9; ++i) {
            s.oldweaponsowned[i] = g.players[s.player].weaponowned[i];
        }
        for (uint256 i; i < 3; ++i) {
            s.keyboxes[i] = -1;
        }
    }

    function ST_createWidgets(
        STState memory s,
        STGraphics memory a,
        Player memory p,
        GameDefinitions memory d
    ) internal pure {
        L.STlib_initNum(s.w_ready, 44, 171, a.tallnum, 3);
        s.w_ready.data = int32(p.readyweapon);
        // Original takes an out-of-bounds ammo pointer for a no-ammo weapon
        // until the first ticker. Resolve that sentinel safely at creation too.
        s.readyammo = _readyAmmo(p, d);
        L.STlib_initPercent(s.w_health, 90, 171, a.tallnum, a.tallpercent);
        L.STlib_initBinIcon(s.w_armsbg, 104, 168, a.armsbg);
        for (uint256 i; i < 6; ++i) {
            L.STlib_initMultIcon(
                s.w_arms[i], 111 + int32(uint32(i % 3)) * 12, 172 + int32(uint32(i / 3)) * 10, a.arms[i]
            );
        }
        L.STlib_initNum(s.w_frags, 138, 171, a.tallnum, 2);
        L.STlib_initMultIcon(s.w_faces, 143, 168, a.faces);
        L.STlib_initPercent(s.w_armor, 221, 171, a.tallnum, a.tallpercent);
        for (uint256 i; i < 3; ++i) {
            L.STlib_initMultIcon(s.w_keyboxes[i], 239, 171 + int32(uint32(i)) * 10, a.keys);
        }
        int32[4] memory y = [int32(173), 179, 191, 185];
        for (uint256 i; i < 4; ++i) {
            L.STlib_initNum(s.w_ammo[i], 288, y[i], a.shortnum, 3);
            L.STlib_initNum(s.w_maxammo[i], 314, y[i], a.shortnum, 3);
        }
    }

    function ST_Start(STState memory s, STGraphics memory a, GameState memory g, GameDefinitions memory d)
        internal
        pure
    {
        if (!s.st_stopped) ST_Stop(s, a);
        ST_initData(s, g);
        ST_createWidgets(s, a, g.players[s.player], d);
        s.st_stopped = false;
    }

    function ST_Stop(STState memory s, STGraphics memory a) internal pure {
        if (s.st_stopped) return;
        _setPalette(s, a.playpal, 0);
        s.st_stopped = true;
        // Original does not reset st_palette here.
    }

    function ST_calcPainOffset(STState memory s, Player memory p) internal pure returns (int32) {
        int32 health = p.health > 100 ? int32(100) : p.health;
        if (health != s.painOldhealth) {
            s.lastcalc = 8 * (((100 - health) * 5) / 101);
            s.painOldhealth = health;
        }
        return s.lastcalc;
    }

    function ST_updateFaceWidget(STState memory s, GameState memory g) internal pure {
        Player memory p = g.players[s.player];
        if (s.priority < 10 && p.health == 0) {
            s.priority = 9;
            s.st_faceindex = 41;
            s.st_facecount = 1;
        }
        if (s.priority < 9 && p.bonuscount != 0) {
            bool grin;
            for (uint256 i; i < 9; ++i) {
                if (s.oldweaponsowned[i] != p.weaponowned[i]) {
                    grin = true;
                    s.oldweaponsowned[i] = p.weaponowned[i];
                }
            }
            if (grin) {
                s.priority = 8;
                s.st_facecount = 70;
                s.st_faceindex = ST_calcPainOffset(s, p) + 6;
            }
        }
        if (s.priority < 8 && p.damagecount != 0 && p.attacker != GameConst.NULL && p.attacker != p.mo) {
            s.priority = 7;
            // Preserve the original reversed subtraction (including its ouch bug).
            if (p.health - s.st_oldhealth > 20) {
                s.st_facecount = 35;
                s.st_faceindex = ST_calcPainOffset(s, p) + 5;
            } else {
                Mobj memory mo = g.mobjs[p.mo];
                Mobj memory attacker = g.mobjs[p.attacker];
                RenderState memory rs;
                uint32 angle = R_Main.R_PointToAngle2(rs, mo.x, mo.y, attacker.x, attacker.y);
                uint32 diff;
                bool right;
                if (angle > mo.angle) {
                    diff = angle - mo.angle;
                    right = diff > 0x80000000;
                } else {
                    diff = mo.angle - angle;
                    right = diff <= 0x80000000;
                }
                s.st_facecount = 35;
                s.st_faceindex = ST_calcPainOffset(s, p);
                if (diff < 0x20000000) s.st_faceindex += 7;
                else if (right) s.st_faceindex += 3;
                else s.st_faceindex += 4;
            }
        }
        if (s.priority < 7 && p.damagecount != 0) {
            if (p.health - s.st_oldhealth > 20) {
                s.priority = 7;
                s.st_faceindex = ST_calcPainOffset(s, p) + 5;
            } else {
                s.priority = 6;
                s.st_faceindex = ST_calcPainOffset(s, p) + 7;
            }
            s.st_facecount = 35;
        }
        if (s.priority < 6) {
            if (p.attackdown != 0) {
                if (s.lastattackdown == -1) {
                    s.lastattackdown = 70;
                } else if (--s.lastattackdown == 0) {
                    s.priority = 5;
                    s.st_faceindex = ST_calcPainOffset(s, p) + 7;
                    s.st_facecount = 1;
                    s.lastattackdown = 1;
                }
            } else {
                s.lastattackdown = -1;
            }
        }
        if (s.priority < 5 && ((p.cheats & 2) != 0 || p.powers[0] != 0)) {
            s.priority = 4;
            s.st_faceindex = 40;
            s.st_facecount = 1;
        }
        if (s.st_facecount == 0) {
            s.st_faceindex = ST_calcPainOffset(s, p) + (s.st_randomnumber % 3);
            s.st_facecount = 17;
            s.priority = 0;
        }
        --s.st_facecount;
    }

    function _readyAmmo(Player memory p, GameDefinitions memory d) private pure returns (int32) {
        int32 ammo = d.weaponinfo[p.readyweapon].ammo;
        return ammo == 5 ? int32(1994) : p.ammo[uint32(ammo)];
    }

    function ST_updateWidgets(STState memory s, GameState memory g, GameDefinitions memory d) internal pure {
        Player memory p = g.players[s.player];
        s.readyammo = _readyAmmo(p, d);
        s.w_ready.data = int32(p.readyweapon);
        for (uint256 i; i < 3; ++i) {
            s.keyboxes[i] = p.cards[i] ? int32(uint32(i)) : int32(-1);
            if (p.cards[i + 3]) s.keyboxes[i] = int32(uint32(i + 3));
        }
        ST_updateFaceWidget(s, g);
        s.st_notdeathmatch = g.deathmatch == 0;
        s.st_armson = s.st_statusbaron && g.deathmatch == 0;
        s.st_fragson = g.deathmatch != 0 && s.st_statusbaron;
        s.st_fragscount = 0;
        unchecked {
            for (uint256 i; i < 4; ++i) {
                if (i != uint32(g.consoleplayer)) s.st_fragscount += p.frags[i];
                else s.st_fragscount -= p.frags[i];
            }
            if (--s.st_msgcounter == 0) s.st_chat = s.st_oldchat;
        }
    }

    function ST_Ticker(STState memory s, GameState memory g, GameDefinitions memory d) internal pure {
        unchecked {
            ++s.st_clock;
        }
        s.st_randomnumber = M_Random.M_RandomValue(g);
        ST_updateWidgets(s, g, d);
        s.st_oldhealth = g.players[s.player].health;
    }

    function ST_doPaletteStuff(STState memory s, STGraphics memory a, Player memory p) internal pure {
        int32 palette;
        int32 cnt = p.damagecount;
        if (p.powers[1] != 0) {
            int32 bzc = 12 - (p.powers[1] >> 6);
            if (bzc > cnt) cnt = bzc;
        }
        if (cnt != 0) {
            palette = (cnt + 7) >> 3;
            if (palette >= 8) palette = 7;
            palette += 1;
        } else if (p.bonuscount != 0) {
            palette = (p.bonuscount + 7) >> 3;
            if (palette >= 4) palette = 3;
            palette += 9;
        } else if (p.powers[3] > 128 || (p.powers[3] & 8) != 0) {
            palette = 13;
        }
        if (palette != s.st_palette) {
            s.st_palette = palette;
            _setPalette(s, a.playpal, palette);
        }
    }

    /// @dev D_Display restores PLAYPAL outside GS_LEVEL without changing st_palette.
    function ST_BasePalette(STState memory s, bytes memory playpal) internal pure {
        _setPalette(s, playpal, 0);
    }

    function _setPalette(STState memory s, bytes memory playpal, int32 palette) private pure {
        if (palette < 0 || uint32(palette) * 768 + 768 > playpal.length || s.usegamma > 4) {
            revert StatusDomain();
        }
        bytes memory gamma = _gamma(s.usegamma);
        s.paletteRGB = new bytes(768);
        for (uint256 i; i < 768; ++i) {
            s.paletteRGB[i] = gamma[uint8(playpal[uint32(palette) * 768 + i])];
        }
        unchecked {
            ++s.paletteRevision;
        }
    }

    function ST_refreshBackground(STState memory s, STGraphics memory a, VideoState memory v, bool netgame)
        internal
        pure
    {
        if (s.st_statusbaron) {
            V.V_DrawPatch(v, 0, 0, 4, a.sbar);
            if (netgame) V.V_DrawPatch(v, 143, 0, 4, a.faceback);
            V.V_CopyRect(v, 0, 0, 4, 320, 32, 0, 168, 0);
        }
    }

    function ST_drawWidgets(
        STState memory s,
        STGraphics memory a,
        VideoState memory v,
        GameState memory g,
        GameDefinitions memory d,
        bool refresh
    ) internal pure {
        Player memory p = g.players[s.player];
        s.st_armson = s.st_statusbaron && g.deathmatch == 0;
        s.st_fragson = g.deathmatch != 0 && s.st_statusbaron;
        // This is a live C pointer: ammo changes between ticker and drawer are visible.
        int32 ammoType = d.weaponinfo[uint32(s.w_ready.data)].ammo;
        int32 ready = ammoType == 5 ? int32(1994) : p.ammo[uint32(ammoType)];
        L.STlib_updateNum(v, s.w_ready, ready, s.st_statusbaron, refresh, a.sttminus);
        for (uint256 i; i < 4; ++i) {
            L.STlib_updateNum(v, s.w_ammo[i], p.ammo[i], s.st_statusbaron, refresh, a.sttminus);
            L.STlib_updateNum(v, s.w_maxammo[i], p.maxammo[i], s.st_statusbaron, refresh, a.sttminus);
        }
        L.STlib_updatePercent(v, s.w_health, p.health, s.st_statusbaron, refresh, a.sttminus);
        L.STlib_updatePercent(v, s.w_armor, p.armorpoints, s.st_statusbaron, refresh, a.sttminus);
        L.STlib_updateBinIcon(v, s.w_armsbg, s.st_notdeathmatch, s.st_statusbaron, refresh);
        for (uint256 i; i < 6; ++i) {
            L.STlib_updateMultIcon(
                v, s.w_arms[i], p.weaponowned[i + 1] ? int32(1) : int32(0), s.st_armson, refresh
            );
        }
        L.STlib_updateMultIcon(v, s.w_faces, s.st_faceindex, s.st_statusbaron, refresh);
        for (uint256 i; i < 3; ++i) {
            L.STlib_updateMultIcon(v, s.w_keyboxes[i], s.keyboxes[i], s.st_statusbaron, refresh);
        }
        L.STlib_updateNum(v, s.w_frags, s.st_fragscount, s.st_fragson, refresh, a.sttminus);
    }

    function ST_doRefresh(
        STState memory s,
        STGraphics memory a,
        VideoState memory v,
        GameState memory g,
        GameDefinitions memory d
    ) internal pure {
        s.st_firsttime = false;
        ST_refreshBackground(s, a, v, g.netgame);
        ST_drawWidgets(s, a, v, g, d, true);
    }

    function ST_diffDraw(
        STState memory s,
        STGraphics memory a,
        VideoState memory v,
        GameState memory g,
        GameDefinitions memory d
    ) internal pure {
        ST_drawWidgets(s, a, v, g, d, false);
    }

    function ST_Drawer(
        STState memory s,
        STGraphics memory a,
        VideoState memory v,
        GameState memory g,
        GameDefinitions memory d,
        bool fullscreen,
        bool refresh,
        bool automapactive
    ) internal pure {
        s.st_statusbaron = !fullscreen || automapactive;
        s.st_firsttime = s.st_firsttime || refresh;
        ST_doPaletteStuff(s, a, g.players[s.player]);
        if (s.st_firsttime) ST_doRefresh(s, a, v, g, d);
        else ST_diffDraw(s, a, v, g, d);
    }

    // Status-bar portion of ST_Responder. Cheat parsing is Goal 4.4; gameflow is Goal 4.6.
    function ST_Responder(STState memory s, int32 eventType, int32 data1) internal pure returns (bool) {
        if (eventType == 1 && (uint32(data1) & 0xffff0000) == 0x616d0000) {
            if (uint32(data1) == 0x616d6500) {
                s.st_gamestate = 0;
                s.st_firsttime = true;
            } else if (uint32(data1) == 0x616d7800) {
                s.st_gamestate = 1;
            }
        }
        return false;
    }

    // Original v_video.c gammatable, generated verbatim; I_SetPalette's X11
    // 16-bit (c<<8)+c channels have the same 8-bit RGB components returned here.
    function _gamma(uint8 level) private pure returns (bytes memory) {
        // Generated below from the pinned C table, no approximation.
        if (level == 0) {
            return hex"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f80808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6e7e8e9eaebecedeeeff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff";
        }
        if (level == 1) {
            return hex"02040507080a0b0c0e0f10121314151718191a1b1d1e1f2021222425262728292a2c2d2e2f3031323334363738393a3b3c3d3e3f4041424345464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f80818182838485868788898a8b8c8d8e8f90919293949495969798999a9b9c9d9e9fa0a1a2a3a3a4a5a6a7a8a9aaabacadaeafafb0b1b2b3b4b5b6b7b8b9bababbbcbdbebfc0c1c2c3c4c4c5c6c7c8c9cacbcccdcdcecfd0d1d2d3d4d5d6d6d7d8d9dadbdcdddededfe0e1e2e3e4e5e6e6e7e8e9eaebecededeeeff0f1f2f3f4f5f5f6f7f8f9fafbfcfcfdfeff";
        }
        if (level == 2) {
            return hex"0407090b0d0f11131516181a1b1d1e202123242627282a2b2d2e2f30323334363738393b3c3d3e3f41424344454648494a4b4c4d4e4f5052535455565758595a5b5c5d5e5f6061626465666768696a6b6c6d6e6f70717272737475767778797a7b7c7d7e7f80818283848585868788898a8b8c8d8e8f9090919293949596979899999a9b9c9d9e9fa0a0a1a2a3a4a5a6a6a7a8a9aaabacacadaeafb0b1b2b2b3b4b5b6b7b7b8b9babbbcbcbdbebfc0c1c1c2c3c4c5c5c6c7c8c9c9cacbcccdcececfd0d1d2d2d3d4d5d5d6d7d8d9d9dadbdcdddddedfe0e0e1e2e3e4e4e5e6e7e7e8e9eaebebecedeeeeeff0f1f1f2f3f4f4f5f6f7f7f8f9fafbfbfcfdfefeff";
        }
        if (level == 3) {
            return hex"080c101316181b1d1f22242628292b2d2f3132343537393a3c3d3f404143444647484a4b4c4d4f50515254555657585a5b5c5d5e5f6062636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f80818283848586878788898a8b8c8d8e8f8f90919293949596969798999a9b9b9c9d9e9fa0a0a1a2a3a4a5a5a6a7a8a9a9aaabacadadaeafb0b0b1b2b3b4b4b5b6b7b7b8b9bababbbcbdbdbebfc0c0c1c2c3c3c4c5c5c6c7c8c8c9cacacbcccdcdcecfcfd0d1d2d2d3d4d4d5d6d6d7d8d8d9dadbdbdcdddddedfdfe0e1e1e2e3e3e4e5e5e6e7e7e8e9e9eaebebecededeeeeeff0f0f1f2f2f3f4f4f5f6f6f7f7f8f9f9fafbfbfcfdfdfefeff";
        }
        if (level == 4) {
            return hex"10171c2024272a2d30323537393c3e4042444547494b4c4e505153545657595a5c5d5e60616264656667696a6b6c6d6e707172737475767778797a7b7c7d7e80808182838485868788898a8b8c8d8e8f8f90919293949596969798999a9b9b9c9d9e9f9fa0a1a2a3a3a4a5a6a6a7a8a9a9aaabacacadaeafafb0b1b1b2b3b4b4b5b6b6b7b8b8b9babbbbbcbdbdbebfbfc0c1c1c2c3c3c4c4c5c6c6c7c8c8c9cacacbcbcccdcdcecfcfd0d0d1d2d2d3d3d4d5d5d6d6d7d8d8d9d9dadbdbdcdcdddddedfdfe0e0e1e1e2e3e3e4e4e5e5e6e6e7e8e8e9e9eaeaebebececededeeefeff0f0f1f1f2f2f3f3f4f4f5f5f6f6f7f7f8f8f9f9fafafbfbfcfcfdfefeffff";
        }
        revert StatusDomain();
    }
}
