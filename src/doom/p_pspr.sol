// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {GameContext, GameConst, Player, PlayerState, PlayerPSprite, StateDef, Mobj} from "./p_game_state.sol";
import {P_Info} from "./p_info.sol";
import {M_Random} from "./m_random.sol";
import {M_Fixed} from "./m_fixed.sol";
import {Tables} from "./tables.sol";
import {RenderState} from "./r_state.sol";
import {R_Main} from "./r_main.sol";

/// @custom:source linuxdoom-1.10/p_pspr.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
library P_Pspr {
    uint32 internal constant WP_NOCHANGE = 10;
    int32 internal constant AM_NOAMMO = 5;
    int32 internal constant WEAPONBOTTOM = 128 * 65536;
    int32 internal constant WEAPONTOP = 32 * 65536;
    uint32 internal constant ANG90 = 0x40000000;
    error UnknownWeaponAction(uint32 action);

    function P_SetPsprite(GameContext memory c, uint32 player, uint32 position, uint32 stnum) internal view {
        PlayerPSprite memory psp = c.state.players[player].psprites[position];
        do {
            if (stnum == P_Info.S_NULL) {
                psp.state = GameConst.NULL;
                break;
            }
            StateDef memory state = c.definitions.states[stnum];
            psp.state = stnum;
            psp.tics = state.tics;
            if (state.misc1 != 0) {
                unchecked {
                    psp.sx = state.misc1 * 65536;
                    psp.sy = state.misc2 * 65536;
                }
            }
            if (state.action != 0) {
                c.hooks.actionPSprite(c, state.action, player, position);
                if (psp.state == GameConst.NULL) break;
            }
            stnum = c.definitions.states[psp.state].nextstate;
        } while (psp.tics == 0);
    }

    // Original unobserved swing globals returned explicitly; no persistent state consumer.
    function P_CalcSwing(GameContext memory c, uint32 player)
        internal
        pure
        returns (int32 swingx, int32 swingy)
    {
        unchecked {
            uint32 angle = uint32((int32(8192) / 70) * c.state.leveltime) & 8191;
            swingx = M_Fixed.FixedMul(c.state.players[player].bob, Tables.finesine(angle));
            angle = uint32((int32(8192) / 70) * c.state.leveltime + 8192 / 2) & 8191;
            swingy = -M_Fixed.FixedMul(swingx, Tables.finesine(angle));
        }
    }

    function P_BringUpWeapon(GameContext memory c, uint32 player) internal view {
        Player memory p = c.state.players[player];
        if (p.pendingweapon == WP_NOCHANGE) p.pendingweapon = p.readyweapon;
        uint32 newstate = c.definitions.weaponinfo[p.pendingweapon].upstate;
        p.pendingweapon = WP_NOCHANGE;
        p.psprites[0].sy = WEAPONBOTTOM;
        P_SetPsprite(c, player, 0, newstate);
    }

    function P_CheckAmmo(GameContext memory c, uint32 player) internal view returns (bool) {
        Player memory p = c.state.players[player];
        int32 ammo = c.definitions.weaponinfo[p.readyweapon].ammo;
        int32 count = p.readyweapon == 6 ? int32(40) : (p.readyweapon == 8 ? int32(2) : int32(1));
        if (ammo == AM_NOAMMO || p.ammo[uint32(ammo)] >= count) return true;
        if (p.weaponowned[5] && p.ammo[2] != 0 && c.state.gamemode != 0) p.pendingweapon = 5;
        else if (p.weaponowned[8] && p.ammo[1] > 2 && c.state.gamemode == 2) p.pendingweapon = 8;
        else if (p.weaponowned[3] && p.ammo[0] != 0) p.pendingweapon = 3;
        else if (p.weaponowned[2] && p.ammo[1] != 0) p.pendingweapon = 2;
        else if (p.ammo[0] != 0) p.pendingweapon = 1;
        else if (p.weaponowned[7]) p.pendingweapon = 7;
        else if (p.weaponowned[4] && p.ammo[3] != 0) p.pendingweapon = 4;
        else if (p.weaponowned[6] && p.ammo[2] > 40 && c.state.gamemode != 0) p.pendingweapon = 6;
        else p.pendingweapon = 0;
        P_SetPsprite(c, player, 0, c.definitions.weaponinfo[p.readyweapon].downstate);
        return false;
    }

    function P_FireWeapon(GameContext memory c, uint32 player) internal view {
        if (!P_CheckAmmo(c, player)) return;
        Player memory p = c.state.players[player];
        c.hooks.setMobjState(c, p.mo, P_Info.S_PLAY_ATK1);
        P_SetPsprite(c, player, 0, c.definitions.weaponinfo[p.readyweapon].atkstate);
        c.hooks.noiseAlert(c, p.mo, p.mo);
    }

    function P_DropWeapon(GameContext memory c, uint32 player) internal view {
        P_SetPsprite(c, player, 0, c.definitions.weaponinfo[c.state.players[player].readyweapon].downstate);
    }

    function A_WeaponReady(GameContext memory c, uint32 player, uint32 slot) internal view {
        Player memory p = c.state.players[player];
        PlayerPSprite memory psp = p.psprites[slot];
        uint32 state = c.state.mobjs[p.mo].state;
        if (state == P_Info.S_PLAY_ATK1 || state == P_Info.S_PLAY_ATK2) {
            c.hooks.setMobjState(c, p.mo, P_Info.S_PLAY);
        }
        if (p.pendingweapon != WP_NOCHANGE || p.health == 0) {
            P_SetPsprite(c, player, 0, c.definitions.weaponinfo[p.readyweapon].downstate);
            return;
        }
        if (p.cmd.buttons & GameConst.BT_ATTACK != 0) {
            if (p.attackdown == 0 || (p.readyweapon != 4 && p.readyweapon != 6)) {
                p.attackdown = 1;
                P_FireWeapon(c, player);
                return;
            }
        } else {
            p.attackdown = 0;
        }
        unchecked {
            uint32 angle = uint32(128 * c.state.leveltime) & 8191;
            psp.sx = 65536 + M_Fixed.FixedMul(p.bob, Tables.finecosine(angle));
            angle &= 4095;
            psp.sy = WEAPONTOP + M_Fixed.FixedMul(p.bob, Tables.finesine(angle));
        }
    }

    function A_ReFire(GameContext memory c, uint32 player, uint32) internal view {
        Player memory p = c.state.players[player];
        if (p.cmd.buttons & GameConst.BT_ATTACK != 0 && p.pendingweapon == WP_NOCHANGE && p.health != 0) {
            unchecked {
                ++p.refire;
            }
            P_FireWeapon(c, player);
        } else {
            p.refire = 0;
            P_CheckAmmo(c, player);
        }
    }

    function A_CheckReload(GameContext memory c, uint32 player, uint32) internal view {
        P_CheckAmmo(c, player);
    }

    function A_Lower(GameContext memory c, uint32 player, uint32 slot) internal view {
        Player memory p = c.state.players[player];
        PlayerPSprite memory psp = p.psprites[slot];
        unchecked {
            psp.sy += 6 * 65536;
        }
        if (psp.sy < WEAPONBOTTOM) return;
        if (p.playerstate == PlayerState.dead) {
            psp.sy = WEAPONBOTTOM;
            return;
        }
        if (p.health == 0) {
            P_SetPsprite(c, player, 0, P_Info.S_NULL);
            return;
        }
        p.readyweapon = p.pendingweapon;
        P_BringUpWeapon(c, player);
    }

    function A_Raise(GameContext memory c, uint32 player, uint32 slot) internal view {
        Player memory p = c.state.players[player];
        PlayerPSprite memory psp = p.psprites[slot];
        unchecked {
            psp.sy -= 6 * 65536;
        }
        if (psp.sy > WEAPONTOP) return;
        psp.sy = WEAPONTOP;
        P_SetPsprite(c, player, 0, c.definitions.weaponinfo[p.readyweapon].readystate);
    }

    function A_GunFlash(GameContext memory c, uint32 player, uint32) internal view {
        Player memory p = c.state.players[player];
        c.hooks.setMobjState(c, p.mo, P_Info.S_PLAY_ATK2);
        P_SetPsprite(c, player, 1, c.definitions.weaponinfo[p.readyweapon].flashstate);
    }

    function _spread(GameContext memory c, uint32 shift) private pure returns (uint32) {
        int32 first = M_Random.P_Random(c.state);
        int32 second = M_Random.P_Random(c.state);
        unchecked {
            return uint32((first - second) * int32(uint32(1) << shift));
        }
    }

    function _angle(Mobj memory from, Mobj memory to) private pure returns (uint32) {
        RenderState memory rs;
        return R_Main.R_PointToAngle2(rs, from.x, from.y, to.x, to.y);
    }

    function A_Punch(GameContext memory c, uint32 player, uint32) internal view {
        Player memory p = c.state.players[player];
        int32 damage = (M_Random.P_Random(c.state) % 10 + 1) * 2;
        if (p.powers[1] != 0) damage *= 10;
        uint32 angle;
        unchecked {
            angle = c.state.mobjs[p.mo].angle + _spread(c, 18);
        }
        int32 slope = c.hooks.aimLineAttack(c, p.mo, angle, GameConst.MELEERANGE);
        c.hooks.lineAttack(c, p.mo, angle, GameConst.MELEERANGE, slope, damage);
        if (c.move.linetarget != GameConst.NULL) {
            c.state.mobjs[p.mo].angle = _angle(c.state.mobjs[p.mo], c.state.mobjs[c.move.linetarget]);
        }
    }

    function A_Saw(GameContext memory c, uint32 player, uint32) internal view {
        Player memory p = c.state.players[player];
        Mobj memory mo = c.state.mobjs[p.mo];
        int32 damage = 2 * (M_Random.P_Random(c.state) % 10 + 1);
        uint32 angle;
        unchecked {
            angle = mo.angle + _spread(c, 18);
        }
        int32 slope = c.hooks.aimLineAttack(c, p.mo, angle, GameConst.MELEERANGE + 1);
        c.hooks.lineAttack(c, p.mo, angle, GameConst.MELEERANGE + 1, slope, damage);
        if (c.move.linetarget == GameConst.NULL) return;
        angle = _angle(mo, c.state.mobjs[c.move.linetarget]);
        unchecked {
            uint32 delta = angle - mo.angle;
            if (delta > 0x80000000) {
                if (delta < uint32(0) - ANG90 / 20) mo.angle = angle + ANG90 / 21;
                else mo.angle -= ANG90 / 20;
            } else {
                if (delta > ANG90 / 20) mo.angle = angle - ANG90 / 21;
                else mo.angle += ANG90 / 20;
            }
        }
        mo.flags |= GameConst.MF_JUSTATTACKED;
    }

    function A_FireMissile(GameContext memory c, uint32 player, uint32) internal view {
        Player memory p = c.state.players[player];
        unchecked {
            --p.ammo[uint32(c.definitions.weaponinfo[p.readyweapon].ammo)];
        }
        c.hooks.spawnPlayerMissile(c, p.mo, P_Info.MT_ROCKET);
    }

    function A_FireBFG(GameContext memory c, uint32 player, uint32) internal view {
        Player memory p = c.state.players[player];
        unchecked {
            p.ammo[uint32(c.definitions.weaponinfo[p.readyweapon].ammo)] -= 40;
        }
        c.hooks.spawnPlayerMissile(c, p.mo, P_Info.MT_BFG);
    }

    function A_FirePlasma(GameContext memory c, uint32 player, uint32) internal view {
        Player memory p = c.state.players[player];
        unchecked {
            --p.ammo[uint32(c.definitions.weaponinfo[p.readyweapon].ammo)];
        }
        P_SetPsprite(
            c,
            player,
            1,
            c.definitions.weaponinfo[p.readyweapon].flashstate + uint32(M_Random.P_Random(c.state) & 1)
        );
        c.hooks.spawnPlayerMissile(c, p.mo, P_Info.MT_PLASMA);
    }

    function P_BulletSlope(GameContext memory c, uint32 mo) internal view {
        uint32 an = c.state.mobjs[mo].angle;
        c.move.bulletslope = c.hooks.aimLineAttack(c, mo, an, 16 * 64 * 65536);
        if (c.move.linetarget == GameConst.NULL) {
            unchecked {
                an += 1 << 26;
            }
            c.move.bulletslope = c.hooks.aimLineAttack(c, mo, an, 16 * 64 * 65536);
            if (c.move.linetarget == GameConst.NULL) {
                unchecked {
                    an -= 2 << 26;
                }
                c.move.bulletslope = c.hooks.aimLineAttack(c, mo, an, 16 * 64 * 65536);
            }
        }
    }

    function P_GunShot(GameContext memory c, uint32 mo, bool accurate) internal view {
        int32 damage = 5 * (M_Random.P_Random(c.state) % 3 + 1);
        uint32 angle = c.state.mobjs[mo].angle;
        if (!accurate) {
            unchecked {
                angle += _spread(c, 18);
            }
        }
        c.hooks.lineAttack(c, mo, angle, GameConst.MISSILERANGE, c.move.bulletslope, damage);
    }

    function A_FirePistol(GameContext memory c, uint32 player, uint32) internal view {
        Player memory p = c.state.players[player];
        c.hooks.setMobjState(c, p.mo, P_Info.S_PLAY_ATK2);
        unchecked {
            --p.ammo[uint32(c.definitions.weaponinfo[p.readyweapon].ammo)];
        }
        P_SetPsprite(c, player, 1, c.definitions.weaponinfo[p.readyweapon].flashstate);
        P_BulletSlope(c, p.mo);
        P_GunShot(c, p.mo, p.refire == 0);
    }

    function A_FireShotgun(GameContext memory c, uint32 player, uint32) internal view {
        Player memory p = c.state.players[player];
        c.hooks.setMobjState(c, p.mo, P_Info.S_PLAY_ATK2);
        unchecked {
            --p.ammo[uint32(c.definitions.weaponinfo[p.readyweapon].ammo)];
        }
        P_SetPsprite(c, player, 1, c.definitions.weaponinfo[p.readyweapon].flashstate);
        P_BulletSlope(c, p.mo);
        for (uint32 i; i < 7; ++i) {
            P_GunShot(c, p.mo, false);
        }
    }

    function A_FireShotgun2(GameContext memory c, uint32 player, uint32) internal view {
        Player memory p = c.state.players[player];
        c.hooks.setMobjState(c, p.mo, P_Info.S_PLAY_ATK2);
        unchecked {
            p.ammo[uint32(c.definitions.weaponinfo[p.readyweapon].ammo)] -= 2;
        }
        P_SetPsprite(c, player, 1, c.definitions.weaponinfo[p.readyweapon].flashstate);
        P_BulletSlope(c, p.mo);
        for (uint32 i; i < 20; ++i) {
            int32 damage = 5 * (M_Random.P_Random(c.state) % 3 + 1);
            uint32 angle;
            unchecked {
                angle = c.state.mobjs[p.mo].angle + _spread(c, 19);
            }
            int32 slope;
            unchecked {
                slope = c.move.bulletslope + int32(_spread(c, 5));
            }
            c.hooks.lineAttack(c, p.mo, angle, GameConst.MISSILERANGE, slope, damage);
        }
    }

    function A_FireCGun(GameContext memory c, uint32 player, uint32 slot) internal view {
        Player memory p = c.state.players[player];
        uint32 ammo = uint32(c.definitions.weaponinfo[p.readyweapon].ammo);
        if (p.ammo[ammo] == 0) return;
        c.hooks.setMobjState(c, p.mo, P_Info.S_PLAY_ATK2);
        unchecked {
            --p.ammo[ammo];
        }
        uint32 flash;
        unchecked {
            flash =
                c.definitions.weaponinfo[p.readyweapon].flashstate + p.psprites[slot].state - P_Info.S_CHAIN1;
        }
        P_SetPsprite(c, player, 1, flash);
        P_BulletSlope(c, p.mo);
        P_GunShot(c, p.mo, p.refire == 0);
    }

    function A_Light0(GameContext memory c, uint32 player, uint32) internal pure {
        c.state.players[player].extralight = 0;
    }

    function A_Light1(GameContext memory c, uint32 player, uint32) internal pure {
        c.state.players[player].extralight = 1;
    }

    function A_Light2(GameContext memory c, uint32 player, uint32) internal pure {
        c.state.players[player].extralight = 2;
    }

    function A_BFGSpray(GameContext memory c, uint32 mo) internal view {
        Mobj memory actor = c.state.mobjs[mo];
        for (uint32 i; i < 40; ++i) {
            uint32 an;
            unchecked {
                an = actor.angle - ANG90 / 2 + (ANG90 / 40) * i;
            }
            c.hooks.aimLineAttack(c, actor.target, an, 16 * 64 * 65536);
            if (c.move.linetarget == GameConst.NULL) continue;
            uint32 target = c.move.linetarget;
            Mobj memory victim = c.state.mobjs[target];
            int32 z;
            unchecked {
                z = victim.z + (victim.height >> 2);
            }
            c.hooks.spawnMobj(c, victim.x, victim.y, z, P_Info.MT_EXTRABFG);
            int32 damage;
            for (uint32 j; j < 15; ++j) {
                damage += (M_Random.P_Random(c.state) & 7) + 1;
            }
            c.hooks.damageMobj(c, target, actor.target, actor.target, damage);
        }
    }

    // Original action is exclusively an audio call; audio host side effects are outside gameplay.
    function A_BFGsound(GameContext memory, uint32, uint32) internal pure {}

    function P_SetupPsprites(GameContext memory c, uint32 player) internal view {
        Player memory p = c.state.players[player];
        for (uint32 i; i < 2; ++i) {
            p.psprites[i].state = GameConst.NULL;
        }
        p.pendingweapon = p.readyweapon;
        P_BringUpWeapon(c, player);
    }

    function P_MovePsprites(GameContext memory c, uint32 player) internal view {
        Player memory p = c.state.players[player];
        for (uint32 i; i < 2; ++i) {
            PlayerPSprite memory psp = p.psprites[i];
            if (psp.state != GameConst.NULL && psp.tics != -1) {
                unchecked {
                    --psp.tics;
                }
                if (psp.tics == 0) P_SetPsprite(c, player, i, c.definitions.states[psp.state].nextstate);
            }
        }
        p.psprites[1].sx = p.psprites[0].sx;
        p.psprites[1].sy = p.psprites[0].sy;
    }

    function actionPSprite(GameContext memory c, uint32 action, uint32 player, uint32 slot) internal view {
        if (action == P_Info.A_Light0) {
            A_Light0(c, player, slot);
        } else if (action == P_Info.A_WeaponReady) {
            A_WeaponReady(c, player, slot);
        } else if (action == P_Info.A_Lower) {
            A_Lower(c, player, slot);
        } else if (action == P_Info.A_Raise) {
            A_Raise(c, player, slot);
        } else if (action == P_Info.A_Punch) {
            A_Punch(c, player, slot);
        } else if (action == P_Info.A_ReFire) {
            A_ReFire(c, player, slot);
        } else if (action == P_Info.A_FirePistol) {
            A_FirePistol(c, player, slot);
        } else if (action == P_Info.A_Light1) {
            A_Light1(c, player, slot);
        } else if (action == P_Info.A_FireShotgun) {
            A_FireShotgun(c, player, slot);
        } else if (action == P_Info.A_Light2) {
            A_Light2(c, player, slot);
        } else if (action == P_Info.A_FireShotgun2) {
            A_FireShotgun2(c, player, slot);
        } else if (action == P_Info.A_CheckReload) {
            A_CheckReload(c, player, slot);
        }
        // These p_enemy.c actions are sound-only, except close also re-fires.
        else if (
            action == P_Info.A_OpenShotgun2 || action == P_Info.A_LoadShotgun2 || action == P_Info.A_BFGsound
        ) {} else if (action == P_Info.A_CloseShotgun2) {
            A_ReFire(c, player, slot);
        } else if (action == P_Info.A_FireCGun) {
            A_FireCGun(c, player, slot);
        } else if (action == P_Info.A_GunFlash) {
            A_GunFlash(c, player, slot);
        } else if (action == P_Info.A_FireMissile) {
            A_FireMissile(c, player, slot);
        } else if (action == P_Info.A_Saw) {
            A_Saw(c, player, slot);
        } else if (action == P_Info.A_FirePlasma) {
            A_FirePlasma(c, player, slot);
        } else if (action == P_Info.A_FireBFG) {
            A_FireBFG(c, player, slot);
        } else {
            revert UnknownWeaponAction(action);
        }
    }
}
