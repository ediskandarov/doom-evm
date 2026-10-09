// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {RenderContext} from "./r_render_state.sol";

/// @dev Original renderer cross-module calls, supplied internally to avoid circular imports.
/// No external contract calls or host callbacks are involved.
struct RenderHooks {
    function(RenderContext memory) internal pure clearClipSegs;
    function(RenderContext memory) internal pure clearDrawSegs;
    function(RenderContext memory) internal pure clearPlanes;
    function(RenderContext memory) internal pure clearSprites;
    function(RenderContext memory, int32) internal view renderBSPNode;
    function(RenderContext memory) internal view drawPlanes;
    function(RenderContext memory) internal view drawMasked;
}
