// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {
    GameState,
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
    }
}
