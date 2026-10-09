// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
// Copyright (C) 1993-1996 by id Software, Inc.
import {Ticcmd, GameInputState, KeyboardInput} from "./d_ticcmd.sol";
import {GameContext, GameState, Player, PlayerState, GameConst} from "./p_game_state.sol";
import {R_Data} from "./r_data.sol";

library G_Game {
    error InvalidTurnState(int32 turnheld);
    error InvalidWeaponRequest(uint8 request);

    /// @custom:source linuxdoom-1.10/g_game.c G_ExitLevel
    function G_ExitLevel(GameState memory state) internal pure {
        state.secretExit = false;
        state.gameaction = 6; // d_event.h ga_completed
    }

    /// @custom:source linuxdoom-1.10/g_game.c G_SecretExitLevel
    function G_SecretExitLevel(GameContext memory c) internal pure {
        c.state.secretExit =
        !(c.state.gamemode == 2 && R_Data.W_CheckNumForName(c.resources.source, "MAP31") < 0);
        c.state.gameaction = 6;
    }

    /// @custom:source linuxdoom-1.10/g_game.c G_PlayerReborn
    function G_PlayerReborn(GameState memory state, uint32 playerId) internal pure {
        Player memory old = state.players[playerId];
        Player memory fresh;
        // Original memcpy preserves these statistics across the memset.
        for (uint256 i; i < 4; ++i) {
            fresh.frags[i] = old.frags[i];
        }
        fresh.killcount = old.killcount;
        fresh.itemcount = old.itemcount;
        fresh.secretcount = old.secretcount;
        fresh.mo = GameConst.NULL;
        fresh.attacker = GameConst.NULL;
        fresh.psprites[0].state = GameConst.NULL;
        fresh.psprites[1].state = GameConst.NULL;
        fresh.usedown = 1;
        fresh.attackdown = 1;
        fresh.playerstate = PlayerState.live;
        fresh.health = 100;
        fresh.readyweapon = 1;
        fresh.pendingweapon = 1;
        fresh.weaponowned[0] = true;
        fresh.weaponowned[1] = true;
        fresh.ammo[0] = 50;
        fresh.maxammo = [int32(200), int32(50), int32(300), int32(50)];
        state.players[playerId] = fresh;
    }

    // Original g_game.c G_BuildTiccmd, declared keyboard profile: zero base command,
    // ticdup=1, single player, no chat/mouse/joystick/save/pause. See INPUT_PROTOCOL.md.
    // Unused original double-click clocks are omitted because device buttons stay zero.
    function G_BuildTiccmd(GameInputState memory state, KeyboardInput memory keys)
        internal
        pure
        returns (Ticcmd memory cmd)
    {
        if (keys.weaponRequest > 9) revert InvalidWeaponRequest(keys.weaponRequest);
        if (state.turnheld < 0) revert InvalidTurnState(state.turnheld);
        bool strafe = keys.strafe;
        uint256 speed = keys.speed ? 1 : 0;
        if (keys.right || keys.left) {
            if (state.turnheld == type(int32).max) revert InvalidTurnState(state.turnheld);
            ++state.turnheld;
        } else {
            state.turnheld = 0;
        }
        uint256 tspeed = state.turnheld < 6 ? 2 : speed;
        int32 side;
        int32 forward;
        int32 sideStep = speed == 0 ? int32(24) : int32(40);
        int16 turnStep = tspeed == 2 ? int16(320) : (tspeed == 0 ? int16(640) : int16(1280));
        if (strafe) {
            if (keys.right) side += sideStep;
            if (keys.left) side -= sideStep;
        } else {
            if (keys.right) cmd.angleturn -= turnStep;
            if (keys.left) cmd.angleturn += turnStep;
        }
        int32 forwardStep = speed == 0 ? int32(25) : int32(50);
        if (keys.up) forward += forwardStep;
        if (keys.down) forward -= forwardStep;
        if (keys.straferight) side += sideStep;
        if (keys.strafeleft) side -= sideStep;
        if (keys.fire) cmd.buttons |= 1; // BT_ATTACK
        if (keys.use) cmd.buttons |= 2; // BT_USE: held, not edge-detected here.
        // The original loop scans i < NUMWEAPONS-1: digit 9 is ignored.
        // Fist/chainsaw and shotgun/supershotgun resolution belongs to P_PlayerThink.
        if (keys.weaponRequest >= 1 && keys.weaponRequest <= 8) {
            cmd.buttons |= 4; // BT_CHANGE
            cmd.buttons |= (keys.weaponRequest - 1) << 3; // BT_WEAPONSHIFT
        }
        if (forward > 50) forward = 50;
        else if (forward < -50) forward = -50;
        if (side > 50) side = 50;
        else if (side < -50) side = -50;
        cmd.forwardmove += int8(forward);
        cmd.sidemove += int8(side);
    }
}
