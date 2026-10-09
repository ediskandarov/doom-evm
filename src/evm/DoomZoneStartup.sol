// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {ZoneState, ZoneConst} from "../doom/z_zone_types.sol";
import {Z_Zone} from "../doom/z_zone.sol";
import {ResourceView, RenderResources, Texture} from "../doom/r_data_types.sol";
import {SpriteDef} from "../doom/r_sprite_state.sol";
import {R_Data} from "../doom/r_data.sol";

/// @notice Source-backed allocator metadata for original renderer startup.
/// @dev Inputs are authenticated resources and their parsed original definitions.
/// No native allocation tape, zone headers, world state or pixels are accepted.
struct StartupObservation {
    bool enabled;
    bytes32 digest;
    uint32 operations;
}

struct StartupRecord {
    uint32 op;
    uint32 requestedSize;
    uint32 requestedTag;
    uint32 owner;
    uint32 headerOffset;
    uint32 blockSize;
}

library DoomZoneStartup {
    error StartupOwnerBounds();
    error NativeSizeBounds();
    error InvalidTextureDefinition();

    // Pinned LP64 original-host layout. Native sizeof exports verify each value.
    // r_data.c texture_t includes its first texpatch_t; later patches add12 bytes.
    uint32 internal constant POINTER_BYTES = 8;
    uint32 internal constant INT_BYTES = 4;
    uint32 internal constant SHORT_BYTES = 2;
    uint32 internal constant TEXTURE_BYTES = 28;
    uint32 internal constant TEXPATCH_BYTES = 12;
    uint32 internal constant SPRITEDEF_BYTES = 16;
    uint32 internal constant SPRITEFRAME_BYTES = 28;

    function nativeSize(uint256 size) private pure returns (uint32) {
        // Original Z_Malloc accepts signed int sizes on the pinned native ABI.
        if (size > uint256(uint32(type(int32).max))) revert NativeSizeBounds();
        return uint32(size);
    }

    function record(StartupObservation memory observation, ZoneState memory zone, StartupRecord memory event_)
        private
        pure
    {
        if (!observation.enabled) return;
        observation.digest = sha256(
            abi.encodePacked(
                observation.digest,
                event_.op,
                event_.requestedSize,
                event_.requestedTag,
                event_.owner,
                event_.headerOffset,
                event_.blockSize,
                zone.blocks[zone.rover].offset
            )
        );
        ++observation.operations;
    }

    function allocate(
        ZoneState memory zone,
        uint32 size,
        uint8 tag,
        uint32 owner,
        StartupObservation memory observation
    ) private pure returns (uint32 blockId) {
        blockId = Z_Zone.Z_Malloc(zone, size, tag, owner);
        if (observation.enabled) {
            record(
                observation,
                zone,
                StartupRecord(
                    1, size, uint32(tag), owner, zone.blocks[blockId].offset, zone.blocks[blockId].size
                )
            );
        }
    }

    function free(ZoneState memory zone, uint32 blockId, StartupObservation memory observation) private pure {
        // Capture input header metadata before original coalescing mutates links.
        StartupRecord memory event_;
        if (observation.enabled) {
            event_ = StartupRecord(
                2, 0, 0, zone.blocks[blockId].owner, zone.blocks[blockId].offset, zone.blocks[blockId].size
            );
        }
        Z_Zone.Z_Free(zone, blockId);
        if (observation.enabled) record(observation, zone, event_);
    }

    /// @custom:source w_wad.c W_CacheLumpNum
    /// @dev Original lumpcache[] is malloc-owned outside the zone. Each owner
    /// slot here represents its pointer only; reserving owner slots allocates no
    /// original zone block. Cache hits use original Z_ChangeTag2 semantics.
    function cacheLump(ZoneState memory zone, ResourceView memory source, uint32 lump, uint8 tag)
        internal
        pure
        returns (uint32 blockId)
    {
        StartupObservation memory observation;
        return cache(zone, source, lump, tag, observation);
    }

    function cache(
        ZoneState memory zone,
        ResourceView memory source,
        uint32 lump,
        uint8 tag,
        StartupObservation memory observation
    ) private pure returns (uint32 blockId) {
        if (lump >= source.lumps.length || lump >= zone.ownerBlocks.length) {
            revert StartupOwnerBounds();
        }
        blockId = zone.ownerBlocks[lump];
        if (blockId == ZoneConst.NULL) {
            blockId = allocate(zone, nativeSize(source.lumps[lump].length), tag, lump, observation);
        } else {
            Z_Zone.Z_ChangeTag2(zone, blockId, tag);
            if (observation.enabled) {
                record(
                    observation,
                    zone,
                    StartupRecord(
                        3, 0, uint32(tag), lump, zone.blocks[blockId].offset, zone.blocks[blockId].size
                    )
                );
            }
        }
    }

    function staticAllocation(ZoneState memory zone, uint256 size, StartupObservation memory observation)
        private
        pure
    {
        allocate(zone, nativeSize(size), ZoneConst.PU_STATIC, ZoneConst.NULL, observation);
    }

    /// @custom:source r_data.c R_InitTextures
    function initTextures(
        ZoneState memory zone,
        RenderResources memory resources,
        StartupObservation memory observation
    ) private pure {
        ResourceView memory source = resources.source;
        uint32 pnames =
            cache(zone, source, R_Data.W_GetNumForName(source, "PNAMES"), ZoneConst.PU_STATIC, observation);
        // Original patchlookup[] uses alloca, not Z_Malloc.
        free(zone, pnames, observation);

        uint32 texture1 =
            cache(zone, source, R_Data.W_GetNumForName(source, "TEXTURE1"), ZoneConst.PU_STATIC, observation);
        int32 second = R_Data.W_CheckNumForName(source, "TEXTURE2");
        uint32 texture2 = ZoneConst.NULL;
        if (second >= 0) texture2 = cache(zone, source, uint32(second), ZoneConst.PU_STATIC, observation);

        uint256 count = resources.textures.length;
        // Original pointer arrays retain the reviewed LP64 sizeof(*array)
        // adaptation; original int/fixed_t arrays remain four bytes per entry.
        staticAllocation(zone, count * POINTER_BYTES, observation); // textures
        staticAllocation(zone, count * POINTER_BYTES, observation); // texturecolumnlump
        staticAllocation(zone, count * POINTER_BYTES, observation); // texturecolumnofs
        staticAllocation(zone, count * POINTER_BYTES, observation); // texturecomposite
        staticAllocation(zone, count * INT_BYTES, observation); // texturecompositesize
        staticAllocation(zone, count * INT_BYTES, observation); // texturewidthmask
        staticAllocation(zone, count * INT_BYTES, observation); // textureheight
        for (uint256 i; i < count; ++i) {
            Texture memory texture = resources.textures[i];
            if (texture.patches.length == 0 || texture.width == 0) revert InvalidTextureDefinition();
            staticAllocation(zone, TEXTURE_BYTES + TEXPATCH_BYTES * (texture.patches.length - 1), observation);
            staticAllocation(zone, uint256(texture.width) * SHORT_BYTES, observation); // texturecolumnlump[i]
            staticAllocation(zone, uint256(texture.width) * SHORT_BYTES, observation); // texturecolumnofs[i]
        }
        free(zone, texture1, observation);
        if (texture2 != ZoneConst.NULL) free(zone, texture2, observation);

        // R_GenerateLookup caches each patch before clipping its columns. Its
        // patchcount[] is alloca; composite bytes are not allocated at startup.
        for (uint256 i; i < count; ++i) {
            Texture memory texture = resources.textures[i];
            for (uint256 j; j < texture.patches.length; ++j) {
                cache(zone, source, texture.patches[j].patch, ZoneConst.PU_CACHE, observation);
            }
        }
        staticAllocation(zone, (count + 1) * INT_BYTES, observation); // texturetranslation
    }

    /// @custom:source r_main.c R_Init; r_data.c R_InitData; r_things.c R_InitSpriteDefs
    /// @dev Source R_Init order is textures, flats, sprite lump metadata,
    /// colormaps, translation tables; R_InitSprites follows in the gameplay host.
    /// Caller supplies Z_Init's existing zone and original parsed sprite defs.
    function replay(ZoneState memory zone, RenderResources memory resources, SpriteDef[] memory definitions)
        internal
        pure
    {
        StartupObservation memory observation;
        replayInternal(zone, resources, definitions, observation);
    }

    /// @notice Comparison-only observation of the same source-generated calls.
    /// @dev No native records are accepted. Normal replay disables observation;
    /// the digest never controls allocator, resource, gameplay or renderer work.
    function replayObserved(
        ZoneState memory zone,
        RenderResources memory resources,
        SpriteDef[] memory definitions
    ) internal pure returns (bytes32 digest, uint32 operations) {
        StartupObservation memory observation;
        observation.enabled = true;
        replayInternal(zone, resources, definitions, observation);
        return (observation.digest, observation.operations);
    }

    function replayInternal(
        ZoneState memory zone,
        RenderResources memory resources,
        SpriteDef[] memory definitions,
        StartupObservation memory observation
    ) private pure {
        if (uint256(resources.source.lumps.length) + resources.textures.length > zone.ownerBlocks.length) {
            revert StartupOwnerBounds();
        }
        initTextures(zone, resources, observation);
        staticAllocation(zone, (uint256(resources.numflats) + 1) * INT_BYTES, observation);
        staticAllocation(zone, uint256(resources.numspritelumps) * INT_BYTES, observation); // spritewidth
        staticAllocation(zone, uint256(resources.numspritelumps) * INT_BYTES, observation); // spriteoffset
        staticAllocation(zone, uint256(resources.numspritelumps) * INT_BYTES, observation); // spritetopoffset
        for (uint32 i; i < resources.numspritelumps; ++i) {
            cache(zone, resources.source, resources.firstspritelump + i, ZoneConst.PU_CACHE, observation);
        }
        uint32 colormap = R_Data.W_GetNumForName(resources.source, "COLORMAP");
        staticAllocation(zone, uint256(resources.source.lumps[colormap].length) + 255, observation);
        // R_InitTranslationTables precedes R_InitSprites in the original host.
        staticAllocation(zone, 256 * 3 + 255, observation);
        if (definitions.length == 0) return;
        staticAllocation(zone, definitions.length * SPRITEDEF_BYTES, observation);
        for (uint256 i; i < definitions.length; ++i) {
            if (definitions[i].frames.length != 0) {
                staticAllocation(zone, definitions[i].frames.length * SPRITEFRAME_BYTES, observation);
            }
        }
    }
}
