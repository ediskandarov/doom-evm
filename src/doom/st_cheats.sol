// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
// Copyright (C) 1993-1996 by id Software, Inc.
import {CheatSequence, M_Cheat} from "./m_cheat.sol";
import {GameContext, Player, Mobj, GameConst} from "./p_game_state.sol";
import {G_Game, GameflowState} from "./g_game.sol";
import {P_Inter} from "./p_inter.sol";

/// @dev Original global recognizers, static position message, and AM cheating.
/// Persist atomically with GameState/GameflowState. ST_Start/AM_Start must not reset it.
struct CheatState {
    CheatSequence[16] sequences;
    string positionMessage;
    uint8 automapCheating;
}

/// @dev Cheat-only portion of st_stuff.c; leaves status bar ownership separate.
library ST_Cheats {
    /// @custom:source linuxdoom-1.10/st_stuff.c cheat_*_seq; am_map.c cheat_amap_seq
    function initialize(CheatState memory s) internal pure {
        if (s.sequences[0].sequence.length != 0) return;
        s.sequences[0].sequence = hex"b22626aa26ff"; // iddqd
        s.sequences[1].sequence = hex"b22666a2ff"; // idfa
        s.sequences[2].sequence = hex"b226f266a2ff"; // idkfa
        s.sequences[3].sequence = hex"b226ea2ab2ea2af62a26ff"; // idspispopd
        s.sequences[4].sequence = hex"b226e236b22aff"; // idclip
        s.sequences[5].sequence = hex"b22662a632f636266eff"; // beholdv
        s.sequences[6].sequence = hex"b22662a632f63626eaff"; // beholds
        s.sequences[7].sequence = hex"b22662a632f63626b2ff"; // beholdi
        s.sequences[8].sequence = hex"b22662a632f636266aff"; // beholdr
        s.sequences[9].sequence = hex"b22662a632f63626a2ff"; // beholda
        s.sequences[10].sequence = hex"b22662a632f6362636ff"; // beholdl
        s.sequences[11].sequence = hex"b22662a632f63626ff"; // behold
        s.sequences[12].sequence = hex"b226e232f62a2aa66aeaff"; // idchoppers
        s.sequences[13].sequence = hex"b226b6ba2af6eaff"; // idmypos
        s.sequences[14].sequence = hex"b226e236a66e010000ff"; // idclev + raw bytes
        s.sequences[15].sequence = hex"b226262eff"; // iddt
    }

    function check(CheatState memory s, uint256 index, uint8 key) private pure returns (bool) {
        return M_Cheat.cht_CheckCheat(s.sequences[index], key);
    }

    function arsenal(Player memory p, bool keys) private pure {
        p.armorpoints = 200;
        p.armortype = 2;
        for (uint256 i; i < 9; ++i) {
            p.weaponowned[i] = true;
        }
        for (uint256 i; i < 4; ++i) {
            p.ammo[i] = p.maxammo[i];
        }
        if (keys) {
            for (uint256 i; i < 6; ++i) {
                p.cards[i] = true;
            }
        }
        p.message = keys ? "Very Happy Ammo Added" : "Ammo (no keys) Added";
    }

    function hex32(uint32 value) private pure returns (string memory) {
        bytes memory digits = "0123456789abcdef";
        bytes memory out = new bytes(8);
        uint256 n;
        do {
            out[7 - n++] = digits[value & 15];
            value >>= 4;
        } while (value != 0);
        bytes memory result = new bytes(n);
        for (uint256 i; i < n; ++i) {
            result[i] = out[8 - n + i];
        }
        return string(result);
    }

    /// @custom:source linuxdoom-1.10/st_stuff.c ST_Responder keydown branch
    /// @dev ev_keydown=0, ev_keyup=1. Like C, never consumes the event. Routing
    /// to this level responder is the caller's job; nightmare/dead/paused are allowed.
    /// IDMUS and its branch are deliberately omitted. Both noclip codes work in all modes.
    function ST_Responder(
        GameContext memory c,
        GameflowState memory f,
        CheatState memory s,
        uint8 eventType,
        int32 data1
    ) internal pure returns (bool) {
        if (eventType != 0) return false;
        initialize(s);
        uint8 key = uint8(uint32(data1)); // original char conversion (low byte)
        uint32 player = uint32(c.state.consoleplayer);
        Player memory p = c.state.players[player];
        if (!c.state.netgame) {
            if (check(s, 0, key)) {
                p.cheats ^= GameConst.CF_GODMODE;
                if (p.cheats & GameConst.CF_GODMODE != 0) {
                    if (p.mo != GameConst.NULL) c.state.mobjs[p.mo].health = 100;
                    p.health = 100;
                    p.message = "Degreelessness Mode On";
                } else {
                    p.message = "Degreelessness Mode Off";
                }
            } else if (check(s, 1, key)) {
                arsenal(p, false);
            } else if (check(s, 2, key)) {
                arsenal(p, true);
            } else if (check(s, 3, key) || check(s, 4, key)) {
                p.cheats ^= GameConst.CF_NOCLIP;
                p.message =
                    p.cheats & GameConst.CF_NOCLIP != 0 ? "No Clipping Mode ON" : "No Clipping Mode OFF";
            }
            for (uint32 i; i < 6; ++i) {
                if (check(s, 5 + i, key)) {
                    if (p.powers[i] == 0) P_Inter.P_GivePower(c, player, i);
                    else if (i != 1) p.powers[i] = 1;
                    else p.powers[i] = 0;
                    p.message = "Power-up Toggled";
                }
            }
            if (check(s, 11, key)) {
                p.message = "inVuln, Str, Inviso, Rad, Allmap, or Lite-amp";
            } else if (check(s, 12, key)) {
                p.weaponowned[7] = true;
                p.powers[0] = 1; // C assigns boolean true, not INVULNTICS
                p.message = "... doesn't suck - GM";
            } else if (check(s, 13, key)) {
                Mobj memory mo = c.state.mobjs[p.mo];
                s.positionMessage = string.concat(
                    "ang=0x",
                    hex32(mo.angle),
                    ";x,y=(0x",
                    hex32(uint32(mo.x)),
                    ",0x",
                    hex32(uint32(mo.y)),
                    ")"
                );
                p.message = s.positionMessage;
            }
        }
        // Original IDCLEV is outside the !netgame guard.
        if (check(s, 14, key)) {
            bytes memory param = M_Cheat.cht_GetParam(s.sequences[14]);
            // C's buf[3] has indeterminate bytes after an early NUL. Reject this
            // undefined profile; parser still clears exactly the C visited slots.
            if (param.length != 3 || param[0] == 0 || param[1] == 0) return false;
            int32 a = int32(int8(uint8(param[0]))) - 48;
            int32 b = int32(int8(uint8(param[1]))) - 48;
            int32 episode = c.state.gamemode == 2 ? int32(0) : a;
            int32 map = c.state.gamemode == 2 ? a * 10 + b : b;
            if (episode < 1 || map < 1) return false;
            if (c.state.gamemode == 3 && (episode > 4 || map > 9)) return false;
            if (c.state.gamemode == 1 && (episode > 3 || map > 9)) return false;
            if (c.state.gamemode == 0 && (episode > 1 || map > 9)) return false;
            if (c.state.gamemode == 2 && (episode > 1 || map > 34)) return false;
            p.message = "Changing Level...";
            G_Game.G_DeferedInitNew(c.state, f, c.state.gameskill, episode, map);
        }
        return false;
    }

    /// @custom:source linuxdoom-1.10/am_map.c AM_Responder cheat branch
    /// @dev Call once in the entered active-map keydown branch (after switch),
    /// even if that switch just closed the map. True means AM must return false.
    /// Ordinary AM navigation, tab dispatch and rendering remain AM's responsibility.
    function AM_CheckCheat(
        CheatState memory s,
        uint8 eventType,
        int32 data1,
        bool activeBranch,
        int32 deathmatch
    ) internal pure returns (bool completed) {
        if (!activeBranch || eventType != 0 || deathmatch != 0) return false;
        initialize(s);
        if (check(s, 15, uint8(uint32(data1)))) {
            s.automapCheating = (s.automapCheating + 1) % 3;
            return true;
        }
    }
}
