// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

// Copyright (C) 1993-1996 by id Software, Inc.

/// @custom:source linuxdoom-1.10/m_cheat.h cheatseq_t
/// @dev Offset replaces the native pointer; sequence includes mutable parameter slots.
struct CheatSequence {
    bytes sequence;
    uint32 cursor;
}

library M_Cheat {
    function scramble(uint8 a) internal pure returns (uint8) {
        return ((a & 1) << 7) | ((a & 2) << 5) | (a & 4) | ((a & 8) << 1) | ((a & 16) >> 1) | (a & 32)
            | ((a & 64) >> 5) | ((a & 128) >> 7);
    }

    /// @custom:source linuxdoom-1.10/m_cheat.c cht_CheckCheat
    /// @dev A mismatch consumes the key. Do not retry it as a new prefix.
    function cht_CheckCheat(CheatSequence memory cht, uint8 key) internal pure returns (bool rc) {
        uint32 p = cht.cursor;
        if (cht.sequence[p] == 0) {
            cht.sequence[p++] = bytes1(key);
        } else if (scramble(key) == uint8(cht.sequence[p])) {
            ++p;
        } else {
            p = 0;
        }
        if (cht.sequence[p] == 0x01) {
            ++p;
        } else if (cht.sequence[p] == 0xff) {
            p = 0;
            rc = true;
        }
        cht.cursor = p;
    }

    /// @custom:source linuxdoom-1.10/m_cheat.c cht_GetParam
    /// @dev Includes the C terminating zero. Stops on embedded NUL and clears only
    /// the same visited slots as C; unvisited slots remain mutable sequence data.
    function cht_GetParam(CheatSequence memory cht) internal pure returns (bytes memory buffer) {
        uint256 p;
        while (cht.sequence[p++] != 0x01) {}
        buffer = new bytes(cht.sequence.length - p);
        uint256 n;
        bytes1 ch;
        do {
            ch = cht.sequence[p];
            buffer[n++] = ch;
            cht.sequence[p++] = 0;
        } while (ch != 0 && cht.sequence[p] != 0xff);
        if (cht.sequence[p] == 0xff) buffer[n++] = 0;
        assembly ("memory-safe") { mstore(buffer, n) }
    }
}
