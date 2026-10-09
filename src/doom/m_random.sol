// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
// Generated original random table; gameplay and miscellaneous streams are independent.
pragma solidity 0.8.37;
import {GameState} from "./p_game_state.sol";

/// @custom:source linuxdoom-1.10/m_random.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
library M_Random {
    function P_Random(GameState memory state) internal pure returns (int32) {
        state.prndindex = (state.prndindex + 1) & 255;
        return int32(uint32(value(state.prndindex)));
    }

    function M_RandomValue(GameState memory state) internal pure returns (int32) {
        state.rndindex = (state.rndindex + 1) & 255;
        return int32(uint32(value(state.rndindex)));
    }

    function M_ClearRandom(GameState memory state) internal pure {
        state.rndindex = 0;
        state.prndindex = 0;
    }

    function value(uint32 index) internal pure returns (uint8) {
        require(index < 256, "random index");
        uint256 packed;
        if (index / 32 == 0) packed = 0x00086ddcdef1956b4bf8fe8c10424a15d32f50f29a1bcd80a1594d245f6e5530;
        else if (index / 32 == 1) packed = 0xd48cd3f9164fc8321cbc348cca7844913e46b8be5bc598e0956819b2fcb6cab6;
        else if (index / 32 == 2) packed = 0x8dc50451b5f2912a27e39cc6e1c1db5d7aaff900af8f46ef2ef6a335a36da887;
        else if (index / 32 == 3) packed = 0x02eb195c14918a4d45a64eb0add4a6715ea12932ef316fa4463c0225ab4b889c;
        else if (index / 32 == 4) packed = 0x0b382a928ae549924d3d62c4876a3fc5c35660cb7165aaf7b57150fa6c07ffed;
        else if (index / 32 == 5) packed = 0x81e24f6b70a667f118dfef78c63a3c528003b8428fe091e051cea32d3f5aa872;
        else if (index / 32 == 6) packed = 0x3b219f5f1c8b7b627dc40f46c2fd360e6de24711a15dba57f48a14347bfb1a24;
        else if (index / 32 == 7) packed = 0x112e34e7e84c1fdd5425d8a5d46ac5f2622b27affe91be5476debb8878a3ecf9;
        return uint8(packed >> ((31 - index % 32) * 8));
    }
}
