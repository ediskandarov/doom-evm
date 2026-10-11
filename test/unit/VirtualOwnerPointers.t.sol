// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {Z_Zone} from "../../src/doom/z_zone.sol";
import {Z_ZoneVirtual as V} from "../../src/doom/z_zone_virtual.sol";
import {Z_ZoneBacking as B} from "../../src/doom/z_zone_backing.sol";
import {W_ZoneCache as W} from "../../src/doom/w_zone_cache.sol";
import {ZoneState, ZoneConst as C} from "../../src/doom/z_zone_types.sol";
import {RenderResources} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
import {RenderState, DrawColumn} from "../../src/doom/r_state.sol";
import {R_Draw} from "../../src/doom/r_draw.sol";

interface OwnerVm {
    function expectRevert(bytes4) external;
}

library OwnerFixture {
    function resources() internal pure returns (RenderResources memory r) {
        r.nativeZone = Z_Zone.Z_Init(8192, 4);
        r.nativeZone.experimentalVirtualPointers = true;
        r.source.lumps = new LumpDescriptor[](3);
        r.lumpcache = new bytes[](3);
        for (uint32 i; i < 3; ++i) {
            r.source.lumps[i].length = 512;
        }
        Z_Zone.Z_Malloc(r.nativeZone, 512, C.PU_STATIC, C.NULL);
        W.cacheLump(r.nativeZone, r.source, 2, C.PU_CACHE);
    }
}

contract OwnerPersistence {
    RenderResources private saved;

    constructor() {
        saved = OwnerFixture.resources();
    }

    function digest() external view returns (bytes32) {
        return keccak256(abi.encode(saved));
    }

    function read() external view returns (bytes memory, bytes memory) {
        return B.tailWithProvenance(saved, 1, 512, 40);
    }

    function rejectedTransaction() external {
        saved.nativeZone.experimentalVirtualPointers = false;
        RenderResources memory r = saved;
        DrawColumn memory dc;
        dc.source = new bytes(512);
        dc.sourceOffset = 393;
        dc.texturemid = -1;
        dc.colormap = new bytes(256);
        RenderState memory rs;
        rs.framebuffer = new bytes(64000);
        R_Draw.R_InitBuffer(rs, 320, 200);
        B.bindColumn(r, dc, 1);
        R_Draw.R_DrawColumn(rs, dc);
    }
}

contract VirtualOwnerPointersTest {
    OwnerVm constant vm = OwnerVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testOwnerAddressAndLittleEndian() public view {
        RenderResources memory r = OwnerFixture.resources();
        require(V.validTopology(r.nativeZone, 1));
        (uint64 ptr, bool k) = V.lumpOwnerFromValidatedHeader(r.nativeZone, 2, 3);
        require(k && ptr == V.VIRTUAL_LUMPCACHE_BASE + 16);
        require(ptr != V.VIRTUAL_ZONE_BASE + r.nativeZone.blocks[2].offset + 40, "slot differs from payload");
        (bytes memory data, bytes memory p) = B.tailWithProvenance(r, 1, 512, 40);
        for (uint32 i; i < 8; ++i) {
            require(p[8 + i] == 0x05 && uint8(data[8 + i]) == uint8(ptr >> (8 * i)));
        }
        (, p) = B.tail(r, 1, 512, 40);
        require(p[8] == 0x01);
    }

    function testFuzzStableIdentity(uint16 index) public pure {
        ZoneState memory z = Z_Zone.Z_Init(8192, uint32(index) + 1);
        z.experimentalVirtualPointers = true;
        uint32 id = Z_Zone.Z_Malloc(z, 16, C.PU_CACHE, index);
        require(V.validTopology(z, id));
        (uint64 ptr, bool k) = V.lumpOwnerFromValidatedHeader(z, id, uint32(index) + 1);
        require(k && ptr == V.VIRTUAL_LUMPCACHE_BASE + uint64(index) * 8 && ptr < uint64(1) << 48);
    }

    function testProfilesAndPreviousProvenancePreserved() public view {
        for (uint32 profile; profile < 3; ++profile) {
            RenderResources memory r = OwnerFixture.resources();
            r.nativeZone.experimentalVirtualPointers = false;
            r.nativeZone.deterministicInitialization = profile != 0;
            r.nativeZone.canonicalPointerHighBytes = profile == 2;
            (bytes memory old, bytes memory oldP) = B.tailWithProvenance(r, 1, 512, 40);
            require(oldP[8] == 0);
            r.nativeZone.experimentalVirtualPointers = true;
            (bytes memory data, bytes memory p) = B.tailWithProvenance(r, 1, 512, 40);
            for (uint32 i; i < 40; ++i) {
                if (oldP[i] != 0) require(p[i] == oldP[i] && data[i] == old[i]);
            }
            require(p[8] == 0x05 && p[14] == (profile == 2 ? bytes1(0x03) : bytes1(0x05)));
        }
    }

    function testInvalidOwnerCatalogAndMappingRejected() public view {
        for (uint32 defect; defect < 7; ++defect) {
            RenderResources memory r = OwnerFixture.resources();
            if (defect == 0) r.lumpcache = new bytes[](0);
            if (defect == 1) r.source.lumps = new LumpDescriptor[](0);
            if (defect == 2) r.nativeZone.ownerBlocks[2] = C.NULL;
            if (defect == 3) r.nativeZone.blocks[2].owner = 3; // composite/other owner domain
            if (defect == 4) r.nativeZone.blocks[2].idKnown = false;
            if (defect == 5) r.nativeZone.blocks[2].prev = 0;
            if (defect == 6) r.nativeZone.experimentalVirtualPointers = false;
            (, bytes memory p) = B.tailWithProvenance(r, 1, 512, 40);
            require(p[8] == 0, "unsupported never zero-filled");
        }
    }

    function testFreePurgeReuseAndClearLifetime() public view {
        RenderResources memory r = OwnerFixture.resources();
        (uint64 before_, bool k) = V.lumpOwnerFromValidatedHeader(r.nativeZone, 2, 3);
        require(k);
        require(W.cacheLump(r.nativeZone, r.source, 2, C.PU_STATIC) == 2);
        Z_Zone.Z_Free(r.nativeZone, 2);
        require(r.nativeZone.ownerBlocks[2] == C.NULL);
        (, k) = V.lumpOwnerFromValidatedHeader(r.nativeZone, 2, 3);
        require(!k);
        Z_Zone.Z_Malloc(r.nativeZone, 512, C.PU_STATIC, C.NULL);
        uint32 next = W.cacheLump(r.nativeZone, r.source, 2, C.PU_CACHE);
        require(next != 2);
        (uint64 after_, bool known) = V.lumpOwnerFromValidatedHeader(r.nativeZone, next, 3);
        require(known && before_ == after_);
        Z_Zone.Z_FreeTags(r.nativeZone, C.PU_CACHE, C.PU_CACHE);
        require(r.nativeZone.ownerBlocks[2] == C.NULL);
        next = W.cacheLump(r.nativeZone, r.source, 2, C.PU_CACHE);
        Z_Zone.Z_ClearZone(r.nativeZone);
        require(!V.validTopology(r.nativeZone, next));
        // Clear retains stale cache marks just as C does: it never grants current-header admission.
        Z_Zone.Z_Malloc(r.nativeZone, 512, C.PU_STATIC, C.NULL);
        (, bytes memory p) = B.tailWithProvenance(r, 1, 512, 600);
        require(p[560] == 0);
    }

    function testOwnerOverwriteRejectsOldClaim() public pure {
        RenderResources memory r = OwnerFixture.resources();
        uint32 newer = Z_Zone.Z_Malloc(r.nativeZone, 512, C.PU_CACHE, 2);
        require(V.validTopology(r.nativeZone, 2));
        (, bool oldKnown) = V.lumpOwnerFromValidatedHeader(r.nativeZone, 2, 3);
        (uint64 ptr, bool newKnown) = V.lumpOwnerFromValidatedHeader(r.nativeZone, newer, 3);
        require(!oldKnown && newKnown && ptr == V.VIRTUAL_LUMPCACHE_BASE + 16);
        Z_Zone.Z_Free(r.nativeZone, 2); // Original clearing of a reused slot invalidates the newer claim too.
        (, newKnown) = V.lumpOwnerFromValidatedHeader(r.nativeZone, newer, 3);
        require(!newKnown);
    }

    function testPersistenceAndRejectedDrawRollback() public {
        OwnerPersistence c = new OwnerPersistence();
        bytes32 digest = c.digest();
        (bytes memory data, bytes memory p) = c.read();
        require(p[8] == 0x05 && uint8(data[8]) == 16);
        vm.expectRevert(R_Draw.DrawBounds.selector);
        c.rejectedTransaction();
        require(c.digest() == digest);
        (bytes memory again, bytes memory againP) = c.read();
        require(keccak256(data) == keccak256(again) && keccak256(p) == keccak256(againP));
    }
}
