// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {Z_Zone} from "../../src/doom/z_zone.sol";
import {Z_ZoneVirtual as V} from "../../src/doom/z_zone_virtual.sol";
import {Z_ZoneBacking as B} from "../../src/doom/z_zone_backing.sol";
import {ZoneState, ZoneConst as C} from "../../src/doom/z_zone_types.sol";
import {NativeZoneLayout as N} from "../../src/doom/native_zone_layout.sol";
import {RenderResources} from "../../src/doom/r_data_types.sol";
import {RenderState, DrawColumn} from "../../src/doom/r_state.sol";
import {R_Draw} from "../../src/doom/r_draw.sol";

interface VirtualVm {
    function expectRevert(bytes4) external;
}

contract VirtualPersistence {
    ZoneState private saved;

    constructor() {
        ZoneState memory z = Z_Zone.Z_Init(8192, 0);
        z.experimentalVirtualPointers = true;
        Z_Zone.Z_Malloc(z, 512, C.PU_STATIC, C.NULL);
        Z_Zone.Z_Malloc(z, 512, C.PU_STATIC, C.NULL);
        saved = z;
    }

    function digest() external view returns (bytes32) {
        return keccak256(abi.encode(saved));
    }

    function read() external view returns (bytes memory, bytes memory) {
        RenderResources memory r;
        r.nativeZone = saved;
        return B.tailWithProvenance(r, 1, 512, 40);
    }

    function rejectedTransaction() external {
        saved.experimentalVirtualPointers = false;
        RenderResources memory r;
        r.nativeZone = saved;
        DrawColumn memory dc;
        dc.source = new bytes(512);
        dc.sourceOffset = 410; // masked sample127 => next header byte25
        dc.texturemid = -1;
        dc.colormap = new bytes(256);
        RenderState memory rs;
        rs.framebuffer = new bytes(64000);
        R_Draw.R_InitBuffer(rs, 320, 200);
        B.bindColumn(r, dc, 1);
        R_Draw.R_DrawColumn(rs, dc);
    }
}

contract VirtualPointersTest {
    VirtualVm constant vm = VirtualVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function zone() private pure returns (ZoneState memory z) {
        z = Z_Zone.Z_Init(8192, 2);
        z.experimentalVirtualPointers = true;
        Z_Zone.Z_Malloc(z, 512, C.PU_STATIC, C.NULL);
        Z_Zone.Z_Malloc(z, 512, C.PU_CACHE, 0);
    }

    function testExplicitSelectionAndDomain() public pure {
        ZoneState memory z = Z_Zone.Z_Init(8192, 0);
        require(!z.experimentalVirtualPointers && !V.validTopology(z, 1));
        require(V.VIRTUAL_ZONE_BASE == 0x0000001000000000);
        require(V.validMapping(8192) && !V.validMapping(0) && !V.validMapping(8193));
        require(!V.validMapping(type(uint32).max));
        (uint64 p, bool k) = V.addressForOffset(8192, 0);
        require(k && p == V.VIRTUAL_ZONE_BASE && p != 0);
        (, k) = V.addressForOffset(8192, 8192);
        require(!k);
        (, k) = V.addressForOffset(8192, 57);
        require(!k);
    }

    function testFuzzPointerCalculations(uint32 input) public pure {
        uint32 offset = (input % 8192) & ~uint32(7);
        (uint64 p, bool k) = V.addressForOffset(8192, offset);
        require(k && p == V.VIRTUAL_ZONE_BASE + uint64(offset) && p < uint64(1) << 48);
        uint64 reconstructed;
        for (uint32 i; i < 8; ++i) {
            reconstructed |= uint64(uint8(p >> (i * 8))) << (i * 8);
        }
        require(reconstructed == p);
    }

    function testAllCurrentLinksIncludingSentinelAndRoverAtSentinel() public pure {
        ZoneState memory z = zone();
        require(V.validTopology(z, 2));
        uint32 id;
        do {
            for (uint32 f = N.MEMBLOCK_NEXT_OFFSET; f <= N.MEMBLOCK_PREV_OFFSET; f += 8) {
                (uint64 p, bool k) = V.pointerFromValidatedHeader(z, id, f);
                uint32 target = f == N.MEMBLOCK_NEXT_OFFSET ? z.blocks[id].next : z.blocks[id].prev;
                require(k && p == V.VIRTUAL_ZONE_BASE + z.blocks[target].offset);
                for (uint32 b; b < 8; ++b) {
                    (bytes1 value, bool known) = V.byteFromValidatedHeader(z, id, f + b);
                    require(known && uint8(value) == uint8(p >> (b * 8)));
                }
            }
            id = z.blocks[id].next;
        } while (id != 0);
        z = Z_Zone.Z_Init(8192, 0);
        z.experimentalVirtualPointers = true;
        Z_Zone.Z_Malloc(z, 8096, C.PU_STATIC, C.NULL);
        require(z.rover == 0 && V.validTopology(z, 1));
    }

    function testNullMarkerZoneBaseAndUnsupportedOwners() public pure {
        ZoneState memory z = zone();
        require(V.validTopology(z, 1));
        (uint64 p, bool k) = V.pointerFromValidatedHeader(z, 0, N.MEMBLOCK_USER_OFFSET);
        require(k && p == V.VIRTUAL_ZONE_BASE);
        (p, k) = V.pointerFromValidatedHeader(z, 1, N.MEMBLOCK_USER_OFFSET);
        require(k && p == 2);
        (p, k) = V.pointerFromValidatedHeader(z, 2, N.MEMBLOCK_USER_OFFSET);
        require(!k && p == 0);
        (p, k) = V.pointerFromValidatedHeader(z, 3, N.MEMBLOCK_USER_OFFSET);
        require(k && p == 0);
        (, k) = V.byteFromValidatedHeader(z, 2, 4);
        require(!k, "ABI padding is not a pointer");
    }

    function testProvenanceAndExistingKnownBytesArePreserved() public view {
        for (uint32 profile; profile < 3; ++profile) {
            RenderResources memory r;
            r.nativeZone = zone();
            r.nativeZone.experimentalVirtualPointers = false;
            r.nativeZone.deterministicInitialization = profile != 0;
            r.nativeZone.canonicalPointerHighBytes = profile == 2;
            (bytes memory oldData, bytes memory oldKnown) = B.tailWithProvenance(r, 1, 512, 40);
            r.nativeZone.experimentalVirtualPointers = true;
            (bytes memory data, bytes memory known) = B.tailWithProvenance(r, 1, 512, 40);
            for (uint32 i; i < 40; ++i) {
                if (oldKnown[i] != 0) require(oldKnown[i] == known[i] && oldData[i] == data[i]);
            }
            require(known[25] == 0x04 && known[8] == 0, "new link; unknown owner");
            require(known[30] == (profile == 2 ? bytes1(0x03) : bytes1(0x04)));
            (, known) = B.tail(r, 1, 512, 40);
            require(known[25] == 0x01, "render knownness marker");
        }
    }

    function testRetiredHeadersAndClearDoNotReconstructHistoricalPointers() public view {
        RenderResources memory r;
        r.nativeZone = zone();
        uint32 retired = r.nativeZone.blocks[2].next;
        Z_Zone.Z_Free(r.nativeZone, 2); // merges next fragment into surviving header2
        require(V.validTopology(r.nativeZone, 2) && !V.validTopology(r.nativeZone, retired));
        // Retired fragment at1160 is now inside free payload, after header2 at608.
        (, bytes memory p) = B.tailWithProvenance(r, 1, 512, 600);
        require(p[576] == 0, "old next pointer remains unknown inside free body");
        Z_Zone.Z_ClearZone(r.nativeZone);
        require(!V.validTopology(r.nativeZone, 2));
        Z_Zone.Z_Malloc(r.nativeZone, 512, C.PU_STATIC, C.NULL);
        require(V.validTopology(r.nativeZone, 1));
        (, p) = B.tailWithProvenance(r, 1, 512, 600);
        require(p[576] == 0, "Clear never invents retired bytes");
    }

    function testCorruptIdentityGeometryAndLifetimeRemainUnknown() public view {
        for (uint32 defect; defect < 8; ++defect) {
            RenderResources memory r;
            r.nativeZone = zone();
            if (defect == 0) r.nativeZone.blocks[2].prev = 0;
            if (defect == 1) r.nativeZone.blocks[2].offset += 8;
            if (defect == 2) r.nativeZone.blocks[2].size -= 1;
            if (defect == 3) r.nativeZone.blocks[2].idKnown = false;
            if (defect == 4) r.nativeZone.rover = r.nativeZone.blockCount;
            if (defect == 5) r.nativeZone.blocks[0].offset = 0;
            if (defect == 6) r.nativeZone.blocks[3].owner = 0;
            if (defect == 7) r.nativeZone.blocks[3].next = 3;
            require(!V.validTopology(r.nativeZone, 1));
            // Keep physical traversal otherwise safe in this particular tail.
            if (defect != 1 && defect != 2) {
                (, bytes memory p) = B.tailWithProvenance(r, 1, 512, 40);
                require(p[25] == 0, "invalid topology cannot synthesize pointers");
            }
        }
    }

    function testStoragePersistenceAndDrawBoundsRollback() public {
        VirtualPersistence h = new VirtualPersistence();
        bytes32 before = h.digest();
        (bytes memory data, bytes memory p) = h.read();
        require(p[25] == 0x04 && data[25] == bytes1(uint8(uint64(1160) >> 8)));
        vm.expectRevert(R_Draw.DrawBounds.selector);
        h.rejectedTransaction();
        require(h.digest() == before, "profile and complete ledger rollback");
        (bytes memory afterData, bytes memory afterP) = h.read();
        require(keccak256(afterData) == keccak256(data) && keccak256(afterP) == keccak256(p));
    }
}
