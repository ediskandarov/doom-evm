// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {V_Video as V} from "../doom/v_video.sol";
import {VideoState} from "../doom/v_video_types.sol";
import {M_BBox} from "../doom/m_bbox.sol";
import {R_Data} from "../doom/r_data.sol";
import {ResourceView} from "../doom/r_data_types.sol";
import {RenderState, DrawColumn} from "../doom/r_state.sol";
import {R_Draw} from "../doom/r_draw.sol";
import {IFrameProtocol} from "../evm/FrameProtocol.sol";

/// @notice Verification support only. Original WAD bytes enter the EVM; all graphics run here.
/// No UI module or production gameplay dispatch. Sources are supplied test resource views.
contract VideoProbe is IFrameProtocol {
    uint64 public frameId;

    function render(ResourceView memory source, uint32 lump, int32 x, int32 y, uint32 sequence, bool world168)
        external
    {
        VideoState memory v;
        V.V_Init(v);
        M_BBox.M_ClearBox(v.dirtybox);
        for (uint256 i; i < 64000; ++i) {
            v.screens[0][i] = bytes1(uint8(i * 13 + (i / 320) * 7 + 19));
        }
        RenderState memory rs;
        rs.framebuffer = v.screens[0];
        rs.width = 320;
        rs.height = world168 ? 168 : 200;
        R_Draw.R_InitBuffer(rs, rs.width, rs.height);
        if (world168) {
            DrawColumn memory dc;
            dc.x = 0;
            dc.yl = 0;
            dc.yh = 167;
            dc.source = new bytes(128);
            dc.colormap = new bytes(256);
            dc.colormap[0] = 0x77;
            R_Draw.R_DrawColumn(rs, dc);
        }
        V.V_DrawPatch(v, x, y, 0, R_Data.W_CacheLumpNum(source, lump));
        emit Frame(++frameId, sequence, 320, 200, rs.framebuffer);
    }
}
