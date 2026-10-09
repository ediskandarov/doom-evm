// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {IFrameProtocol} from "../evm/FrameProtocol.sol";

/// @notice Synthetic transport experiment. No original C counterpart, game tick, WAD, or DOOM renderer.
contract FrameFixture is IFrameProtocol {
    error NotDriver();
    error BadSequence();
    error UnsupportedButtons();
    error IntentionalRollback();

    address public immutable driver = msg.sender;
    uint64 public frameId;
    uint32 public inputSeq;

    function stepAndRender(uint32 buttons, uint32 sequence) external {
        if (buttons != 0) revert UnsupportedButtons();
        _frame(sequence);
    }

    /// @notice Test seam proving a revert after LOG rolls back state and receipt logs.
    function revertAfterFrame(uint32 sequence) external {
        _frame(sequence);
        revert IntentionalRollback();
    }

    function _frame(uint32 sequence) internal {
        if (msg.sender != driver) revert NotDriver();
        if (inputSeq == type(uint32).max || sequence != inputSeq + 1) revert BadSequence();
        inputSeq = sequence;
        ++frameId;
        bytes memory pixels = new bytes(320 * 200);
        // Entire payload is generated inside EVM. The sequence shifts this synthetic test pattern.
        for (uint256 i; i < pixels.length; ++i) {
            // Modulo 256 proves this conversion is in the uint8 range.
            // forge-lint: disable-next-line(unsafe-typecast)
            pixels[i] = bytes1(uint8((i + sequence) % 256));
        }
        emit Frame(frameId, sequence, 320, 200, pixels);
    }
}
