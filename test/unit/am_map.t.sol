// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {AutomapFixture as Fixture} from "../../src/support/AutomapFixture.sol";
import {AM_Map as AM} from "../../src/doom/am_map.sol";
import {AutomapState, AMPoint, AMLine} from "../../src/doom/am_map_types.sol";

interface AutomapVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function toString(uint256) external pure returns (string memory);
}

contract AutomapTest {
    AutomapVm constant vm = AutomapVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function markers() private view returns (bytes[10] memory nums) {
        for (uint256 i; i < 10; ++i) {
            nums[i] =
                vm.readFileBinary(
                string.concat("test/fixtures/phase4_automap/AMMNUM", vm.toString(i), ".bin")
            );
        }
    }

    function digest(bytes memory data, uint256 p) private pure returns (bytes32 n) {
        require(p + 32 <= data.length, "digest bounds");
        assembly ("memory-safe") { n := mload(add(add(data, 32), p)) }
    }

    function run(uint256 index) private view {
        bytes memory data = vm.readFileBinary("test/fixtures/phase4_automap/cases.bin");
        Fixture.Cursor memory c;
        uint32 count = Fixture.word(data, c);
        bytes[10] memory nums = markers();
        require(index < count, "case index");
        for (uint256 k; k < count; ++k) {
            uint32 len = Fixture.word(data, c);
            bytes memory input = new bytes(len);
            for (uint256 j; j < len; ++j) {
                input[j] = data[c.pos + j];
            }
            c.pos += len;
            Fixture.Cursor memory ic;
            Fixture.decode(input, ic);
            uint32 actions = Fixture.word(input, ic);
            if (k != index) {
                c.pos += actions * 64;
                continue;
            }
            (bytes memory sh, bytes memory fh,) = Fixture.replay(input, nums);
            for (uint256 j; j < actions; ++j) {
                require(
                    digest(sh, j * 32) == digest(data, c.pos), string.concat("state action ", vm.toString(j))
                );
                require(
                    digest(fh, j * 32) == digest(data, c.pos + 32),
                    string.concat("pixels action ", vm.toString(j))
                );
                c.pos += 64;
            }
            return;
        }
        revert("fixture case not exercised");
    }

    function testNativeWallDiscoveryAndAllmapCheats() public view {
        run(0);
    }

    function testNativePanZoomFollow() public view {
        run(1);
    }

    function testNativeClampsBigRestoreReopen() public view {
        run(2);
    }

    function testNativeGridAndMarkerRing() public view {
        run(3);
    }

    function testNativeFollowStationaryZoomRestore() public view {
        run(4);
    }

    function testNativeCheatMismatchEventsDeathmatch() public view {
        run(5);
    }

    function testNativeFallbackPlayer() public view {
        run(6);
    }

    function testNativeMarkerEdgesSentinel() public view {
        run(7);
    }

    function testNativeRotations() public view {
        for (uint256 i = 8; i < 17; ++i) {
            run(i);
        }
    }

    function testNativeClipOctantsBoundaries() public view {
        run(17);
    }

    function testNativeE1M1Geometry() public view {
        run(18);
    }

    function testNativeRandomFixedCoordinateClipping() public view {
        run(19);
    }

    function testNativeOriginalSlopeAndLightHelpers() public view {
        run(20);
    }

    function testNativeBoundaryVertexOrder() public view {
        run(21);
    }

    function testGlyphDrawingDoesNotMutateVectorDefinitions() public pure {
        AutomapState memory s;
        s.scale = 65536;
        s.inverse = 65536;
        s.x = -160 * 65536;
        s.y = -84 * 65536;
        s.x2 = 160 * 65536;
        s.y2 = 84 * 65536;
        AMLine[] memory glyph = AM.playerArrow(false);
        bytes32 before = keccak256(abi.encode(glyph));
        AM.AM_drawLineCharacter(s, new bytes(64000), glyph, 2 * 65536, 0x12345678, 209, 0, 0);
        require(keccak256(abi.encode(glyph)) == before, "borrowed glyph changed");
    }

    function testSlopesAndDisabledLightTickerHelper() public pure {
        (int32 slope, int32 inverse) = AM.AM_getIslope(AMLine(AMPoint(0, 0), AMPoint(65536, 0)));
        require(slope == 0 && inverse == 2147483647, "horizontal");
        (slope, inverse) = AM.AM_getIslope(AMLine(AMPoint(0, 0), AMPoint(0, 65536)));
        require(slope == -2147483647 && inverse == 0, "vertical");
        AutomapState memory s;
        s.clock = 1;
        AM.AM_updateLightLev(s);
        require(s.light == 0 && s.nextLight == 6, "light0");
        s.clock = 7;
        AM.AM_updateLightLev(s);
        require(s.light == 4 && s.nextLight == 12, "light1");
    }

    function testFuzzBresenhamEndpointBounds(uint16 ax, uint16 ay, uint16 bx, uint16 by) public pure {
        AMLine memory l = AMLine(
            AMPoint(int32(uint32(ax % 320)), int32(uint32(ay % 168))),
            AMPoint(int32(uint32(bx % 320)), int32(uint32(by % 168)))
        );
        bytes memory fb = new bytes(64000);
        AM.AM_drawFline(fb, l, 176);
        require(
            fb[uint32(l.a.y) * 320 + uint32(l.a.x)] == 0xb0
                && fb[uint32(l.b.y) * 320 + uint32(l.b.x)] == 0xb0,
            "inclusive endpoints"
        );
        for (uint256 i = 53760; i < 64000; ++i) {
            require(fb[i] == 0, "status rows");
        }
    }
}
