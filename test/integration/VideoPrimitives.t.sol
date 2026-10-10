// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {VideoProbe} from "../../src/support/VideoProbe.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";

interface VideoIntegrationVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function readFileBinary(string calldata) external view returns (bytes memory);
    function etch(address, bytes calldata) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

contract VideoPrimitivesTest {
    VideoIntegrationVm constant vm =
        VideoIntegrationVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function resources() private returns (ResourceView memory source) {
        bytes memory patch = vm.readFileBinary("test/fixtures/phase4_video/patch-2.bin");
        address chunk = address(0xABCD);
        vm.etch(chunk, bytes.concat(hex"00", patch));
        source.byteLength = uint32(patch.length);
        source.chunks = new address[](1);
        source.chunks[0] = chunk;
        source.lumps = new LumpDescriptor[](1);
        source.lumps[0] = LumpDescriptor(bytes8("STFST00"), 0, uint32(patch.length));
    }

    function check(bool world168) private {
        VideoProbe probe = new VideoProbe();
        ResourceView memory source = resources();
        vm.recordLogs();
        probe.render(source, 0, 40, 30, 7, world168);
        VideoIntegrationVm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 1 && logs[0].emitter == address(probe), "single EVM Frame");
        require(
            logs[0].topics.length == 3
                && logs[0].topics[0] == keccak256("Frame(uint64,uint32,uint16,uint16,bytes)"),
            "frozen ABI"
        );
        require(uint256(logs[0].topics[1]) == 1 && uint256(logs[0].topics[2]) == 7, "frame metadata");
        (uint16 width, uint16 height, bytes memory frame) = abi.decode(logs[0].data, (uint16, uint16, bytes));
        require(width == 320 && height == 200 && frame.length == 64000, "indexed8 output");
        bytes memory patch = vm.readFileBinary("test/fixtures/phase4_video/patch-2.bin");
        uint256 w = uint8(patch[0]) + uint256(uint8(patch[1])) * 256;
        uint256 originX =
            uint256(int256(40) - int16(uint16(uint8(patch[4])) | (uint16(uint8(patch[5])) << 8)));
        uint256 originY =
            uint256(int256(30) - int16(uint16(uint8(patch[6])) | (uint16(uint8(patch[7])) << 8)));
        bytes memory expected = new bytes(64000);
        for (uint256 i; i < 64000; ++i) {
            expected[i] = bytes1(uint8(i * 13 + (i / 320) * 7 + 19));
        }
        if (world168) {
            for (uint256 y; y < 168; ++y) {
                expected[y * 320] = 0x77;
            }
        }
        for (uint256 col; col < w; ++col) {
            uint256 at = 8 + col * 4;
            uint256 p;
            for (uint256 j; j < 4; ++j) {
                p |= uint256(uint8(patch[at + j])) << (j * 8);
            }
            while (patch[p] != 0xff) {
                uint256 count = uint8(patch[p + 1]);
                for (uint256 row; row < count; ++row) {
                    expected[(originY + uint8(patch[p]) + row) * 320 + originX + col] = patch[p + 3 + row];
                }
                p += count + 4;
            }
        }
        require(sha256(frame) == sha256(expected), "all EVM patch and renderer pixels");
        for (uint256 y = 168; y < 200; ++y) {
            require(frame[y * 320] == bytes1(uint8(y * 320 * 13 + y * 7 + 19)), "status area retained");
        }
    }

    function testEVMResourcePatchFrameFullScreen() public {
        check(false);
    }

    function testEVMResourcePatchFrameWorld168AndStatus32() public {
        check(true);
    }
}
