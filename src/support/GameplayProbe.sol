// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {WadResources} from "../evm/WadResources.sol";
import {DoomGame} from "../evm/DoomGame.sol";
import {
    GameContext,
    GameState,
    GameConst,
    ThinkerKind,
    Player,
    Mobj,
    Door,
    FloorMove,
    CeilingMove,
    Plat,
    FireFlicker,
    LightFlash,
    Strobe,
    Glow,
    FloorType,
    PlatStatus
} from "../doom/p_game_state.sol";
import {Ticcmd} from "../doom/d_ticcmd.sol";
import {MapThing} from "../doom/r_defs.sol";
import {P_Info} from "../doom/p_info.sol";
import {P_Pspr} from "../doom/p_pspr.sol";

/// @notice Test-only ordinary-EVM host for the actual gameplay adapter and renderer.
/// @dev DSG1 observations follow tools/reference/gameplay/observe.h, before selected renders.
contract GameplayProbe is WadResources {
    GameState private saved;
    bool private ready;
    event Observation(uint32 tic, bytes state, bytes pixels);
    error InvalidScenario();
    error InvalidCommands();
    error NotReady();

    constructor(address[] memory chunks, bytes memory directory) WadResources(chunks, directory) {}

    /// @dev Reread immutable call data after initialization instead of holding a scalar
    /// across the entire inlined loader. The copy prevents hoisting that lifetime.
    function scenarioArgument() private pure returns (uint8) {
        bytes memory encoded = new bytes(32);
        uint256 raw;
        assembly ("memory-safe") {
            calldatacopy(add(encoded, 32), 4, 32)
            raw := mload(add(encoded, 32))
        }
        if (raw > 6) revert InvalidScenario();
        return uint8(raw);
    }

    function setup() private view returns (GameContext memory c) {
        c = DoomGame.initializeNative(_resourceView(), scenarioArgument() == 4);
        configure(c);
    }

    function configure(GameContext memory c) private view {
        uint8 scenario = scenarioArgument();
        uint32 mo = c.state.players[0].mo;
        if (scenario == 4 || scenario == 5) {
            if (!c.hooks.teleportMove(c, mo, 832 * 65536, 576 * 65536)) revert InvalidScenario();
            c.state.mobjs[mo].z = c.state.mobjs[mo].floorz;
            c.state.mobjs[mo].angle = 0xc0000000;
        } else if (scenario != 0) {
            uint32 enemy = c.hooks
                .spawnMobj(
                    c,
                    c.state.mobjs[mo].x + 64 * 65536,
                    c.state.mobjs[mo].y,
                    GameConst.ONFLOORZ,
                    P_Info.MT_POSSESSED
                );
            if (!c.hooks.checkPosition(c, enemy, c.state.mobjs[enemy].x, c.state.mobjs[enemy].y)) {
                revert InvalidScenario();
            }
            c.state.mobjs[enemy].angle = 0x80000000;
            c.state.mobjs[enemy].target = mo;
            c.hooks.setMobjState(c, enemy, uint32(c.definitions.mobjinfo[P_Info.MT_POSSESSED].seestate));
            if (scenario == 2) {
                c.state.players[0].armorpoints = 100;
                c.state.players[0].armortype = 1;
            }
            if (scenario == 3) {
                c.state.players[0].health = 3;
                c.state.mobjs[mo].health = 3;
            }
        }
        if (scenario == 6) {
            // Same explicit test setup as the independent original-C projectile host.
            // Original wp_missile=4, am_misl=3; no world or pixels are supplied.
            c.state.mobjs[mo].angle = 0;
            c.state.players[0].armorpoints = 200;
            c.state.players[0].armortype = 2;
            c.state.players[0].weaponowned[4] = true;
            c.state.players[0].readyweapon = 4;
            c.state.players[0].pendingweapon = P_Pspr.WP_NOCHANGE;
            c.state.players[0].ammo[3] = 6;
            c.hooks.setupPsprites(c, 0);
        }
    }

    function startup(uint8) external view returns (bytes memory) {
        return observe(setup().state);
    }

    function reset(uint8) external {
        GameContext memory c = setup();
        emit Observation(0, observe(c.state), new bytes(0));
        saved = c.state;
        ready = true;
    }

    function snapshot() external view returns (bytes memory) {
        if (!ready) revert NotReady();
        GameState memory state = saved;
        return observe(state);
    }

    /// @dev Each 7-byte row: int8 forward, int8 side, big-endian int16 angle,
    /// uint8 buttons, uint8 render flag, uint8 reserved=0. Direct original ticcmds.
    function advance(bytes calldata commands) external {
        if (!ready) revert NotReady();
        if (commands.length == 0 || commands.length % 7 != 0) revert InvalidCommands();
        GameState memory state = saved;
        GameContext memory c = DoomGame.load(_resourceView(), state);
        for (uint256 pos; pos < commands.length; pos += 7) {
            if (uint8(commands[pos + 5]) > 1 || commands[pos + 6] != 0) revert InvalidCommands();
            Ticcmd memory cmd;
            cmd.forwardmove = int8(uint8(commands[pos]));
            cmd.sidemove = int8(uint8(commands[pos + 1]));
            cmd.angleturn = int16(uint16(uint8(commands[pos + 2])) << 8 | uint16(uint8(commands[pos + 3])));
            cmd.buttons = uint8(commands[pos + 4]);
            DoomGame.tick(c, cmd);
            bytes memory observation = observe(c.state);
            bytes memory pixels = uint8(commands[pos + 5]) == 0 ? new bytes(0) : DoomGame.render(c);
            emit Observation(uint32(c.state.gametic), observation, pixels);
        }
        saved = c.state;
    }

    struct Words {
        bytes data;
        uint256 pos;
    }

    function w(Words memory b, int256 value) private pure {
        bytes memory data = b.data;
        uint256 pos = b.pos;
        // The allocation reserves 32 trailing bytes for this whole-word store.
        assembly ("memory-safe") { mstore(add(add(data, 32), pos), shl(224, and(value, 0xffffffff))) }
        b.pos = pos + 4;
    }

    function u(Words memory b, uint256 value) private pure {
        w(b, int256(value));
    }

    function flag(bool value) private pure returns (int256) {
        return value ? int256(1) : int256(0);
    }

    function nullable(uint32 value) private pure returns (int256) {
        return value == GameConst.NULL ? int256(-1) : int256(uint256(value));
    }

    function thinkerRef(uint32 value) private pure returns (int256) {
        return value == GameConst.NULL ? int256(0) : (value == 0 ? int256(-1) : int256(uint256(value)));
    }

    function actorRef(GameState memory s, uint32 value) private pure returns (int256) {
        return value == GameConst.NULL ? int256(0) : thinkerRef(s.mobjs[value].thinker);
    }

    function nativeKind(ThinkerKind kind) private pure returns (int256) {
        if (kind == ThinkerKind.fireFlicker) return 9;
        if (kind == ThinkerKind.lightFlash) return 6;
        if (kind == ThinkerKind.strobe) return 7;
        if (kind == ThinkerKind.glow) return 8;
        return int256(uint256(uint8(kind)));
    }

    function mapthing(Words memory b, MapThing memory m) private pure {
        w(b, m.x);
        w(b, m.y);
        w(b, m.angle);
        w(b, m.thingType);
        w(b, m.options);
    }

    function player(Words memory b, GameState memory s, Player memory p) private pure {
        w(b, actorRef(s, p.mo));
        w(b, int256(uint256(uint8(p.playerstate))));
        w(b, p.viewz);
        w(b, p.viewheight);
        w(b, p.deltaviewheight);
        w(b, p.bob);
        w(b, p.health);
        w(b, p.armorpoints);
        w(b, p.armortype);
        for (uint256 i; i < 6; ++i) {
            w(b, p.powers[i]);
        }
        for (uint256 i; i < 6; ++i) {
            w(b, flag(p.cards[i]));
        }
        w(b, flag(p.backpack));
        for (uint256 i; i < 4; ++i) {
            w(b, p.frags[i]);
        }
        u(b, p.readyweapon);
        u(b, p.pendingweapon);
        for (uint256 i; i < 9; ++i) {
            w(b, flag(p.weaponowned[i]));
        }
        for (uint256 i; i < 4; ++i) {
            w(b, p.ammo[i]);
            w(b, p.maxammo[i]);
        }
        w(b, p.attackdown);
        w(b, p.usedown);
        w(b, p.cheats);
        w(b, p.refire);
        w(b, p.killcount);
        w(b, p.itemcount);
        w(b, p.secretcount);
        w(b, p.damagecount);
        w(b, p.bonuscount);
        w(b, actorRef(s, p.attacker));
        w(b, p.extralight);
        w(b, p.fixedcolormap);
        w(b, p.colormap);
        w(b, flag(p.didsecret));
        for (uint256 i; i < 2; ++i) {
            w(b, nullable(p.psprites[i].state));
            w(b, p.psprites[i].tics);
            w(b, p.psprites[i].sx);
            w(b, p.psprites[i].sy);
        }
    }

    function actor(Words memory b, GameState memory s, Mobj memory m) private pure {
        w(b, m.x);
        w(b, m.y);
        w(b, m.z);
        u(b, m.angle);
        u(b, m.sprite);
        u(b, m.frame);
        w(b, m.floorz);
        w(b, m.ceilingz);
        w(b, m.radius);
        w(b, m.height);
        w(b, m.momx);
        w(b, m.momy);
        w(b, m.momz);
        u(b, m.mobjType);
        w(b, m.tics);
        w(b, nullable(m.state));
        u(b, m.flags);
        w(b, m.health);
        w(b, m.movedir);
        w(b, m.movecount);
        w(b, actorRef(s, m.target));
        w(b, m.reactiontime);
        w(b, m.threshold);
        w(b, nullable(m.player));
        w(b, m.lastlook);
        w(b, actorRef(s, m.tracer));
        w(b, nullable(m.subsector));
        w(b, actorRef(s, m.snext));
        w(b, actorRef(s, m.sprev));
        w(b, actorRef(s, m.bnext));
        w(b, actorRef(s, m.bprev));
        mapthing(b, m.spawnpoint);
    }

    function special(Words memory b, GameState memory s, ThinkerKind kind, uint32 payload) private pure {
        int256 missing = type(int32).min;
        if (kind == ThinkerKind.door) {
            Door memory d = s.doors[payload];
            u(b, d.sector);
            u(b, uint8(d.doorType));
            w(b, d.topheight);
            w(b, d.speed);
            w(b, d.direction);
            w(b, d.topwait);
            w(b, d.direction == 0 || d.direction == 2 ? int256(d.topcountdown) : missing);
        } else if (kind == ThinkerKind.floor) {
            FloorMove memory f = s.floors[payload];
            bool changed = f.floorType == FloorType.donutRaise || f.floorType == FloorType.lowerAndChange;
            u(b, f.sector);
            u(b, uint8(f.floorType));
            w(b, flag(f.crush));
            w(b, f.direction);
            w(b, changed ? int256(f.newspecial) : missing);
            w(b, changed ? int256(f.texture) : missing);
            w(b, f.floordestheight);
            w(b, f.speed);
        } else if (kind == ThinkerKind.ceiling) {
            CeilingMove memory f = s.ceilings[payload];
            u(b, f.sector);
            u(b, uint8(f.ceilingType));
            w(b, f.bottomheight);
            w(b, f.topheight);
            w(b, f.speed);
            w(b, flag(f.crush));
            w(b, f.direction);
            w(b, f.tag);
            w(b, f.direction == 0 ? int256(f.olddirection) : missing);
        } else if (kind == ThinkerKind.plat) {
            Plat memory p = s.plats[payload];
            u(b, p.sector);
            w(b, p.speed);
            w(b, p.low);
            w(b, p.high);
            w(b, p.wait);
            w(
                b,
                p.status == PlatStatus.waiting
                    || (p.status == PlatStatus.inStasis && p.oldstatus == PlatStatus.waiting)
                    ? int256(p.count)
                    : missing
            );
            u(b, uint8(p.status));
            w(b, p.status == PlatStatus.inStasis ? int256(uint256(uint8(p.oldstatus))) : missing);
            w(b, flag(p.crush));
            w(b, p.tag);
            u(b, uint8(p.platType));
        } else if (kind == ThinkerKind.lightFlash) {
            LightFlash memory l = s.lightFlashes[payload];
            u(b, l.sector);
            w(b, l.count);
            w(b, l.maxlight);
            w(b, l.minlight);
            w(b, l.maxtime);
            w(b, l.mintime);
        } else if (kind == ThinkerKind.strobe) {
            Strobe memory l = s.strobes[payload];
            u(b, l.sector);
            w(b, l.count);
            w(b, l.minlight);
            w(b, l.maxlight);
            w(b, l.darktime);
            w(b, l.brighttime);
        } else if (kind == ThinkerKind.glow) {
            Glow memory l = s.glows[payload];
            u(b, l.sector);
            w(b, l.minlight);
            w(b, l.maxlight);
            w(b, l.direction);
        } else if (kind == ThinkerKind.fireFlicker) {
            FireFlicker memory l = s.fireFlickers[payload];
            u(b, l.sector);
            w(b, l.count);
            w(b, l.maxlight);
            w(b, l.minlight);
        } else {
            revert InvalidScenario();
        }
    }

    function observe(GameState memory s) private pure returns (bytes memory result) {
        Words memory b;
        // Upper bound includes every allocated thinker; traversal still uses the original live list.
        uint256 words = 1000 + uint256(s.thinkerCount) * 45 + s.sectors.length * 11 + s.map.lines.length * 3
            + s.map.sides.length * 5 + s.blockmap.heads.length + s.texturetranslation.length
            + s.flattranslation.length;
        b.data = new bytes(words * 4 + 32);
        w(b, 0x44534731);
        w(b, s.leveltime);
        u(b, uint32(s.gametic));
        u(b, s.prndindex);
        u(b, s.rndindex);
        w(b, s.gameaction);
        w(b, flag(s.secretExit));
        w(b, s.totalkills);
        w(b, s.totalitems);
        w(b, s.totalsecret);
        w(b, s.gameskill);
        player(b, s, s.players[0]);
        uint32 count;
        uint32 current = s.thinkers[0].next;
        while (current != 0) {
            ++count;
            current = s.thinkers[current].next;
        }
        u(b, count);
        current = s.thinkers[0].next;
        while (current != 0) {
            u(b, current);
            w(b, nativeKind(s.thinkers[current].kind));
            uint8 status = s.thinkers[current].status;
            w(
                b,
                status == GameConst.THINKER_REMOVE
                    ? int256(-1)
                    : (status == GameConst.THINKER_STASIS ? int256(0) : int256(1))
            );
            w(b, thinkerRef(s.thinkers[current].prev));
            w(b, thinkerRef(s.thinkers[current].next));
            if (s.thinkers[current].kind == ThinkerKind.mobj) {
                actor(b, s, s.mobjs[s.thinkers[current].payload]);
            } else {
                special(b, s, s.thinkers[current].kind, s.thinkers[current].payload);
            }
            current = s.thinkers[current].next;
        }
        w(b, int256(s.sectors.length));
        for (uint256 i; i < s.sectors.length; ++i) {
            w(b, s.map.sectors[i].floorheight);
            w(b, s.map.sectors[i].ceilingheight);
            u(b, s.map.sectors[i].floorpic);
            u(b, s.map.sectors[i].ceilingpic);
            w(b, s.map.sectors[i].lightlevel);
            w(b, s.sectors[i].special);
            w(b, s.sectors[i].tag);
            w(b, s.sectors[i].soundtraversed);
            w(b, actorRef(s, s.sectors[i].soundtarget));
            w(b, actorRef(s, s.sectors[i].thinglist));
            w(b, thinkerRef(s.sectors[i].specialdata));
        }
        w(b, int256(s.map.lines.length));
        for (uint256 i; i < s.map.lines.length; ++i) {
            u(b, s.map.lines[i].flags);
            w(b, s.map.lines[i].special);
            w(b, s.map.lines[i].tag);
        }
        w(b, int256(s.map.sides.length));
        for (uint256 i; i < s.map.sides.length; ++i) {
            w(b, s.map.sides[i].textureoffset);
            w(b, s.map.sides[i].rowoffset);
            u(b, s.map.sides[i].toptexture);
            u(b, s.map.sides[i].bottomtexture);
            u(b, s.map.sides[i].midtexture);
        }
        w(b, int256(s.blockmap.heads.length));
        for (uint256 i; i < s.blockmap.heads.length; ++i) {
            w(b, actorRef(s, s.blockmap.heads[i]));
        }
        for (uint256 i; i < 16; ++i) {
            w(b, s.buttons[i].btimer);
            if (s.buttons[i].btimer != 0) {
                u(b, s.buttons[i].line);
                u(b, uint8(s.buttons[i].where));
                w(b, s.buttons[i].btexture);
            }
        }
        for (uint256 i; i < 30; ++i) {
            w(
                b,
                s.activeplats[i] == GameConst.NULL ? int256(0) : thinkerRef(s.plats[s.activeplats[i]].thinker)
            );
        }
        for (uint256 i; i < 30; ++i) {
            w(
                b,
                s.activeceilings[i] == GameConst.NULL
                    ? int256(0)
                    : thinkerRef(s.ceilings[s.activeceilings[i]].thinker)
            );
        }
        w(b, int256(s.texturetranslation.length));
        for (uint256 i; i < s.texturetranslation.length; ++i) {
            u(b, s.texturetranslation[i]);
        }
        w(b, int256(s.flattranslation.length));
        for (uint256 i; i < s.flattranslation.length; ++i) {
            u(b, s.flattranslation[i]);
        }
        u(b, s.iquehead);
        u(b, s.iquetail);
        for (uint32 i = s.iquetail; i != s.iquehead; i = (i + 1) & 127) {
            w(b, s.itemrespawntime[i]);
            mapthing(b, s.itemrespawnque[i]);
        }
        result = b.data;
        uint256 length = b.pos;
        assert(length + 32 <= result.length);
        assembly ("memory-safe") { mstore(result, length) }
    }
}
