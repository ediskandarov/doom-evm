// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {Ticcmd, GameInputState, KeyboardInput} from "../doom/d_ticcmd.sol";
import {G_Game} from "../doom/g_game.sol";
import {GameflowState} from "../doom/g_game.sol";
import {GameContext} from "../doom/p_game_state.sol";
import {CheatState, ST_Cheats} from "../doom/st_cheats.sol";
import {AutomapState} from "../doom/am_map_types.sol";
import {AM_Map} from "../doom/am_map.sol";
import {HU_Stuff} from "../doom/hu_stuff.sol";
import {ST_Stuff} from "../doom/st_stuff.sol";
import {UIState, DoomUI} from "./DoomUI.sol";
import {DoomGame} from "./DoomGame.sol";

/// @dev Original keyboard/parser/module globals; no borrowed geometry or callbacks.
struct InputRuntimeState {
    uint256 gamekeydown;
    CheatState cheats;
    AutomapState automap;
    GameflowState flow;
}

library InputProtocol {
    uint32 internal constant SUPPORTED_MASK = 0x3fff;
    error UnsupportedInputBits(uint32 held);
    error InvalidWeaponRequest(uint8 request);
    error InvalidKeyboardEvents();

    function initialize(InputRuntimeState memory s) internal pure {
        AM_Map.AM_Init(s.automap);
        ST_Cheats.initialize(s.cheats);
        s.flow.viewactive = true;
        s.flow.usergame = true;
        // Production startup has already synchronously installed the current level.
        s.flow.initialized = true;
    }

    function statusEvent(
        InputRuntimeState memory s,
        GameContext memory c,
        UIState memory u,
        int32 kind,
        int32 key
    ) private pure {
        ST_Stuff.ST_Responder(u.status, kind, key);
        ST_Cheats.ST_Responder(c, s.flow, s.cheats, uint8(uint32(kind)), key);
    }

    /// @custom:source g_game.c G_Responder GS_LEVEL and keyboard branches.
    /// @dev Packet is <=64 original keyboard events, each [type,key] bytes.
    /// All events, including repeat keydowns, reach responders exactly once.
    function respond(InputRuntimeState memory s, GameContext memory c, UIState memory u, bytes memory events)
        internal
        view
    {
        if (events.length > 128 || events.length % 2 != 0) revert InvalidKeyboardEvents();
        for (uint256 i; i < events.length; i += 2) {
            int32 kind = int32(uint32(uint8(events[i])));
            int32 key = int32(uint32(uint8(events[i + 1])));
            if (kind > 1) revert InvalidKeyboardEvents(); // mouse/joystick are outside production scope
            // G_Responder's spy branch precedes the level responders, even in
            // this single-player profile (where displayplayer returns to zero).
            if (c.state.gamestate == 0 && kind == 0 && key == 216 && c.state.deathmatch == 0) {
                do {
                    ++c.state.displayplayer;
                    if (c.state.displayplayer == 4) c.state.displayplayer = 0;
                } while (
                    !c.state.playeringame[uint32(c.state.displayplayer)]
                        && c.state.displayplayer != c.state.consoleplayer
                );
                continue;
            }
            if (c.state.gamestate == 0) {
                if (HU_Stuff.HU_Responder(u.hud, kind, key)) continue;
                statusEvent(s, c, u, kind, key);
                // Original reentrant AM_Start performs Stop -> notify -> Start.
                // Flush the stop here, because the library exposes its last notification.
                if (!s.automap.active && !s.automap.stopped && kind == 0 && key == 9) {
                    AM_Map.AM_Stop(s.automap);
                    statusEvent(s, c, u, s.automap.notification[0], s.automap.notification[1]);
                }
                bool activeBranch = s.automap.active && kind == 0;
                uint32 loads = s.automap.loads;
                uint32 unloads = s.automap.unloads;
                bool consumed =
                    AM_Map.AM_Responder(s.automap, DoomGame.automapWorld(c, s.automap.player), kind, key);
                if (s.automap.loads != loads || s.automap.unloads != unloads) {
                    // Stop's malformed [keydown,1,AM_MSGEXITED] also reaches ST cheats.
                    statusEvent(s, c, u, s.automap.notification[0], s.automap.notification[1]);
                    if (s.automap.loads != loads) DoomUI.automapPics(c.resources.source);
                }
                if (activeBranch && (key == 102 || key == 103 || key == 109 || key == 99)) {
                    c.state.players[s.automap.player].message = s.automap.message;
                }
                s.flow.automapactive = s.automap.active;
                s.flow.viewactive = s.automap.viewactive;
                if (consumed) continue;
            }
            if (kind == 0) {
                if (key == 255) G_Game.G_RequestPause(s.flow);
                else s.gamekeydown |= uint256(1) << uint32(key);
            } else {
                s.gamekeydown &= ~(uint256(1) << uint32(key));
            }
        }
    }

    function held(InputRuntimeState memory s, uint32 key) private pure returns (bool) {
        return s.gamekeydown & (uint256(1) << key) != 0;
    }

    /// @dev Original gamekeydown is projected into the accepted command builder.
    /// WASD/E are the retained browser profile's declared additional bindings.
    function build(InputRuntimeState memory s, GameContext memory c) internal pure returns (Ticcmd memory) {
        KeyboardInput memory k;
        k.up = held(s, 0xad) || held(s, 119);
        k.down = held(s, 0xaf) || held(s, 115);
        k.strafeleft = held(s, 44) || held(s, 97);
        k.straferight = held(s, 46) || held(s, 100);
        k.left = held(s, 0xac);
        k.right = held(s, 0xae);
        k.use = held(s, 32) || held(s, 101);
        k.fire = held(s, 0x9d);
        k.speed = held(s, 0xb6);
        k.strafe = held(s, 0xb8);
        for (uint8 i = 1; i <= 8; ++i) {
            if (held(s, 48 + i)) {
                k.weaponRequest = i;
                break;
            }
        }
        s.flow.keys = k;
        return G_Game.G_BuildTiccmd(c.state, s.flow);
    }

    function build(GameInputState memory state, uint32 held) internal pure returns (Ticcmd memory) {
        if (held & ~SUPPORTED_MASK != 0) revert UnsupportedInputBits(held);
        uint8 weapon = uint8((held >> 10) & 15);
        if (weapon > 9) revert InvalidWeaponRequest(weapon);
        KeyboardInput memory keys = KeyboardInput(
            held & 1 != 0,
            held & 2 != 0,
            held & 4 != 0,
            held & 8 != 0,
            held & 16 != 0,
            held & 32 != 0,
            held & 64 != 0,
            held & 128 != 0,
            held & 256 != 0,
            held & 512 != 0,
            weapon
        );
        return G_Game.G_BuildTiccmd(state, keys);
    }
}
