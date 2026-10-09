// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {GameContext, Mobj, Thinker, ThinkerKind, GameConst as C} from "./p_game_state.sol";
import {P_Info} from "./p_info.sol";
import {Tables} from "./tables.sol";

/// @custom:source linuxdoom-1.10/p_telept.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
library P_Telept {
    function EV_Teleport(GameContext memory c, uint32 line, int32 side, uint32 thing)
        internal
        view
        returns (int32)
    {
        unchecked {
            Mobj memory actor = c.state.mobjs[thing];
            if (actor.flags & C.MF_MISSILE != 0 || side == 1) return 0;
            int32 tag = c.map.lines[line].tag;
            for (uint32 sec; sec < c.state.sectors.length; sec++) {
                if (c.state.sectors[sec].tag != tag) continue;
                for (uint32 id = c.state.thinkers[0].next; id != 0; id = c.state.thinkers[id].next) {
                    Thinker memory thinker = c.state.thinkers[id];
                    if (thinker.kind != ThinkerKind.mobj || thinker.status != C.THINKER_ACTIVE) continue;
                    Mobj memory marker = c.state.mobjs[thinker.payload];
                    if (marker.mobjType != P_Info.MT_TELEPORTMAN) continue;
                    if (c.map.subsectors[marker.subsector].sector != sec) continue;
                    int32 oldx = actor.x;
                    int32 oldy = actor.y;
                    int32 oldz = actor.z;
                    if (!c.hooks.teleportMove(c, thing, marker.x, marker.y)) return 0;
                    actor.z = actor.floorz;
                    if (actor.player != C.NULL) {
                        c.state.players[actor.player].viewz =
                            actor.z + c.state.players[actor.player].viewheight;
                    }
                    c.hooks.spawnMobj(c, oldx, oldy, oldz, P_Info.MT_TFOG);
                    uint32 an = marker.angle >> 19;
                    c.hooks
                        .spawnMobj(
                            c,
                            marker.x + 20 * Tables.finecosine(an),
                            marker.y + 20 * Tables.finesine(an),
                            actor.z,
                            P_Info.MT_TFOG
                        );
                    if (actor.player != C.NULL) actor.reactiontime = 18;
                    actor.angle = marker.angle;
                    actor.momx = 0;
                    actor.momy = 0;
                    actor.momz = 0;
                    return 1;
                }
            }
            return 0;
        }
    }
}
