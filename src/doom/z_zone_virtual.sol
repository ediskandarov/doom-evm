// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {ZoneState, ZoneBlock, ZoneConst as C} from "./z_zone_types.sol";
import {NativeZoneLayout as N} from "./native_zone_layout.sol";

/// @notice Experimental LP64 little-endian address representation, not native placement.
/// @dev z_zone.c writes current links/user at Init/Clear/split/allocate/free/coalesce.
/// The ledger records their current identities, not historical pointer bytes.
library Z_ZoneVirtual {
    uint64 internal constant VIRTUAL_ZONE_BASE = 0x0000001000000000;
    uint64 internal constant ADDRESS_LIMIT = uint64(1) << 48;

    function validMapping(uint32 length) internal pure returns (bool) {
        return N.PRIMITIVE_POINTER == 8 && N.ALLOCATION_ALIGNMENT == 8
            && length >= N.MEMZONE_SIZE + N.MEMBLOCK_SIZE && length <= uint32(type(int32).max)
            && length % N.ALLOCATION_ALIGNMENT == 0 && uint256(VIRTUAL_ZONE_BASE) + length <= ADDRESS_LIMIT;
    }

    function addressForOffset(uint32 length, uint32 offset) internal pure returns (uint64 value, bool known) {
        if (!validMapping(length) || offset >= length || offset % N.ALLOCATION_ALIGNMENT != 0) {
            return (0, false);
        }
        return (VIRTUAL_ZONE_BASE + uint64(offset), true);
    }

    /// @dev Validate the complete CURRENT ring, and prove source membership once per tail.
    /// Contiguous geometry and reciprocal identities exclude retired overlapping headers.
    /// All eligible headers were written by the modeled original allocator operations.
    function validTopology(ZoneState memory z, uint32 source) internal pure returns (bool) {
        if (
            !z.experimentalVirtualPointers || !validMapping(z.byteLength) || z.blockCount < 2
                || z.blockCount > z.blocks.length || source >= z.blockCount
        ) return false;
        ZoneBlock memory sentinel = z.blocks[0];
        if (
            sentinel.offset != N.MEMZONE_BLOCKLIST_OFFSET || !sentinel.allocated || sentinel.owner != C.NULL
                || sentinel.next == 0
        ) return false;
        uint32 id = sentinel.next;
        uint32 previous;
        uint32 traversed;
        uint256 expected = N.MEMZONE_SIZE;
        bool found = source == 0;
        bool roverFound = z.rover == 0; // Original rover may reach the permanent sentinel.
        bool previousFree;
        while (id != 0) {
            if (id >= z.blockCount || ++traversed >= z.blockCount) return false;
            ZoneBlock memory b = z.blocks[id];
            if (
                b.offset != expected || b.size < N.MEMBLOCK_SIZE || b.size % N.ALLOCATION_ALIGNMENT != 0
                    || b.prev != previous || b.next >= z.blockCount || z.blocks[b.next].prev != id
                    || (!b.allocated && b.owner != C.NULL)
                    || (b.allocated && (!b.idKnown || b.id != C.ZONEID)) || (previousFree && !b.allocated)
            ) return false;
            expected += b.size;
            if (expected > z.byteLength) return false;
            if (id == source) found = true;
            if (id == z.rover) roverFound = true;
            previousFree = !b.allocated;
            previous = id;
            id = b.next;
        }
        return found && roverFound && expected == z.byteLength && sentinel.prev == previous;
    }

    /// @dev Caller MUST have validated this ring and obtained id by following its links.
    /// Same-zone links are never NULL: block zero maps to the sentinel at offset8.
    /// Native owner-slot addresses cannot be derived from an owner namespace.
    function pointerFromValidatedHeader(ZoneState memory z, uint32 id, uint32 field)
        internal
        pure
        returns (uint64 value, bool known)
    {
        ZoneBlock memory b = z.blocks[id];
        if (field == N.MEMBLOCK_NEXT_OFFSET || field == N.MEMBLOCK_PREV_OFFSET) {
            uint32 target = field == N.MEMBLOCK_NEXT_OFFSET ? b.next : b.prev;
            return addressForOffset(z.byteLength, z.blocks[target].offset);
        }
        if (field != N.MEMBLOCK_USER_OFFSET) return (0, false);
        if (id == 0) return addressForOffset(z.byteLength, 0);
        if (!b.allocated) return (0, true); // source-written NULL, not base+zero
        if (b.owner == C.NULL) return (2, true); // original (void*)2 marker
        return (0, false); // external OR zone-resident owner slot: neither address is recorded
    }

    function byteFromValidatedHeader(ZoneState memory z, uint32 id, uint32 relative)
        internal
        pure
        returns (bytes1 value, bool known)
    {
        uint32 field;
        if (relative >= N.MEMBLOCK_USER_OFFSET && relative < N.MEMBLOCK_USER_OFFSET + 8) {
            field = N.MEMBLOCK_USER_OFFSET;
        } else if (relative >= N.MEMBLOCK_NEXT_OFFSET && relative < N.MEMBLOCK_NEXT_OFFSET + 8) {
            field = N.MEMBLOCK_NEXT_OFFSET;
        } else if (relative >= N.MEMBLOCK_PREV_OFFSET && relative < N.MEMBLOCK_PREV_OFFSET + 8) {
            field = N.MEMBLOCK_PREV_OFFSET;
        } else {
            return (0, false);
        }
        (uint64 pointer, bool supported) = pointerFromValidatedHeader(z, id, field);
        return (bytes1(uint8(pointer >> ((relative - field) * 8))), supported);
    }
}
