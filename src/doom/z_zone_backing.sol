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
                }
                work.cursor += work.count;
                work.physical += work.count;
            }
        }
    }
}
