// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

/// @notice Header adaptation only; not an arithmetic port.
/// @custom:source linuxdoom-1.10/doomtype.h, m_fixed.h, tables.h at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @dev fixed_t uses int32 (16.16); angle_t uses uint32. Use primitive types at module boundaries.
library DoomType {
    uint32 internal constant NULL_INDEX = type(uint32).max;
    uint32 internal constant NF_SUBSECTOR = 0x8000;
    int32 internal constant FRACUNIT = 65536;
    uint8 internal constant FRACBITS = 16;
}
