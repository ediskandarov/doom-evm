// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {GameContext, GameConst, Player, PlayerState, Mobj, GameSector} from "../../src/doom/p_game_state.sol";
import {Subsector} from "../../src/doom/r_defs.sol";
import {P_Info} from "../../src/doom/p_info.sol";
import {P_Inter} from "../../src/doom/p_inter.sol";
import {P_Pspr} from "../../src/doom/p_pspr.sol";

interface VmCombat {
    function readFileBinary(string calldata path) external view returns (bytes memory);
}

contract PInterTest {
    VmCombat constant vm = VmCombat(address(uint160(uint256(keccak256("hevm cheat code")))));
    event log_named_uint(string key, uint256 value);

    function _word(bytes memory data, uint256 offset) private pure returns (uint32 value) {
        for (uint32 i; i < 4; ++i) {
            value = (value << 8) | uint8(data[offset + i]);
        }
    }

    function _noop(GameContext memory, uint32, uint32, uint32) internal pure {}

    function _remove(GameContext memory c, uint32 mo) internal pure {
        c.state.mobjs[mo].allocated = false;
    }

    function _spawn(GameContext memory c, int32 x, int32 y, int32 z, uint32 kind)
        internal
        pure
        returns (uint32)
    {
        Mobj memory m = c.state.mobjs[2];
        m.x = x;
        m.y = y;
        m.z = z;
        m.mobjType = kind;
        m.flags = uint32(c.definitions.mobjinfo[kind].flags);
        return 2;
    }

    function _state(GameContext memory c, uint32 mo, uint32 state) internal pure returns (bool) {
        c.state.mobjs[mo].state = state == 0 ? GameConst.NULL : state;
        c.state.mobjs[mo].tics = c.definitions.states[state].tics;
        return state != 0;
    }

    function _context() private pure returns (GameContext memory c) {
        c.definitions = P_Info.load();
        c.state.mobjs = new Mobj[](3);
        c.state.sectors = new GameSector[](1);
        c.map.subsectors = new Subsector[](1);
        c.hooks.actionPSprite = _noop;
        c.hooks.removeMobj = _remove;
        c.hooks.spawnMobj = _spawn;
        c.hooks.setMobjState = _state;
        c.hooks.dropWeapon = P_Pspr.P_DropWeapon;
    }

    function _initialize(GameContext memory c, uint32[16] memory a) private pure {
        Player memory p;
        p.mo = 0;
        p.readyweapon = a[7];
        p.pendingweapon = 10;
        p.health = int32(a[10]);
        p.armorpoints = int32(a[11]);
        p.armortype = int32(a[12]);
        for (uint32 i; i < 9; ++i) {
            p.weaponowned[i] = a[8] & (uint32(1) << i) != 0;
        }
        int32[4] memory maxammo = [int32(200), 50, 300, 50];
        for (uint32 i; i < 4; ++i) {
            p.ammo[i] = int32(a[9]);
            p.maxammo[i] = maxammo[i];
        }
        for (uint32 i; i < 6; ++i) {
            p.powers[i] = a[13] & (uint32(1) << i) != 0 ? int32(1) : int32(0);
            p.cards[i] = a[14] & (uint32(1) << i) != 0;
        }
        for (uint32 i; i < 2; ++i) {
            p.psprites[i].state = GameConst.NULL;
        }
        c.state.players[0] = p;
        c.state.gameskill = int32(a[3]);
        c.state.gamemode = int32(a[4]);
        c.state.netgame = a[5] != 0;
        c.state.deathmatch = int32(a[6]);
        c.state.prndindex = a[15];
        Mobj memory mo;
        mo.player = 0;
        mo.mobjType = P_Info.MT_PLAYER;
        mo.health = p.health;
        mo.flags = GameConst.MF_SOLID | GameConst.MF_SHOOTABLE;
        mo.height = 56 * 65536;
        mo.state = P_Info.S_PLAY;
        mo.tics = c.definitions.states[P_Info.S_PLAY].tics;
        mo.reactiontime = 9;
        if (a[0] == 9) {
            mo.mobjType = a[1];
            mo.health = int32(a[2]);
            mo.player = GameConst.NULL;
            mo.flags |= GameConst.MF_COUNTKILL | GameConst.MF_FLOAT | GameConst.MF_NOGRAVITY
            | GameConst.MF_SKULLFLY;
            mo.height = c.definitions.mobjinfo[mo.mobjType].height;
        }
        c.state.mobjs[0] = mo;
        Mobj memory special;
        special.sprite = a[1];
        special.allocated = true;
        special.flags = GameConst.MF_SPECIAL | GameConst.MF_COUNTITEM | (a[2] != 0 ? GameConst.MF_DROPPED : 0);
        c.state.mobjs[1] = special;
        Mobj memory spawned;
        spawned.mobjType = GameConst.NULL;
        c.state.mobjs[2] = spawned;
        c.state.sectors[0].special = a[0] == 7 ? int16(int32(a[1])) : int16(0);
    }

    function _hash(string memory text) private pure returns (uint32 hash) {
        bytes memory data = bytes(text);
        if (data.length == 0) return 0;
        hash = 2166136261;
        for (uint256 i; i < data.length; ++i) {
            unchecked {
                hash = (hash ^ uint8(data[i])) * 16777619;
            }
        }
    }

    function _output(GameContext memory c, bool result) private pure returns (uint32[42] memory o) {
        Player memory p = c.state.players[0];
        Mobj memory mo = c.state.mobjs[0];
        o[0] = result ? 1 : 0;
        o[1] = p.pendingweapon;
        o[2] = uint32(p.health);
        o[3] = uint32(p.armorpoints);
        o[4] = uint32(p.armortype);
        for (uint32 i; i < 9; ++i) {
            if (p.weaponowned[i]) o[5] |= uint32(1) << i;
        }
        o[6] = p.backpack ? 1 : 0;
        o[7] = uint32(p.bonuscount);
        o[8] = uint32(p.itemcount);
        o[9] = uint32(p.damagecount);
        o[10] = uint32(p.playerstate);
        for (uint32 i; i < 4; ++i) {
            o[11 + i] = uint32(p.ammo[i]);
            o[15 + i] = uint32(p.maxammo[i]);
        }
        for (uint32 i; i < 6; ++i) {
            o[19 + i] = uint32(p.powers[i]);
            if (p.cards[i]) o[25] |= uint32(1) << i;
        }
        o[26] = uint32(mo.health);
        o[27] = mo.flags;
        o[28] = p.psprites[0].state;
        o[29] = mo.state;
        o[30] = uint32(mo.tics);
        o[31] = uint32(mo.reactiontime);
        o[32] = uint32(mo.threshold);
        o[33] = c.state.prndindex;
        o[34] = c.state.mobjs[1].allocated ? 0 : 1;
        o[35] = c.state.mobjs[2].mobjType;
        o[36] = _hash(p.message);
        o[37] = uint32(p.killcount);
        for (uint32 i; i < 4; ++i) {
            o[38 + i] = uint32(p.frags[i]);
        }
    }

    function _apply(GameContext memory c, uint32[16] memory a) private view returns (bool result) {
        if (a[0] == 0) result = P_Inter.P_GiveAmmo(c, 0, int32(a[1]), int32(a[2]));
        else if (a[0] == 1) result = P_Inter.P_GiveWeapon(c, 0, a[1], a[2] != 0);
        else if (a[0] == 2) result = P_Inter.P_GiveBody(c, 0, int32(a[2]));
        else if (a[0] == 3) result = P_Inter.P_GiveArmor(c, 0, int32(a[2]));
        else if (a[0] == 4) P_Inter.P_GiveCard(c, 0, a[1]);
        else if (a[0] == 5) result = P_Inter.P_GivePower(c, 0, a[1]);
        else if (a[0] == 6) P_Inter.P_TouchSpecialThing(c, 1, 0);
        else if (a[0] == 7) P_Inter.P_DamageMobj(c, 0, GameConst.NULL, GameConst.NULL, int32(a[2]));
        else if (a[0] == 8) result = P_Pspr.P_CheckAmmo(c, 0);
        else if (a[0] == 9) P_Inter.P_KillMobj(c, GameConst.NULL, 0);
        else revert("unknown combat fixture op");
    }

    function _batch(uint32 operation, uint32 argument) private {
        bytes memory data = vm.readFileBinary("test/fixtures/phase3_combat/vectors.bin");
        uint32 count = _word(data, 0);
        require(count == 6025 && data.length == 4 + uint256(count) * 232);
        GameContext memory c = _context();
        uint32 cases;
        for (uint32 i; i < count; ++i) {
            uint256 offset = 4 + uint256(i) * 232;
            if (_word(data, offset) != operation) continue;
            if (argument != GameConst.NULL && _word(data, offset + 4) != argument) continue;
            uint32[16] memory a;
            for (uint32 j; j < 16; ++j) {
                a[j] = _word(data, offset + uint256(j) * 4);
            }
            _initialize(c, a);
            bool result = _apply(c, a);
            uint32[42] memory o = _output(c, result);
            for (uint32 j; j < 42; ++j) {
                uint32 expected = _word(data, offset + 64 + uint256(j) * 4);
                if (o[j] != expected) {
                    emit log_named_uint("row", i);
                    emit log_named_uint("field", j);
                    emit log_named_uint("actual", o[j]);
                    emit log_named_uint("expected", expected);
                    revert("original combat field mismatch");
                }
            }
            ++cases;
        }
        require(cases != 0, "empty combat operation");
    }

    function testOriginalCGiveAmmoClip() public {
        _batch(0, 0);
    }

    function testOriginalCGiveAmmoShell() public {
        _batch(0, 1);
    }

    function testOriginalCGiveAmmoCell() public {
        _batch(0, 2);
    }

    function testOriginalCGiveAmmoMissile() public {
        _batch(0, 3);
    }

    function testOriginalCGiveNoAmmo() public {
        _batch(0, 5);
    }

    function testOriginalCGiveWeapon() public {
        _batch(1, GameConst.NULL);
    }

    function testOriginalCGiveBody() public {
        _batch(2, GameConst.NULL);
    }

    function testOriginalCGiveArmor() public {
        _batch(3, GameConst.NULL);
    }

    function testOriginalCGiveCard() public {
        _batch(4, GameConst.NULL);
    }

    function testOriginalCGivePower() public {
        _batch(5, GameConst.NULL);
    }

    function testOriginalCAllPickupSprites() public {
        _batch(6, GameConst.NULL);
    }

    function testOriginalCDamageArmorPowerExitAndDeath() public {
        _batch(7, GameConst.NULL);
    }

    function testOriginalCWeaponAmmoSelection() public {
        _batch(8, GameConst.NULL);
    }

    function testOriginalCMonsterDeathsGibsDropsAndKillCounting() public {
        _batch(9, GameConst.NULL);
    }

    function invalidAmmo(int32 ammo) external pure returns (bool) {
        GameContext memory c;
        return P_Inter.P_GiveAmmo(c, 0, ammo, 1);
    }

    function testInvalidAmmoRejectsErrorAndOriginalArrayOverrunDomain() public view {
        for (int32 ammo = -1; ammo <= 4; ++ammo) {
            if (ammo >= 0 && ammo < 4) continue;
            try this.invalidAmmo(ammo) returns (bool) {
                revert("invalid ammo accepted");
            } catch (bytes memory reason) {
                require(
                    keccak256(reason) == keccak256(abi.encodeWithSelector(P_Inter.InvalidAmmo.selector, ammo))
                );
            }
        }
        require(!this.invalidAmmo(5), "noammo should return before player dereference");
    }
}
