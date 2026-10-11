// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {ResourceView} from "../doom/r_data_types.sol";
import {ResourceIdentity, LumpDescriptor} from "./ResourceTypes.sol";

/// @notice Authenticated, immutable source for the pinned production IWAD profiles.
/// @dev EVM adapter, no original C counterpart. All resource bytes remain original bundle bytes.
abstract contract ProductionWadResources {
    error ResourceDimensions();
    error DirectoryIdentity();
    error ChunkIdentity();

    bytes32 internal constant DIRECTORY_SHA256 =
        0x4acf70e1a550810a0682365afb4a717b8258082e18962f898554eac4dbd1d012;
    // SHA256 of concatenated SHA256(STOP || chunk payload), in bundle order.
    bytes32 internal constant CHUNK_HASHES_SHA256 =
        0x62a3aec2214b5b7776713b87435b010d6f6300929e3b169d0b6e7e03de01fb6a;
    ResourceView private wad;

    constructor(address[] memory chunks, bytes memory directory) {
        bool ultimate = chunks.length == 756 && directory.length == 2306 * 16;
        if (!ultimate && (chunks.length != 1755 || directory.length != 3163 * 16)) revert ResourceDimensions();
        bytes32 directoryHash = ultimate
            ? bytes32(0x6c5e07c8ea410c014b2dc57959c214bae0783c78668fb119d32c6a5514d33287)
            : DIRECTORY_SHA256;
        if (sha256(directory) != directoryHash) revert DirectoryIdentity();
        _authenticateChunks(chunks, ultimate);
        wad.identity = ResourceIdentity(
            0,
            ultimate ? bytes32(0x6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f)
                : bytes32(0x7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d),
            ultimate ? bytes32(0x1154fc21f0fa60e793ffb6da569b2293191dfc7f1791e0c083672b764917d7ba)
                : bytes32(0xd379076f21645cf7cc5acb056663d0faacc4065489a0ca99738479323c9f7a47),
            0xfd895921b5d0a394612bb29852ed003d44d69f76dec31c0dc6b5d5fc7d63f7bb,
            0
        );
        wad.byteLength = ultimate ? 12370751 : 28741889;
        for (uint256 i; i < chunks.length; ++i) {
            wad.chunks.push(chunks[i]);
        }
        for (uint256 i; i < directory.length / 16; ++i) {
            uint256 p = i * 16;
            bytes8 name;
            // p+16 <= directory.length; this word may include the next descriptor or ABI padding.
            assembly ("memory-safe") { name := mload(add(add(directory, 32), p)) }
            wad.lumps.push(LumpDescriptor(name, _le32(directory, p + 8), _le32(directory, p + 12)));
        }
    }

    function resourceIdentity() public view returns (ResourceIdentity memory) {
        return wad.identity;
    }

    /// @notice Authenticated startup profile: 0 Freedoom, 1 Ultimate.
    /// @dev Startup selection is independent of renderer backing policy.
    function resourceProfile() public view returns (uint8) {
        return wad.identity.wadSha256 ==
            0x6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f ? 1 : 0;
    }

    function _resourceView() internal view returns (ResourceView memory) {
        return wad;
    }

    function _le32(bytes memory data, uint256 p) private pure returns (uint32) {
        return uint32(uint8(data[p])) | uint32(uint8(data[p + 1])) << 8 | uint32(uint8(data[p + 2])) << 16
            | uint32(uint8(data[p + 3])) << 24;
    }

    function _authenticateChunks(address[] memory chunks, bool ultimate) private view {
        bytes memory scratch = new bytes(16385);
        bytes memory hashes = new bytes(chunks.length * 32);
        for (uint256 i; i < chunks.length; ++i) {
            address chunk = chunks[i];
            uint256 size = i == chunks.length - 1 ? (ultimate ? 832 : 4354) : 16385;
            if (chunk.code.length != size) revert ResourceDimensions();
            // scratch owns 16,385 payload bytes. Only its logical length shrinks on the final
            // iteration; neither EXTCODECOPY nor SHA256 accesses outside that allocation.
            assembly ("memory-safe") {
                mstore(scratch, size)
                extcodecopy(chunk, add(scratch, 32), 0, size)
            }
            bytes32 digest = sha256(scratch);
            // i < chunks.length, so this full word is inside hashes' allocated payload.
            assembly ("memory-safe") { mstore(add(add(hashes, 32), mul(i, 32)), digest) }
        }
        bytes32 expected = ultimate
            ? bytes32(0x0ab133e15d4bcfe400cf7106b8dc1d26ca62f912ca1314eac69a6c0e2bdc8c04)
            : CHUNK_HASHES_SHA256;
        if (sha256(hashes) != expected) revert ChunkIdentity();
    }
}
