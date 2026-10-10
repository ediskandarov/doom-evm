// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {Z_Zone} from "../../src/doom/z_zone.sol";
import {W_ZoneCache} from "../../src/doom/w_zone_cache.sol";
import {Z_ZoneBacking} from "../../src/doom/z_zone_backing.sol";
import {ZoneConst as C} from "../../src/doom/z_zone_types.sol";
import {RenderResources} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
import {ResourceStore} from "../../src/evm/ResourceStore.sol";
import {RenderState, DrawColumn} from "../../src/doom/r_state.sol";
import {R_Draw} from "../../src/doom/r_draw.sol";

interface Tic52Vm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function expectRevert(bytes4) external;
}

/// @notice Regression of the exact rejected sample, not a golden for address-dependent pixels.
contract SpeedrunTic52BackingTest {
    Tic52Vm constant vm = Tic52Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function rejectedSample(uint8 profile) external {
        bytes memory bonus1 = vm.readFileBinary("test/fixtures/speedrun_tic52/BON1D0.bin");
        bytes memory bonus2 = vm.readFileBinary("test/fixtures/speedrun_tic52/BON2A0.bin");
        require(bonus1.length == 238 && bonus2.length == 340, "authenticated native lump lengths");
        RenderResources memory r;
        r.source.chunks = new address[](1);
        r.source.chunks[0] = address(new ResourceStore(bytes.concat(bonus1, bonus2)));
        r.source.byteLength = 578;
        r.source.lumps = new LumpDescriptor[](2);
        r.source.lumps[0] = LumpDescriptor("BON1D0", 0, 238);
        r.source.lumps[1] = LumpDescriptor("BON2A0", 238, 340);
        r.nativeZone = Z_Zone.Z_Init(64 * 1024 * 1024, 2);
        // Position the two real lumps at the measured source/sample headers.
        // Earlier gameplay allocations are outside this focused backing proof.
        Z_Zone.Z_Malloc(r.nativeZone, 12785288, C.PU_STATIC, C.NULL);
        uint32 source = W_ZoneCache.cacheLump(r.nativeZone, r.source, 0, C.PU_CACHE);
        uint32 neighbor = W_ZoneCache.cacheLump(r.nativeZone, r.source, 1, C.PU_CACHE);
        require(r.nativeZone.blocks[source].offset == 12785384, "measured source header");
        require(r.nativeZone.blocks[source].size == 280, "measured source block size");
        require(r.nativeZone.blocks[neighbor].offset == 12785664, "measured next header");
        require(r.nativeZone.blocks[neighbor].size == 384, "measured next block size");
        r.nativeZone.deterministicInitialization = profile != 0;
        r.nativeZone.canonicalPointerHighBytes = profile == 2;
        (, bytes memory provenance) = Z_ZoneBacking.tailWithProvenance(r, source, 238, 34);
        require(provenance[27] == 0, "next pointer byte1 must remain unknown");
        if (profile == 2) {
            require(provenance[32] == 0x03 && provenance[33] == 0x03, "Episode high-byte extension retained");
        }
        RenderState memory rs;
        rs.framebuffer = new bytes(64000);
        R_Draw.R_InitBuffer(rs, 320, 200);
        DrawColumn memory dc;
        dc.x = 301;
        dc.yl = 155;
        dc.yh = 166;
        dc.source = bonus1;
        dc.sourceOffset = 138;
        // The original projected first fraction is -8. Holding this fraction
        // isolates the first rejected sample without replacing any draw logic.
        dc.texturemid = -8;
        dc.colormap = new bytes(256);
        Z_ZoneBacking.bindColumn(r, dc, source);
        require(dc.sourceTail.length == 28 && dc.sourceTailKnown[27] == 0, "exact sample265 guard");
        R_Draw.R_DrawColumn(rs, dc);
    }

    function testStrictRejectsExactTic52PointerSample() public {
        vm.expectRevert(R_Draw.DrawBounds.selector);
        this.rejectedSample(0);
    }

    function testLegacyRejectsExactTic52PointerSample() public {
        vm.expectRevert(R_Draw.DrawBounds.selector);
        this.rejectedSample(1);
    }

    function testEpisodeRejectsExactTic52PointerSample() public {
        vm.expectRevert(R_Draw.DrawBounds.selector);
        this.rejectedSample(2);
    }
}
