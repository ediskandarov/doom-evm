// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;

import {ResourceView} from "./r_data_types.sol";
import {R_Data} from "./r_data.sol";
import {V_Video} from "./v_video.sol";
import {VideoState} from "./v_video_types.sol";
import {HU_Stuff} from "./hu_stuff.sol";
import {HU_Lib} from "./hu_lib.sol";

/// @dev Original globals/menu_t.lastOn; patch/font pointers are borrowed per draw.
struct MenuState {
    bool menuactive;
    bool extended;
    uint8 currentMenu; // MainDef=0, EpiDef=1, NewDef=2, SelectDef=3 (extension)
    int32 itemOn;
    int32[4] lastOn;
    int32 whichSkull;
    int32 skullAnimCounter;
    int32 selectedMap;
    int32 selectedSkill;
    bool startRequested;
    bool messageToPrint;
    bool directSelection;
}

/// @custom:source linuxdoom-1.10/m_menu.c, m_menu.h at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @dev Relevant original drawing/state functions. No renderer, palette expansion
/// or gameplay is delegated to the host. SelectDef is explicitly non-original.
library M_Menu {
    function M_Init(MenuState memory m, bool extended) internal pure {
        m.currentMenu = 0;
        m.menuactive = false;
        m.itemOn = 0;
        m.lastOn[2] = 2; // hurtme
        m.whichSkull = 0;
        m.skullAnimCounter = 10;
        m.messageToPrint = false;
        m.extended = extended;
        m.selectedMap = 1;
    }

    function M_Ticker(MenuState memory m) internal pure {
        if (--m.skullAnimCounter <= 0) {
            m.whichSkull ^= 1;
            m.skullAnimCounter = 8;
        }
    }

    function M_StartControlPanel(MenuState memory m) internal pure {
        if (m.menuactive) return;
        m.menuactive = true;
        m.currentMenu = 0;
        m.itemOn = m.lastOn[0];
    }

    function M_ClearMenus(MenuState memory m) internal pure {
        m.menuactive = false;
    }

    function M_SetupNextMenu(MenuState memory m, uint8 menu) internal pure {
        m.currentMenu = menu;
        m.itemOn = m.lastOn[menu];
    }

    function M_NewGame(MenuState memory m) internal pure {
        m.directSelection = false;
        m.selectedMap = 1;
        M_SetupNextMenu(m, 1);
    }

    function M_Episode(MenuState memory m, int32 choice) internal pure {
        // Other episodes are explicitly unsupported, never clamped to E1.
        if (choice != 0) return;
        M_SetupNextMenu(m, 2);
    }

    function M_VerifyNightmare(MenuState memory m, int32 ch) internal pure {
        if (ch != 121) return;
        m.selectedSkill = 4;
        m.startRequested = true;
        M_ClearMenus(m);
    }

    function M_ChooseSkill(MenuState memory m, int32 choice) internal pure {
        if (choice == 4) {
            m.messageToPrint = true;
            m.menuactive = true;
            return;
        }
        m.selectedSkill = choice;
        m.startRequested = true;
        M_ClearMenus(m);
    }

    function numitems(MenuState memory m) private pure returns (int32) {
        if (m.currentMenu == 0) return m.extended ? int32(2) : int32(6);
        if (m.currentMenu == 1) return m.extended ? int32(1) : int32(4);
        return m.currentMenu == 2 ? int32(5) : int32(9);
    }

    function alpha(MenuState memory m, int32 item) private pure returns (int32) {
        if (m.currentMenu == 0) {
            if (m.extended) return item == 0 ? int32(110) : int32(115);
            return int32(uint32(uint8(bytes("nolsrq")[uint32(item)])));
        }
        if (m.currentMenu == 1) return int32(uint32(uint8(bytes("ktit")[uint32(item)])));
        if (m.currentMenu == 2) return int32(uint32(uint8(bytes("ihhun")[uint32(item)])));
        return item + 49;
    }

    /// @custom:source m_menu.c M_Responder keyboard/menu branches, M_NewGame/M_Episode/M_ChooseSkill.
    /// @dev Audio and unsupported function-key/Save/Load/Options branches are absent.
    /// Original false returns are preserved here; production dispatch separately
    /// isolates all active-menu input from gameplay, including unknown keys/keyups.
    function M_Responder(MenuState memory m, int32 kind, int32 ch) internal pure returns (bool) {
        if (kind != 0) return false;
        if (m.messageToPrint) {
            if (ch != 32 && ch != 110 && ch != 121 && ch != 27) return false;
            m.messageToPrint = false;
            M_VerifyNightmare(m, ch);
            m.menuactive = false;
            return true;
        }
        if (!m.menuactive) {
            if (ch != 27) return false;
            M_StartControlPanel(m);
            return true;
        }
        if (ch == 175) { // KEY_DOWNARROW
            m.itemOn = m.itemOn + 1 > numitems(m) - 1 ? int32(0) : m.itemOn + 1;
            return true;
        }
        if (ch == 173) { // KEY_UPARROW
            m.itemOn = m.itemOn == 0 ? numitems(m) - 1 : m.itemOn - 1;
            return true;
        }
        if (ch == 172 || ch == 174) return true; // no status2 slider in supported menus
        if (ch == 13) {
            m.lastOn[m.currentMenu] = m.itemOn;
            if (m.currentMenu == 0) {
                if (m.itemOn == 0) M_NewGame(m);
                else if (m.extended && m.itemOn == 1) {
                    m.directSelection = true;
                    M_SetupNextMenu(m, 3);
                }
            } else if (m.currentMenu == 1) M_Episode(m, m.itemOn);
            else if (m.currentMenu == 2) M_ChooseSkill(m, m.itemOn);
            else {
                m.selectedMap = m.itemOn + 1;
                M_SetupNextMenu(m, 2);
            }
            return true;
        }
        if (ch == 27) {
            m.lastOn[m.currentMenu] = m.itemOn;
            M_ClearMenus(m);
            return true;
        }
        if (ch == 127) {
            m.lastOn[m.currentMenu] = m.itemOn;
            if (m.currentMenu != 0) {
                M_SetupNextMenu(m, m.currentMenu == 2 ? (m.directSelection ? uint8(3) : uint8(1)) : uint8(0));
            }
            return true;
        }
        for (int32 i = m.itemOn + 1; i < numitems(m); ++i) {
            if (alpha(m, i) == ch) { m.itemOn = i; return true; }
        }
        for (int32 i; i <= m.itemOn; ++i) {
            if (alpha(m, i) == ch) { m.itemOn = i; return true; }
        }
        return false;
    }

    function patch(ResourceView memory source, bytes8 name) private view returns (bytes memory) {
        return R_Data.W_CacheLumpNum(source, R_Data.W_GetNumForName(source, name));
    }

    function draw(ResourceView memory source, VideoState memory v, int32 x, int32 y, bytes8 name)
        private view
    {
        V_Video.V_DrawPatchDirect(v, x, y, 0, patch(source, name));
    }

    function M_DrawMainMenu(ResourceView memory source, VideoState memory v) internal view {
        draw(source, v, 94, 2, "M_DOOM");
    }

    function M_DrawNewGame(ResourceView memory source, VideoState memory v) internal view {
        draw(source, v, 96, 14, "M_NEWG");
        draw(source, v, 54, 38, "M_SKILL");
    }

    function M_DrawEpisode(ResourceView memory source, VideoState memory v) internal view {
        draw(source, v, 54, 38, "M_EPISOD");
    }

    /// @custom:source m_menu.c M_WriteText. Preserve uppercasing, widths, newline12 and right edge.
    function M_WriteText(VideoState memory v, bytes[] memory font, int32 x, int32 y, bytes memory text)
        internal pure
    {
        int32 cx = x;
        int32 cy = y;
        for (uint256 i; i < text.length; ++i) {
            int32 c = int32(uint32(uint8(text[i])));
            if (c == 0) break;
            if (c == 10) { cx = x; cy += 12; continue; }
            if (c >= 97 && c <= 122) c -= 32;
            c -= 33;
            if (c < 0 || c >= 63) { cx += 4; continue; }
            int32 w = HU_Lib.patchShort(font[uint32(c)], 0);
            if (cx + w > 320) break;
            V_Video.V_DrawPatchDirect(v, cx, cy, 0, font[uint32(c)]);
            cx += w;
        }
    }

    function M_StringWidth(bytes[] memory font, bytes memory text) internal pure returns (int32 width) {
        for (uint256 i; i < text.length && text[i] != 0; ++i) {
            int32 c = int32(uint32(uint8(text[i])));
            if (c >= 97 && c <= 122) c -= 32;
            c -= 33;
            width += c < 0 || c >= 63 ? int32(4) : HU_Lib.patchShort(font[uint32(c)], 0);
        }
    }

    function nightmareMessage() internal pure returns (bytes memory) {
        return bytes("are you sure? this skill level\nisn't even remotely fair.\n\npress y or n.");
    }

    function itemName(uint8 menu, int32 item) internal pure returns (bytes8) {
        if (menu == 0) {
            if (item == 0) return "M_NGAME";
            if (item == 1) return "M_OPTION";
            if (item == 2) return "M_LOADG";
            if (item == 3) return "M_SAVEG";
            if (item == 4) return "M_RDTHIS";
            return "M_QUITG";
        }
        if (menu == 1) {
            if (item == 0) return "M_EPI1";
            if (item == 1) return "M_EPI2";
            if (item == 2) return "M_EPI3";
            return "M_EPI4";
        }
        if (item == 0) return "M_JKILL";
        if (item == 1) return "M_ROUGH";
        if (item == 2) return "M_HURT";
        if (item == 3) return "M_ULTRA";
        return "M_NMARE";
    }

    /// @custom:source m_menu.c M_Drawer; D_PageDrawer supplies TITLEPIC before the menu.
    /// @dev Caller supplies the current gameplay screen or a title page. The original
    /// menu is an overlay, with the same patches, coordinates and skull highlighting.
    function M_Drawer(MenuState memory m, ResourceView memory source, bytes memory pixels) internal view {
        VideoState memory v;
        v.screens[0] = pixels;
        if (!m.menuactive && !m.messageToPrint) return;
        bytes[] memory font;
        if (m.messageToPrint || m.extended) font = HU_Stuff.HU_Init(source);
        if (m.messageToPrint) {
            bytes memory message = nightmareMessage();
            int32 height = HU_Lib.patchShort(font[0], 2);
            int32 y = 100 - height * 4 / 2;
            uint256 start;
            for (uint256 end; end <= message.length; ++end) {
                if (end != message.length && message[end] != 0x0a) continue;
                bytes memory line = new bytes(end - start);
                for (uint256 i; i < line.length; ++i) line[i] = message[start + i];
                M_WriteText(v, font, 160 - M_StringWidth(font, line) / 2, y, line);
                y += height;
                start = end + 1;
            }
            return;
        }
        int32 x = m.currentMenu == 0 ? int32(97) : int32(48);
        int32 y = m.currentMenu == 0 ? int32(64) : int32(63);
        int32 max = m.currentMenu == 0 ? int32(6) : m.currentMenu == 1 ? int32(4) : int32(5);
        if (m.currentMenu == 0) M_DrawMainMenu(source, v);
        else if (m.currentMenu == 1) M_DrawEpisode(source, v);
        else if (m.currentMenu == 2) M_DrawNewGame(source, v);
        // Supported production rows only. Original complete graphics remain
        // available for isolated unmodified drawing checkpoints (extended=false).
        if (m.extended && m.currentMenu == 0) max = 2;
        if (m.extended && m.currentMenu == 1) max = 1;
        if (m.currentMenu == 3) {
            x = 80; y = 48; max = 9;
            M_WriteText(v, font, 80, 24, bytes("SELECT LEVEL"));
        }
        for (int32 i; i < max; ++i) {
            if (m.currentMenu == 3) {
                M_WriteText(v, font, x, y + i * 16, abi.encodePacked("E1M", bytes1(uint8(uint32(i) + 49))));
            } else if (m.extended && m.currentMenu == 0 && i == 1) {
                M_WriteText(v, font, x, y + i * 16, bytes("SELECT LEVEL"));
            } else draw(source, v, x, y + i * 16, itemName(m.currentMenu, i));
        }
        draw(source, v, x - 32, y - 5 + m.itemOn * 16, m.whichSkull == 0 ? bytes8("M_SKULL1") : bytes8("M_SKULL2"));
    }

    function title(ResourceView memory source) internal view returns (bytes memory pixels) {
        pixels = new bytes(64000);
        VideoState memory v;
        v.screens[0] = pixels;
        draw(source, v, 0, 0, "TITLEPIC");
    }
}
