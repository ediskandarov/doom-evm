// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

/// @dev Original z_zone.c allocator links become indices; byte offsets retain the
/// pinned native LP64 backing layout. Each block packs into one storage word.
struct ZoneBlock {
    uint32 offset;
    uint32 size;
    uint32 prev;
    uint32 next;
    uint32 owner;
    uint32 id;
    uint8 tag;
    bool allocated;
    bool idKnown;
    // Conservative written-body history at this header address. Never shrinks on
    // free, coalescing or Clear; prevents reseeding reused bytes as virgin memory.
    uint32 payloadExtent;
}

/// @dev Block zero is the permanent blocklist sentinel. UINT32_MAX is no owner.
/// Owner slots identify original lumpcache[] and texturecomposite[] references;
/// callers reserve deterministic namespaces. Payload bytes are separate from this
/// allocation ledger. Reading pointer or padding bytes is never silently invented.
struct ZoneState {
    uint32 byteLength;
    uint32 rover;
    uint32 blockCount;
    // Explicit platform policy: untouched bytes of the initial zone are zero.
    // False retains the original strict source-written-only diagnostic profile.
    bool deterministicInitialization;
    // Explicit Episode LP64 platform domain: native addresses are below 2^48.
    // Only the two high bytes of CURRENT header pointer fields are then known.
    // Legacy/strict profiles leave this disabled; low address bytes remain unknown.
    bool canonicalPointerHighBytes;
    ZoneBlock[] blocks;
    uint32[] ownerBlocks;
}

library ZoneConst {
    uint32 internal constant NULL = type(uint32).max;
    uint32 internal constant ZONEID = 0x1d4a11;
    uint32 internal constant NATIVE_HEADER_BYTES = 40;
    uint32 internal constant NATIVE_ZONE_BYTES = 56;
    uint32 internal constant NATIVE_ALIGNMENT = 8;
    uint32 internal constant MINFRAGMENT = 64;
    uint8 internal constant PU_STATIC = 1;
    uint8 internal constant PU_LEVEL = 50;
    uint8 internal constant PU_LEVSPEC = 51;
    uint8 internal constant PU_PURGELEVEL = 100;
    uint8 internal constant PU_CACHE = 101;
}
