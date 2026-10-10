// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {V_Video as V} from "../../src/doom/v_video.sol";
import {VideoState} from "../../src/doom/v_video_types.sol";
import {M_BBox} from "../../src/doom/m_bbox.sol";

interface VideoVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function toString(uint256) external pure returns (string memory);
}

contract VVideoTest {
    VideoVm constant vm = VideoVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    // Two columns; signed offsets (-2,-3); transparent gaps and two posts in column 0.
    function patch() private pure returns (bytes memory) {
        return hex"02000400fefffdff100000001b00000000010011000201002200ff010200334400ff";
    }

    function fresh() private pure returns (VideoState memory v) {
        V.V_Init(v);
        M_BBox.M_ClearBox(v.dirtybox);
    }

    function testInitFourScreensAndLeavesCallerScreen4AndDirtybox() public pure {
        VideoState memory v;
        v.screens[4] = new bytes(10240);
        v.screens[4][0] = 0xab;
        v.dirtybox[0] = 123;
        V.V_Init(v);
        for (uint256 i; i < 4; ++i) {
            require(v.screens[i].length == 64000 && v.screens[i][0] == 0, "screen");
        }
        require(v.screens[4][0] == 0xab && v.dirtybox[0] == 123, "original untouched globals");
    }

    function testOffsetsTransparencyFlippedAndDirect() public pure {
        VideoState memory v = fresh();
        V.V_DrawPatch(v, 8, 7, 0, patch()); // origin 10,10
        require(v.screens[0][3210] == 0x11 && v.screens[0][3850] == 0x22, "posts");
        require(v.screens[0][3530] == 0 && v.screens[0][3531] == 0x33 && v.screens[0][3851] == 0x44, "holes");
        V.V_DrawPatchFlipped(v, 8, 7, 1, patch());
        require(v.screens[1][3530] == 0x33 && v.screens[1][3211] == 0x11, "mirror");
        V.V_DrawPatchDirect(v, 8, 7, 2, patch());
        require(sha256(v.screens[0]) == sha256(v.screens[2]), "direct alias");
        require(
            v.dirtybox[0] == 13 && v.dirtybox[1] == 10 && v.dirtybox[2] == 10 && v.dirtybox[3] == 11, "bbox"
        );
    }

    function testRectScreen4StatusBarCopyAndGet() public pure {
        VideoState memory v = fresh();
        v.screens[4] = new bytes(10240);
        V.V_DrawBlock(v, 318, 30, 4, 2, 2, hex"11223344");
        V.V_CopyRect(v, 318, 30, 4, 2, 2, 318, 198, 0);
        bytes memory got = new bytes(4);
        V.V_GetBlock(v, 318, 198, 0, 2, 2, got);
        require(keccak256(got) == keccak256(hex"11223344"), "stride and bottom edge");
    }

    function testVerticalCopyRetainsOriginalRowOrder() public pure {
        VideoState memory v = fresh();
        v.screens[0][0] = 0x12;
        v.screens[0][320] = 0x34;
        V.V_CopyRect(v, 0, 0, 0, 1, 2, 0, 1, 0);
        require(v.screens[0][320] == 0x12 && v.screens[0][640] == 0x12, "sequential memcpy rows");
    }

    function testNormalOutOfBoundsIgnoredBeforeDirtyMark() public pure {
        VideoState memory v = fresh();
        V.V_DrawPatch(v, -3, 0, 0, patch());
        V.V_DrawPatch(v, 318, 197, 0, patch());
        V.V_DrawPatchDirect(v, 0, 0, -1, patch());
        require(v.dirtybox[0] == type(int32).min && v.screens[0][0] == 0, "ignored");
    }

    function callPatch(bytes calldata data, int32 x, int32 y, int32 screen, bool flip, bool small)
        external
        pure
    {
        VideoState memory v = fresh();
        if (small) v.screens[4] = new bytes(10240);
        if (flip) V.V_DrawPatchFlipped(v, x, y, screen, data);
        else V.V_DrawPatch(v, x, y, screen, data);
    }

    function expect(bytes memory data, int32 x, int32 y, int32 screen, bool flip, bool small, bytes4 selector)
        private
    {
        (bool ok, bytes memory err) =
            address(this).call(abi.encodeCall(this.callPatch, (data, x, y, screen, flip, small)));
        require(!ok && bytes4(err) == selector, "strict diagnostic");
    }

    function testMalformedHeadersOffsetsPostsAndPhysicalBounds() public {
        expect(hex"00", 0, 0, 0, false, false, V.MalformedPatch.selector);
        expect(hex"01000400000000000c0000000001001100", 0, 0, 0, false, false, V.MalformedPatch.selector);
        expect(hex"ffff040000000000", 0, 0, 0, false, false, V.MalformedPatch.selector);
        expect(hex"010004000000000000000000", 0, 0, 0, false, false, V.MalformedPatch.selector);
        expect(hex"0100040000000000ffffffff", 0, 0, 0, false, false, V.MalformedPatch.selector);
        expect(hex"01000400000000000c00000000010011", 0, 0, 0, false, false, V.MalformedPatch.selector);
        expect(hex"01000400000000000c000000030200112200ff", 0, 0, 0, false, false, V.MalformedPatch.selector);
        expect(patch(), -3, 0, 0, true, false, V.VideoBounds.selector);
        expect(patch(), 0, 30, 4, false, true, V.VideoBounds.selector);
        expect(patch(), 0, 0, 4, false, false, V.VideoBounds.selector);
    }

    function testFuzzMalformedPatchRejectsWithoutPanic(
        bytes calldata data,
        int32 x,
        int32 y,
        int32 screen,
        bool flip
    ) public {
        (bool ok, bytes memory err) =
            address(this).call(abi.encodeCall(this.callPatch, (data, x, y, screen, flip, false)));
        require(
            ok || bytes4(err) == V.MalformedPatch.selector || bytes4(err) == V.VideoBounds.selector,
            "only documented domains"
        );
    }

    function badRect(uint256 op) external pure {
        VideoState memory v = fresh();
        if (op == 0) V.V_DrawBlock(v, 0, 0, 0, -1, 1, hex"11");
        if (op == 1) V.V_DrawBlock(v, 0, 0, 0, 2, 1, hex"11");
        if (op == 2) V.V_GetBlock(v, 0, 0, 0, 2, 1, new bytes(1));
        if (op == 3) V.V_CopyRect(v, 0, 0, 0, 320, 1, 1, 0, 0);
        if (op == 4) V.V_CopyRect(v, 0, 0, 0, 2, 1, 1, 0, 0);
    }

    function testRectBoundsShortBuffersAndUndefinedOverlap() public {
        for (uint256 op; op < 5; ++op) {
            (bool ok, bytes memory err) = address(this).call(abi.encodeCall(this.badRect, (op)));
            require(
                !ok && bytes4(err) == (op == 4 ? V.OverlappingCopy.selector : V.VideoBounds.selector),
                "rect reject"
            );
        }
    }

    function signedWord(bytes memory b, uint256 p) private pure returns (int32 value) {
        assembly ("memory-safe") { value := signextend(3, shr(224, mload(add(add(b, 32), p)))) }
    }

    function digest(bytes memory b, uint256 p) private pure returns (bytes32 value) {
        assembly ("memory-safe") { value := mload(add(add(b, 32), p)) }
    }

    function nativeCase(int32[13] calldata a, bytes calldata pic)
        external
        pure
        returns (int32[4] memory, bytes32[6] memory hashes)
    {
        VideoState memory v = fresh();
        v.screens[4] = new bytes(320 * uint32(a[11]));
        bytes memory pattern = new bytes(768);
        for (uint256 i; i < 768; ++i) {
            pattern[i] = bytes1(uint8(i * 13));
        }
        for (uint256 screen; screen < 5; ++screen) {
            bytes memory data = v.screens[screen];
            for (uint256 row; row < data.length / 320; ++row) {
                uint256 offset = ((row * 71 + screen * 41 + uint32(a[10])) * 197) & 255;
                uint256 pos = row * 320;
                // Complete 320-byte row lies inside both Solidity allocations (pattern has 768 bytes).
                assembly ("memory-safe") {
                    mcopy(add(add(data, 32), pos), add(add(pattern, 32), offset), 320)
                }
            }
        }
        bytes memory output = new bytes(0);
        if (a[0] == 1) V.V_MarkRect(v, a[1], a[2], a[4], a[5]);
        if (a[0] == 2) V.V_CopyRect(v, a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8]);
        if (a[0] == 3) V.V_DrawPatch(v, a[1], a[2], a[3], pic);
        if (a[0] == 4) V.V_DrawPatchFlipped(v, a[1], a[2], a[3], pic);
        if (a[0] == 5) V.V_DrawPatchDirect(v, a[1], a[2], a[3], pic);
        if (a[0] == 6) {
            bytes memory src = new bytes(uint32(a[4]) * uint32(a[5]));
            for (uint256 i; i < src.length; ++i) {
                src[i] = bytes1(uint8(i * 17 + uint32(a[10]) + 3));
            }
            V.V_DrawBlock(v, a[1], a[2], a[3], a[4], a[5], src);
        }
        if (a[0] == 7) {
            output = new bytes(uint32(a[4]) * uint32(a[5]));
            V.V_GetBlock(v, a[1], a[2], a[3], a[4], a[5], output);
        }
        for (uint256 i; i < 5; ++i) {
            hashes[i] = sha256(v.screens[i]);
        }
        hashes[5] = sha256(output);
        return (v.dirtybox, hashes);
    }

    function nativeRange(uint256 start, uint256 end) private {
        bytes memory data = vm.readFileBinary("test/fixtures/phase4_video/cases.bin");
        require(data.length == 58 * 260, "complete native cases");
        for (uint256 row = start; row < end; ++row) {
            int32[13] memory a;
            uint256 at = row * 260;
            for (uint256 i; i < 13; ++i) {
                a[i] = signedWord(data, at + i * 4);
            }
            bytes memory pic = a[9] < 0
                ? new bytes(0)
                : vm.readFileBinary(
                    string.concat("test/fixtures/phase4_video/patch-", vm.toString(uint32(a[9])), ".bin")
                );
            (bool ok, bytes memory ret) = address(this).call(abi.encodeCall(this.nativeCase, (a, pic)));
            if (a[12] == 1) {
                require(!ok && bytes4(ret) == V.VideoBounds.selector, "original I_Error");
                continue;
            }
            require(ok, "native defined case succeeds");
            (int32[4] memory box, bytes32[6] memory hashes) = abi.decode(ret, (int32[4], bytes32[6]));
            for (uint256 i; i < 4; ++i) {
                require(box[i] == signedWord(data, at + 52 + i * 4), "original dirtybox");
            }
            for (uint256 i; i < 6; ++i) {
                require(hashes[i] == digest(data, at + 68 + i * 32), "original native bytes");
            }
        }
    }

    function testNativeCases00to07() public {
        nativeRange(0, 8);
    }

    function testNativeCases08to15() public {
        nativeRange(8, 16);
    }

    function testNativeCases16to23() public {
        nativeRange(16, 24);
    }

    function testNativeCases24to31() public {
        nativeRange(24, 32);
    }

    function testNativeCases32to39() public {
        nativeRange(32, 40);
    }

    function testNativeCases40to47() public {
        nativeRange(40, 48);
    }

    function testNativeCases48to57() public {
        nativeRange(48, 58);
    }
}
