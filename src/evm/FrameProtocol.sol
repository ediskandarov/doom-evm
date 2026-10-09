// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

/// @notice EVM transport, no original C counterpart. Frozen Phase 0 ABI v0.
interface IFrameProtocol {
    event Frame(uint64 indexed frameId, uint32 indexed inputSeq, uint16 width, uint16 height, bytes pixels);
}
