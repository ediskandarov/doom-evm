// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {GameState, GameContext, ThinkerKind} from "../../src/doom/p_game_state.sol";
import {P_Heap} from "../../src/doom/p_heap.sol";
import {P_Tick} from "../../src/doom/p_tick.sol";
import {Z_Zone} from "../../src/doom/z_zone.sol";
import {ZoneConst} from "../../src/doom/z_zone_types.sol";

contract GameZoneHeapTest {
    GameState private saved;

    function testAllEmbeddedPayloadSizesTagsAndNoThinkerDoubleAllocation() public pure {
        GameState memory s;
        s.nativeZone = Z_Zone.Z_Init(65536, 0);
        P_Tick.P_InitThinkers(s);
        uint32[9] memory payloads;
        payloads[0] = P_Heap.allocateMobj(s);
        payloads[1] = P_Heap.allocateDoor(s);
        payloads[2] = P_Heap.allocateFloorMove(s);
        payloads[3] = P_Heap.allocateCeilingMove(s);
        payloads[4] = P_Heap.allocatePlat(s);
        payloads[5] = P_Heap.allocateFireFlicker(s);
        payloads[6] = P_Heap.allocateLightFlash(s);
        payloads[7] = P_Heap.allocateStrobe(s);
        payloads[8] = P_Heap.allocateGlow(s);
        // Actual C sizeof exports, including the embedded 24-byte thinker.
        uint32[9] memory sizes = [uint32(224), 64, 64, 72, 72, 48, 56, 56, 48];
        uint32 offset = 56;
        uint32 blockCount = s.nativeZone.blockCount;
        for (uint32 i; i < 9; ++i) {
            uint32 blockId = s.nativePayloadBlocks[i][payloads[i]];
            require(s.nativeZone.blocks[blockId].offset == offset, "original placement");
            require(s.nativeZone.blocks[blockId].size == sizes[i] + 40, "native sizeof");
            require(s.nativeZone.blocks[blockId].tag == (i == 0 ? 50 : 51), "original tag");
            require(s.nativeZone.blocks[blockId].owner == ZoneConst.NULL, "unowned payload");
            P_Tick.P_AddThinker(s, ThinkerKind(i + 1), payloads[i]);
            offset += sizes[i] + 40;
        }
        require(s.nativeZone.blockCount == blockCount, "thinker embeds in existing payload");
        Z_Zone.Z_CheckHeap(s.nativeZone);
    }

    function testLazyFreeAndPhysicalReuseKeepStablePayloadIdentity() public view {
        GameContext memory c;
        c.state.nativeZone = Z_Zone.Z_Init(65536, 0);
        P_Tick.P_InitThinkers(c.state);
        uint32 first = P_Heap.allocateMobj(c.state);
        c.state.mobjs[first].allocated = true;
        uint32 blockId = c.state.nativePayloadBlocks[0][first];
        uint32 offset = c.state.nativeZone.blocks[blockId].offset;
        uint32 thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.mobj, first);
        P_Tick.P_RemoveThinker(c.state, thinker);
        require(c.state.nativeZone.blocks[blockId].allocated, "removal remains lazy");
        P_Tick.P_RunThinkers(c);
        require(!c.state.mobjs[first].allocated, "logical tombstone");
        require(c.state.nativePayloadBlocks[0][first] == 0, "physical ownership cleared");
        uint32 second = P_Heap.allocateMobj(c.state);
        require(second == first + 1, "stable actor identity not reused");
        uint32 secondBlock = c.state.nativePayloadBlocks[0][second];
        require(c.state.nativeZone.blocks[secondBlock].offset == offset, "original physical reuse");
        require(c.state.thinkers[0].next == 0, "original unlink");
        Z_Zone.Z_CheckHeap(c.state.nativeZone);
    }

    function testPoolGrowthZoneStorageAndResourceAlias() public {
        GameContext memory c;
        c.state.nativeZone = Z_Zone.Z_Init(65536, 1);
        c.resources.nativeZone = c.state.nativeZone;
        for (uint32 i; i < 17; ++i) {
            require(P_Heap.allocateMobj(c.state) == i, "stable ID");
        }
        uint32 last = c.state.nativePayloadBlocks[0][16];
        require(c.resources.nativeZone.blocks[last].allocated, "resource alias sees growth");
        require(c.state.mobjs.length == 32 && c.state.nativePayloadBlocks[0].length == 32, "pool growth");
        saved = c.state;
        GameContext memory next;
        next.state = saved;
        next.resources.nativeZone = next.state.nativeZone;
        require(next.state.nativePayloadBlocks[0][16] == last, "payload block storage");
        require(next.resources.nativeZone.blocks[last].offset == 56 + 16 * 264, "native storage layout");
        uint32 cache = Z_Zone.Z_Malloc(next.resources.nativeZone, 17, 101, 0);
        require(next.state.nativeZone.ownerBlocks[0] == cache, "owner alias persists");
        saved = next.state;
        require(saved.nativeZone.ownerBlocks[0] == cache, "owner mark storage");
        require(saved.nativeZone.blocks[cache].id == ZoneConst.ZONEID, "known header storage");
    }
}
