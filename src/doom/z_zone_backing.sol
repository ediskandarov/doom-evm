// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {ZoneState, ZoneBlock, ZoneConst as C} from "./z_zone_types.sol";
import {RenderResources} from "./r_data_types.sol";
import {DrawColumn} from "./r_state.sol";
import {R_Data} from "./r_data.sol";
import {NativeZoneLayout as N} from "./native_zone_layout.sol";

/// @dev Source-derived LP64 physical backing, with explicit per-byte knownness.
/// No address, pointer, padding, free payload or allocation slack is synthesized.
library Z_ZoneBacking {
    error InvalidBacking();

    function clear(DrawColumn memory dc) internal pure {
        bytes memory empty;
        dc.sourceTail = empty;
        dc.sourceTailKnown = empty;
    }

    function integerByte(ZoneBlock memory b, uint32 relative)
        private
        pure
        returns (bytes1 value, bool known)
    {
        uint32 number;
        uint32 shift;
        if (relative < N.MEMBLOCK_SIZE_OFFSET + 4) {
            number = b.size;
            shift = relative - N.MEMBLOCK_SIZE_OFFSET;
        } else if (relative >= N.MEMBLOCK_TAG_OFFSET && relative < N.MEMBLOCK_TAG_OFFSET + 4) {
            // Original Init leaves first-free tag untouched. Other free headers have
            // fragment/free writes; Clear preserves first-header known alloc/free fields.
            if (!b.allocated && !b.idKnown && b.offset == N.MEMZONE_SIZE) return (0, false);
            number = b.tag;
            shift = relative - N.MEMBLOCK_TAG_OFFSET;
        } else if (relative >= N.MEMBLOCK_ID_OFFSET && relative < N.MEMBLOCK_ID_OFFSET + 4 && b.idKnown) {
            number = b.id;
            shift = relative - N.MEMBLOCK_ID_OFFSET;
        } else {
            return (0, false);
        }
        return (bytes1(uint8(number >> (shift * 8))), true);
    }

    function bindColumn(RenderResources memory resources, DrawColumn memory dc, uint32 sourceBlock)
        internal
        view
    {
        clear(dc);
        if (resources.nativeZone.byteLength == 0 || sourceBlock == 0) return;
        // Original ordinary column loop masks every source sample with127.
        uint256 end = uint256(dc.sourceOffset) + 128;
        if (end <= dc.source.length) return;
        uint256 required = end - dc.source.length;
        if (required > 256) revert InvalidBacking();
        (dc.sourceTail, dc.sourceTailKnown) =
            tail(resources, sourceBlock, uint32(dc.source.length), uint32(required));
    }

    /// @dev Call-local reader variables, not a persisted heap or supplied byte recipe.
    struct TailWork {
        ZoneState zone;
        ZoneBlock current;
        uint256 physical;
        uint32 id;
        uint256 cursor;
        uint32 traversed;
        uint256 end;
        uint32 relative;
        uint256 count;
        uint32 owner;
        uint32 local;
        uint32 payloadLength;
        uint256 written;
        bytes payload;
    }

    function tail(RenderResources memory resources, uint32 sourceBlock, uint32 logicalLength, uint32 length)
        internal
        view
        returns (bytes memory data, bytes memory known)
    {
        (data, known) = tailWithProvenance(resources, sourceBlock, logicalLength, length);
        for (uint256 i; i < known.length; ++i) {
            if (known[i] == 0x02 || known[i] == 0x03) known[i] = 0x01;
        }
    }

    /// @notice 0=unknown/invalid, 1=original source-written, 2=initial-zone zero, 3=bounded LP64 address high byte.
    /// @dev Initialization never establishes provenance for a pointer, an
    /// unmodeled written body, a reused body or a byte outside the initial zone.
    function tailWithProvenance(
        RenderResources memory resources,
        uint32 sourceBlock,
        uint32 logicalLength,
        uint32 length
    ) internal view returns (bytes memory data, bytes memory known) {
        TailWork memory work;
        work.zone = resources.nativeZone;
        if (work.zone.byteLength == 0 || sourceBlock == 0 || sourceBlock >= work.zone.blockCount) {
            revert InvalidBacking();
        }
        work.current = work.zone.blocks[sourceBlock];
        if (
            !work.current.allocated || work.current.size < N.MEMBLOCK_SIZE
                || logicalLength > work.current.size - N.MEMBLOCK_SIZE
        ) {
            revert InvalidBacking();
        }
        data = new bytes(length);
        known = new bytes(length);
        work.physical = uint256(work.current.offset) + N.MEMBLOCK_SIZE + logicalLength;
        work.id = sourceBlock;

        while (work.cursor < length && work.physical < work.zone.byteLength) {
            if (work.id == 0 || work.id >= work.zone.blockCount) revert InvalidBacking();
            work.current = work.zone.blocks[work.id];
            work.end = uint256(work.current.offset) + work.current.size;
            if (work.physical >= work.end) {
                if (++work.traversed > work.zone.blockCount) revert InvalidBacking();
                work.id = work.current.next;
                continue;
            }
            if (work.physical < work.current.offset) revert InvalidBacking();
            work.relative = uint32(work.physical - work.current.offset);
            if (work.relative < N.MEMBLOCK_SIZE) {
                (bytes1 value, bool isKnown) = integerByte(work.current, work.relative);
                if (isKnown) {
                    data[work.cursor] = value;
                    known[work.cursor] = 0x01;
                } else if (work.zone.canonicalPointerHighBytes && pointerHighByte(work.relative)) {
                    // Original writes user/next/prev as LP64 addresses (or NULL/2).
                    // In the explicitly bounded <2^48 platform domain their high
                    // two bytes are zero. No lower pointer byte or old body is inferred.
                    known[work.cursor] = 0x03;
                }
                ++work.cursor;
                ++work.physical;
            } else {
                work.count = work.end - work.physical;
                if (work.count > length - work.cursor) work.count = length - work.cursor;
                work.owner = work.current.owner;
                work.local = work.relative - N.MEMBLOCK_SIZE;
                if (
                    work.current.allocated && work.owner < resources.source.lumps.length
                        && work.zone.ownerBlocks[work.owner] == work.id
                ) {
                    work.payloadLength = resources.source.lumps[work.owner].length;
                    if (work.local < work.payloadLength) {
                        work.written = work.payloadLength - work.local;
                        if (work.written > work.count) work.written = work.count;
                        work.payload = R_Data.read(
                            resources.source,
                            resources.source.lumps[work.owner].offset + work.local,
                            uint32(work.written)
                        );
                        for (uint256 i; i < work.written; ++i) {
                            data[work.cursor + i] = work.payload[i];
                            known[work.cursor + i] = 0x01;
                        }
                    }
                } else if (
                    work.current.allocated && work.owner >= resources.source.lumps.length
                        && work.owner < resources.source.lumps.length + resources.textures.length
                        && work.owner < work.zone.ownerBlocks.length
                        && work.zone.ownerBlocks[work.owner] == work.id
                ) {
                    // Source-written R_GenerateComposite payload, including a
                    // neighboring texture. No native allocation/cache call is replayed.
                    work.payload = R_Data.compositeBacking(
                        resources, work.owner - uint32(resources.source.lumps.length)
                    );
                    if (work.local < work.payload.length) {
                        work.written = work.payload.length - work.local;
                        if (work.written > work.count) work.written = work.count;
                        for (uint256 i; i < work.written; ++i) {
                            data[work.cursor + i] = work.payload[work.local + i];
                            known[work.cursor + i] = 0x01;
                        }
                    }
                }
                work.cursor += work.count;
                work.physical += work.count;
            }
        }
        if (work.zone.deterministicInitialization) {
            initializedBytes(
                work.zone, work.zone.blocks[sourceBlock].offset + N.MEMBLOCK_SIZE + logicalLength, data, known
            );
        }
    }

    function pointerHighByte(uint32 relative) private pure returns (bool) {
        return relative == N.MEMBLOCK_USER_OFFSET + 6 || relative == N.MEMBLOCK_USER_OFFSET + 7
            || relative == N.MEMBLOCK_NEXT_OFFSET + 6 || relative == N.MEMBLOCK_NEXT_OFFSET + 7
            || relative == N.MEMBLOCK_PREV_OFFSET + 6 || relative == N.MEMBLOCK_PREV_OFFSET + 7;
    }

    function exclude(bytes memory candidates, uint256 start, uint256 end, uint256 first) private pure {
        uint256 limit = first + candidates.length;
        if (end <= first || start >= limit) return;
        if (start < first) start = first;
        if (end > limit) end = limit;
        for (uint256 address_ = start; address_ < end; ++address_) {
            candidates[address_ - first] = 0x00;
        }
    }

    /// @dev Sparse zero-initialized platform backing. Historical header records
    /// and monotonically increasing payload extents exclude every potentially
    /// overwritten byte. Unknown mutable bodies are deliberately conservative.
    function initializedBytes(
        ZoneState memory zone,
        uint256 first,
        bytes memory data,
        bytes memory provenance
    ) private pure {
        bytes memory candidates = new bytes(data.length);
        bool needed;
        for (uint256 i; i < data.length; ++i) {
            if (provenance[i] == 0x00 && first + i >= N.MEMZONE_SIZE && first + i < zone.byteLength) {
                candidates[i] = 0x01;
                needed = true;
            }
        }
        if (!needed) return;
        for (uint32 id = 1; id < zone.blockCount; ++id) {
            ZoneBlock memory b = zone.blocks[id];
            uint256 header = b.offset;
            // Header size and pointer fields are always written. Tag/ID are
            // excluded conservatively even when a particular fragment did not
            // write them. Only genuine ABI padding remains eligible.
            exclude(candidates, header, header + 4, first);
            exclude(candidates, header + N.MEMBLOCK_USER_OFFSET, header + N.MEMBLOCK_SIZE, first);
            exclude(candidates, header + N.MEMBLOCK_SIZE, header + N.MEMBLOCK_SIZE + b.payloadExtent, first);
        }
        for (uint256 i; i < data.length; ++i) {
            if (candidates[i] == 0x01) {
                // The value comes from the explicit zero-initialized domain;
                // no resource/index/pixel-specific replacement is involved.
                provenance[i] = 0x02;
            }
        }
    }
}
