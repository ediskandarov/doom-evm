// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {WadResources} from "../evm/WadResources.sol";
import {ResourceView} from "../doom/r_data_types.sol";
import {LumpDescriptor} from "../evm/ResourceTypes.sol";
import {R_Data} from "../doom/r_data.sol";

/// @notice Ordinary-deployment verification fixture for the authenticated production resource base.
/// @dev No authentication logic is replaced. Memory instrumentation belongs to a separate deployment.
contract WadResourcesProbe is WadResources {
    struct Report {
        uint256[2] gasCost;
        uint256[4] memoryBytes;
        bytes32 outputSha256;
    }

    constructor(address[] memory chunks, bytes memory directory) WadResources(chunks, directory) {}

    function readRange(uint32 offset, uint32 length) external view returns (bytes memory) {
        return R_Data.read(_resourceView(), offset, length);
    }

    /// @notice Digest binds every stored directory descriptor and chunk address as well as identity.
    function metadataDigest() external view returns (bytes32) {
        ResourceView memory v = _resourceView();
        bytes memory directory = new bytes(v.lumps.length * 16);
        for (uint256 i; i < v.lumps.length; i++) {
            LumpDescriptor memory l = v.lumps[i];
            uint256 p = i * 16;
            for (uint256 j; j < 8; j++) {
                directory[p + j] = l.name[j];
            }
            for (uint256 j; j < 4; j++) {
                directory[p + 8 + j] = bytes1(uint8(l.offset >> (j * 8)));
                directory[p + 12 + j] = bytes1(uint8(l.length >> (j * 8)));
            }
        }
        return sha256(
            abi.encode(
                v.identity,
                uint256(v.byteLength),
                v.chunks.length,
                v.lumps.length,
                sha256(directory),
                sha256(abi.encode(v.chunks))
            )
        );
    }

    function memorySize() private view returns (uint256 size) {
        // Only this helper's source-mapped GAS becomes MSIZE in the separate telemetry deployment.
        assembly ("memory-safe") { size := gas() }
    }

    function probeRead(uint32 offset, uint32 length) external view returns (Report memory r) {
        r.memoryBytes[0] = memorySize();
        uint256 start = gasleft();
        ResourceView memory v = _resourceView();
        r.gasCost[0] = start - gasleft();
        r.memoryBytes[1] = memorySize();
        start = gasleft();
        bytes memory value = R_Data.read(v, offset, length);
        r.gasCost[1] = start - gasleft();
        r.memoryBytes[2] = memorySize();
        r.outputSha256 = sha256(value);
        r.memoryBytes[3] = memorySize();
    }
}
