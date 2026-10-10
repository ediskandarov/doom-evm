// SPDX-License-Identifier: GPL-2.0-only
// Observation-only copy of the accepted DSG1 serializer; see episode_startup/reference.py.
pragma solidity 0.8.37;
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
import {GameflowState} from "../doom/g_game.sol";
import {Z_Zone} from "../doom/z_zone.sol";
import {ZoneState, ZoneBlock, ZoneConst} from "../doom/z_zone_types.sol";
import {P_Pspr} from "../doom/p_pspr.sol";

library EpisodeStartupSnapshot {
    error InvalidScenario();

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

    function observe(GameState memory s) internal pure returns (bytes memory result) {
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

    function collision(GameState memory s) internal pure returns (bytes memory result) {
        uint256 refs;
        for (uint256 i; i < s.sectors.length; ++i) {
            refs += s.sectors[i].lines.length;
        }
        Words memory b;
        b.data = new bytes(
            (64
                    + s.blockmap.lump.length
                    + refs
                    + s.sectors.length
                    * 7
                    + s.scrollingLines.length
                    + s.deathmatchStartCount
                    * 5) * 4 + s.rejectmatrix.length + 32
        );
        w(b, s.blockmap.orgx);
        w(b, s.blockmap.orgy);
        w(b, s.blockmap.width);
        w(b, s.blockmap.height);
        u(b, s.blockmap.lump.length);
        for (uint256 i; i < s.blockmap.lump.length; ++i) {
            w(b, s.blockmap.lump[i]);
        }
        u(b, s.rejectmatrix.length);
        for (uint256 i; i < s.rejectmatrix.length; ++i) {
            b.data[b.pos++] = s.rejectmatrix[i];
        }
        u(b, s.sectors.length);
        for (uint256 i; i < s.sectors.length; ++i) {
            u(b, s.sectors[i].lines.length);
            for (uint256 j; j < s.sectors[i].lines.length; ++j) {
                u(b, s.sectors[i].lines[j]);
            }
            w(b, s.sectors[i].soundorgx);
            w(b, s.sectors[i].soundorgy);
            for (uint256 j; j < 4; ++j) {
                w(b, s.sectors[i].blockbox[j]);
            }
        }
        u(b, s.scrollingLines.length);
        for (uint256 i; i < s.scrollingLines.length; ++i) {
            u(b, s.scrollingLines[i]);
        }
        for (uint256 i; i < 4; ++i) {
            mapthing(b, s.playerstarts[i]);
        }
        u(b, s.deathmatchStartCount);
        for (uint256 i; i < s.deathmatchStartCount; ++i) {
            mapthing(b, s.deathmatchstarts[i]);
        }
        result = finish(b);
    }

    function zone(ZoneState memory z) internal pure returns (bytes memory result) {
        uint32 count;
        for (uint32 id = z.blocks[0].next; id != 0; id = z.blocks[id].next) {
            ++count;
        }
        Words memory b;
        b.data = new bytes((7 + uint256(count) * 9 + z.ownerBlocks.length) * 4 + 32);
        u(b, z.byteLength);
        u(b, z.blocks[z.rover].offset);
        u(b, z.blocks[z.blocks[0].prev].offset);
        u(b, z.blocks[z.blocks[0].next].offset);
        u(b, Z_Zone.Z_FreeMemory(z));
        u(b, count);
        for (uint32 id = z.blocks[0].next; id != 0; id = z.blocks[id].next) {
            ZoneBlock memory block_ = z.blocks[id];
            u(b, block_.offset);
            u(b, block_.size);
            w(b, flag(block_.allocated));
            u(b, block_.owner);
            u(b, block_.allocated ? block_.tag : 0);
            w(b, flag(block_.idKnown));
            u(b, block_.idKnown ? block_.id : 0);
            u(b, z.blocks[block_.prev].offset);
            u(b, z.blocks[block_.next].offset);
        }
        u(b, z.ownerBlocks.length);
        for (uint256 i; i < z.ownerBlocks.length; ++i) {
            uint32 id = z.ownerBlocks[i];
            u(b, id == ZoneConst.NULL ? ZoneConst.NULL : Z_Zone.Z_PayloadOffset(z, id));
        }
        result = finish(b);
    }

    function flow(GameState memory s, GameflowState memory f) internal pure returns (bytes memory result) {
        Words memory b;
        b.data = new bytes(22 * 4 + 32);
        w(b, s.gameepisode);
        w(b, s.gamemap);
        w(b, s.gamemode);
        w(b, s.gamestate);
        w(b, s.gameaction);
        w(b, s.gameskill);
        w(b, flag(s.paused));
        w(b, flag(s.menuactive));
        w(b, flag(s.netgame));
        w(b, s.deathmatch);
        w(b, s.consoleplayer);
        w(b, s.displayplayer);
        w(b, flag(s.respawnmonsters));
        w(b, flag(s.nomonsters));
        w(b, flag(s.fastparm));
        u(b, f.levelstarttic);
        w(b, flag(f.usergame));
        w(b, flag(f.viewactive));
        w(b, flag(f.automapactive));
        w(b, f.wipegamestate);
        w(b, f.wminfo.maxfrags);
        w(b, f.wminfo.partime);
        result = finish(b);
    }

    function difficulty(GameContext memory c) internal pure returns (bytes memory result) {
        Words memory b;
        b.data = new bytes(16 * 4 + 32);
        for (uint32 i = P_Info.S_SARG_RUN1; i <= P_Info.S_SARG_PAIN2; ++i) {
            w(b, c.definitions.states[i].tics);
        }
        w(b, c.definitions.mobjinfo[P_Info.MT_BRUISERSHOT].speed);
        w(b, c.definitions.mobjinfo[P_Info.MT_HEADSHOT].speed);
        w(b, c.definitions.mobjinfo[P_Info.MT_TROOPSHOT].speed);
        result = finish(b);
    }

    function finish(Words memory b) private pure returns (bytes memory result) {
        result = b.data;
        uint256 length = b.pos;
        assert(length + 32 <= result.length);
        // Observation buffers reserve32 trailing bytes for the last word store.
        assembly ("memory-safe") { mstore(result, length) }
    }
}
