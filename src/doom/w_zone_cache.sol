// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {ZoneState, ZoneConst as C} from "./z_zone_types.sol";
import {ResourceView} from "./r_data_types.sol";
import {Z_Zone} from "./z_zone.sol";

/// @custom:source linuxdoom-1.10/w_wad.c W_CacheLumpNum; r_data.c R_GenerateComposite
/// @dev Only semantic native cache calls update this ledger; EVM parsing is independent.
library W_ZoneCache {
    error CacheBounds();

    function ownerBlock(ZoneState memory zone, uint32 owner) internal pure returns (uint32) {
        if (zone.byteLength == 0) return 0;
        if (owner >= zone.ownerBlocks.length) revert CacheBounds();
        return zone.ownerBlocks[owner];
    }

    function cacheLump(ZoneState memory zone, ResourceView memory source, uint32 lump, uint8 tag)
        internal
        pure
        returns (uint32 id)
    {
        if (zone.byteLength == 0) return 0;
        if (lump >= source.lumps.length) revert CacheBounds();
        id = ownerBlock(zone, lump);
        if (id == C.NULL) id = Z_Zone.Z_Malloc(zone, source.lumps[lump].length, tag, lump);
        else Z_Zone.Z_ChangeTag(zone, id, tag);
    }

    function compositeOwner(ResourceView memory source, uint32 texture) internal pure returns (uint32) {
        uint256 owner = source.lumps.length + texture;
        if (owner >= C.NULL) revert CacheBounds();
        return uint32(owner);
    }

    function compositeBlock(ZoneState memory zone, ResourceView memory source, uint32 texture)
        internal
        pure
        returns (uint32)
    {
        return ownerBlock(zone, compositeOwner(source, texture));
    }

    function allocateComposite(ZoneState memory zone, ResourceView memory source, uint32 texture, uint32 size)
        internal
        pure
        returns (uint32)
    {
        if (zone.byteLength == 0) return 0;
        return Z_Zone.Z_Malloc(zone, size, C.PU_STATIC, compositeOwner(source, texture));
    }

    function changeTag(ZoneState memory zone, uint32 id, uint8 tag) internal pure {
        if (zone.byteLength != 0) Z_Zone.Z_ChangeTag(zone, id, tag);
    }
}
