// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

/// @notice Static resource identity; storage placement remains a measured Phase 1 decision.
struct ResourceIdentity {
    uint32 schemaVersion;
    bytes32 wadSha256;
    bytes32 bundleSha256;
    bytes32 paletteSha256;
    uint8 paletteVariant;
}

/// @notice Descriptor into a normalized blob. Integers in blob are explicitly little-endian.
/// @dev WAD lump names retain eight bytes; offsets/counts are unsigned after bounds validation.
struct LumpDescriptor {
    bytes8 name;
    uint32 offset;
    uint32 length;
}
