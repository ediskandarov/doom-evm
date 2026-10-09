// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {DoomZoneStartup} from "../../src/evm/DoomZoneStartup.sol";
import {Z_Zone} from "../../src/doom/z_zone.sol";
import {ZoneState, ZoneBlock, ZoneConst} from "../../src/doom/z_zone_types.sol";
import {R_Data} from "../../src/doom/r_data.sol";
import {R_Things} from "../../src/doom/r_things.sol";
import {ResourceView, RenderResources} from "../../src/doom/r_data_types.sol";
import {RenderContext} from "../../src/doom/r_render_state.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
import {Info} from "../../src/doom/info.sol";

interface StartupVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function etch(address, bytes calldata) external;
    function toString(uint256) external pure returns (string memory);
}

contract DoomZoneStartupTest {
    StartupVm constant vm = StartupVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    event TestStageGas(string stage, uint256 gasUsed);

    function installChunk(uint256 i) external {
        vm.etch(
            address(uint160(0x100000 + i)),
            vm.readFileBinary(string.concat("artifacts/local/wad/phase2-chunks/", vm.toString(i), ".bin"))
        );
    }

    function setUp() public {
        for (uint256 i; i < 1755; ++i) {
            this.installChunk(i);
        }
    }

    function le32(bytes memory bytes_, uint256 p) private pure returns (uint32) {
        return uint32(uint8(bytes_[p])) | uint32(uint8(bytes_[p + 1])) << 8 | uint32(uint8(bytes_[p + 2]))
            << 16 | uint32(uint8(bytes_[p + 3])) << 24;
    }

    function be32(bytes memory bytes_, uint256 p) private pure returns (uint32) {
        require(p + 4 <= bytes_.length, "startup observation bounds");
        return uint32(uint8(bytes_[p])) << 24 | uint32(uint8(bytes_[p + 1])) << 16
            | uint32(uint8(bytes_[p + 2])) << 8 | uint32(uint8(bytes_[p + 3]));
    }

    function source() private view returns (ResourceView memory v) {
        v.byteLength = 28741889;
        v.chunks = new address[](1755);
        for (uint256 i; i < v.chunks.length; ++i) {
            v.chunks[i] = address(uint160(0x100000 + i));
        }
        bytes memory directory = vm.readFileBinary("test/fixtures/phase2_data/directory.bin");
        v.lumps = new LumpDescriptor[](directory.length / 16);
        for (uint256 i; i < v.lumps.length; ++i) {
            bytes8 name;
            uint256 p = i * 16;
            assembly ("memory-safe") { name := mload(add(add(directory, 32), p)) }
            v.lumps[i] = LumpDescriptor(name, le32(directory, p + 8), le32(directory, p + 12));
        }
    }

    function definitions() private view returns (RenderContext memory c) {
        c.resources = R_Data.R_InitDataLazy(source());
        R_Things.R_InitSprites(c, Info.load().spriteNames);
    }

    function gold(string memory name) private view returns (bytes memory) {
        return vm.readFileBinary(string.concat("test/fixtures/phase3_zone_startup/", name));
    }

    function equalWord(bytes memory bytes_, uint256 p, uint32 value) private pure returns (uint256) {
        require(be32(bytes_, p) == value, "native startup header word");
        return p + 4;
    }

    function assertHeaders(ZoneState memory z) private view {
        bytes memory expected = gold("headers.bin");
        uint256 p;
        p = equalWord(expected, p, z.byteLength);
        p = equalWord(expected, p, z.blocks[z.rover].offset);
        p = equalWord(expected, p, z.blocks[z.blocks[0].prev].offset);
        p = equalWord(expected, p, z.blocks[z.blocks[0].next].offset);
        p = equalWord(expected, p, Z_Zone.Z_FreeMemory(z));
        uint32 count = be32(expected, p);
        p += 4;
        uint32 id = z.blocks[0].next;
        for (uint32 i; i < count; ++i) {
            require(id != 0, "native startup block count short");
            ZoneBlock memory block_ = z.blocks[id];
            p = equalWord(expected, p, block_.offset);
            p = equalWord(expected, p, block_.size);
            p = equalWord(expected, p, block_.allocated ? 1 : 0);
            p = equalWord(expected, p, block_.owner);
            // Original free-fragment tag bytes are not always initialized.
            p = equalWord(expected, p, block_.allocated ? uint32(block_.tag) : 0);
            p = equalWord(expected, p, block_.idKnown ? 1 : 0);
            p = equalWord(expected, p, block_.idKnown ? block_.id : 0);
            p = equalWord(expected, p, z.blocks[block_.prev].offset);
            p = equalWord(expected, p, z.blocks[block_.next].offset);
            id = block_.next;
        }
        require(id == 0, "native startup block count long");
        p = equalWord(expected, p, uint32(z.ownerBlocks.length));
        for (uint256 i; i < z.ownerBlocks.length; ++i) {
            uint32 ownerBlock = z.ownerBlocks[i];
            uint32 offset =
                ownerBlock == ZoneConst.NULL ? ZoneConst.NULL : Z_Zone.Z_PayloadOffset(z, ownerBlock);
            p = equalWord(expected, p, offset);
        }
        require(p == expected.length, "native startup trailing words");
        Z_Zone.Z_CheckHeap(z);
    }

    function testOriginalStartupOperationOrderAndFinalHeaders() public view {
        RenderContext memory c = definitions();
        ZoneState memory z = Z_Zone.Z_Init(
            64 * 1024 * 1024, uint32(c.resources.source.lumps.length + c.resources.textures.length)
        );
        (bytes32 digest, uint32 count) = DoomZoneStartup.replayObserved(z, c.resources, c.sprite.definitions);
        bytes memory expected = gold("summary.bin");
        require(expected.length == 36 && be32(expected, 0) == count, "native startup operation count");
        bytes32 originalDigest;
        assembly ("memory-safe") { originalDigest := mload(add(expected, 36)) }
        require(digest == originalDigest, "native startup operation order/arguments/placement");
        assertHeaders(z);
    }

    function testOriginalStartupWithoutObservationMatchesSameNativeHeaders() public {
        uint256 start = gasleft();
        RenderContext memory c = definitions();
        uint256 definitionGas = start - gasleft();
        start = gasleft();
        ZoneState memory z = Z_Zone.Z_Init(
            64 * 1024 * 1024, uint32(c.resources.source.lumps.length + c.resources.textures.length)
        );
        uint256 initGas = start - gasleft();
        start = gasleft();
        DoomZoneStartup.replay(z, c.resources, c.sprite.definitions);
        uint256 replayGas = start - gasleft();
        start = gasleft();
        assertHeaders(z);
        uint256 comparisonGas = start - gasleft();
        emit TestStageGas("resource-and-sprite-definition-loading", definitionGas);
        emit TestStageGas("zone-init", initGas);
        emit TestStageGas("normal-startup-replay", replayGas);
        emit TestStageGas("native-header-comparison", comparisonGas);
    }

    function testPinnedNativeSizeofConstants() public view {
        bytes memory expected = gold("layout.bin");
        uint256 p;
        p = equalWord(expected, p, DoomZoneStartup.POINTER_BYTES);
        p = equalWord(expected, p, DoomZoneStartup.INT_BYTES);
        p = equalWord(expected, p, DoomZoneStartup.SHORT_BYTES);
        p = equalWord(expected, p, DoomZoneStartup.TEXTURE_BYTES);
        p = equalWord(expected, p, DoomZoneStartup.TEXPATCH_BYTES);
        p = equalWord(expected, p, DoomZoneStartup.SPRITEDEF_BYTES);
        p = equalWord(expected, p, DoomZoneStartup.SPRITEFRAME_BYTES);
        require(p == expected.length, "native sizeof trailing words");
    }
}
