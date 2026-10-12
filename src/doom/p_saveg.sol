// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {GameState} from "./p_game_state.sol";
import {UIState} from "../evm/DoomUI.sol";
import {InputRuntimeState} from "../evm/InputProtocol.sol";
import {EpisodeState} from "../evm/EpisodeRuntime.sol";
import {SaveSchema} from "../evm/SaveSchema.sol";

/// @custom:source linuxdoom-1.10/p_saveg.c archive/unarchive operations at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @dev EVM archive representation adaptation: exact rooted persisted storage
/// replaces C memcpy/pointer swizzling. Includes RNG, original globals, thinker
/// order, stable IDs and allocator history beyond the deliberately lossy C file.
/// No pointer, transient decode, callback, resource or protocol storage is added.
library P_Saveg {
    error InvalidArchive();
    error ArchiveTooLarge();

    uint256 internal constant MAX_WORDS = 262144; // 8 MiB encoded, before any game/resource decode.

    struct Cursor {
        bytes schema;
        bytes data;
        uint256 position;
        uint8 mode; // 0 count, 1 archive, 2 restore
    }

    function schemaHash() internal pure returns (bytes32) {
        return keccak256(SaveSchema.DATA);
    }

    function short(bytes memory b, uint256 p) private pure returns (uint256) {
        return uint256(uint8(b[p])) * 256 + uint8(b[p + 1]);
    }

    function node(Cursor memory c, uint16 id) private pure returns (uint256 p) {
        if (id >= SaveSchema.NODES) revert InvalidArchive();
        p = uint256(SaveSchema.NODES) * 2 + short(c.schema, uint256(id) * 2);
    }

    function readSlot(uint256 slot) private view returns (uint256 value) {
        assembly ("memory-safe") { value := sload(slot) }
    }

    function base(uint256 slot) private pure returns (uint256 value) {
        // The scratch word0 is inside Solidity's reserved scratch region.
        assembly ("memory-safe") {
            mstore(0, slot)
            value := keccak256(0, 32)
        }
    }

    function words(Cursor memory c, uint256 slot, uint256 count) private {
        if (count > MAX_WORDS || c.position > MAX_WORDS - count) revert ArchiveTooLarge();
        uint256 end = c.position + count;
        if (c.mode != 0 && end > c.data.length / 32) revert InvalidArchive();
        if (c.mode != 0) {
            bytes memory data = c.data;
            uint256 start = c.position;
            if (c.mode == 1) {
                // start..end words lie entirely within the allocated bytes payload.
                assembly ("memory-safe") {
                    for { let i := 0 } lt(i, count) { i := add(i, 1) } {
                        mstore(add(add(data, 32), mul(add(start, i), 32)), sload(add(slot, i)))
                    }
                }
            } else {
                // The same checked payload bounds apply to every mload. Slots
                // originate solely from typed roots and generated field topology.
                assembly ("memory-safe") {
                    for { let i := 0 } lt(i, count) { i := add(i, 1) } {
                        sstore(add(slot, i), mload(add(add(data, 32), mul(add(start, i), 32))))
                    }
                }
            }
        }
        c.position = end;
    }

    /// @dev Fixed words were already visited by the parent. Descend only into
    /// storage regions referenced by bytes/array heads or nested dynamic fields.
    function descendants(Cursor memory c, uint256 slot, uint16 id) private {
        uint256 p = node(c, id);
        uint8 kind = uint8(c.schema[p]);
        if (kind == 1) {
            uint256 head = readSlot(slot);
            if (head & 1 == 0) {
                if ((head & 255) > 62) revert InvalidArchive();
            } else {
                uint256 length = head >> 1;
                if (length < 32 || length > MAX_WORDS * 32) revert InvalidArchive();
                words(c, base(slot), (length + 31) / 32);
            }
        } else if (kind == 2) {
            uint256 length = readSlot(slot);
            uint16 element = uint16(short(c.schema, p + 9));
            uint256 ep = node(c, element);
            uint256 width = short(c.schema, ep + 1);
            if (length > MAX_WORDS || width == 0 || length > MAX_WORDS * 32 / width) {
                revert ArchiveTooLarge();
            }
            uint256 first = base(slot);
            words(
                c,
                first,
                width <= 32 ? (length + 32 / width - 1) / (32 / width) : length * ((width + 31) / 32)
            );
            if (uint8(c.schema[ep]) != 0 || short(c.schema, ep + 5) != 0) {
                // Elements with descendants own at least one whole storage word.
                if (width < 32) revert InvalidArchive();
                uint256 stride = (width + 31) / 32;
                for (uint256 i; i < length; ++i) {
                    descendants(c, first + i * stride, element);
                }
            }
        } else if (kind == 3) {
            uint256 length = short(c.schema, p + 7);
            uint16 element = uint16(short(c.schema, p + 9));
            uint256 ep = node(c, element);
            if (uint8(c.schema[ep]) != 0 || short(c.schema, ep + 5) != 0) {
                uint256 stride = short(c.schema, ep + 3);
                for (uint256 i; i < length; ++i) {
                    descendants(c, slot + i * stride, element);
                }
            }
        } else {
            uint256 count = short(c.schema, p + 5);
            for (uint256 i; i < count; ++i) {
                uint256 child = p + 7 + i * 4;
                descendants(c, slot + short(c.schema, child), uint16(short(c.schema, child + 2)));
            }
        }
    }

    function root(Cursor memory c, uint256 slot, uint16 id) private {
        words(c, slot, short(c.schema, node(c, id) + 3));
        descendants(c, slot, id);
    }

    function visit(
        Cursor memory c,
        GameState storage g,
        UIState storage u,
        InputRuntimeState storage i,
        EpisodeState storage e
    ) private {
        uint256 gs;
        uint256 us;
        uint256 ins;
        uint256 es;
        assembly ("memory-safe") {
            gs := g.slot
            us := u.slot
            ins := i.slot
            es := e.slot
        }
        root(c, gs, SaveSchema.GAMESTATE);
        root(c, us, SaveSchema.UISTATE);
        root(c, ins, SaveSchema.INPUTRUNTIME);
        root(c, es, SaveSchema.EPISODESTATE);
    }

    function P_Archive(
        GameState storage g,
        UIState storage u,
        InputRuntimeState storage i,
        EpisodeState storage e
    ) internal returns (bytes memory data) {
        Cursor memory c;
        c.schema = SaveSchema.DATA;
        visit(c, g, u, i, e);
        data = new bytes(c.position * 32);
        c.data = data;
        c.position = 0;
        c.mode = 1;
        visit(c, g, u, i, e);
    }

    function P_UnArchive(
        GameState storage g,
        UIState storage u,
        InputRuntimeState storage i,
        EpisodeState storage e,
        bytes memory data
    ) internal {
        if (data.length == 0 || data.length % 32 != 0 || data.length > MAX_WORDS * 32) revert InvalidArchive();
        Cursor memory c;
        c.schema = SaveSchema.DATA;
        c.data = data;
        c.mode = 2;
        visit(c, g, u, i, e);
        if (c.position * 32 != data.length) revert InvalidArchive();
    }
}
