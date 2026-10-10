// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {HU_Lib, HuTextLine, HuSText} from "./hu_lib.sol";
import {VideoState} from "./v_video_types.sol";
import {RenderState} from "./r_state.sol";
import {Player} from "./p_game_state.sol";
import {ResourceView} from "./r_data_types.sol";
import {R_Data} from "./r_data.sol";

struct HudState {
    HuSText message;
    HuTextLine title;
    bool headsupactive;
    bool message_dontfuckwithme;
    bool message_nottobefuckedwith;
    int32 message_counter;
}

/// @custom:source linuxdoom-1.10/hu_stuff.c and hu_stuff.h at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @dev Explicit HUD context replaces globals. Caller supplies console Player and existing view/automap state.
/// No multiplayer chat, queues, keyboard translation or chat widgets.
library HU_Stuff {
    error InvalidMapTitle();

    function HU_Init(ResourceView memory source) internal view returns (bytes[] memory font) {
        font = new bytes[](63);
        for (uint256 i; i < 63; ++i) {
            uint256 n = i + 33;
            bytes memory name = bytes("STCFN000");
            name[5] = bytes1(uint8(48 + n / 100));
            name[6] = bytes1(uint8(48 + n / 10 % 10));
            name[7] = bytes1(uint8(48 + n % 10));
            font[i] = R_Data.W_CacheLumpNum(source, R_Data.W_GetNumForName(source, bytes8(name)));
        }
    }

    function HU_Stop(HudState memory h) internal pure {
        h.headsupactive = false;
    }

    function HU_Start(HudState memory h, bytes[] memory font, int32 mode, int32 episode, int32 map)
        internal
        pure
    {
        if (h.headsupactive) HU_Stop(h);
        h.message.on = false;
        h.message_dontfuckwithme = false;
        h.message_nottobefuckedwith = false;
        HU_Lib.HUlib_initSText(h.message, 0, 0, 1, font, 33);
        HU_Lib.HUlib_initTextLine(h.title, 0, 167 - HU_Lib.patchShort(font[0], 2), font, 33);
        bytes memory title = bytes(mapTitle(mode, episode, map));
        for (uint256 i; i < title.length; ++i) {
            HU_Lib.HUlib_addCharToTextLine(h.title, title[i]);
        }
        // Original HU_Start does not reset message_counter, nor consume Player.message.
        h.headsupactive = true;
    }

    function HU_Ticker(HudState memory h, Player memory p, bool showMessages) internal pure {
        if (h.message_counter != 0 && --h.message_counter == 0) {
            h.message.on = false;
            h.message_nottobefuckedwith = false;
        }
        if (showMessages || h.message_dontfuckwithme) {
            if (bytes(p.message).length != 0 && (!h.message_nottobefuckedwith || h.message_dontfuckwithme)) {
                HU_Lib.HUlib_addMessageToSText(h.message, "", bytes(p.message));
                p.message = "";
                h.message.on = true;
                h.message_counter = 140;
                h.message_nottobefuckedwith = h.message_dontfuckwithme;
                h.message_dontfuckwithme = false;
            }
        }
    }

    function HU_Responder(HudState memory h, int32 eventType, int32 key) internal pure returns (bool) {
        if (eventType != 0 || key != 13) return false;
        h.message.on = true;
        h.message_counter = 140;
        return true;
    }

    function HU_Drawer(HudState memory h, VideoState memory v, bool automap) internal pure {
        HU_Lib.HUlib_drawSText(h.message, v);
        if (automap) HU_Lib.HUlib_drawTextLine(h.title, v, false);
    }

    function HU_Erase(HudState memory h, VideoState memory v, RenderState memory rs, bool automap)
        internal
        pure
    {
        HU_Lib.HUlib_eraseSText(h.message, v, rs, automap);
        HU_Lib.HUlib_eraseTextLine(h.title, v, rs, automap);
    }

    function mapTitle(int32 mode, int32 episode, int32 map) internal pure returns (string memory) {
        // Generated literal tables below retain the active original HU_Start switch.
        // Plutonia/TNT branches are commented out in the pinned C and are not enabled here.
        if (mode == 0 || mode == 1 || mode == 3) {
            if (episode < 1 || episode > 5 || map < 1 || map > 9) revert InvalidMapTitle();
            return doomTitle(uint32((episode - 1) * 9 + map - 1));
        }
        if (map < 1 || map > 32) revert InvalidMapTitle();
        return doom2Title(uint32(map - 1));
    }

    function doomTitle(uint32 index) private pure returns (string memory) {
        if (index == 0) return "E1M1: Hangar";
        if (index == 1) return "E1M2: Nuclear Plant";
        if (index == 2) return "E1M3: Toxin Refinery";
        if (index == 3) return "E1M4: Command Control";
        if (index == 4) return "E1M5: Phobos Lab";
        if (index == 5) return "E1M6: Central Processing";
        if (index == 6) return "E1M7: Computer Station";
        if (index == 7) return "E1M8: Phobos Anomaly";
        if (index == 8) return "E1M9: Military Base";
        if (index == 9) return "E2M1: Deimos Anomaly";
        if (index == 10) return "E2M2: Containment Area";
        if (index == 11) return "E2M3: Refinery";
        if (index == 12) return "E2M4: Deimos Lab";
        if (index == 13) return "E2M5: Command Center";
        if (index == 14) return "E2M6: Halls of the Damned";
        if (index == 15) return "E2M7: Spawning Vats";
        if (index == 16) return "E2M8: Tower of Babel";
        if (index == 17) return "E2M9: Fortress of Mystery";
        if (index == 18) return "E3M1: Hell Keep";
        if (index == 19) return "E3M2: Slough of Despair";
        if (index == 20) return "E3M3: Pandemonium";
        if (index == 21) return "E3M4: House of Pain";
        if (index == 22) return "E3M5: Unholy Cathedral";
        if (index == 23) return "E3M6: Mt. Erebus";
        if (index == 24) return "E3M7: Limbo";
        if (index == 25) return "E3M8: Dis";
        if (index == 26) return "E3M9: Warrens";
        if (index == 27) return "E4M1: Hell Beneath";
        if (index == 28) return "E4M2: Perfect Hatred";
        if (index == 29) return "E4M3: Sever The Wicked";
        if (index == 30) return "E4M4: Unruly Evil";
        if (index == 31) return "E4M5: They Will Repent";
        if (index == 32) return "E4M6: Against Thee Wickedly";
        if (index == 33) return "E4M7: And Hell Followed";
        if (index == 34) return "E4M8: Unto The Cruel";
        if (index == 35) return "E4M9: Fear";
        return "NEWLEVEL";
    }

    function doom2Title(uint32 index) private pure returns (string memory) {
        if (index == 0) return "level 1: entryway";
        if (index == 1) return "level 2: underhalls";
        if (index == 2) return "level 3: the gantlet";
        if (index == 3) return "level 4: the focus";
        if (index == 4) return "level 5: the waste tunnels";
        if (index == 5) return "level 6: the crusher";
        if (index == 6) return "level 7: dead simple";
        if (index == 7) return "level 8: tricks and traps";
        if (index == 8) return "level 9: the pit";
        if (index == 9) return "level 10: refueling base";
        if (index == 10) return "level 11: 'o' of destruction!";
        if (index == 11) return "level 12: the factory";
        if (index == 12) return "level 13: downtown";
        if (index == 13) return "level 14: the inmost dens";
        if (index == 14) return "level 15: industrial zone";
        if (index == 15) return "level 16: suburbs";
        if (index == 16) return "level 17: tenements";
        if (index == 17) return "level 18: the courtyard";
        if (index == 18) return "level 19: the citadel";
        if (index == 19) return "level 20: gotcha!";
        if (index == 20) return "level 21: nirvana";
        if (index == 21) return "level 22: the catacombs";
        if (index == 22) return "level 23: barrels o' fun";
        if (index == 23) return "level 24: the chasm";
        if (index == 24) return "level 25: bloodfalls";
        if (index == 25) return "level 26: the abandoned mines";
        if (index == 26) return "level 27: monster condo";
        if (index == 27) return "level 28: the spirit world";
        if (index == 28) return "level 29: the living end";
        if (index == 29) return "level 30: icon of sin";
        if (index == 30) return "level 31: wolfenstein";
        if (index == 31) return "level 32: grosse";
        revert InvalidMapTitle();
    }
}
