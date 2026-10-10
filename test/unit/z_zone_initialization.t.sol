// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {Z_Zone} from "../../src/doom/z_zone.sol";
import {Z_ZoneBacking} from "../../src/doom/z_zone_backing.sol";
import {W_ZoneCache} from "../../src/doom/w_zone_cache.sol";
import {ZoneConst as C} from "../../src/doom/z_zone_types.sol";
import {RenderResources, ColumnView} from "../../src/doom/r_data_types.sol";
import {RenderContext} from "../../src/doom/r_render_state.sol";
import {DrawColumn} from "../../src/doom/r_state.sol";
import {R_Draw} from "../../src/doom/r_draw.sol";
import {R_Things} from "../../src/doom/r_things.sol";
import {ResourceStore} from "../../src/evm/ResourceStore.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";

interface InitializationVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function expectRevert(bytes4) external;
}

contract ZoneInitializationTest {
    InitializationVm constant vm = InitializationVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function context(bool deterministic, bool reused)
        private
        returns (RenderContext memory c, uint32 block_)
    {
        bytes memory source = vm.readFileBinary("test/fixtures/drawbounds_blood/source.bin");
        c.resources.source.chunks = new address[](1);
        c.resources.source.chunks[0] = address(new ResourceStore(source));
        c.resources.source.byteLength = uint32(source.length);
        c.resources.source.lumps = new LumpDescriptor[](2);
        c.resources.source.lumps[0] = LumpDescriptor("BLUDA0", 0, uint32(source.length));
        // The next allocation's body is deliberately unmodeled, not a fixture pixel source.
        c.resources.source.lumps[1] = LumpDescriptor("NEXT", 0, 196);
        c.resources.nativeZone = Z_Zone.Z_Init(8192, 2);
        c.resources.nativeZone.deterministicInitialization = deterministic;
        if (reused) {
            uint32 old = Z_Zone.Z_Malloc(c.resources.nativeZone, 1024, C.PU_STATIC, C.NULL);
            Z_Zone.Z_Free(c.resources.nativeZone, old);
        }
        block_ = W_ZoneCache.cacheLump(c.resources.nativeZone, c.resources.source, 0, C.PU_CACHE);
        Z_Zone.Z_Malloc(c.resources.nativeZone, 196, C.PU_STATIC, C.NULL);
        c.resources.currentColumnZoneBlock = block_;
        c.rs.framebuffer = new bytes(64000);
        c.rs.centery = 100;
        R_Draw.R_InitBuffer(c.rs, 320, 200);
        c.dc.x = 123;
        c.dc.iscale = 9472;
        c.dc.texturemid = -542247;
        c.dc.colormap = vm.readFileBinary("test/fixtures/drawbounds_blood/colormap.bin");
        c.sprite.spryscale = 453406;
        c.sprite.sprtopscreen = 10305097;
        c.sprite.mfloorclip = new int32[](320);
        c.sprite.mceilingclip = new int32[](320);
        for (uint32 x; x < 320; ++x) {
            c.sprite.mfloorclip[x] = 200;
            c.sprite.mceilingclip[x] = -1;
        }
    }

    function draw(bool deterministic, bool reused) external returns (uint8 pixel) {
        (RenderContext memory c,) = context(deterministic, reused);
        bytes memory source = vm.readFileBinary("test/fixtures/drawbounds_blood/source.bin");
        R_Things.R_DrawMaskedColumn(c, ColumnView(source, 202));
        return uint8(c.rs.framebuffer[178 * 320 + 123]);
    }

    function testReportedBLUDA0FirstPostMatchesExplicitNativeZeroInitializedProfile() public {
        bytes memory map = vm.readFileBinary("test/fixtures/drawbounds_blood/colormap.bin");
        require(this.draw(true, false) == uint8(map[0]), "native initialized-domain sample");
    }

    function testReportedBLUDA0StillRejectsInStrictDiagnosticMode() public {
        vm.expectRevert(R_Draw.DrawBounds.selector);
        this.draw(false, false);
    }

    function testReusedPayloadNeverSilentlyBecomesInitializedPadding() public {
        vm.expectRevert(R_Draw.DrawBounds.selector);
        this.draw(true, true);
    }

    function testThreeProvenanceClassesAndInvalidDomain() public {
        (RenderContext memory c, uint32 block_) = context(true, false);
        (bytes memory bytes_, bytes memory provenance) =
            Z_ZoneBacking.tailWithProvenance(c.resources, block_, 324, 16);
        require(bytes_[8] == 0 && provenance[8] == 0x02, "virgin ABI padding");
        require(provenance[4] == 0x01 && bytes_[4] == 0xf0, "original written size integer");
        require(provenance[12] == 0x00, "written pointer remains unknown");
        (, provenance) = Z_ZoneBacking.tailWithProvenance(c.resources, block_, 324, 8000);
        uint32 first = c.resources.nativeZone.blocks[block_].offset + 40 + 324;
        require(provenance[c.resources.nativeZone.byteLength - first] == 0x00, "outside zone");
    }

    function testFreeAndClearNeverReseedWrittenHistory() public {
        (RenderContext memory c, uint32 block_) = context(true, true);
        (, bytes memory p) = Z_ZoneBacking.tailWithProvenance(c.resources, block_, 324, 9);
        require(p[8] == 0x00, "old body is not virgin");
        Z_Zone.Z_Free(c.resources.nativeZone, block_);
        Z_Zone.Z_ClearZone(c.resources.nativeZone);
        block_ = Z_Zone.Z_Malloc(c.resources.nativeZone, 324, C.PU_STATIC, C.NULL);
        (, p) = Z_ZoneBacking.tailWithProvenance(c.resources, block_, 324, 9);
        require(p[8] == 0x00, "Clear did not clear native bytes");
    }

    function testMatrixFreshAndReusedLengthsKeepSourceBytesAndPointerRejection() public {
        uint32[5] memory lengths = [uint32(7), 111, 324, 511, 1128];
        for (uint256 row; row < lengths.length; ++row) {
            for (uint256 reused; reused < 2; ++reused) {
                uint32 len = lengths[row];
                RenderResources memory r;
                r.nativeZone = Z_Zone.Z_Init(8192, 0);
                r.nativeZone.deterministicInitialization = true;
                if (reused != 0) {
                    uint32 old = Z_Zone.Z_Malloc(r.nativeZone, 4096, C.PU_STATIC, C.NULL);
                    Z_Zone.Z_Free(r.nativeZone, old);
                }
                uint32 id = Z_Zone.Z_Malloc(r.nativeZone, len, C.PU_STATIC, C.NULL);
                Z_Zone.Z_Malloc(r.nativeZone, 160, C.PU_STATIC, C.NULL);
                (, bytes memory p) = Z_ZoneBacking.tailWithProvenance(r, id, len, 48);
                uint32 padding = ((len + 7) & ~uint32(7)) - len + 4;
                require(p[padding] == (reused == 0 ? bytes1(0x02) : bytes1(0x00)));
                require(p[padding + 4] == 0x00, "pointer");
                require(p[padding - 4] == 0x01, "written header size");
            }
        }
    }
}
