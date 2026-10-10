// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {HudTestBase} from "./hu_stuff.t.sol";
import {HU_Lib, HuTextLine, HuSText} from "../../src/doom/hu_lib.sol";
import {VideoState} from "../../src/doom/v_video_types.sol";
import {RenderState} from "../../src/doom/r_state.sol";

contract HULibTest is HudTestBase {
    function testLineCapacityNulDeletionAndClearUpdateCounts() public view {
        HuTextLine memory l;
        HU_Lib.HUlib_initTextLine(l, 0, 0, fonts(), 33);
        require(l.needsupdate == 1 && !HU_Lib.HUlib_delCharFromTextLine(l));
        for (uint256 i; i < 80; ++i) {
            require(HU_Lib.HUlib_addCharToTextLine(l, 0x61));
        }
        require(
            !HU_Lib.HUlib_addCharToTextLine(l, 0x62) && l.len == 80 && l.text[80] == 0 && l.needsupdate == 4
        );
        require(HU_Lib.HUlib_delCharFromTextLine(l) && l.len == 79 && l.text[79] == 0);
        HU_Lib.HUlib_clearTextLine(l);
        require(l.len == 0 && l.text[0] == 0 && l.needsupdate == 1 && l.text[1] == 0x61);
    }

    function testPrefixAndMessageShareEightyByteLimit() public view {
        HuSText memory s;
        HU_Lib.HUlib_initSText(s, 0, 0, 1, fonts(), 33);
        bytes memory prefix = new bytes(79);
        for (uint256 i; i < 79; ++i) {
            prefix[i] = 0x50;
        }
        HU_Lib.HUlib_addMessageToSText(s, prefix, "abc");
        require(s.lines[0].len == 80 && s.lines[0].text[79] == 0x61 && s.lines[0].text[80] == 0);
    }

    function testPositionUsesPatchOffsetsWithoutGlyphScaling() public view {
        bytes[] memory f = fonts();
        // Width2 height4, offsets(-2,-3), transparency and multiple posts from accepted V tests.
        f[32] = hex"02000400fefffdff100000001b00000000010011000201002200ff010200334400ff";
        HuTextLine memory l;
        HU_Lib.HUlib_initTextLine(l, 8, 7, f, 33);
        HU_Lib.HUlib_addCharToTextLine(l, 0x41);
        VideoState memory v;
        v.screens[0] = new bytes(64000);
        HU_Lib.HUlib_drawTextLine(l, v, false);
        require(v.screens[0][3210] == 0x11 && v.screens[0][3850] == 0x22 && v.screens[0][3531] == 0x33);
        require(v.screens[0][3530] == 0 && v.screens[0][3851] == 0x44);
    }

    function testFuzzTextCapacityAndTrailingNul(bytes calldata input) public view {
        HuTextLine memory l;
        HU_Lib.HUlib_initTextLine(l, 0, 0, fonts(), 33);
        uint256 n = input.length;
        if (n > 160) n = 160;
        for (uint256 i; i < n; ++i) {
            require(HU_Lib.HUlib_addCharToTextLine(l, input[i]) == (i < 80));
        }
        require(l.len == (n > 80 ? 80 : n) && l.text[l.len] == 0);
    }

    function invalidHeight(uint32 h) external view {
        HuSText memory s;
        HU_Lib.HUlib_initSText(s, 0, 0, h, fonts(), 33);
    }

    function testUndefinedScrollingWidgetHeightRejected() public {
        for (uint32 h; h < 6; h += 5) {
            (bool ok, bytes memory err) = address(this).call(abi.encodeCall(this.invalidHeight, (h)));
            require(!ok && bytes4(err) == HU_Lib.InvalidTextWidget.selector);
        }
    }
}
