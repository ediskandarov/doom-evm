// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {IFrameProtocol} from "./FrameProtocol.sol";
import {DoomState} from "../doom/doomstat.sol";
import {WadResources} from "./WadResources.sol";
import {DoomRenderer} from "./DoomRenderer.sol";
import {RenderContext} from "../doom/r_render_state.sol";

/// @notice Static Freedoom E1M1 world view computed entirely inside the ordinary EVM.
/// @dev The resource/camera setup is recreated in memory per transaction. No gameplay ticks.
contract Doom is IFrameProtocol, WadResources {
    error NotDriver();
    error BadSequence();
    error UnsupportedButtons();
    error InvalidFrame();

    address public immutable driver = msg.sender;
    uint64 public frameId;
    uint32 public inputSeq;
    uint32 private fuzzpos;
    DoomState internal doomState;

    constructor(address[] memory chunks, bytes memory directory) WadResources(chunks, directory) {}

    function renderFrame() external {
        if (inputSeq == type(uint32).max) revert BadSequence();
        _frame(inputSeq + 1);
    }

    function stepAndRender(uint32 buttons, uint32 sequence) external {
        if (buttons != 0) revert UnsupportedButtons();
        _frame(sequence);
    }

    function _frame(uint32 sequence) private {
        if (msg.sender != driver) revert NotDriver();
        if (inputSeq == type(uint32).max || sequence != inputSeq + 1) revert BadSequence();
        RenderContext memory ctx = DoomRenderer.initialize(_resourceView());
        ctx.rs.fuzzpos = fuzzpos;
        DoomRenderer.render(ctx);
        if (ctx.rs.framebuffer.length != 320 * 200) revert InvalidFrame();
        fuzzpos = ctx.rs.fuzzpos;
        inputSeq = sequence;
        ++frameId;
        emit Frame(frameId, sequence, 320, 200, ctx.rs.framebuffer);
    }
}
