// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;

import {GameContext, Player, PlayerState, Mobj, GameConst} from "./p_game_state.sol";
import {Ticcmd} from "./d_ticcmd.sol";
import {M_Fixed} from "./m_fixed.sol";
import {Tables} from "./tables.sol";
import {P_Info} from "./p_info.sol";
import {R_Main} from "./r_main.sol";
import {RenderState} from "./r_state.sol";

/// @custom:source linuxdoom-1.10/p_user.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
library P_User {
    function P_Thrust(GameContext memory c, uint32 playerId, uint32 angle, int32 move) internal pure {
        Mobj memory mo = c.state.mobjs[c.state.players[playerId].mo];
        angle >>= 19;
        unchecked {
            mo.momx += M_Fixed.FixedMul(move, Tables.finecosine(angle));
            mo.momy += M_Fixed.FixedMul(move, Tables.finesine(angle));
        }
    }

    function P_CalcHeight(GameContext memory c, uint32 playerId) internal pure {
        Player memory player = c.state.players[playerId];
        Mobj memory mo = c.state.mobjs[player.mo];
        unchecked {
            player.bob = M_Fixed.FixedMul(mo.momx, mo.momx) + M_Fixed.FixedMul(mo.momy, mo.momy);
            player.bob >>= 2;
            if (player.bob > 0x100000) player.bob = 0x100000;
            if ((player.cheats & GameConst.CF_NOMOMENTUM) != 0 || !c.move.onground) {
                player.viewz = mo.z + GameConst.VIEWHEIGHT;
                if (player.viewz > mo.ceilingz - 4 * 65536) player.viewz = mo.ceilingz - 4 * 65536;
                // Original overwrites the previous clamp in the airborne branch.
                player.viewz = mo.z + player.viewheight;
                return;
            }
            uint32 angle = uint32((int32(8192) / 20 * c.state.leveltime) & 8191);
            int32 bob = M_Fixed.FixedMul(player.bob / 2, Tables.finesine(angle));
            if (player.playerstate == PlayerState.live) {
                player.viewheight += player.deltaviewheight;
                if (player.viewheight > GameConst.VIEWHEIGHT) {
                    player.viewheight = GameConst.VIEWHEIGHT;
                    player.deltaviewheight = 0;
                }
                if (player.viewheight < GameConst.VIEWHEIGHT / 2) {
                    player.viewheight = GameConst.VIEWHEIGHT / 2;
                    if (player.deltaviewheight <= 0) player.deltaviewheight = 1;
                }
                if (player.deltaviewheight != 0) {
                    player.deltaviewheight += 65536 / 4;
                    if (player.deltaviewheight == 0) player.deltaviewheight = 1;
                }
            }
            player.viewz = mo.z + player.viewheight + bob;
            if (player.viewz > mo.ceilingz - 4 * 65536) player.viewz = mo.ceilingz - 4 * 65536;
        }
    }

    function P_MovePlayer(GameContext memory c, uint32 playerId) internal view {
        Player memory player = c.state.players[playerId];
        Mobj memory mo = c.state.mobjs[player.mo];
        Ticcmd memory cmd = player.cmd;
        unchecked {
            mo.angle += uint32(int32(cmd.angleturn) << 16);
            c.move.onground = mo.z <= mo.floorz;
            if (cmd.forwardmove != 0 && c.move.onground) {
                P_Thrust(c, playerId, mo.angle, int32(cmd.forwardmove) * 2048);
            }
            if (cmd.sidemove != 0 && c.move.onground) {
                P_Thrust(c, playerId, mo.angle - Tables.ANG90, int32(cmd.sidemove) * 2048);
            }
            if ((cmd.forwardmove != 0 || cmd.sidemove != 0) && mo.state == P_Info.S_PLAY) {
                c.hooks.setMobjState(c, player.mo, P_Info.S_PLAY_RUN1);
            }
        }
    }

    function P_DeathThink(GameContext memory c, uint32 playerId) internal view {
        Player memory player = c.state.players[playerId];
        Mobj memory mo = c.state.mobjs[player.mo];
        c.hooks.movePsprites(c, playerId);
        unchecked {
            if (player.viewheight > 6 * 65536) player.viewheight -= 65536;
            if (player.viewheight < 6 * 65536) player.viewheight = 6 * 65536;
            player.deltaviewheight = 0;
            c.move.onground = mo.z <= mo.floorz;
            P_CalcHeight(c, playerId);
            if (player.attacker != GameConst.NULL && player.attacker != player.mo) {
                Mobj memory attacker = c.state.mobjs[player.attacker];
                RenderState memory geometry;
                uint32 angle = R_Main.R_PointToAngle2(geometry, mo.x, mo.y, attacker.x, attacker.y);
                uint32 delta = angle - mo.angle;
                uint32 ang5 = Tables.ANG90 / 18;
                if (delta < ang5 || delta > uint32(0) - ang5) {
                    mo.angle = angle;
                    if (player.damagecount != 0) --player.damagecount;
                } else if (delta < Tables.ANG180) {
                    mo.angle += ang5;
                } else {
                    mo.angle -= ang5;
                }
            } else if (player.damagecount != 0) {
                --player.damagecount;
            }
            if ((player.cmd.buttons & GameConst.BT_USE) != 0) player.playerstate = PlayerState.reborn;
        }
    }

    function P_PlayerThink(GameContext memory c, uint32 playerId) internal view {
        Player memory player = c.state.players[playerId];
        Mobj memory mo = c.state.mobjs[player.mo];
        Ticcmd memory cmd = player.cmd;
        unchecked {
            if ((player.cheats & GameConst.CF_NOCLIP) != 0) mo.flags |= GameConst.MF_NOCLIP;
            else mo.flags &= ~GameConst.MF_NOCLIP;
            if ((mo.flags & GameConst.MF_JUSTATTACKED) != 0) {
                cmd.angleturn = 0;
                cmd.forwardmove = 0xc800 / 512;
                cmd.sidemove = 0;
                mo.flags &= ~GameConst.MF_JUSTATTACKED;
            }
            if (player.playerstate == PlayerState.dead) {
                P_DeathThink(c, playerId);
                return;
            }
            if (mo.reactiontime != 0) --mo.reactiontime;
            else P_MovePlayer(c, playerId);
            P_CalcHeight(c, playerId);
            if (c.state.sectors[c.map.subsectors[mo.subsector].sector].special != 0) {
                c.hooks.playerSpecialSector(c, playerId);
            }
            if ((cmd.buttons & GameConst.BT_SPECIAL) != 0) cmd.buttons = 0;
            if ((cmd.buttons & GameConst.BT_CHANGE) != 0) {
                uint32 newweapon = uint32((cmd.buttons & GameConst.BT_WEAPONMASK) >> GameConst.BT_WEAPONSHIFT);
                // wp_fist=0, wp_chainsaw=7; pw_strength=1.
                if (
                    newweapon == 0 && player.weaponowned[7]
                        && !(player.readyweapon == 7 && player.powers[1] != 0)
                ) newweapon = 7;
                // Original commercial (2) mode toggles shotgun/supershotgun.
                if (
                    c.state.gamemode == 2 && newweapon == 2 && player.weaponowned[8]
                        && player.readyweapon != 8
                ) newweapon = 8;
                if (player.weaponowned[newweapon] && newweapon != player.readyweapon) {
                    if ((newweapon != 5 && newweapon != 6) || c.state.gamemode != 0) {
                        player.pendingweapon = newweapon;
                    }
                }
            }
            if ((cmd.buttons & GameConst.BT_USE) != 0) {
                if (player.usedown == 0) {
                    c.hooks.useLines(c, playerId);
                    player.usedown = 1;
                }
            } else {
                player.usedown = 0;
            }
            c.hooks.movePsprites(c, playerId);
            if (player.powers[1] != 0) ++player.powers[1];
            if (player.powers[0] != 0) --player.powers[0];
            if (player.powers[2] != 0) {
                --player.powers[2];
                if (player.powers[2] == 0) mo.flags &= ~GameConst.MF_SHADOW;
            }
            if (player.powers[5] != 0) --player.powers[5];
            if (player.powers[3] != 0) --player.powers[3];
            if (player.damagecount != 0) --player.damagecount;
            if (player.bonuscount != 0) --player.bonuscount;
            if (player.powers[0] != 0) {
                player.fixedcolormap =
                    player.powers[0] > 4 * 32 || (player.powers[0] & 8) != 0 ? int32(32) : int32(0);
            } else if (player.powers[5] != 0) {
                player.fixedcolormap =
                    player.powers[5] > 4 * 32 || (player.powers[5] & 8) != 0 ? int32(1) : int32(0);
            } else {
                player.fixedcolormap = 0;
            }
        }
    }
}
