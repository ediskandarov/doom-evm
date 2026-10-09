// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {M_BBox} from "../../src/doom/m_bbox.sol";

interface VmBBox {
    function readFileBinary(string calldata path) external view returns (bytes memory);
}

contract MBBoxTest {
    VmBBox constant vm = VmBBox(address(uint160(uint256(keccak256("hevm cheat code")))));

    function word(bytes memory b, uint256 p) private pure returns (int32 v) {
        assembly ("memory-safe") { v := signextend(3, shr(224, mload(add(add(b, 32), p)))) }
    }

    function verify(int32[4] memory box, bytes memory data, uint256 pos) private pure {
        for (uint32 i; i < 4; i++) {
            require(box[i] == word(data, pos + i * 4), "native prefix bounds");
        }
    }

    function testAllOriginalBoundingStreams() public view {
        bytes memory data = vm.readFileBinary("test/fixtures/phase3_bbox/vectors.bin");
        uint256 pos;
        uint32 streams;
        uint32 points;
        while (pos < data.length) {
            uint32 count = uint32(word(data, pos));
            pos += 4;
            int32[4] memory box;
            M_BBox.M_ClearBox(box);
            verify(box, data, pos);
            pos += 16;
            for (uint32 i; i < count; i++) {
                M_BBox.M_AddToBox(box, word(data, pos), word(data, pos + 4));
                pos += 8;
                verify(box, data, pos);
                pos += 16;
                points++;
            }
            streams++;
        }
        require(pos == data.length && streams == 521, "all streams");
        require(points > 8000, "point coverage");
    }
}
