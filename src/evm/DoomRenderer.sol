// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {DoomScene, StaticCamera} from "./DoomScene.sol";
import {ResourceView} from "../doom/r_data_types.sol";
import {RenderContext} from "../doom/r_render_state.sol";
import {RenderHooks} from "../doom/r_render_hooks.sol";
import {Info, InfoData} from "../doom/info.sol";
import {P_SetupStatic} from "../doom/p_setup_static.sol";
import {R_Main} from "../doom/r_main.sol";
import {R_BSP} from "../doom/r_bsp.sol";
import {R_Plane} from "../doom/r_plane.sol";
import {R_Segs} from "../doom/r_segs.sol";
import {R_Things} from "../doom/r_things.sol";

/// @notice EVM integration for the original renderer's complete static world-view pipeline.
library DoomRenderer {
    function initialize(ResourceView memory source) internal view returns (RenderContext memory ctx) {
        StaticCamera memory camera;
        (ctx, camera) = DoomScene.load(source);
        InfoData memory info = Info.load();
        R_Things.R_InitSprites(ctx, info.spriteNames);
        P_SetupStatic.load(ctx, info);
        ctx.rs.viewx = camera.x;
        ctx.rs.viewy = camera.y;
        ctx.rs.viewz = camera.z;
        ctx.rs.viewangle = camera.angle;
        ctx.rs.extralight = 0;
        ctx.rs.fixedcolormap = -1;
    }

    function render(RenderContext memory ctx) internal view {
        RenderHooks memory hooks = RenderHooks(
            R_BSP.R_ClearClipSegs,
            R_BSP.R_ClearDrawSegs,
            R_Plane.R_ClearPlanes,
            R_Things.R_ClearSprites,
            _bsp,
            R_Plane.R_DrawPlanes,
            _masked
        );
        R_Main.R_RenderPlayerView(ctx, hooks);
    }

    function _bsp(RenderContext memory ctx, int32 node) private view {
        R_BSP.R_RenderBSPNode(ctx, node, R_Segs.R_StoreWallRange, R_Things.R_AddSprites);
    }

    function _maskedRange(RenderContext memory ctx, uint32 drawseg, int32 x1, int32 x2) private view {
        R_Segs.R_RenderMaskedSegRange(ctx, drawseg, x1, x2, R_Things.R_DrawMaskedColumn);
    }

    function _masked(RenderContext memory ctx) private view {
        R_Things.R_DrawMasked(ctx, _maskedRange);
    }
}
