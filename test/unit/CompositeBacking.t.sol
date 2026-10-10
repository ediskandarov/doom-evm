// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {R_Data} from "../../src/doom/r_data.sol";
import {Z_Zone} from "../../src/doom/z_zone.sol";
import {Z_ZoneBacking} from "../../src/doom/z_zone_backing.sol";
import {W_ZoneCache} from "../../src/doom/w_zone_cache.sol";
import {ZoneConst as C} from "../../src/doom/z_zone_types.sol";
import {RenderResources, ResourceView, Texture, TexPatch} from "../../src/doom/r_data_types.sol";
import {ResourceStore} from "../../src/evm/ResourceStore.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";

contract CompositeBackingTest {
    function textureContext(ResourceView memory source) private pure returns (RenderResources memory r) {
        r.source = source;
        r.textures = new Texture[](1);
        r.textures[0].width = 1;
        r.textures[0].height = 4;
        r.textures[0].patches = new TexPatch[](2);
        r.textures[0].patches[0] = TexPatch(0, 0, 1);
        r.textures[0].patches[1] = TexPatch(0, 0, 1);
    }

    function testNeighborCompositeBytesRebuildWithoutNativeCacheEffects() public {
        // Same original-C-proven two-patch construction as the inherited cache test.
        bytes memory patch = hex"01000400000000000c0000000004000a141e2800ff";
        ResourceView memory source;
        source.chunks = new address[](1);
        source.chunks[0] = address(new ResourceStore(bytes.concat(new bytes(16), patch)));
        source.byteLength = uint32(16 + patch.length);
        source.lumps = new LumpDescriptor[](2);
        source.lumps[0] = LumpDescriptor("SOURCE", 0, 16);
        source.lumps[1] = LumpDescriptor("PATCH", 16, uint32(patch.length));
        RenderResources memory r = textureContext(source);
        r.nativeZone = Z_Zone.Z_Init(8192, 3);
        uint32 first = W_ZoneCache.cacheLump(r.nativeZone, source, 0, C.PU_CACHE);
        R_Data.R_GetColumn(r, 0, 0);
        bytes32 zoneBefore = keccak256(abi.encode(r.nativeZone));
        // Simulate the next transaction's ephemeral decode, retaining the native cache.
        RenderResources memory next = textureContext(source);
        next.nativeZone = r.nativeZone;
        (bytes memory data, bytes memory known) = Z_ZoneBacking.tailWithProvenance(next, first, 16, 44);
        require(
            keccak256(abi.encode(next.nativeZone)) == zoneBefore, "no allocation, purge, tag or owner effects"
        );
        require(
            !r.textures[0].compositeReady || r.textures[0].composite.length == 4,
            "original complete composite"
        );
        bytes memory expected = hex"0a141e28";
        for (uint256 i; i < 4; ++i) {
            require(
                data[40 + i] == expected[i] && known[40 + i] == 0x01, "neighbor original composite payload"
            );
        }
        require(known[15] == 0, "no pointer domain inferred");
        Z_Zone.Z_Free(next.nativeZone, W_ZoneCache.compositeBlock(next.nativeZone, source, 0));
        (, known) = Z_ZoneBacking.tailWithProvenance(next, first, 16, 44);
        for (uint256 i; i < 4; ++i) {
            require(known[40 + i] == 0, "freed composite remains unknown");
        }
    }
}
