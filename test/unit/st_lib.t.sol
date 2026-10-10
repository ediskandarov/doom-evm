// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {ST_Lib as L, STNumber, STMultIcon, STBinIcon, STPercent} from "../../src/doom/st_lib.sol";
import {VideoState} from "../../src/doom/v_video_types.sol";
import {V_Video as V} from "../../src/doom/v_video.sol";

contract STLibTest {
    function patch() private pure returns (bytes memory) {
        // width1,height1,left=-2,top=-1; literal pixel 0x77.
        return hex"01000100feffffff0c0000000001007700ff";
    }

    function fresh() private pure returns (VideoState memory v) {
        v.screens[0] = new bytes(64000);
        v.screens[4] = new bytes(10240);
        for (uint256 i; i < 10240; ++i) {
            v.screens[4][i] = 0x23;
        }
    }

    function icons() private pure returns (bytes[] memory p) {
        p = new bytes[](2);
        p[0] = patch();
        p[1] = patch();
    }

    function testMultIconOffsetsRestoreAndMinusOneLeavesHistory() public pure {
        VideoState memory v = fresh();
        STMultIcon memory i;
        L.STlib_initMultIcon(i, 12, 170, icons());
        L.STlib_updateMultIcon(v, i, 0, true, false);
        require(v.screens[0][171 * 320 + 14] == 0x77, "offset draw");
        L.STlib_updateMultIcon(v, i, -1, true, false);
        require(i.oldinum == 0 && v.screens[0][171 * 320 + 14] == 0x77, "original stale icon");
        v.screens[0][171 * 320 + 14] = 0x55;
        L.STlib_updateMultIcon(v, i, 0, true, false);
        require(v.screens[0][171 * 320 + 14] == 0x55, "no redraw unchanged");
        L.STlib_updateMultIcon(v, i, 0, true, true);
        require(v.screens[0][171 * 320 + 14] == 0x77, "refresh redraw");
        L.STlib_updateMultIcon(v, i, 1, false, true);
        require(i.oldinum == 0, "disabled history");
    }

    function testBinaryIconFalseRestoresBackground() public pure {
        VideoState memory v = fresh();
        STBinIcon memory i;
        L.STlib_initBinIcon(i, 12, 170, patch());
        L.STlib_updateBinIcon(v, i, true, true, false);
        require(v.screens[0][171 * 320 + 14] == 0x77, "draw");
        L.STlib_updateBinIcon(v, i, false, true, false);
        require(v.screens[0][171 * 320 + 14] == 0x23 && !i.oldval, "restore with offsets");
        L.STlib_updateBinIcon(v, i, true, false, true);
        require(!i.oldval, "disabled history");
    }

    function invalid(uint8 kind) external pure {
        VideoState memory v = fresh();
        if (kind == 0) {
            STNumber memory n;
            L.STlib_initNum(n, 44, 167, icons(), 3);
            L.STlib_updateNum(v, n, 1, true, false, patch());
        } else if (kind == 1) {
            STBinIcon memory i;
            L.STlib_initBinIcon(i, 12, 166, patch());
            L.STlib_updateBinIcon(v, i, true, true, false);
        } else if (kind == 2) {
            STMultIcon memory i;
            L.STlib_initMultIcon(i, 12, 166, icons());
            i.oldinum = 0;
            L.STlib_updateMultIcon(v, i, 1, true, false);
        } else {
            STNumber memory n;
            L.STlib_initNum(n, 44, 171, icons(), 1);
            L.STlib_updateNum(v, n, type(int32).min, true, false, patch());
        }
    }

    function testRejectsOriginalWidgetFatalBoundsAndUndefinedNegation() public {
        for (uint8 i; i < 4; ++i) {
            (bool ok, bytes memory err) = address(this).call(abi.encodeCall(this.invalid, (i)));
            require(!ok && bytes4(err) == L.WidgetBounds.selector, "widget rejection");
        }
    }

    function testDisabledWidgetsDoNotReadPatchesOrScreens() public pure {
        // Zero-sized buffer is not read by any disabled widget.
        VideoState memory v;
        STBinIcon memory i;
        L.STlib_updateBinIcon(v, i, true, false, true);
        STNumber memory n;
        L.STlib_updateNum(v, n, 100, false, true, hex"");
    }
}
