// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {ResourceView} from "../doom/r_data_types.sol";
import {RenderContext} from "../doom/r_render_state.sol";
import {MapData, MapThing, Sector} from "../doom/r_defs.sol";
import {R_Data} from "../doom/r_data.sol";
import {R_Main} from "../doom/r_main.sol";
import {Tables} from "../doom/tables.sol";

struct StaticCamera {
    int32 x;
    int32 y;
    int32 z;
    uint32 angle;
}

/// @notice Static E1M1 startup adapter. Geometry and camera placement execute inside the EVM.
/// @dev Combines original R_Init/view-size setup and the declared stationary player-start
/// camera policy. No simulation, host visibility, projected geometry, or frame pixels are inputs.
library DoomScene {
    error MissingPlayerStart();

    function load(ResourceView memory source)
        internal
        view
        returns (RenderContext memory ctx, StaticCamera memory camera)
    {
        ctx.resources = R_Data.R_InitDataLazy(source);
        ctx.map = R_Data.R_LoadMap(ctx.resources, "E1M1");
        camera = playerStart(ctx.map);
        ctx.skyflatnum = R_Data.R_FlatNumForName(ctx.resources, "F_SKY1");
        ctx.skytexture = R_Data.R_TextureNumForName(ctx.resources, "SKY1");
        // Original R_InitSkyMap, r_sky.c.
        ctx.skytexturemid = 100 * 65536;
        ctx.rs.validcount = 1;
        ctx.rs.framebuffer = new bytes(320 * 200);
        R_Main.R_InitLightTables(ctx.rs);
        R_Main.R_ExecuteSetViewSize(ctx.rs, 11, 0);
        ctx.sectorValidcount = new uint32[](ctx.map.sectors.length);
    }

    /// @dev Same player-one selection and angle quantization as the native static host.
    /// Last player-one start wins, matching sequential P_LoadThings/P_SpawnPlayer setup.
    /// Stationary viewz is min(floor+41, ceiling-4); bob and gameplay ticks are outside Phase 2.
    function playerStart(MapData memory map) internal pure returns (StaticCamera memory camera) {
        bool found;
        for (uint256 i; i < map.things.length; ++i) {
            MapThing memory thing = map.things[i];
            if (thing.thingType != 1) continue;
            found = true;
            camera.x = int32(thing.x) * 65536;
            camera.y = int32(thing.y) * 65536;
            unchecked {
                camera.angle = uint32(int32(thing.angle) / 45) * Tables.ANG45;
            }
        }
        if (!found) revert MissingPlayerStart();
        uint32 subsector = R_Main.R_PointInSubsector(camera.x, camera.y, map);
        Sector memory sector = map.sectors[map.subsectors[subsector].sector];
        // Explicit int32 wrapping follows the pinned native -fwrapv profile at extreme heights.
        int32 limit;
        unchecked {
            camera.z = sector.floorheight + 41 * 65536;
            limit = sector.ceilingheight - 4 * 65536;
        }
        if (camera.z > limit) camera.z = limit;
    }
}
