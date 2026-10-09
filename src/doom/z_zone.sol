// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {ZoneState, ZoneBlock, ZoneConst as C} from "./z_zone_types.sol";

/// @custom:source linuxdoom-1.10/z_zone.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @dev Pinned LP64 layout and align8 native adaptation. Bytes/pointers are not invented.
library Z_Zone {
    error InvalidZone();
    error InvalidBlock();
    error OwnerRequired();
    error AllocationFailed(uint32 size);
    error CorruptHeap();

    function Z_Init(uint32 byteLength, uint32 ownerCount) internal pure returns (ZoneState memory z) {
        if (byteLength < C.NATIVE_ZONE_BYTES + C.NATIVE_HEADER_BYTES || byteLength > uint32(type(int32).max))
        {
            revert InvalidZone();
        }
        z.byteLength = byteLength;
        z.blocks = new ZoneBlock[](8);
        z.blockCount = 2;
        z.ownerBlocks = new uint32[](ownerCount);
        for (uint256 i; i < ownerCount; ++i) {
            z.ownerBlocks[i] = C.NULL;
        }
        z.blocks[0].offset = 8;
        z.blocks[1].offset = C.NATIVE_ZONE_BYTES;
        Z_ClearZone(z);
    }

    function Z_ClearZone(ZoneState memory z) internal pure {
        if (z.blockCount < 2 || z.blocks.length < z.blockCount) revert InvalidZone();
        z.blocks[0].next = 1;
        z.blocks[0].prev = 1;
        z.blocks[0].owner = C.NULL;
        z.blocks[0].allocated = true; // original sentinel user points to the zone
        z.blocks[0].tag = C.PU_STATIC;
        z.rover = 1;
        z.blocks[1].prev = 0;
        z.blocks[1].next = 0;
        z.blocks[1].owner = C.NULL;
        z.blocks[1].allocated = false;
        z.blocks[1].size = z.byteLength - C.NATIVE_ZONE_BYTES;
        // Original does not clear ID, tag, old headers, payload bytes or owner marks.
    }

    function append(ZoneState memory z) private pure returns (uint32 id) {
        id = z.blockCount;
        if (id == C.NULL) revert InvalidZone();
        if (id == z.blocks.length) {
            uint256 capacity = z.blocks.length * 2;
            if (capacity > C.NULL) revert InvalidZone();
            ZoneBlock[] memory expanded = new ZoneBlock[](capacity);
            for (uint256 i; i < id; ++i) {
                expanded[i] = z.blocks[i];
            }
            z.blocks = expanded;
        }
        ++z.blockCount;
    }

    function block(ZoneState memory z, uint32 id) private pure returns (ZoneBlock memory b) {
        if (id >= z.blockCount || z.blocks.length < z.blockCount) revert InvalidBlock();
        b = z.blocks[id];
    }

    function Z_Malloc(ZoneState memory z, uint32 payloadSize, uint8 tag, uint32 owner)
        internal
        pure
        returns (uint32 base)
    {
        if (payloadSize > uint32(type(int32).max) - C.NATIVE_HEADER_BYTES - 7) revert InvalidZone();
        uint32 size = ((payloadSize + 7) & ~uint32(7)) + C.NATIVE_HEADER_BYTES;
        base = z.rover;
        if (!block(z, block(z, base).prev).allocated) base = z.blocks[base].prev;
        uint32 rover = base;
        uint32 start = z.blocks[base].prev;
        uint32 visited;
        do {
            if (rover == start) revert AllocationFailed(size);
            // An invalid linked cycle is outside the original valid heap domain.
            if (++visited > z.blockCount * 2) revert CorruptHeap();
            if (block(z, rover).allocated) {
                if (z.blocks[rover].tag < C.PU_PURGELEVEL) {
                    base = z.blocks[rover].next;
                    rover = base;
                } else {
                    base = z.blocks[base].prev;
                    Z_Free(z, rover);
                    base = z.blocks[base].next;
                    rover = z.blocks[base].next;
                }
            } else {
                rover = z.blocks[rover].next;
            }
        } while (z.blocks[base].allocated || z.blocks[base].size < size);
        uint32 extra = z.blocks[base].size - size;
        if (extra > C.MINFRAGMENT) {
            uint32 fresh = append(z);
            z.blocks[fresh].offset = z.blocks[base].offset + size;
            z.blocks[fresh].size = extra;
            z.blocks[fresh].owner = C.NULL;
            z.blocks[fresh].allocated = false;
            z.blocks[fresh].tag = 0;
            z.blocks[fresh].prev = base;
            z.blocks[fresh].next = z.blocks[base].next;
            z.blocks[z.blocks[fresh].next].prev = fresh;
            z.blocks[base].next = fresh;
            z.blocks[base].size = size;
            // New free fragment ID bytes are untouched in original C, even on reuse.
            z.blocks[fresh].idKnown = false;
        }
        if (owner != C.NULL) {
            if (owner >= z.ownerBlocks.length) revert InvalidBlock();
            z.blocks[base].owner = owner;
            z.ownerBlocks[owner] = base;
        } else {
            if (tag >= C.PU_PURGELEVEL) revert OwnerRequired();
            z.blocks[base].owner = C.NULL; // original non-pointer user value 2
        }
        z.blocks[base].allocated = true;
        z.blocks[base].tag = tag;
        z.rover = z.blocks[base].next;
        z.blocks[base].id = C.ZONEID;
        z.blocks[base].idKnown = true;
    }

    function Z_Free(ZoneState memory z, uint32 id) internal pure {
        ZoneBlock memory b = block(z, id);
        if (id == 0 || !b.allocated || !b.idKnown || b.id != C.ZONEID) revert InvalidBlock();
        if (b.owner != C.NULL) z.ownerBlocks[b.owner] = C.NULL;
        b.owner = C.NULL;
        b.allocated = false;
        b.tag = 0;
        b.id = 0;
        b.idKnown = true;
        uint32 other = b.prev;
        if (!z.blocks[other].allocated) {
            z.blocks[other].size += b.size;
            z.blocks[other].next = b.next;
            z.blocks[b.next].prev = other;
            if (id == z.rover) z.rover = other;
            id = other;
        }
        other = z.blocks[id].next;
        if (!z.blocks[other].allocated) {
            z.blocks[id].size += z.blocks[other].size;
            z.blocks[id].next = z.blocks[other].next;
            z.blocks[z.blocks[other].next].prev = id;
            if (other == z.rover) z.rover = id;
        }
    }

    function Z_FreeTags(ZoneState memory z, uint8 lowtag, uint8 hightag) internal pure {
        uint32 id = z.blocks[0].next;
        uint32 visited;
        while (id != 0) {
            if (++visited > z.blockCount * 2) revert CorruptHeap();
            uint32 next = block(z, id).next; // original reads before possible merging
            if (z.blocks[id].allocated && z.blocks[id].tag >= lowtag && z.blocks[id].tag <= hightag) {
                Z_Free(z, id);
            }
            id = next;
        }
    }

    function Z_ChangeTag(ZoneState memory z, uint32 id, uint8 tag) internal pure {
        ZoneBlock memory b = block(z, id);
        if (id == 0 || !b.allocated || !b.idKnown || b.id != C.ZONEID) revert InvalidBlock();
        if (tag >= C.PU_PURGELEVEL && b.owner == C.NULL) revert OwnerRequired();
        b.tag = tag;
    }

    function Z_ChangeTag2(ZoneState memory z, uint32 id, uint8 tag) internal pure {
        Z_ChangeTag(z, id, tag);
    }

    function Z_CheckHeap(ZoneState memory z) internal pure {
        uint32 id = z.blocks[0].next;
        uint32 visited;
        for (;;) {
            if (++visited > z.blockCount) revert CorruptHeap();
            ZoneBlock memory b = block(z, id);
            if (b.next == 0) break; // original excludes the sentinel-adjacent pair
            ZoneBlock memory next = block(z, b.next);
            if (b.offset + b.size != next.offset || next.prev != id || (!b.allocated && !next.allocated)) {
                revert CorruptHeap();
            }
            id = b.next;
        }
    }

    function Z_FreeMemory(ZoneState memory z) internal pure returns (uint32 free) {
        uint32 id = z.blocks[0].next;
        uint32 visited;
        while (id != 0) {
            if (++visited > z.blockCount) revert CorruptHeap();
            ZoneBlock memory b = block(z, id);
            if (!b.allocated || b.tag >= C.PU_PURGELEVEL) free += b.size;
            id = b.next;
        }
    }

    function Z_BlockOffset(ZoneState memory z, uint32 id) internal pure returns (uint32) {
        return block(z, id).offset;
    }

    function Z_PayloadOffset(ZoneState memory z, uint32 id) internal pure returns (uint32) {
        if (id == 0) revert InvalidBlock();
        return block(z, id).offset + C.NATIVE_HEADER_BYTES;
    }
}
