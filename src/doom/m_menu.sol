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
    uint8 currentMenu; // Main=0, Episode=1, Skill=2, Select=3, Options=4, Load=5, Save=6
    int32 itemOn;
    int32[7] lastOn;
    int32 whichSkull;
    int32 skullAnimCounter;
    int32 selectedMap;
    int32 selectedSkill;
    bool startRequested;
    bool messageToPrint;
    bool directSelection;
    bool showMessages;
    int32 screenSize; // original screenblocks - 3; production supports 7/8 only
    bool usergame;
    bool messagesChanged;
    bool endRequested;
    uint8 messageKind; // 0 Nightmare, 1 End Game
    bool commercial; // Explicit DOOM II adapter selection; default Episode One remains unchanged.
    bool savesEnabled; // explicit production capability; retained historical menu fixtures stay unchanged
    bool canSave;
    bool saveStringEnter;
    uint8 saveAction; // 0 none, 1 save, 2 load; consumed at the adapter control boundary
    uint8 saveSlot;
    bytes saveDescription;
    bytes saveOldString;
    bytes[6] savegamestrings;
    bool[6] saveOccupied;
    uint64[6] saveRevisions;
    uint8[63] saveFontWidths; // immutable font metrics, not borrowed patch data
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
        m.showMessages = true;
        m.screenSize = 7;
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
        M_SetupNextMenu(m, m.commercial ? uint8(2) : uint8(1));
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
            m.messageKind = 0;
            m.messageToPrint = true;
            m.menuactive = true;
            return;
        }
        m.selectedSkill = choice;
        m.startRequested = true;
        M_ClearMenus(m);
    }

    function M_Options(MenuState memory m) internal pure {
        M_SetupNextMenu(m, 4);
    }

    /// @custom:source m_menu.c M_ChangeMessages; caller applies player.message and HUD force flag.
    function M_ChangeMessages(MenuState memory m) internal pure {
        m.showMessages = !m.showMessages;
        m.messagesChanged = true;
    }

    /// @custom:source m_menu.c M_SizeDisplay.
    /// @dev Original bounds 0..8; production restricts to existing blocks10/11.
    function M_SizeDisplay(MenuState memory m, int32 choice) internal pure {
        if (choice == 0) {
            if (m.screenSize > (m.extended ? int32(7) : int32(0))) --m.screenSize;
        } else if (choice == 1 && m.screenSize < 8) {
            ++m.screenSize;
        }
    }

    function M_EndGame(MenuState memory m) internal pure {
        if (!m.usergame) return;
        m.messageKind = 1;
        m.messageToPrint = true;
        m.menuactive = true;
    }

    function M_EndGameResponse(MenuState memory m, int32 ch) internal pure {
        if (ch != 121) return;
        m.lastOn[m.currentMenu] = m.itemOn;
        M_ClearMenus(m);
        m.endRequested = true;
    }

    /// @custom:source m_menu.c M_ReadSaveStrings; EVM slot metadata replaces file headers.
    function M_ReadSaveStrings(
        MenuState memory m,
        uint8 slot,
        bytes memory description,
        bool occupied,
        uint64 revision
    ) internal pure {
        m.savegamestrings[slot] = occupied ? description : bytes("EMPTY SLOT");
        m.saveOccupied[slot] = occupied;
        m.saveRevisions[slot] = revision;
    }

    function M_LoadSaveFont(MenuState memory m, ResourceView memory source) internal view {
        if (m.saveFontWidths[0] != 0) return;
        bytes[] memory font = HU_Stuff.HU_Init(source);
        for (uint256 i; i < 63; ++i) {
            m.saveFontWidths[i] = uint8(uint32(HU_Lib.patchShort(font[i], 0)));
        }
    }

    /// @custom:source m_menu.c M_SaveGame/M_LoadGame/M_SaveSelect/M_LoadSelect/M_DoSave.
    function M_SaveGame(MenuState memory m) internal pure {
        if (!m.usergame || !m.canSave) return;
        M_SetupNextMenu(m, 6);
    }

    function M_LoadGame(MenuState memory m) internal pure {
        M_SetupNextMenu(m, 5);
        if (!m.saveOccupied[uint32(m.itemOn)]) {
            for (uint8 i; i < 6; ++i) {
                if (m.saveOccupied[i]) {
                    m.itemOn = int32(uint32(i));
                    break;
                }
            }
        }
    }

    function M_SaveSelect(MenuState memory m) internal pure {
        m.saveSlot = uint8(uint32(m.itemOn));
        m.saveOldString = m.savegamestrings[m.saveSlot];
        m.saveDescription = m.saveOccupied[m.saveSlot] ? m.saveOldString : bytes("");
        m.saveStringEnter = true;
    }

    function saveWidth(MenuState memory m, bytes memory text) private pure returns (uint256 w) {
        for (uint256 i; i < text.length; ++i) {
            uint8 ch = uint8(text[i]);
            w += ch < 33 || ch > 95 ? 4 : m.saveFontWidths[ch - 33];
        }
    }

    function M_ValidateSaveDescription(MenuState memory m, bytes memory text)
        internal
        pure
        returns (bytes memory result)
    {
        require(text.length > 0 && text.length < 24, "save description length");
        result = new bytes(text.length);
        uint256 width;
        for (uint256 i; i < text.length; ++i) {
            uint8 ch = uint8(text[i]);
            if (ch >= 97 && ch <= 122) ch -= 32;
            require(ch >= 32 && ch <= 95 && width < 176, "save description glyph/width");
            result[i] = bytes1(ch);
            width += ch == 32 ? 4 : m.saveFontWidths[ch - 33];
        }
    }

    function saveResponder(MenuState memory m, int32 ch) private pure returns (bool) {
        if (ch == 127) {
            if (m.saveDescription.length != 0) {
                bytes memory cut = new bytes(m.saveDescription.length - 1);
                for (uint256 i; i < cut.length; ++i) {
                    cut[i] = m.saveDescription[i];
                }
                m.saveDescription = cut;
            }
        } else if (ch == 27) {
            m.saveStringEnter = false;
            m.saveDescription = m.saveOldString;
        } else if (ch == 13) {
            m.saveStringEnter = false;
            if (m.saveDescription.length != 0) {
                m.saveAction = 1;
                M_ClearMenus(m);
            }
        } else {
            if (ch >= 97 && ch <= 122) ch -= 32;
            if (
                ch >= 32 && ch <= 95 && m.saveDescription.length < 23 && saveWidth(m, m.saveDescription) < 176
            ) {
                m.saveDescription = bytes.concat(m.saveDescription, bytes1(uint8(uint32(ch))));
            }
        }
        return true;
    }

    function numitems(MenuState memory m) private pure returns (int32) {
        if (m.currentMenu == 0) return m.extended ? (m.savesEnabled ? int32(5) : int32(3)) : int32(6);
        if (m.currentMenu == 5 || m.currentMenu == 6) return 6;
        if (m.currentMenu == 1) return m.extended ? int32(1) : int32(4);
        if (m.currentMenu == 4) return m.extended ? int32(4) : int32(8);
        return m.currentMenu == 2 ? int32(5) : (m.commercial ? int32(32) : int32(9));
    }

    function selectable(MenuState memory m, int32 item) private pure returns (bool) {
        if (m.currentMenu == 5) {
            bool any;
            for (uint8 i; i < 6; ++i) {
                if (m.saveOccupied[i]) any = true;
            }
            return !any || m.saveOccupied[uint32(item)];
        }
        // No decorative detail, mouse or audio settings. Preserve original row positions.
        return m.currentMenu != 4 || item == 0 || item == 1 || item == 3;
    }

    function alpha(MenuState memory m, int32 item) private pure returns (int32) {
        if (m.currentMenu == 0) {
            if (m.extended) return int32(uint32(uint8(bytes("nsolg")[uint32(item)])));
            return int32(uint32(uint8(bytes("nolsrq")[uint32(item)])));
        }
        if (m.currentMenu == 5 || m.currentMenu == 6) return item + 49;
        if (m.currentMenu == 4) return int32(uint32(uint8(bytes("emgs\x00m\x00s")[uint32(item)])));
        if (m.currentMenu == 1) return int32(uint32(uint8(bytes("ktit")[uint32(item)])));
        if (m.currentMenu == 2) return int32(uint32(uint8(bytes("ihhun")[uint32(item)])));
        return m.commercial && item >= 9 ? int32(-1) : item + 49;
    }

    /// @custom:source m_menu.c M_Responder keyboard/menu branches, M_NewGame/M_Episode/M_ChooseSkill.
    /// @dev Audio, mouse and unsupported function-key/Save/Load branches are absent.
    /// Original false returns are preserved here; production dispatch separately
    /// isolates all active-menu input from gameplay, including unknown keys/keyups.
    function M_Responder(MenuState memory m, int32 kind, int32 ch) internal pure returns (bool) {
        if (kind != 0) return false;
        if (m.saveStringEnter) return saveResponder(m, ch);
        if (m.messageToPrint) {
            if (ch != 32 && ch != 110 && ch != 121 && ch != 27) return false;
            m.messageToPrint = false;
            if (m.messageKind == 1) M_EndGameResponse(m, ch);
            else M_VerifyNightmare(m, ch);
            m.menuactive = false;
            return true;
        }
        if (!m.menuactive) {
            if (m.savesEnabled && (ch == 188 || ch == 189)) {
                M_StartControlPanel(m);
                if (ch == 188) M_SaveGame(m);
                else M_LoadGame(m);
                return true;
            }
            if (ch != 27) return false;
            M_StartControlPanel(m);
            return true;
        }
        if (ch == 175) {
            // KEY_DOWNARROW
            do {
                m.itemOn = m.itemOn + 1 > numitems(m) - 1 ? int32(0) : m.itemOn + 1;
            } while (!selectable(m, m.itemOn));
            return true;
        }
        if (ch == 173) {
            // KEY_UPARROW
            do {
                m.itemOn = m.itemOn == 0 ? numitems(m) - 1 : m.itemOn - 1;
            } while (!selectable(m, m.itemOn));
            return true;
        }
        if (ch == 172 || ch == 174) {
            if (m.currentMenu == 4 && m.itemOn == 3) M_SizeDisplay(m, ch == 172 ? int32(0) : int32(1));
            return true;
        }
        if (ch == 13) {
            m.lastOn[m.currentMenu] = m.itemOn;
            if (m.currentMenu == 0) {
                if (m.itemOn == 0) {
                    M_NewGame(m);
                } else if ((!m.extended && m.itemOn == 1) || (m.extended && m.itemOn == 2)) {
                    M_Options(m);
                } else if (m.extended && m.itemOn == 1) {
                    m.directSelection = true;
                    M_SetupNextMenu(m, 3);
                } else if (m.savesEnabled && m.itemOn == (m.extended ? int32(3) : int32(2))) {
                    M_LoadGame(m);
                } else if (m.savesEnabled && m.itemOn == (m.extended ? int32(4) : int32(3))) {
                    M_SaveGame(m);
                }
            } else if (m.currentMenu == 1) {
                M_Episode(m, m.itemOn);
            } else if (m.currentMenu == 2) {
                M_ChooseSkill(m, m.itemOn);
            } else if (m.currentMenu == 4) {
                if (m.itemOn == 0) M_EndGame(m);
                else if (m.itemOn == 1) M_ChangeMessages(m);
                else if (m.itemOn == 3) M_SizeDisplay(m, 1);
            } else if (m.currentMenu == 5) {
                if (m.saveOccupied[uint32(m.itemOn)]) {
                    m.saveSlot = uint8(uint32(m.itemOn));
                    m.saveAction = 2;
                    M_ClearMenus(m);
                }
            } else if (m.currentMenu == 6) {
                M_SaveSelect(m);
            } else {
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
                M_SetupNextMenu(
                    m,
                    m.currentMenu == 2
                        ? (m.directSelection ? uint8(3) : (m.commercial ? uint8(0) : uint8(1)))
                        : uint8(0)
                );
            }
            return true;
        }
        for (int32 i = m.itemOn + 1; i < numitems(m); ++i) {
            if (selectable(m, i) && alpha(m, i) == ch) {
                m.itemOn = i;
                return true;
            }
        }
        for (int32 i; i <= m.itemOn; ++i) {
            if (selectable(m, i) && alpha(m, i) == ch) {
                m.itemOn = i;
                return true;
            }
        }
        return false;
    }

    function patch(ResourceView memory source, bytes8 name) private view returns (bytes memory) {
        return R_Data.W_CacheLumpNum(source, R_Data.W_GetNumForName(source, name));
    }

    function draw(ResourceView memory source, VideoState memory v, int32 x, int32 y, bytes8 name)
        private
        view
    {
        V_Video.V_DrawPatchDirect(v, x, y, 0, patch(source, name));
    }

    /// @custom:source m_menu.c M_DrawThermo, same original patches and eight-pixel spacing.
    function M_DrawThermo(
        ResourceView memory source,
        VideoState memory v,
        int32 x,
        int32 y,
        int32 width,
        int32 dot
    ) internal view {
        draw(source, v, x, y, "M_THERML");
        int32 xx = x + 8;
        for (int32 i; i < width; ++i) {
            draw(source, v, xx, y, "M_THERMM");
            xx += 8;
        }
        draw(source, v, xx, y, "M_THERMR");
        draw(source, v, x + 8 + dot * 8, y, "M_THERMO");
    }

    /// @custom:source m_menu.c M_DrawOptions. Unsupported production rows are omitted.
    function M_DrawOptions(MenuState memory m, ResourceView memory source, VideoState memory v)
        internal
        view
    {
        draw(source, v, 108, 15, "M_OPTTTL");
        draw(source, v, 180, 53, m.showMessages ? bytes8("M_MSGON") : bytes8("M_MSGOFF"));
        M_DrawThermo(source, v, 60, 101, 9, m.screenSize);
        if (!m.extended) {
            draw(source, v, 235, 69, "M_GDHIGH");
            M_DrawThermo(source, v, 60, 133, 10, 5);
        }
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
        internal
        pure
    {
        int32 cx = x;
        int32 cy = y;
        for (uint256 i; i < text.length; ++i) {
            int32 c = int32(uint32(uint8(text[i])));
            if (c == 0) break;
            if (c == 10) {
                cx = x;
                cy += 12;
                continue;
            }
            if (c >= 97 && c <= 122) c -= 32;
            c -= 33;
            if (c < 0 || c >= 63) {
                cx += 4;
                continue;
            }
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
        if (m.messageToPrint || m.extended || m.currentMenu >= 5) font = HU_Stuff.HU_Init(source);
        if (m.messageToPrint) {
            bytes memory message = m.messageKind == 1
                ? bytes("are you sure you want to end the game?\n\npress y or n.")
                : nightmareMessage();
            int32 lines = 1;
            for (uint256 i; i < message.length; ++i) {
                if (message[i] == 0x0a) ++lines;
            }
            int32 height = HU_Lib.patchShort(font[0], 2);
            int32 y = 100 - height * lines / 2;
            uint256 start;
            for (uint256 end; end <= message.length; ++end) {
                if (end != message.length && message[end] != 0x0a) continue;
                bytes memory line = new bytes(end - start);
                for (uint256 i; i < line.length; ++i) {
                    line[i] = message[start + i];
                }
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
        if (m.extended && m.currentMenu == 0) max = m.savesEnabled ? int32(5) : int32(3);
        if (m.extended && m.currentMenu == 1) max = 1;
        if (m.currentMenu == 3) {
            x = 80;
            y = 48;
            max = m.commercial ? int32(8) : int32(9);
            M_WriteText(v, font, 80, 24, bytes("SELECT LEVEL"));
        }
        if (m.currentMenu == 4) {
            x = 60;
            y = 37;
            max = m.extended ? int32(4) : int32(8);
            M_DrawOptions(m, source, v);
        }
        if (m.currentMenu == 5 || m.currentMenu == 6) {
            x = 80;
            y = 54;
            max = 6;
            draw(source, v, 72, 28, m.currentMenu == 5 ? bytes8("M_LOADG") : bytes8("M_SAVEG"));
            for (uint8 slot; slot < 6; ++slot) {
                int32 yy = y + int32(uint32(slot)) * 16;
                draw(source, v, x - 8, yy + 7, "M_LSLEFT");
                for (int32 j; j < 24; ++j) {
                    draw(source, v, x + j * 8, yy + 7, "M_LSCNTR");
                }
                draw(source, v, x + 24 * 8, yy + 7, "M_LSRGHT");
                bytes memory text =
                    m.saveStringEnter && slot == m.saveSlot ? m.saveDescription : m.savegamestrings[slot];
                M_WriteText(v, font, x, yy, text);
                if (m.saveStringEnter && slot == m.saveSlot) {
                    M_WriteText(v, font, x + M_StringWidth(font, text), yy, bytes("_"));
                }
            }
            draw(
                source,
                v,
                x - 32,
                y - 5 + m.itemOn * 16,
                m.whichSkull == 0 ? bytes8("M_SKULL1") : bytes8("M_SKULL2")
            );
            return;
        }
        for (int32 i; i < max; ++i) {
            if (m.currentMenu == 4) {
                if (i == 0) draw(source, v, x, y, "M_ENDGAM");
                else if (i == 1) draw(source, v, x, y + 16, "M_MESSG");
                else if (i == 3) draw(source, v, x, y + 48, "M_SCRNSZ");
                else if (!m.extended && i == 2) draw(source, v, x, y + 32, "M_DETAIL");
                else if (!m.extended && i == 5) draw(source, v, x, y + 80, "M_MSENS");
                else if (!m.extended && i == 7) draw(source, v, x, y + 112, "M_SVOL");
            } else if (m.currentMenu == 3) {
                if (m.commercial) {
                    int32 map = (m.itemOn / 8) * 8 + i + 1;
                    M_WriteText(
                        v,
                        font,
                        x,
                        y + i * 16,
                        abi.encodePacked(
                            "MAP", bytes1(uint8(uint32(map / 10) + 48)), bytes1(uint8(uint32(map % 10) + 48))
                        )
                    );
                } else {
                    M_WriteText(
                        v, font, x, y + i * 16, abi.encodePacked("E1M", bytes1(uint8(uint32(i) + 49)))
                    );
                }
            } else if (m.extended && m.currentMenu == 0 && i == 1) {
                M_WriteText(v, font, x, y + i * 16, bytes("SELECT LEVEL"));
            } else if (m.extended && m.currentMenu == 0 && i >= 2) {
                draw(
                    source,
                    v,
                    x,
                    y + i * 16,
                    i == 2 ? bytes8("M_OPTION") : i == 3 ? bytes8("M_LOADG") : bytes8("M_SAVEG")
                );
            } else {
                draw(source, v, x, y + i * 16, itemName(m.currentMenu, i));
            }
        }
        draw(
            source,
            v,
            x - 32,
            y - 5 + (m.commercial && m.currentMenu == 3 ? m.itemOn % 8 : m.itemOn) * 16,
            m.whichSkull == 0 ? bytes8("M_SKULL1") : bytes8("M_SKULL2")
        );
    }

    function title(ResourceView memory source) internal view returns (bytes memory pixels) {
        pixels = new bytes(64000);
        VideoState memory v;
        v.screens[0] = pixels;
        draw(source, v, 0, 0, "TITLEPIC");
    }
}
