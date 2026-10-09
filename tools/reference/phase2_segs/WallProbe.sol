// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {R_Data} from "../../../src/doom/r_data.sol";
import {R_Main} from "../../../src/doom/r_main.sol";
import {R_BSP} from "../../../src/doom/r_bsp.sol";
import {R_Plane} from "../../../src/doom/r_plane.sol";
import {R_Segs} from "../../../src/doom/r_segs.sol";
import {ResourceView} from "../../../src/doom/r_data_types.sol";
import {LumpDescriptor, ResourceIdentity} from "../../../src/evm/ResourceTypes.sol";
import {RenderContext} from "../../../src/doom/r_render_state.sol";

/// @notice Ordinary-EVM wall measurement fixture; separate source-mapped MSIZE telemetry deployment.
contract WallProbe {
    ResourceView private resources;

    struct Report {
        uint256[3] gasUsed;
        uint256[5] memoryBytes;
        bytes32 pixels;
        uint256 drawsegs;
        uint256 planes;
        uint256 openings;
    }

    constructor(address[] memory chunks, bytes memory directory) {
        require(chunks.length == 1755 && directory.length == 3163 * 16);
        resources.identity = ResourceIdentity(
            0,
            0x7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d,
            0xd379076f21645cf7cc5acb056663d0faacc4065489a0ca99738479323c9f7a47,
            0xfd895921b5d0a394612bb29852ed003d44d69f76dec31c0dc6b5d5fc7d63f7bb,
            0
        );
        resources.byteLength = 28741889;
        for (uint256 i; i < chunks.length; ++i) {
            require(chunks[i].code.length == (i == 1754 ? 4354 : 16385));
            resources.chunks.push(chunks[i]);
        }
        for (uint256 i; i < 3163; ++i) {
            uint256 p = i * 16;
            bytes8 name;
            assembly ("memory-safe") { name := mload(add(add(directory, 32), p)) }
            resources.lumps.push(LumpDescriptor(name, le32(directory, p + 8), le32(directory, p + 12)));
        }
    }

    function le32(bytes memory data, uint256 p) private pure returns (uint32) {
        return uint32(uint8(data[p])) | uint32(uint8(data[p + 1])) << 8 | uint32(uint8(data[p + 2])) << 16
            | uint32(uint8(data[p + 3])) << 24;
    }

    function memorySize() private view returns (uint256 size) {
        // MSIZE_PATCH_MARKER: only this helper's source-mapped GAS becomes MSIZE in the separate telemetry deployment.
        assembly ("memory-safe") { size := gas() }
    }
    function noSprites(RenderContext memory, uint32) internal pure {}

    function render(uint32 angle) external view returns (Report memory report) {
        require(angle % 0x20000000 == 0);
        report.memoryBytes[0] = memorySize();
        uint256 start = gasleft();
        ResourceView memory source = resources;
        report.gasUsed[0] = start - gasleft();
        report.memoryBytes[1] = memorySize();
        start = gasleft();
        RenderContext memory c;
        c.resources = R_Data.R_InitDataLazy(source);
        c.map = R_Data.R_LoadMap(c.resources, "E1M1");
        c.skyflatnum = R_Data.R_FlatNumForName(c.resources, "F_SKY1");
        c.skytexture = R_Data.R_TextureNumForName(c.resources, "SKY1");
        c.skytexturemid = 100 * 65536;
        R_Main.R_ExecuteSetViewSize(c.rs, 11, 0);
        c.rs.validcount = 1;
        R_Main.R_SetupFrame(c.rs, -27262976, 16777216, 2686976, angle, 0, -1);
        c.rs.framebuffer = new bytes(64000);
        R_BSP.R_ClearClipSegs(c);
        R_BSP.R_ClearDrawSegs(c);
        R_Plane.R_ClearPlanes(c);
        report.gasUsed[1] = start - gasleft();
        report.memoryBytes[2] = memorySize();
        start = gasleft();
        R_BSP.R_RenderBSPNode(c, int32(uint32(c.map.nodes.length - 1)), R_Segs.R_StoreWallRange, noSprites);
        report.gasUsed[2] = start - gasleft();
        report.memoryBytes[3] = memorySize();
        report.pixels = sha256(c.rs.framebuffer);
        report.memoryBytes[4] = memorySize();
        report.drawsegs = c.drawsegCount;
        report.planes = c.visplaneCount;
        report.openings = c.openingCount;
    }
}
