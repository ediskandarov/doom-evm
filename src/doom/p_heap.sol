// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {
    GameState,
    ThinkerKind,
    Mobj,
    Thinker,
    Door,
    FloorMove,
    CeilingMove,
    Plat,
    FireFlicker,
    LightFlash,
    Strobe,
    Glow
} from "./p_game_state.sol";

import {Z_Zone} from "./z_zone.sol";
import {ZoneConst} from "./z_zone_types.sol";
import {NativeZoneLayout} from "./native_zone_layout.sol";

/// @notice Z_Malloc adapter: stable slots, geometric memory pools, original linked-list order.
/// @dev Pool capacity is not thinker/actor iteration order; only live lists drive simulation.
library P_Heap {
    error PoolExhausted();

    function allocateMobj(GameState memory s) internal pure returns (uint32 index) {
        index = s.mobjCount;
        if (index == type(uint32).max) revert PoolExhausted();
        if (index == s.mobjs.length) {
            uint256 capacity = s.mobjs.length == 0 ? 8 : s.mobjs.length * 2;
            if (capacity > type(uint32).max) revert PoolExhausted();
            Mobj[] memory grown = new Mobj[](capacity);
            for (uint256 i; i < index; ++i) {
                grown[i] = s.mobjs[i];
            }
            s.mobjs = grown;
        }
        s.mobjCount = index + 1;
        allocateNativePayload(s, ThinkerKind.mobj, index, NativeZoneLayout.MOBJ_SIZE);
    }

    function allocateThinker(GameState memory s) internal pure returns (uint32 index) {
        index = s.thinkerCount;
        if (index == type(uint32).max) revert PoolExhausted();
        if (index == s.thinkers.length) {
            uint256 capacity = s.thinkers.length == 0 ? 8 : s.thinkers.length * 2;
            if (capacity > type(uint32).max) revert PoolExhausted();
            Thinker[] memory grown = new Thinker[](capacity);
            for (uint256 i; i < index; ++i) {
                grown[i] = s.thinkers[i];
            }
            s.thinkers = grown;
        }
        s.thinkerCount = index + 1;
    }

    function allocateDoor(GameState memory s) internal pure returns (uint32 index) {
        index = s.doorCount;
        if (index == type(uint32).max) revert PoolExhausted();
        if (index == s.doors.length) {
            uint256 capacity = s.doors.length == 0 ? 8 : s.doors.length * 2;
            if (capacity > type(uint32).max) revert PoolExhausted();
            Door[] memory grown = new Door[](capacity);
            for (uint256 i; i < index; ++i) {
                grown[i] = s.doors[i];
            }
            s.doors = grown;
        }
        s.doorCount = index + 1;
        allocateNativePayload(s, ThinkerKind.door, index, NativeZoneLayout.VLDOOR_SIZE);
    }

    function allocateFloorMove(GameState memory s) internal pure returns (uint32 index) {
        index = s.floorCount;
        if (index == type(uint32).max) revert PoolExhausted();
        if (index == s.floors.length) {
            uint256 capacity = s.floors.length == 0 ? 8 : s.floors.length * 2;
            if (capacity > type(uint32).max) revert PoolExhausted();
            FloorMove[] memory grown = new FloorMove[](capacity);
            for (uint256 i; i < index; ++i) {
                grown[i] = s.floors[i];
            }
            s.floors = grown;
        }
        s.floorCount = index + 1;
        allocateNativePayload(s, ThinkerKind.floor, index, NativeZoneLayout.FLOORMOVE_SIZE);
    }

    function allocateCeilingMove(GameState memory s) internal pure returns (uint32 index) {
        index = s.ceilingCount;
        if (index == type(uint32).max) revert PoolExhausted();
        if (index == s.ceilings.length) {
            uint256 capacity = s.ceilings.length == 0 ? 8 : s.ceilings.length * 2;
            if (capacity > type(uint32).max) revert PoolExhausted();
            CeilingMove[] memory grown = new CeilingMove[](capacity);
            for (uint256 i; i < index; ++i) {
                grown[i] = s.ceilings[i];
            }
            s.ceilings = grown;
        }
        s.ceilingCount = index + 1;
        allocateNativePayload(s, ThinkerKind.ceiling, index, NativeZoneLayout.CEILING_SIZE);
    }

    function allocatePlat(GameState memory s) internal pure returns (uint32 index) {
        index = s.platCount;
        if (index == type(uint32).max) revert PoolExhausted();
        if (index == s.plats.length) {
            uint256 capacity = s.plats.length == 0 ? 8 : s.plats.length * 2;
            if (capacity > type(uint32).max) revert PoolExhausted();
            Plat[] memory grown = new Plat[](capacity);
            for (uint256 i; i < index; ++i) {
                grown[i] = s.plats[i];
            }
            s.plats = grown;
        }
        s.platCount = index + 1;
        allocateNativePayload(s, ThinkerKind.plat, index, NativeZoneLayout.PLAT_SIZE);
    }

    function allocateFireFlicker(GameState memory s) internal pure returns (uint32 index) {
        index = s.fireFlickerCount;
        if (index == type(uint32).max) revert PoolExhausted();
        if (index == s.fireFlickers.length) {
            uint256 capacity = s.fireFlickers.length == 0 ? 8 : s.fireFlickers.length * 2;
            if (capacity > type(uint32).max) revert PoolExhausted();
            FireFlicker[] memory grown = new FireFlicker[](capacity);
            for (uint256 i; i < index; ++i) {
                grown[i] = s.fireFlickers[i];
            }
            s.fireFlickers = grown;
        }
        s.fireFlickerCount = index + 1;
        allocateNativePayload(s, ThinkerKind.fireFlicker, index, NativeZoneLayout.FIREFLICKER_SIZE);
    }

    function allocateLightFlash(GameState memory s) internal pure returns (uint32 index) {
        index = s.lightFlashCount;
        if (index == type(uint32).max) revert PoolExhausted();
        if (index == s.lightFlashes.length) {
            uint256 capacity = s.lightFlashes.length == 0 ? 8 : s.lightFlashes.length * 2;
            if (capacity > type(uint32).max) revert PoolExhausted();
            LightFlash[] memory grown = new LightFlash[](capacity);
            for (uint256 i; i < index; ++i) {
                grown[i] = s.lightFlashes[i];
            }
            s.lightFlashes = grown;
        }
        s.lightFlashCount = index + 1;
        allocateNativePayload(s, ThinkerKind.lightFlash, index, NativeZoneLayout.LIGHTFLASH_SIZE);
    }

    function allocateStrobe(GameState memory s) internal pure returns (uint32 index) {
        index = s.strobeCount;
        if (index == type(uint32).max) revert PoolExhausted();
        if (index == s.strobes.length) {
            uint256 capacity = s.strobes.length == 0 ? 8 : s.strobes.length * 2;
            if (capacity > type(uint32).max) revert PoolExhausted();
            Strobe[] memory grown = new Strobe[](capacity);
            for (uint256 i; i < index; ++i) {
                grown[i] = s.strobes[i];
            }
            s.strobes = grown;
        }
        s.strobeCount = index + 1;
        allocateNativePayload(s, ThinkerKind.strobe, index, NativeZoneLayout.STROBE_SIZE);
    }

    function allocateGlow(GameState memory s) internal pure returns (uint32 index) {
        index = s.glowCount;
        if (index == type(uint32).max) revert PoolExhausted();
        if (index == s.glows.length) {
            uint256 capacity = s.glows.length == 0 ? 8 : s.glows.length * 2;
            if (capacity > type(uint32).max) revert PoolExhausted();
            Glow[] memory grown = new Glow[](capacity);
            for (uint256 i; i < index; ++i) {
                grown[i] = s.glows[i];
            }
            s.glows = grown;
        }
        s.glowCount = index + 1;
        allocateNativePayload(s, ThinkerKind.glow, index, NativeZoneLayout.GLOW_SIZE);
    }

    /// @dev Original payload embeds thinker_t; pool/index growth has no native allocation.
    function allocateNativePayload(GameState memory s, ThinkerKind kind, uint32 index, uint32 size)
        private
        pure
    {
        if (s.nativeZone.byteLength == 0) return;
        uint32 slot = uint32(kind) - 1;
        uint32[] memory blocks = s.nativePayloadBlocks[slot];
        if (index == blocks.length) {
            uint256 capacity = blocks.length == 0 ? 8 : blocks.length * 2;
            uint32[] memory grown = new uint32[](capacity);
            for (uint256 i; i < index; ++i) grown[i] = blocks[i];
            s.nativePayloadBlocks[slot] = grown;
            blocks = grown;
        }
        if (index >= blocks.length || blocks[index] != 0) revert PoolExhausted();
        blocks[index] = Z_Zone.Z_Malloc(
            s.nativeZone, size, kind == ThinkerKind.mobj ? ZoneConst.PU_LEVEL : ZoneConst.PU_LEVSPEC,
            ZoneConst.NULL
        );
    }

    /// @dev Original P_RunThinkers frees only when lazy removal reaches this node.
    /// Stable Solidity payloads remain tombstones, while the physical block is reusable.
    function freeNativePayload(GameState memory s, ThinkerKind kind, uint32 index) internal pure {
        if (s.nativeZone.byteLength == 0) return;
        uint32 slot = uint32(kind) - 1;
        if (index >= s.nativePayloadBlocks[slot].length) revert PoolExhausted();
        uint32 blockId = s.nativePayloadBlocks[slot][index];
        if (blockId == 0) revert PoolExhausted();
        Z_Zone.Z_Free(s.nativeZone, blockId);
        s.nativePayloadBlocks[slot][index] = 0;
    }
}
