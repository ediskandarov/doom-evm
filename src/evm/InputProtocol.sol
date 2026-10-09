// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {Ticcmd, GameInputState, KeyboardInput} from "../doom/d_ticcmd.sol";
import {G_Game} from "../doom/g_game.sol";

library InputProtocol {
    uint32 internal constant SUPPORTED_MASK = 0x3fff;
    error UnsupportedInputBits(uint32 held);
    error InvalidWeaponRequest(uint8 request);

    function build(GameInputState memory state, uint32 held) internal pure returns (Ticcmd memory) {
        if (held & ~SUPPORTED_MASK != 0) revert UnsupportedInputBits(held);
        uint8 weapon = uint8((held >> 10) & 15);
        if (weapon > 9) revert InvalidWeaponRequest(weapon);
        KeyboardInput memory keys = KeyboardInput(
            held & 1 != 0,
            held & 2 != 0,
            held & 4 != 0,
            held & 8 != 0,
            held & 16 != 0,
            held & 32 != 0,
            held & 64 != 0,
            held & 128 != 0,
            held & 256 != 0,
            held & 512 != 0,
            weapon
        );
        return G_Game.G_BuildTiccmd(state, keys);
    }
}
