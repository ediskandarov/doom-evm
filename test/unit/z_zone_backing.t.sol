// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {Z_Zone} from "../../src/doom/z_zone.sol";
import {W_ZoneCache} from "../../src/doom/w_zone_cache.sol";
import {Z_ZoneBacking} from "../../src/doom/z_zone_backing.sol";
import {ZoneConst as C} from "../../src/doom/z_zone_types.sol";
import {RenderResources, ResourceView, Texture, TexPatch, ColumnView} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
import {ResourceStore} from "../../src/evm/ResourceStore.sol";
import {RenderState, DrawColumn} from "../../src/doom/r_state.sol";
import {R_Draw} from "../../src/doom/r_draw.sol";
import {R_Data} from "../../src/doom/r_data.sol";

interface BackingVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function expectRevert(bytes4) external;
}

contract ZoneBackingTest {
    BackingVm constant vm = BackingVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    error BackingMismatch(uint32 row, uint32 byteIndex);

    function word(bytes memory data, uint256 at) private pure returns (uint32) {
        return uint32(uint8(data[at])) << 24 | uint32(uint8(data[at + 1])) << 16 | uint32(uint8(data[at + 2]))
            << 8 | uint32(uint8(data[at + 3]));
    }

    function setup(uint32 len, uint32 kind, uint32 tag, uint32 heap)
        private
        returns (RenderResources memory r, uint32 id)
    {
        bytes memory payload = new bytes(uint256(len) + 160);
        for (uint32 i; i < len; ++i) {
            payload[i] = bytes1(uint8(i * 7 + 5));
        }
        for (uint32 i; i < 160; ++i) {
            payload[len + i] = bytes1(uint8(i * 29 + 7));
        }
        r.source.chunks = new address[](1);
        r.source.chunks[0] = address(new ResourceStore(payload));
        r.source.byteLength = uint32(payload.length);
        r.source.lumps = new LumpDescriptor[](2);
        r.source.lumps[0] = LumpDescriptor("SOURCE", 0, len);
        r.source.lumps[1] = LumpDescriptor("NEXT", len, 160);
        r.nativeZone = Z_Zone.Z_Init(heap, 2);
        id = W_ZoneCache.cacheLump(r.nativeZone, r.source, 0, C.PU_CACHE);
        if (kind == 0 || kind == 2) {
            uint32 next = W_ZoneCache.cacheLump(r.nativeZone, r.source, 1, uint8(tag));
            if (kind == 2) Z_Zone.Z_Free(r.nativeZone, next);
        } else if (kind == 1) {
            Z_Zone.Z_Malloc(r.nativeZone, 160, uint8(tag), C.NULL);
        }
    }

    function pixels(RenderResources memory r, uint32 id, uint32 len) private view returns (uint8) {
        RenderState memory rs;
        rs.framebuffer = new bytes(64000);
        R_Draw.R_InitBuffer(rs, 320, 200);
        DrawColumn memory dc;
        dc.source = R_Data.W_CacheLumpNum(r.source, 0);
        dc.colormap = new bytes(256);
        for (uint32 i; i < 256; ++i) {
            dc.colormap[i] = bytes1(uint8(i * 7 + 3));
        }
        uint32 sample = ((len + 7) & ~uint32(7)) + 20;
        dc.sourceOffset = sample - 127;
        dc.texturemid = -1;
        Z_ZoneBacking.bindColumn(r, dc, id);
        R_Draw.R_DrawColumn(rs, dc);
        return uint8(rs.framebuffer[0]);
    }

    function testEveryOriginalPhysicalTailAndKnownHeaderPixel() public {
        bytes memory vectors = vm.readFileBinary("test/fixtures/phase3_zone_backing/vectors.bin");
        uint32 count = word(vectors, 0);
        require(count == 80);
        for (uint32 row; row < count; ++row) {
            uint256 at = 4 + uint256(row) * 276;
            uint32 len = word(vectors, at);
            uint32 kind = word(vectors, at + 4);
            uint32 tag = word(vectors, at + 8);
            uint32 heap = word(vectors, at + 12);
            (RenderResources memory r, uint32 id) = setup(len, kind, tag, heap);
            (bytes memory values, bytes memory known) = Z_ZoneBacking.tail(r, id, len, 128);
            for (uint32 i; i < 128; ++i) {
                if (values[i] != vectors[at + 20 + i] || known[i] != vectors[at + 148 + i]) {
                    revert BackingMismatch(row, i);
                }
            }
            uint32 expected = word(vectors, at + 16);
            if (expected != C.NULL) {
                require(pixels(r, id, len) == expected, "original R_DrawColumn integer-header pixel");
            }
        }
        require(vectors.length == 4 + 80 * 276);
    }

    function testCacheHitChangesTagAndOwnerReallocation() public {
        (RenderResources memory r, uint32 id) = setup(111, 0, 50, 8192);
        uint32 before = r.nativeZone.blockCount;
        require(W_ZoneCache.cacheLump(r.nativeZone, r.source, 0, 1) == id);
        require(r.nativeZone.blockCount == before && r.nativeZone.blocks[id].tag == 1);
        Z_Zone.Z_Free(r.nativeZone, id);
        require(r.nativeZone.ownerBlocks[0] == C.NULL);
        uint32 roverOffset = r.nativeZone.blocks[r.nativeZone.rover].offset;
        uint32 again = W_ZoneCache.cacheLump(r.nativeZone, r.source, 0, 101);
        require(
            r.nativeZone.blocks[again].offset == roverOffset && r.nativeZone.blocks[again].allocated
                && r.nativeZone.ownerBlocks[0] == again
        );
    }

    function testBindingClearsStaleTailAndFastPathAllocatesNothing() public {
        (RenderResources memory r, uint32 id) = setup(111, 0, 1, 8192);
        DrawColumn memory dc;
        dc.source = new bytes(111);
        dc.sourceOffset = 5;
        Z_ZoneBacking.bindColumn(r, dc, id);
        require(dc.sourceTail.length != 0);
        dc.source = new bytes(256);
        dc.sourceOffset = 0;
        uint256 before;
        uint256 afterMem;
        assembly ("memory-safe") { before := mload(0x40) }
        Z_ZoneBacking.bindColumn(r, dc, id);
        assembly ("memory-safe") { afterMem := mload(0x40) }
        require(
            dc.sourceTail.length == 0 && dc.sourceTailKnown.length == 0 && before == afterMem,
            "lazy empty bind allocated"
        );
        dc.sourceTail = hex"11";
        dc.sourceTailKnown = hex"01";
        r.nativeZone.byteLength = 0;
        Z_ZoneBacking.bindColumn(r, dc, 0);
        require(dc.sourceTail.length == 0 && dc.sourceTailKnown.length == 0);
    }

    function compositeContext(ResourceView memory source) private pure returns (RenderResources memory r) {
        r.source = source;
        r.textures = new Texture[](1);
        r.textures[0].width = 1;
        r.textures[0].height = 4;
        r.textures[0].patches = new TexPatch[](2);
        r.textures[0].patches[0] = TexPatch(0, 0, 1);
        r.textures[0].patches[1] = TexPatch(0, 0, 1);
    }

    function testCompositeReconstructionKeepsNativeCacheAndPurgeRegenerates() public {
        bytes memory patch = hex"01000400000000000c0000000004000a141e2800ff";
        ResourceView memory source;
        source.chunks = new address[](1);
        source.chunks[0] = address(new ResourceStore(patch));
        source.byteLength = uint32(patch.length);
        source.lumps = new LumpDescriptor[](2);
        source.lumps[1] = LumpDescriptor("PATCH", 0, uint32(patch.length));
        RenderResources memory r = compositeContext(source);
        r.nativeZone = Z_Zone.Z_Init(8192, 3);
        ColumnView memory column = R_Data.R_GetColumn(r, 0, 0);
        require(keccak256(column.data) == keccak256(hex"0a141e28"));
        uint32 composite = W_ZoneCache.compositeBlock(r.nativeZone, source, 0);
        uint32 patchBlock = W_ZoneCache.ownerBlock(r.nativeZone, 1);
        require(
            r.nativeZone.blocks[composite].offset < r.nativeZone.blocks[patchBlock].offset,
            "original composite before patch cache"
        );
        uint32 count = r.nativeZone.blockCount;
        Z_Zone.Z_ChangeTag(r.nativeZone, patchBlock, 50);
        RenderResources memory next = compositeContext(source);
        next.nativeZone = r.nativeZone;
        column = R_Data.R_GetColumn(next, 0, 0);
        require(
            next.nativeZone.blockCount == count && next.nativeZone.blocks[patchBlock].tag == 50,
            "ephemeral parsing replayed native cache"
        );
        require(
            next.currentColumnZoneBlock == composite && keccak256(column.data) == keccak256(hex"0a141e28")
        );
        Z_Zone.Z_Free(next.nativeZone, composite);
        column = R_Data.R_GetColumn(next, 0, 0);
        require(
            next.nativeZone.blocks[patchBlock].tag == 101 && next.currentColumnZoneBlock != composite,
            "purged native composite not regenerated"
        );
        require(keccak256(column.data) == keccak256(hex"0a141e28"));
    }

    function rejected(uint32 which) external {
        RenderState memory rs;
        rs.framebuffer = new bytes(64000);
        R_Draw.R_InitBuffer(rs, 320, 200);
        DrawColumn memory dc;
        dc.source = new bytes(1);
        dc.sourceOffset = 1;
        dc.colormap = new bytes(256);
        dc.sourceTail = hex"11";
        dc.sourceTailKnown = which == 0 ? bytes(hex"00") : which == 1 ? bytes(hex"02") : new bytes(0);
        R_Draw.R_DrawColumn(rs, dc);
    }

    function rejectedPhysical(uint32 which) external {
        uint32 kind = which == 3 ? 1 : which == 4 ? 3 : which == 5 ? 4 : 0;
        uint32 heap = kind == 4 ? 272 : 8192;
        (RenderResources memory r, uint32 id) = setup(111, kind, 1, heap);
        RenderState memory rs;
        rs.framebuffer = new bytes(64000);
        R_Draw.R_InitBuffer(rs, 320, 200);
        DrawColumn memory dc;
        dc.source = R_Data.W_CacheLumpNum(r.source, 0);
        dc.colormap = new bytes(256);
        uint32 sample = which == 0
            ? 116
            : which == 1 ? 120 : which == 2 ? 111 : which == 3 ? 152 : which == 4 ? 132 : 176;
        if (sample > 127) {
            dc.sourceOffset = sample - 127;
            dc.texturemid = 127 * 65536;
        } else {
            dc.texturemid = int32(sample * 65536);
        }
        Z_ZoneBacking.bindColumn(r, dc, id);
        R_Draw.R_DrawColumn(rs, dc);
    }

    function testUnknownPhysicalPaddingPointersSlackAndFragmentsReject() public {
        for (uint32 i; i < 6; ++i) {
            vm.expectRevert(R_Draw.DrawBounds.selector);
            this.rejectedPhysical(i);
        }
    }

    function testUnknownAndInvalidKnownMasksRemainRejected() public {
        for (uint32 i; i < 3; ++i) {
            vm.expectRevert(R_Draw.DrawBounds.selector);
            this.rejected(i);
        }
    }
}
