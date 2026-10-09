// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;

import {GameContext, GameState, Thinker, ThinkerKind, GameConst} from "./p_game_state.sol";
import {P_Heap} from "./p_heap.sol";

/// @custom:source linuxdoom-1.10/p_tick.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
library P_Tick {
    error InvalidThinker();

    function P_InitThinkers(GameState memory s) internal pure {
        // A fresh level owns a fresh list. Existing actors are released by level setup.
        s.thinkers = new Thinker[](8);
        s.thinkerCount = 1;
        s.thinkers[0].prev = 0;
        s.thinkers[0].next = 0;
        s.thinkers[0].kind = ThinkerKind.cap;
        s.thinkers[0].status = GameConst.THINKER_STASIS;
    }

    /// @dev Z_Malloc's allocation is represented by P_Heap; insertion is original tail order.
    function P_AddThinker(GameState memory s, ThinkerKind kind, uint32 payload)
        internal
        pure
        returns (uint32 id)
    {
        if (s.thinkerCount == 0 || kind == ThinkerKind.cap) revert InvalidThinker();
        id = P_Heap.allocateThinker(s);
        Thinker memory thinker = s.thinkers[id];
        thinker.kind = kind;
        thinker.payload = payload;
        thinker.status = GameConst.THINKER_ACTIVE;
        thinker.prev = s.thinkers[0].prev;
        s.thinkers[thinker.prev].next = id;
        thinker.next = 0;
        s.thinkers[0].prev = id;
    }

    function P_RemoveThinker(GameState memory s, uint32 id) internal pure {
        if (id == 0 || id >= s.thinkerCount) revert InvalidThinker();
        s.thinkers[id].status = GameConst.THINKER_REMOVE;
    }

    /// @dev Original P_AllocateThinker is an empty function, distinct from Z_Malloc.
    function P_AllocateThinker(GameState memory, uint32) internal pure {}

    function P_RunThinkers(GameContext memory c) internal view {
        uint32 current = c.state.thinkers[0].next;
        while (current != 0) {
            if (current >= c.state.thinkerCount) revert InvalidThinker();
            Thinker memory thinker = c.state.thinkers[current];
            if (thinker.status == GameConst.THINKER_REMOVE) {
                c.state.thinkers[thinker.next].prev = thinker.prev;
                c.state.thinkers[thinker.prev].next = thinker.next;
                // The stable payload remains a tombstone, replacing zone deallocation.
                if (thinker.kind == ThinkerKind.mobj) c.state.mobjs[thinker.payload].allocated = false;
            } else if (thinker.status == GameConst.THINKER_ACTIVE) {
                c.hooks.thinkerDispatch(c, current);
            }
            // Read AFTER the callback: its newly appended tail can run in this same tic.
            current = thinker.next;
        }
    }

    function P_Ticker(GameContext memory c) internal view {
        if (c.state.paused) return;
        if (
            !c.state.netgame && c.state.menuactive && !c.state.demoplayback
                && c.state.players[uint32(c.state.consoleplayer)].viewz != 1
        ) return;
        for (uint32 i; i < 4; ++i) {
            if (c.state.playeringame[i]) c.hooks.playerThink(c, i);
        }
        P_RunThinkers(c);
        c.hooks.updateSpecials(c);
        c.hooks.respawnSpecials(c);
        unchecked {
            ++c.state.leveltime;
        }
    }
}
