// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {WadResources} from "../../src/evm/WadResources.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {R_Data} from "../../src/doom/r_data.sol";

interface WadVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function etch(address, bytes calldata) external;
    function toString(uint256) external pure returns (string memory);
}

contract WadResourcesHarness is WadResources {
    constructor(address[] memory chunks, bytes memory directory) WadResources(chunks, directory) {}

    function inspect() external view returns (uint32, uint256, uint256, bytes memory) {
        ResourceView memory v = _resourceView();
        return (v.byteLength, v.chunks.length, v.lumps.length, R_Data.read(v, 16380, 16));
    }
}

contract WadResourcesTest {
    WadVm constant vm = WadVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function installChunk(uint256 i) external {
        vm.etch(address(uint160(0x100000 + i)), chunkBytes(i));
    }

    function chunkBytes(uint256 i) private view returns (bytes memory) {
        return vm.readFileBinary(string.concat("artifacts/local/wad/phase2-chunks/", vm.toString(i), ".bin"));
    }

    function setUp() public {
        for (uint256 i; i < 1755; ++i) {
            this.installChunk(i);
        }
    }

    function inputs() private view returns (address[] memory chunks, bytes memory directory) {
        chunks = new address[](1755);
        for (uint256 i; i < chunks.length; ++i) {
            chunks[i] = address(uint160(0x100000 + i));
        }
        directory = vm.readFileBinary("test/fixtures/phase2_data/directory.bin");
    }

    function testPinnedBytesAcceptedAndReadableAcrossChunkBoundary() public {
        (address[] memory chunks, bytes memory directory) = inputs();
        WadResourcesHarness source = new WadResourcesHarness(chunks, directory);
        (uint32 size, uint256 count, uint256 lumps, bytes memory crossing) = source.inspect();
        require(size == 28741889 && count == 1755 && lumps == 3163, "source dimensions");
        require(
            source.resourceIdentity().bundleSha256
                == 0xd379076f21645cf7cc5acb056663d0faacc4065489a0ca99738479323c9f7a47
        );
        bytes memory a = chunkBytes(0);
        bytes memory b = chunkBytes(1);
        for (uint256 i; i < 16; ++i) {
            require(crossing[i] == (i < 4 ? a[16381 + i] : b[1 + i - 4]), "cross-chunk source");
        }
    }

    function rejects(address[] memory chunks, bytes memory directory, bytes4 expected) private {
        try new WadResourcesHarness(chunks, directory) {
            revert("corrupted source accepted");
        } catch (bytes memory reason) {
            require(reason.length >= 4 && bytes4(reason) == expected, "wrong rejection");
        }
    }

    function testRejectsModifiedDirectory() public {
        (address[] memory chunks, bytes memory directory) = inputs();
        directory[0] ^= 0x01;
        rejects(chunks, directory, WadResources.DirectoryIdentity.selector);
    }

    function testRejectsReorderedChunksWithValidLengths() public {
        (address[] memory chunks, bytes memory directory) = inputs();
        (chunks[0], chunks[1]) = (chunks[1], chunks[0]);
        rejects(chunks, directory, WadResources.ChunkIdentity.selector);
    }

    function testRejectsAlteredLastPayloadByte() public {
        (address[] memory chunks, bytes memory directory) = inputs();
        bytes memory b = chunkBytes(1754);
        b[b.length - 1] ^= 0x01;
        vm.etch(chunks[1754], b);
        rejects(chunks, directory, WadResources.ChunkIdentity.selector);
    }

    function testRejectsNonStopPrefix() public {
        (address[] memory chunks, bytes memory directory) = inputs();
        bytes memory b = chunkBytes(0);
        b[0] = 0x01;
        vm.etch(chunks[0], b);
        rejects(chunks, directory, WadResources.ChunkIdentity.selector);
    }

    function testRejectsWrongChunkDimensions() public {
        (address[] memory chunks, bytes memory directory) = inputs();
        vm.etch(chunks[1754], hex"00");
        rejects(chunks, directory, WadResources.ResourceDimensions.selector);
        chunks = new address[](0);
        rejects(chunks, directory, WadResources.ResourceDimensions.selector);
    }
}
