// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

/// @notice Persistent context scaffold. No tick/gameplay implemented in Phase 0.
/// @custom:source linuxdoom-1.10/doomstat.h at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @dev Explicit simulated tic; never derived from block.timestamp.
struct DoomState {
    uint64 gametic;
}
