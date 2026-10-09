// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {GameContext, GameConst, Player, PlayerState, Mobj, MapScratch} from "../../src/doom/p_game_state.sol";
import {P_Info} from "../../src/doom/p_info.sol";
import {P_Pspr} from "../../src/doom/p_pspr.sol";

interface VmWeapons {
    function readFileBinary(string calldata path) external view returns (bytes memory);
}

contract PPsprTest {
    struct WeaponCase {
        bytes data;
        GameContext context;
        uint32 weapon;
        uint32 scenario;
        uint32 tick;
        uint256 start;
    }
    VmWeapons constant vm = VmWeapons(address(uint160(uint256(keccak256("hevm cheat code")))));
    event log_named_uint(string key, uint256 value);

    function _word(bytes memory data, uint256 offset) private pure returns (uint32 value) {
        for (uint32 i; i < 4; ++i) {
            value = (value << 8) | uint8(data[offset + i]);
        }
    }

    function _mix(uint32 hash, uint32 value) private pure returns (uint32) {
        unchecked {
            return (hash ^ value) * 16777619;
        }
    }

    function _state(GameContext memory c, uint32 mo, uint32 state) internal pure returns (bool) {
        c.state.mobjs[mo].state = state;
        c.state.mobjs[mo].tics = c.definitions.states[state].tics;
        return state != 0;
    }

    function _aim(GameContext memory c, uint32, uint32 angle, int32 range) internal pure returns (int32) {
        ++c.move.tmx;
        c.move.tmy = int32(_mix(_mix(uint32(c.move.tmy), angle), uint32(range)));
        c.move.linetarget = c.move.floatok ? uint32(1) : GameConst.NULL;
        return 12345;
    }

    function _line(GameContext memory c, uint32, uint32 angle, int32 range, int32 slope, int32 damage)
        internal
        pure
    {
        ++c.move.tmfloorz;
        c.move.tmceilingz = int32(
            _mix(
                _mix(_mix(_mix(uint32(c.move.tmceilingz), angle), uint32(range)), uint32(slope)),
                uint32(damage)
            )
        );
        c.move.linetarget = c.move.floatok ? uint32(1) : GameConst.NULL;
    }

    function _missile(GameContext memory c, uint32, uint32 kind) internal pure {
        ++c.move.tmdropoffz;
        c.move.bestslidefrac = int32(_mix(uint32(c.move.bestslidefrac), kind));
    }

    function _noise(GameContext memory c, uint32, uint32) internal pure {
        ++c.move.secondslidefrac;
    }

    function _spawn(GameContext memory c, int32, int32, int32, uint32) internal pure returns (uint32) {
        ++c.move.tmxmove;
        return 2;
    }

    function _damage(GameContext memory c, uint32, uint32, uint32, int32 damage) internal pure {
        ++c.move.tmymove;
        c.move.lowfloor = int32(_mix(uint32(c.move.lowfloor), uint32(damage)));
    }

    function _context() private pure returns (GameContext memory c) {
        c.definitions = P_Info.load();
        c.state.mobjs = new Mobj[](3);
        c.hooks.actionPSprite = P_Pspr.actionPSprite;
        c.hooks.setMobjState = _state;
        c.hooks.aimLineAttack = _aim;
        c.hooks.lineAttack = _line;
        c.hooks.spawnPlayerMissile = _missile;
        c.hooks.noiseAlert = _noise;
        c.hooks.spawnMobj = _spawn;
        c.hooks.damageMobj = _damage;
        c.hooks.playerThink = _advance;
    }

    function _initialize(GameContext memory c, uint32 weapon, bool ammo, bool hits) private view {
        Player memory p;
        p.mo = 0;
        p.readyweapon = weapon;
        p.pendingweapon = 10;
        p.health = 100;
        p.bob = 65536;
        for (uint32 i; i < 9; ++i) {
            p.weaponowned[i] = true;
        }
        for (uint32 i; i < 4; ++i) {
            p.ammo[i] = ammo ? int32(100) : int32(0);
        }
        c.state.players[0] = p;
        Mobj memory actor;
        actor.state = P_Info.S_PLAY;
        actor.angle = 0x12000000;
        actor.flags = GameConst.MF_SOLID | GameConst.MF_SHOOTABLE;
        actor.target = 0;
        c.state.mobjs[0] = actor;
        Mobj memory victim;
        victim.x = 64 * 65536;
        victim.y = 64 * 65536;
        victim.height = 56 * 65536;
        c.state.mobjs[1] = victim;
        c.state.prndindex = 17;
        c.state.leveltime = 0;
        c.state.gamemode = 2;
        MapScratch memory move;
        move.floatok = hits;
        move.linetarget = GameConst.NULL;
        move.tmceilingz = int32(uint32(2166136261));
        move.tmy = int32(uint32(2166136261));
        move.bestslidefrac = int32(uint32(2166136261));
        move.lowfloor = int32(uint32(2166136261));
        c.move = move;
        P_Pspr.P_SetupPsprites(c, 0);
    }

    function _output(GameContext memory c) private pure returns (uint32[33] memory o) {
        Player memory p = c.state.players[0];
        for (uint32 slot; slot < 2; ++slot) {
            o[slot * 4] = p.psprites[slot].state;
            o[slot * 4 + 1] = uint32(p.psprites[slot].tics);
            o[slot * 4 + 2] = uint32(p.psprites[slot].sx);
            o[slot * 4 + 3] = uint32(p.psprites[slot].sy);
        }
        o[8] = p.readyweapon;
        o[9] = p.pendingweapon;
        o[10] = uint32(p.attackdown);
        o[11] = uint32(p.refire);
        o[12] = uint32(p.extralight);
        for (uint32 i; i < 4; ++i) {
            o[13 + i] = uint32(p.ammo[i]);
        }
        o[17] = c.state.mobjs[0].state;
        o[18] = c.state.mobjs[0].angle;
        o[19] = c.state.mobjs[0].flags;
        o[20] = c.state.prndindex;
        o[21] = uint32(c.move.tmfloorz);
        o[22] = uint32(c.move.tmceilingz);
        o[23] = uint32(c.move.tmx);
        o[24] = uint32(c.move.tmy);
        o[25] = uint32(c.move.tmdropoffz);
        o[26] = uint32(c.move.bestslidefrac);
        o[27] = uint32(c.move.secondslidefrac);
        o[28] = uint32(c.move.tmxmove);
        o[29] = uint32(c.move.tmymove);
        o[30] = uint32(c.move.lowfloor);
        (int32 sx, int32 sy) = P_Pspr.P_CalcSwing(c, 0);
        o[31] = uint32(sx);
        o[32] = uint32(sy);
    }

    function _advance(GameContext memory c, uint32) internal view {
        Player memory p = c.state.players[0];
        uint32 tick = uint32(c.state.leveltime);
        p.cmd.buttons = c.state.gameepisode == 0 || tick % 24 < 12 ? uint8(1) : uint8(0);
        if (tick == 70) p.powers[1] = 1;
        if (tick == 120) {
            p.health = 0;
            p.playerstate = PlayerState.dead;
            P_Pspr.P_DropWeapon(c, 0);
        }
        P_Pspr.P_MovePsprites(c, 0);
        if (c.state.gamemap == 6 && tick == 100) P_Pspr.A_BFGSpray(c, 0);
    }

    // External test-only boundary prevents nine copies of the complete weapon dispatcher
    // from being inlined into the fixture loop. Each scenario retains all 160 sequential tics.
    function runScenario(uint32 weapon, uint32 scenario) external {
        require(weapon < 9 && scenario / 8 == weapon, "scenario identity");
        WeaponCase memory w;
        w.weapon = weapon;
        w.scenario = scenario;
        w.data = vm.readFileBinary("test/fixtures/phase3_combat/weapons.bin");
        require(
            _word(w.data, 0) == 72 && _word(w.data, 4) == 160 && _word(w.data, 8) == 33
                && w.data.length == 12 + 72 * 160 * 152,
            "weapon fixture extent"
        );
        w.context = _context();
        w.start = 12 + uint256(w.scenario) * 160 * 152;
        require(_word(w.data, w.start) == w.weapon, "weapon fixture grouping");
        _initialize(w.context, w.weapon, _word(w.data, w.start + 4) != 0, _word(w.data, w.start + 12) != 0);
        // Test profile metadata occupies unused game fields; callbacks remain on one context.
        w.context.state.gameepisode = int32(_word(w.data, w.start + 8));
        w.context.state.gamemap = int32(w.weapon);
        for (; w.tick < 160; ++w.tick) {
            w.context.state.leveltime = int32(w.tick);
            w.context.hooks.playerThink(w.context, 0);
            _compare(w);
        }
    }

    function _compare(WeaponCase memory w) private {
        uint32[33] memory o = _output(w.context);
        uint256 offset = w.start + uint256(w.tick) * 152;
        require(_word(w.data, offset + 16) == w.tick, "native tic sequence");
        for (uint32 j; j < 33; ++j) {
            uint32 expected = _word(w.data, offset + 20 + uint256(j) * 4);
            if (o[j] != expected) {
                emit log_named_uint("scenario", w.scenario);
                emit log_named_uint("tick", w.tick);
                emit log_named_uint("field", j);
                emit log_named_uint("actual", o[j]);
                emit log_named_uint("expected", expected);
                revert("original p_pspr mismatch");
            }
        }
    }

    function _batch(uint32 weapon) private {
        for (uint32 scenario = weapon * 8; scenario < weapon * 8 + 8; ++scenario) {
            this.runScenario(weapon, scenario);
        }
    }

    function testOriginalCFist() public {
        _batch(0);
    }

    function testOriginalCPistol() public {
        _batch(1);
    }

    function testOriginalCShotgun() public {
        _batch(2);
    }

    function testOriginalCChaingun() public {
        _batch(3);
    }

    function testOriginalCRocket() public {
        _batch(4);
    }

    function testOriginalCPlasma() public {
        _batch(5);
    }

    function testOriginalCBFGAndSpray() public {
        _batch(6);
    }

    function testOriginalCChainsaw() public {
        _batch(7);
    }

    function testOriginalCSuperShotgun() public {
        _batch(8);
    }
}
