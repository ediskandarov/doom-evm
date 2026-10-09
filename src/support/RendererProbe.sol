// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {WadResources} from "../evm/WadResources.sol";
import {IFrameProtocol} from "../evm/FrameProtocol.sol";
import {DoomRenderer} from "../evm/DoomRenderer.sol";
import {ResourceView} from "../doom/r_data_types.sol";
import {RenderContext} from "../doom/r_render_state.sol";
import {R_Main} from "../doom/r_main.sol";
import {R_BSP} from "../doom/r_bsp.sol";
import {R_Plane} from "../doom/r_plane.sol";
import {R_Segs} from "../doom/r_segs.sol";
import {R_Things} from "../doom/r_things.sol";

/// @notice Separately deployed evidence probe; production Doom has no telemetry markers.
contract RendererProbe is WadResources, IFrameProtocol {
    constructor(address[] memory chunks, bytes memory directory) WadResources(chunks, directory) {}

    function memorySize() private view returns (uint256 size) {
        assembly ("memory-safe") { size := gas() }
    }

    function probe(uint32 angle)
        external
        view
        returns (
            bytes memory pixels,
            uint256[3] memory gasCost,
            uint256[4] memory memoryBytes,
            int256[4] memory camera,
            uint256[5] memory counts
        )
    {
        memoryBytes[0] = memorySize();
        uint256 start = gasleft();
        ResourceView memory source = _resourceView();
        gasCost[0] = start - gasleft();
        memoryBytes[1] = memorySize();
        start = gasleft();
        RenderContext memory c = DoomRenderer.initialize(source);
        gasCost[1] = start - gasleft();
        memoryBytes[2] = memorySize();
        c.rs.viewangle = angle;
        start = gasleft();
        DoomRenderer.render(c);
        gasCost[2] = start - gasleft();
        memoryBytes[3] = memorySize();
        camera = [int256(c.rs.viewx), int256(c.rs.viewy), int256(c.rs.viewz), int256(uint256(c.rs.viewangle))];
        counts = [
            c.sprite.things.length,
            uint256(c.drawsegCount),
            uint256(c.visplaneCount),
            uint256(c.sprite.visspriteCount),
            uint256(c.rs.sscount)
        ];
        pixels = c.rs.framebuffer;
    }

    /// @notice Genuine intermediate wall event, separate from full-only production Doom.
    function wallFrame() external {
        RenderContext memory c = DoomRenderer.initialize(_resourceView());
        R_Main.R_SetupFrame(c.rs, c.rs.viewx, c.rs.viewy, c.rs.viewz, c.rs.viewangle, 0, -1);
        R_BSP.R_ClearClipSegs(c);
        R_BSP.R_ClearDrawSegs(c);
        R_Plane.R_ClearPlanes(c);
        R_Things.R_ClearSprites(c);
        R_BSP.R_RenderBSPNode(
            c, int32(uint32(c.map.nodes.length)) - 1, R_Segs.R_StoreWallRange, R_Things.R_AddSprites
        );
        emit Frame(1, 1, 320, 200, c.rs.framebuffer);
    }
}
