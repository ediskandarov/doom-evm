// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {GameContext, GameConst, Player, PlayerState, Mobj, MobjInfo} from "./p_game_state.sol";
import {P_Info} from "./p_info.sol";
import {M_Random} from "./m_random.sol";
import {M_Fixed} from "./m_fixed.sol";
import {Tables} from "./tables.sol";
import {RenderState} from "./r_state.sol";
import {R_Main} from "./r_main.sol";

/// @custom:source linuxdoom-1.10/p_inter.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
library P_Inter {
    error InvalidAmmo(int32 ammo);
    error UnknownSpecialThing(uint32 sprite);
    error NonPlayerToucher(uint32 toucher);

    function P_GiveAmmo(GameContext memory c, uint32 player, int32 ammo, int32 num)
        internal
        pure
        returns (bool)
    {
        if (ammo == 5) return false; // am_noammo, not NUMAMMO (4).
        // Original ammo==NUMAMMO accesses beyond arrays: explicit undefined-C rejection.
        if (ammo < 0 || ammo >= 4) revert InvalidAmmo(ammo);
        Player memory p = c.state.players[player];
        uint32 a = uint32(ammo);
        if (p.ammo[a] == p.maxammo[a]) return false;
        int32[4] memory clipammo = [int32(10), 4, 20, 1];
        unchecked {
            if (num != 0) num *= clipammo[a];
            else num = clipammo[a] / 2;
            if (c.state.gameskill == 0 || c.state.gameskill == 4) num *= 2;
            int32 oldammo = p.ammo[a];
            p.ammo[a] += num;
            if (p.ammo[a] > p.maxammo[a]) p.ammo[a] = p.maxammo[a];
            if (oldammo != 0) return true;
        }
        if (ammo == 0 && p.readyweapon == 0) {
            p.pendingweapon = p.weaponowned[3] ? uint32(3) : uint32(1);
        } else if (ammo == 1 && (p.readyweapon == 0 || p.readyweapon == 1) && p.weaponowned[2]) {
            p.pendingweapon = 2;
        } else if (ammo == 2 && (p.readyweapon == 0 || p.readyweapon == 1) && p.weaponowned[5]) {
            p.pendingweapon = 5;
        } else if (ammo == 3 && p.readyweapon == 0 && p.weaponowned[4]) {
            p.pendingweapon = 4;
        }
        return true;
    }

    function P_GiveWeapon(GameContext memory c, uint32 player, uint32 weapon, bool dropped)
        internal
        pure
        returns (bool)
    {
        Player memory p = c.state.players[player];
        if (c.state.netgame && c.state.deathmatch != 2 && !dropped) {
            if (p.weaponowned[weapon]) return false;
            unchecked {
                p.bonuscount += 6;
            }
            p.weaponowned[weapon] = true;
            P_GiveAmmo(
                c,
                player,
                c.definitions.weaponinfo[weapon].ammo,
                c.state.deathmatch != 0 ? int32(5) : int32(2)
            );
            p.pendingweapon = weapon;
            return false;
        }
        bool gaveammo;
        if (c.definitions.weaponinfo[weapon].ammo != 5) {
            gaveammo =
                P_GiveAmmo(c, player, c.definitions.weaponinfo[weapon].ammo, dropped ? int32(1) : int32(2));
        }
        bool gaveweapon = !p.weaponowned[weapon];
        if (gaveweapon) {
            p.weaponowned[weapon] = true;
            p.pendingweapon = weapon;
        }
        return gaveweapon || gaveammo;
    }

    function P_GiveBody(GameContext memory c, uint32 player, int32 num) internal pure returns (bool) {
        Player memory p = c.state.players[player];
        if (p.health >= 100) return false;
        unchecked {
            p.health += num;
        }
        if (p.health > 100) p.health = 100;
        c.state.mobjs[p.mo].health = p.health;
        return true;
    }

    function P_GiveArmor(GameContext memory c, uint32 player, int32 armortype) internal pure returns (bool) {
        Player memory p = c.state.players[player];
        int32 hits;
        unchecked {
            hits = armortype * 100;
        }
        if (p.armorpoints >= hits) return false;
        p.armortype = armortype;
        p.armorpoints = hits;
        return true;
    }

    function P_GiveCard(GameContext memory c, uint32 player, uint32 card) internal pure {
        Player memory p = c.state.players[player];
        if (p.cards[card]) return;
        p.bonuscount = 6;
        p.cards[card] = true;
    }

    function P_GivePower(GameContext memory c, uint32 player, uint32 power) internal pure returns (bool) {
        Player memory p = c.state.players[player];
        if (power == 0) {
            p.powers[power] = 30 * 35;
            return true;
        }
        if (power == 2) {
            p.powers[power] = 60 * 35;
            c.state.mobjs[p.mo].flags |= GameConst.MF_SHADOW;
            return true;
        }
        if (power == 5) {
            p.powers[power] = 120 * 35;
            return true;
        }
        if (power == 3) {
            p.powers[power] = 60 * 35;
            return true;
        }
        if (power == 1) {
            P_GiveBody(c, player, 100);
            p.powers[power] = 1;
            return true;
        }
        if (p.powers[power] != 0) return false;
        p.powers[power] = 1;
        return true;
    }

    function P_TouchSpecialThing(GameContext memory c, uint32 specialId, uint32 toucherId) internal view {
        Mobj memory special = c.state.mobjs[specialId];
        Mobj memory toucher = c.state.mobjs[toucherId];
        int32 delta;
        unchecked {
            delta = special.z - toucher.z;
        }
        if (delta > toucher.height || delta < -8 * 65536) return;
        if (toucher.health <= 0) return;
        uint32 player = toucher.player;
        if (player == GameConst.NULL) revert NonPlayerToucher(toucherId);
        Player memory p = c.state.players[player];
        uint32 sprite = special.sprite;
        if (sprite == P_Info.SPR_ARM1) {
            if (!P_GiveArmor(c, player, 1)) return;
            p.message = "Picked up the armor.";
        } else if (sprite == P_Info.SPR_ARM2) {
            if (!P_GiveArmor(c, player, 2)) return;
            p.message = "Picked up the MegaArmor!";
        } else if (sprite == P_Info.SPR_BON1) {
            unchecked {
                ++p.health;
            }
            if (p.health > 200) p.health = 200;
            c.state.mobjs[p.mo].health = p.health;
            p.message = "Picked up a health bonus.";
        } else if (sprite == P_Info.SPR_BON2) {
            unchecked {
                ++p.armorpoints;
            }
            if (p.armorpoints > 200) p.armorpoints = 200;
            if (p.armortype == 0) p.armortype = 1;
            p.message = "Picked up an armor bonus.";
        } else if (sprite == P_Info.SPR_SOUL) {
            unchecked {
                p.health += 100;
            }
            if (p.health > 200) p.health = 200;
            c.state.mobjs[p.mo].health = p.health;
            p.message = "Supercharge!";
        } else if (sprite == P_Info.SPR_MEGA) {
            if (c.state.gamemode != 2) return;
            p.health = 200;
            c.state.mobjs[p.mo].health = 200;
            P_GiveArmor(c, player, 2);
            p.message = "MegaSphere!";
        } else if (
            sprite == P_Info.SPR_BKEY || sprite == P_Info.SPR_YKEY || sprite == P_Info.SPR_RKEY
                || sprite == P_Info.SPR_BSKU || sprite == P_Info.SPR_YSKU || sprite == P_Info.SPR_RSKU
        ) {
            uint32 card = sprite == P_Info.SPR_BKEY
                ? 0
                : sprite == P_Info.SPR_YKEY
                    ? 1
                    : sprite == P_Info.SPR_RKEY
                        ? 2
                        : sprite == P_Info.SPR_BSKU ? 3 : sprite == P_Info.SPR_YSKU ? 4 : 5;
            if (!p.cards[card]) {
                if (card == 0) p.message = "Picked up a blue keycard.";
                else if (card == 1) p.message = "Picked up a yellow keycard.";
                else if (card == 2) p.message = "Picked up a red keycard.";
                else if (card == 3) p.message = "Picked up a blue skull key.";
                else if (card == 4) p.message = "Picked up a yellow skull key.";
                else p.message = "Picked up a red skull key.";
            }
            P_GiveCard(c, player, card);
            if (c.state.netgame) return;
        } else if (sprite == P_Info.SPR_STIM) {
            if (!P_GiveBody(c, player, 10)) return;
            p.message = "Picked up a stimpack.";
        } else if (sprite == P_Info.SPR_MEDI) {
            if (!P_GiveBody(c, player, 25)) return;
            p.message = p.health < 25 ? "Picked up a medikit that you REALLY need!" : "Picked up a medikit.";
        } else if (
            sprite == P_Info.SPR_PINV || sprite == P_Info.SPR_PSTR || sprite == P_Info.SPR_PINS
                || sprite == P_Info.SPR_SUIT || sprite == P_Info.SPR_PMAP || sprite == P_Info.SPR_PVIS
        ) {
            uint32 power = sprite == P_Info.SPR_PINV
                ? 0
                : sprite == P_Info.SPR_PSTR
                    ? 1
                    : sprite == P_Info.SPR_PINS
                        ? 2
                        : sprite == P_Info.SPR_SUIT ? 3 : sprite == P_Info.SPR_PMAP ? 4 : 5;
            if (!P_GivePower(c, player, power)) return;
            if (power == 0) {
                p.message = "Invulnerability!";
            } else if (power == 1) {
                p.message = "Berserk!";
                if (p.readyweapon != 0) p.pendingweapon = 0;
            } else if (power == 2) {
                p.message = "Partial Invisibility";
            } else if (power == 3) {
                p.message = "Radiation Shielding Suit";
            } else if (power == 4) {
                p.message = "Computer Area Map";
            } else {
                p.message = "Light Amplification Visor";
            }
        } else if (
            sprite == P_Info.SPR_CLIP || sprite == P_Info.SPR_AMMO || sprite == P_Info.SPR_ROCK
                || sprite == P_Info.SPR_BROK || sprite == P_Info.SPR_CELL || sprite == P_Info.SPR_CELP
                || sprite == P_Info.SPR_SHEL || sprite == P_Info.SPR_SBOX
        ) {
            int32 ammo = (sprite == P_Info.SPR_CLIP || sprite == P_Info.SPR_AMMO)
                ? int32(0)
                : (sprite == P_Info.SPR_SHEL || sprite == P_Info.SPR_SBOX)
                    ? int32(1)
                    : (sprite == P_Info.SPR_CELL || sprite == P_Info.SPR_CELP) ? int32(2) : int32(3);
            int32 num = (sprite == P_Info.SPR_AMMO || sprite == P_Info.SPR_BROK || sprite == P_Info.SPR_CELP
                    || sprite == P_Info.SPR_SBOX)
                ? int32(5)
                : int32(1);
            if (sprite == P_Info.SPR_CLIP && special.flags & GameConst.MF_DROPPED != 0) num = 0;
            if (!P_GiveAmmo(c, player, ammo, num)) return;
            if (sprite == P_Info.SPR_CLIP) p.message = "Picked up a clip.";
            else if (sprite == P_Info.SPR_AMMO) p.message = "Picked up a box of bullets.";
            else if (sprite == P_Info.SPR_ROCK) p.message = "Picked up a rocket.";
            else if (sprite == P_Info.SPR_BROK) p.message = "Picked up a box of rockets.";
            else if (sprite == P_Info.SPR_CELL) p.message = "Picked up an energy cell.";
            else if (sprite == P_Info.SPR_CELP) p.message = "Picked up an energy cell pack.";
            else if (sprite == P_Info.SPR_SHEL) p.message = "Picked up 4 shotgun shells.";
            else p.message = "Picked up a box of shotgun shells.";
        } else if (sprite == P_Info.SPR_BPAK) {
            if (!p.backpack) {
                for (uint32 i; i < 4; ++i) {
                    unchecked {
                        p.maxammo[i] *= 2;
                    }
                }
                p.backpack = true;
            }
            for (int32 i; i < 4; ++i) {
                P_GiveAmmo(c, player, i, 1);
            }
            p.message = "Picked up a backpack full of ammo!";
        } else if (
            sprite == P_Info.SPR_BFUG || sprite == P_Info.SPR_MGUN || sprite == P_Info.SPR_CSAW
                || sprite == P_Info.SPR_LAUN || sprite == P_Info.SPR_PLAS || sprite == P_Info.SPR_SHOT
                || sprite == P_Info.SPR_SGN2
        ) {
            uint32 weapon = sprite == P_Info.SPR_BFUG
                ? 6
                : sprite == P_Info.SPR_MGUN
                    ? 3
                    : sprite == P_Info.SPR_CSAW
                        ? 7
                        : sprite == P_Info.SPR_LAUN
                            ? 4
                            : sprite == P_Info.SPR_PLAS ? 5 : sprite == P_Info.SPR_SHOT ? 2 : 8;
            bool dropped =
                (sprite == P_Info.SPR_MGUN || sprite == P_Info.SPR_SHOT || sprite == P_Info.SPR_SGN2)
                    && special.flags & GameConst.MF_DROPPED != 0;
            if (!P_GiveWeapon(c, player, weapon, dropped)) return;
            if (weapon == 6) p.message = "You got the BFG9000!  Oh, yes.";
            else if (weapon == 3) p.message = "You got the chaingun!";
            else if (weapon == 7) p.message = "A chainsaw!  Find some meat!";
            else if (weapon == 4) p.message = "You got the rocket launcher!";
            else if (weapon == 5) p.message = "You got the plasma gun!";
            else if (weapon == 2) p.message = "You got the shotgun!";
            else p.message = "You got the super shotgun!";
        } else {
            revert UnknownSpecialThing(sprite);
        }
        if (special.flags & GameConst.MF_COUNTITEM != 0) {
            unchecked {
                ++p.itemcount;
            }
        }
        c.hooks.removeMobj(c, specialId);
        unchecked {
            p.bonuscount += 6;
        }
    }

    function P_KillMobj(GameContext memory c, uint32 sourceId, uint32 targetId) internal view {
        Mobj memory target = c.state.mobjs[targetId];
        target.flags &= ~(GameConst.MF_SHOOTABLE | GameConst.MF_FLOAT | GameConst.MF_SKULLFLY);
        if (target.mobjType != P_Info.MT_SKULL) target.flags &= ~GameConst.MF_NOGRAVITY;
        target.flags |= GameConst.MF_CORPSE | GameConst.MF_DROPOFF;
        target.height >>= 2;
        if (sourceId != GameConst.NULL && c.state.mobjs[sourceId].player != GameConst.NULL) {
            Player memory source = c.state.players[c.state.mobjs[sourceId].player];
            if (target.flags & GameConst.MF_COUNTKILL != 0) {
                unchecked {
                    ++source.killcount;
                }
            }
            if (target.player != GameConst.NULL) {
                unchecked {
                    ++source.frags[target.player];
                }
            }
        } else if (!c.state.netgame && target.flags & GameConst.MF_COUNTKILL != 0) {
            unchecked {
                ++c.state.players[0].killcount;
            }
        }
        if (target.player != GameConst.NULL) {
            Player memory p = c.state.players[target.player];
            if (sourceId == GameConst.NULL) {
                unchecked {
                    ++p.frags[target.player];
                }
            }
            target.flags &= ~GameConst.MF_SOLID;
            p.playerstate = PlayerState.dead;
            c.hooks.dropWeapon(c, target.player);
        }
        MobjInfo memory info = c.definitions.mobjinfo[target.mobjType];
        int32 negativeSpawn;
        unchecked {
            negativeSpawn = -info.spawnhealth;
        }
        c.hooks
            .setMobjState(
                c,
                targetId,
                uint32(
                    target.health < negativeSpawn && info.xdeathstate != 0
                        ? info.xdeathstate
                        : info.deathstate
                )
            );
        unchecked {
            target.tics -= M_Random.P_Random(c.state) & 3;
        }
        if (target.tics < 1) target.tics = 1;
        uint32 item;
        if (target.mobjType == P_Info.MT_WOLFSS || target.mobjType == P_Info.MT_POSSESSED) {
            item = P_Info.MT_CLIP;
        } else if (target.mobjType == P_Info.MT_SHOTGUY) {
            item = P_Info.MT_SHOTGUN;
        } else if (target.mobjType == P_Info.MT_CHAINGUY) {
            item = P_Info.MT_CHAINGUN;
        } else {
            return;
        }
        uint32 mo = c.hooks.spawnMobj(c, target.x, target.y, GameConst.ONFLOORZ, item);
        c.state.mobjs[mo].flags |= GameConst.MF_DROPPED;
    }

    function P_DamageMobj(
        GameContext memory c,
        uint32 targetId,
        uint32 inflictorId,
        uint32 sourceId,
        int32 damage
    ) internal view {
        Mobj memory target = c.state.mobjs[targetId];
        if (target.flags & GameConst.MF_SHOOTABLE == 0 || target.health <= 0) return;
        if (target.flags & GameConst.MF_SKULLFLY != 0) {
            target.momx = 0;
            target.momy = 0;
            target.momz = 0;
        }
        uint32 player = target.player;
        if (player != GameConst.NULL && c.state.gameskill == 0) damage >>= 1;
        MobjInfo memory info = c.definitions.mobjinfo[target.mobjType];
        if (
            inflictorId != GameConst.NULL && target.flags & GameConst.MF_NOCLIP == 0
                && (sourceId == GameConst.NULL
                    || c.state.mobjs[sourceId].player == GameConst.NULL
                    || c.state.players[c.state.mobjs[sourceId].player].readyweapon != 7)
        ) {
            Mobj memory inflictor = c.state.mobjs[inflictorId];
            RenderState memory rs;
            uint32 ang = R_Main.R_PointToAngle2(rs, inflictor.x, inflictor.y, target.x, target.y);
            int32 thrust;
            unchecked {
                thrust = damage * (65536 >> 3) * 100 / info.mass;
            }
            int32 heightDelta;
            unchecked {
                heightDelta = target.z - inflictor.z;
            }
            if (
                damage < 40 && damage > target.health && heightDelta > 64 * 65536
                    && M_Random.P_Random(c.state) & 1 != 0
            ) {
                unchecked {
                    ang += 0x80000000;
                    thrust *= 4;
                }
            }
            ang >>= 19;
            unchecked {
                target.momx += M_Fixed.FixedMul(thrust, Tables.finecosine(ang));
                target.momy += M_Fixed.FixedMul(thrust, Tables.finesine(ang));
            }
        }
        if (player != GameConst.NULL) {
            Player memory p = c.state.players[player];
            if (
                c.state.sectors[c.map.subsectors[target.subsector].sector].special == 11
                    && damage >= target.health
            ) {
                unchecked {
                    damage = target.health - 1;
                }
            }
            if (damage < 1000 && (p.cheats & GameConst.CF_GODMODE != 0 || p.powers[0] != 0)) return;
            if (p.armortype != 0) {
                int32 saved = p.armortype == 1 ? damage / int32(3) : damage / int32(2);
                if (p.armorpoints <= saved) {
                    saved = p.armorpoints;
                    p.armortype = 0;
                }
                unchecked {
                    p.armorpoints -= saved;
                    damage -= saved;
                }
            }
            unchecked {
                p.health -= damage;
            }
            if (p.health < 0) p.health = 0;
            p.attacker = sourceId;
            unchecked {
                p.damagecount += damage;
            }
            if (p.damagecount > 100) p.damagecount = 100;
        }
        unchecked {
            target.health -= damage;
        }
        if (target.health <= 0) {
            P_KillMobj(c, sourceId, targetId);
            return;
        }
        if (M_Random.P_Random(c.state) < info.painchance && target.flags & GameConst.MF_SKULLFLY == 0) {
            target.flags |= GameConst.MF_JUSTHIT;
            c.hooks.setMobjState(c, targetId, uint32(info.painstate));
        }
        target.reactiontime = 0;
        if (
            (target.threshold == 0 || target.mobjType == P_Info.MT_VILE) && sourceId != GameConst.NULL
                && sourceId != targetId && c.state.mobjs[sourceId].mobjType != P_Info.MT_VILE
        ) {
            target.target = sourceId;
            target.threshold = GameConst.BASETHRESHOLD;
            if (target.state == uint32(info.spawnstate) && info.seestate != 0) {
                c.hooks.setMobjState(c, targetId, uint32(info.seestate));
            }
        }
    }
}
