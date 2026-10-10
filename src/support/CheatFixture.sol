// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {GameContext, Player, Mobj, GameConst} from "../doom/p_game_state.sol";
import {GameflowState} from "../doom/g_game.sol";
import {CheatState, ST_Cheats} from "../doom/st_cheats.sol";

/// @dev Dedicated oracle/probe helper; no production adapter uses this module.
library CheatFixture {
    function fresh(int32[8] memory cfg) internal pure returns (GameContext memory c) {
        c.state.gamemode = cfg[0];
        c.state.netgame = cfg[1] != 0;
        c.state.gameskill = cfg[2];
        c.state.consoleplayer = cfg[3];
        c.state.mobjs = new Mobj[](4);
        uint32 cp = uint32(cfg[3]);
        Player memory p = c.state.players[cp];
        p.mo = cfg[4] != 0 ? cp : GameConst.NULL;
        p.health = cfg[5];
        Mobj memory mo = c.state.mobjs[cp];
        mo.health = cfg[6];
        mo.angle = 0xabcdef01;
        mo.x = -65536;
        mo.y = 0x12345678;
        p.weaponowned[0] = true;
        p.weaponowned[1] = true;
        for (uint256 i; i < 6; ++i) {
            p.powers[i] = cfg[7];
            p.cards[i] = i % 2 == 0;
        }
        p.maxammo = [int32(400), 100, 600, 100];
        for (uint256 i; i < 4; ++i) {
            p.ammo[i] = int32(uint32(i + 1));
        }
    }

    function word(int32 n) private pure returns (bytes memory) {
        return abi.encodePacked(uint32(n));
    }

    /// @dev Byte-exact driver.c snapshot format, independent of Solidity ABI layout.
    function snapshot(GameContext memory c, GameflowState memory f, CheatState memory s)
        internal
        pure
        returns (bytes memory out)
    {
        Player memory p = c.state.players[uint32(c.state.consoleplayer)];
        Mobj memory mo = c.state.mobjs[uint32(c.state.consoleplayer)];
        out = bytes.concat(
            word(p.health),
            word(p.armorpoints),
            word(p.armortype),
            word(p.cheats),
            word(mo.health),
            word(int32(mo.flags))
        );
        for (uint256 i; i < 6; ++i) {
            out = bytes.concat(out, word(p.powers[i]));
        }
        for (uint256 i; i < 6; ++i) {
            out = bytes.concat(out, word(p.cards[i] ? int32(1) : int32(0)));
        }
        for (uint256 i; i < 9; ++i) {
            out = bytes.concat(out, word(p.weaponowned[i] ? int32(1) : int32(0)));
        }
        for (uint256 i; i < 4; ++i) {
            out = bytes.concat(out, word(p.ammo[i]));
        }
        for (uint256 i; i < 4; ++i) {
            out = bytes.concat(out, word(p.maxammo[i]));
        }
        out = bytes.concat(
            out,
            word(c.state.gameaction),
            word(f.deferredSkill),
            word(f.deferredEpisode),
            word(f.deferredMap),
            abi.encodePacked(uint32(s.automapCheating))
        );
        out = bytes.concat(out, abi.encodePacked(uint32(bytes(p.message).length)), bytes(p.message));
        for (uint256 i; i < 16; ++i) {
            out = bytes.concat(
                out,
                abi.encodePacked(s.sequences[i].cursor, uint32(s.sequences[i].sequence.length)),
                s.sequences[i].sequence
            );
        }
    }
}
