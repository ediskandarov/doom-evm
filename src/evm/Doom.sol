// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {IFrameProtocol} from "./FrameProtocol.sol";
import {DoomState} from "../doom/doomstat.sol";

/// @notice Adapter scaffold only. Use support/FrameFixture for the Phase 0 mock experiment.
abstract contract Doom is IFrameProtocol {
    DoomState internal doomState;

    function renderFrame() external virtual;
    function stepAndRender(uint32 buttons, uint32 inputSeq) external virtual;
}
