// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {StatusBarFrame} from "../statusbar/StatusBarFrame.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";

interface StatusIntegrationVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function readFileBinary(string calldata) external view returns (bytes memory);
    function etch(address, bytes calldata) external;
    function toString(uint256) external pure returns (string memory);
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

contract StatusBarIntegrationTest {
    StatusIntegrationVm constant vm =
        StatusIntegrationVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function installChunk(uint256 i) external {
        vm.etch(
            address(uint160(0x100000 + i)),
            vm.readFileBinary(string.concat("artifacts/local/wad/phase2-chunks/", vm.toString(i), ".bin"))
        );
    }

    function setUp() public {
        for (uint256 i; i < 1755; ++i) {
            this.installChunk(i);
        }
    }

    function source() private view returns (ResourceView memory r) {
        r.byteLength = 28741889;
        r.chunks = new address[](1755);
        for (uint256 i; i < 1755; ++i) {
            r.chunks[i] = address(uint160(0x100000 + i));
        }
        bytes memory dir = vm.readFileBinary("test/fixtures/phase2_data/directory.bin");
        r.lumps = new LumpDescriptor[](dir.length / 16);
        for (uint256 i; i < r.lumps.length; ++i) {
            bytes8 name;
            uint256 pos = i * 16;
            assembly ("memory-safe") { name := mload(add(add(dir, 32), pos)) }
            r.lumps[i] = LumpDescriptor(name, le32(dir, pos + 8), le32(dir, pos + 12));
        }
    }

    function le32(bytes memory b, uint256 p) private pure returns (uint32 n) {
        for (uint256 i; i < 4; ++i) {
            n |= uint32(uint8(b[p + i])) << uint32(i * 8);
        }
    }

    function check(bool legacy) private {
        StatusBarFrame probe = new StatusBarFrame();
        ResourceView memory r = source();
        vm.recordLogs();
        probe.render(r, true, legacy, 7, 0);
        StatusIntegrationVm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 2, "palette and complete frame");
        require(
            logs[0].topics[0] == keccak256("StatusPalette(uint64,uint8,bytes)")
                && uint256(logs[0].topics[1]) == 1,
            "palette association"
        );
        (uint8 index, bytes memory rgb) = abi.decode(logs[0].data, (uint8, bytes));
        require(index == 0 && rgb.length == 768, "base palette");
        bytes memory pal = vm.readFileBinary("test/fixtures/phase4_statusbar/PLAYPAL.bin");
        bytes memory gamma = vm.readFileBinary("test/fixtures/phase4_video/gamma.bin");
        for (uint256 i; i < 768; ++i) {
            require(rgb[i] == gamma[uint8(pal[i])], "native gamma palette");
        }
        require(
            logs[1].topics[0] == keccak256("Frame(uint64,uint32,uint16,uint16,bytes)")
                && uint256(logs[1].topics[1]) == 1 && uint256(logs[1].topics[2]) == 7,
            "frozen Frame ABI"
        );
        (uint16 w, uint16 h, bytes memory pixels) = abi.decode(logs[1].data, (uint16, uint16, bytes));
        require(w == 320 && h == 200 && pixels.length == 64000, "complete frame");
        bytes memory expected = vm.readFileBinary(
            legacy
                ? "test/fixtures/renderer/full-angle0/pixels.bin"
                : "test/fixtures/phase4_statusbar_world/frame.bin"
        );
        require(sha256(pixels) == sha256(expected), "all native world and status pixels");
    }

    function testCompleteNativeWorld168PlusStatus32Frame() public {
        check(false);
    }

    function testLegacyWorld200FrameUnchangedWithStatusHidden() public {
        check(true);
    }
}
