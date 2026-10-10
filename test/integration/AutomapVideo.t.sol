// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {AM_Map as AM} from "../../src/doom/am_map.sol";
import {AutomapState, AMWorld, AMPoint, AMActor} from "../../src/doom/am_map_types.sol";
import {VideoState} from "../../src/doom/v_video_types.sol";
import {V_Video as V} from "../../src/doom/v_video.sol";
import {RenderState} from "../../src/doom/r_state.sol";
import {AutomapProbe} from "../../src/support/AutomapProbe.sol";

interface AutomapVideoVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function readFileBinary(string calldata) external view returns (bytes memory);
    function toString(uint256) external pure returns (string memory);
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

contract AutomapVideoTest {
    AutomapVideoVm constant vm = AutomapVideoVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testRendererScreenZeroAliasAndStatusRowsSurviveDrawer() public pure {
        RenderState memory rs;
        rs.framebuffer = new bytes(64000);
        rs.width = 320;
        rs.height = 168;
        VideoState memory v;
        v.screens[0] = rs.framebuffer;
        v.screens[1] = hex"abcd";
        for (uint256 i = 53760; i < 64000; ++i) {
            rs.framebuffer[i] = 0x77;
        }
        AMWorld memory w;
        w.episode = 1;
        w.map = 1;
        w.vertices = new AMPoint[](4);
        w.vertices[0] = AMPoint(-256 * 65536, -256 * 65536);
        w.vertices[1] = AMPoint(256 * 65536, -256 * 65536);
        w.vertices[2] = AMPoint(256 * 65536, 256 * 65536);
        w.vertices[3] = AMPoint(-256 * 65536, 256 * 65536);
        w.players[0] = AMActor(0, 0, 0, true, false);
        AutomapState memory s;
        AM.AM_Init(s);
        require(AM.AM_Responder(s, w, 0, 9), "enter");
        bytes[10] memory nums;
        AM.AM_Drawer(s, w, v, nums);
        require(rs.framebuffer[27040] == 0x60, "alias crosshair");
        for (uint256 i = 53760; i < 64000; ++i) {
            require(rs.framebuffer[i] == 0x77, "status row changed");
        }
        require(keccak256(v.screens[1]) == keccak256(hex"abcd"), "screen1 changed");
        require(v.dirtybox[0] == 167 && v.dirtybox[3] == 319, "video dirty bounds");
        bytes memory pixel = hex"55";
        V.V_DrawBlock(v, 0, 168, 0, 1, 1, pixel);
        require(rs.framebuffer[53760] == 0x55, "video composition alias");
    }

    function testFrozenFrameAbiContainsNativeEquivalentAutomapPixels() public {
        AutomapProbe p = new AutomapProbe();
        bytes[10] memory nums;
        for (uint256 i; i < 10; ++i) {
            nums[i] =
                vm.readFileBinary(
                string.concat("test/fixtures/phase4_automap/AMMNUM", vm.toString(i), ".bin")
            );
        }
        vm.recordLogs();
        p.render(vm.readFileBinary("test/fixtures/phase4_automap/18.bin"), nums, 45);
        AutomapVideoVm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 2, "evidence and frame");
        require(
            logs[1].topics[0] == keccak256("Frame(uint64,uint32,uint16,uint16,bytes)"), "frozen signature"
        );
        require(uint256(logs[1].topics[1]) == 1 && uint256(logs[1].topics[2]) == 45, "counters");
        (uint16 width, uint16 height, bytes memory pixels) = abi.decode(logs[1].data, (uint16, uint16, bytes));
        require(width == 320 && height == 200 && pixels.length == 64000, "frame shape");
        (bytes memory sh, bytes memory fh) = abi.decode(logs[0].data, (bytes, bytes));
        require(sh.length == 21 * 32 && fh.length == 21 * 32, "action evidence");
        bytes32 last;
        assembly ("memory-safe") { last := mload(add(fh, mload(fh))) }
        require(sha256(pixels) == last, "final snapshot pixels");
        bytes memory golden = vm.readFileBinary("test/fixtures/phase4_automap/18.hashes.bin");
        bytes32 native;
        assembly ("memory-safe") { native := mload(add(golden, mload(golden))) }
        require(sha256(pixels) == native, "original C E1M1 pixels");
    }
}
