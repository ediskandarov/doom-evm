// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {Z_Zone} from "../../src/doom/z_zone.sol";
import {ZoneState, ZoneBlock, ZoneConst as C} from "../../src/doom/z_zone_types.sol";

interface ZoneVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
}

struct ZoneWords {
    bytes data;
    uint256 cursor;
}

contract ZoneTest {
    ZoneVm constant vm = ZoneVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    error ZoneMismatch(uint32 row);

    function word(bytes memory data, uint256 at) private pure returns (uint32) {
        return uint32(uint8(data[at])) << 24 | uint32(uint8(data[at + 1])) << 16 | uint32(uint8(data[at + 2]))
            << 8 | uint32(uint8(data[at + 3]));
    }

    function put(ZoneWords memory out, uint32 value) private pure {
        uint256 at = out.cursor;
        require(at + 4 <= out.data.length);
        out.data[at] = bytes1(uint8(value >> 24));
        out.data[at + 1] = bytes1(uint8(value >> 16));
        out.data[at + 2] = bytes1(uint8(value >> 8));
        out.data[at + 3] = bytes1(uint8(value));
        out.cursor = at + 4;
    }

    function snapshot(ZoneState memory z, ZoneWords memory out) private pure {
        out.cursor = 0;
        put(out, z.byteLength);
        put(out, z.blocks[z.rover].offset);
        put(out, z.blocks[z.blocks[0].prev].offset);
        put(out, z.blocks[z.blocks[0].next].offset);
        put(out, Z_Zone.Z_FreeMemory(z));
        uint32 count;
        for (uint32 i = z.blocks[0].next; i != 0; i = z.blocks[i].next) {
            ++count;
        }
        put(out, count);
        for (uint32 i = z.blocks[0].next; i != 0; i = z.blocks[i].next) {
            ZoneBlock memory b = z.blocks[i];
            put(out, b.offset);
            put(out, b.size);
            put(out, b.allocated ? 1 : 0);
            put(out, b.owner);
            put(out, b.tag);
            put(out, b.idKnown ? 1 : 0);
            put(out, b.idKnown ? b.id : 0);
            put(out, z.blocks[b.prev].offset);
            put(out, z.blocks[b.next].offset);
        }
        for (uint32 i; i < 16; ++i) {
            put(out, z.ownerBlocks[i] == C.NULL ? C.NULL : Z_Zone.Z_PayloadOffset(z, z.ownerBlocks[i]));
        }
    }

    function atOffset(ZoneState memory z, uint32 offset) private pure returns (uint32) {
        for (uint32 i = z.blocks[0].next; i != 0; i = z.blocks[i].next) {
            if (z.blocks[i].offset == offset) return i;
        }
        revert("missing header");
    }

    function advance(ZoneState memory z, uint32 op, uint32 a, uint32 b, uint32 c) private pure {
        if (op == 1) Z_Zone.Z_Malloc(z, a, uint8(b), c);
        else if (op == 2) Z_Zone.Z_Free(z, z.ownerBlocks[a]);
        else if (op == 3) Z_Zone.Z_FreeTags(z, uint8(a), uint8(b));
        else if (op == 4) Z_Zone.Z_ChangeTag(z, z.ownerBlocks[a], uint8(b));
        else if (op == 5) Z_Zone.Z_ClearZone(z);
        else if (op == 6) Z_Zone.Z_CheckHeap(z);
        else if (op == 7) Z_Zone.Z_Free(z, atOffset(z, a));
        else if (op == 8) Z_Zone.Z_ChangeTag(z, atOffset(z, a), uint8(b));
        else revert("unknown op");
    }

    function testAllOriginalZoneSequences() public view {
        bytes memory tape = vm.readFileBinary("test/fixtures/phase3_zone_allocator/vectors.bin");
        uint32 rows = word(tape, 0);
        uint256 at = 4;
        ZoneState memory z;
        ZoneWords memory out;
        out.data = new bytes(1024);
        for (uint32 row; row < rows; ++row) {
            uint32 op = word(tape, at);
            uint32 a = word(tape, at + 4);
            uint32 b = word(tape, at + 8);
            uint32 c = word(tape, at + 12);
            uint32 size = word(tape, at + 16);
            at += 20;
            if (op == 0) z = Z_Zone.Z_Init(a, 16);
            else advance(z, op, a, b, c);
            Z_Zone.Z_CheckHeap(z);
            snapshot(z, out);
            if (out.cursor != size) revert ZoneMismatch(row);
            for (uint256 k; k < size; ++k) {
                if (out.data[k] != tape[at + k]) revert ZoneMismatch(row);
            }
            at += size;
        }
        require(at == tape.length, "trailing fixture");
    }

    function mallocUnownedCache() external pure {
        ZoneState memory z = Z_Zone.Z_Init(512, 0);
        Z_Zone.Z_Malloc(z, 8, 101, C.NULL);
    }

    function changeUnownedCache() external pure {
        ZoneState memory z = Z_Zone.Z_Init(512, 0);
        uint32 id = Z_Zone.Z_Malloc(z, 8, 1, C.NULL);
        Z_Zone.Z_ChangeTag(z, id, 100);
    }

    function doubleFree() external pure {
        ZoneState memory z = Z_Zone.Z_Init(512, 0);
        uint32 id = Z_Zone.Z_Malloc(z, 8, 1, C.NULL);
        Z_Zone.Z_Free(z, id);
        Z_Zone.Z_Free(z, id);
    }

    function exhaust() external pure {
        ZoneState memory z = Z_Zone.Z_Init(232, 0);
        Z_Zone.Z_Malloc(z, 72, 1, C.NULL);
        Z_Zone.Z_Malloc(z, 0, 1, C.NULL);
    }

    function corrupt() external pure {
        ZoneState memory z = Z_Zone.Z_Init(512, 0);
        Z_Zone.Z_Malloc(z, 8, 1, C.NULL);
        z.blocks[z.blocks[1].next].prev = 0;
        Z_Zone.Z_CheckHeap(z);
    }

    function testOriginalFatalDomains() public {
        vm.expectRevert(Z_Zone.OwnerRequired.selector);
        this.mallocUnownedCache();
        vm.expectRevert(Z_Zone.OwnerRequired.selector);
        this.changeUnownedCache();
        vm.expectRevert(Z_Zone.InvalidBlock.selector);
        this.doubleFree();
        vm.expectRevert(abi.encodeWithSelector(Z_Zone.AllocationFailed.selector, uint32(40)));
        this.exhaust();
        vm.expectRevert(Z_Zone.CorruptHeap.selector);
        this.corrupt();
    }
}
