// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {InputProtocol, InputRuntimeState} from "../../src/evm/InputProtocol.sol";
import {DoomGame} from "../../src/evm/DoomGame.sol";
import {UIState} from "../../src/evm/DoomUI.sol";
import {GameContext, GameState, GameSector, Mobj, GameConst} from "../../src/doom/p_game_state.sol";
import {P_Info} from "../../src/doom/p_info.sol";
import {Vertex, Sector, Line} from "../../src/doom/r_defs.sol";
import {AMWorld} from "../../src/doom/am_map_types.sol";
import {Ticcmd} from "../../src/doom/d_ticcmd.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";

interface InputRuntimeVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function etch(address, bytes calldata) external;
    function toString(uint256) external pure returns (string memory);
}

contract InputRuntimeAdapterTest {
    InputRuntimeVm constant vm = InputRuntimeVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    GameState private savedGame;
    UIState private savedUI;
    InputRuntimeState private savedInput;
    bool private started;
    error DownstreamFailure();

    function context() private returns (GameContext memory c) {
        c.state.consoleplayer = 0;
        c.state.displayplayer = 0;
        c.state.playeringame[0] = true;
        c.state.gameskill = 2;
        c.state.gamemode = 3;
        c.state.gameepisode = 1;
        c.state.gamemap = 1;
        c.state.mobjs = new Mobj[](3);
        c.state.mobjCount = 3;
        c.state.players[0].mo = 0;
        c.state.players[0].health = 37;
        c.state.players[0].maxammo = [int32(200), 50, 300, 50];
        for (uint32 i; i < 3; ++i) {
            c.state.mobjs[i].allocated = true;
            c.state.mobjs[i].x = int32(i) * 65536;
            c.state.mobjs[i].health = 37;
        }
        c.state.sectors = new GameSector[](1);
        c.state.sectors[0].thinglist = 2;
        c.state.mobjs[2].snext = 0;
        c.state.mobjs[0].snext = 1;
        c.state.mobjs[1].snext = GameConst.NULL;
        c.state.map.vertexes = new Vertex[](4);
        c.state.map.vertexes[0] = Vertex(-64 * 65536, -64 * 65536);
        c.state.map.vertexes[1] = Vertex(64 * 65536, -64 * 65536);
        c.state.map.vertexes[2] = Vertex(64 * 65536, 64 * 65536);
        c.state.map.vertexes[3] = Vertex(-64 * 65536, 64 * 65536);
        c.state.map.sectors = new Sector[](2);
        c.state.map.sectors[0].floorheight = 17;
        c.state.map.sectors[0].ceilingheight = 128 * 65536;
        c.state.map.sectors[1].floorheight = -33;
        c.state.map.sectors[1].ceilingheight = 192 * 65536;
        c.state.map.lines = new Line[](2);
        c.state.map.lines[0].v1 = 0;
        c.state.map.lines[0].v2 = 1;
        c.state.map.lines[0].flags = 256 | 32;
        c.state.map.lines[0].backsector = 1;
        c.state.map.lines[1].v1 = 2;
        c.state.map.lines[1].v2 = 3;
        c.state.map.lines[1].backsector = GameConst.NULL;
        c.map = c.state.map;
        c.definitions = P_Info.load();
        bytes memory assets;
        c.resources.source.lumps = new LumpDescriptor[](10);
        for (uint256 i; i < 10; ++i) {
            bytes memory patch = vm.readFileBinary(
                string.concat("test/fixtures/phase4_automap/AMMNUM", vm.toString(i), ".bin")
            );
            c.resources.source.lumps[i] = LumpDescriptor(
                bytes8(abi.encodePacked("AMMNUM", bytes1(uint8(48 + i)))),
                uint32(assets.length),
                uint32(patch.length)
            );
            assets = bytes.concat(assets, patch);
        }
        vm.etch(address(0xCAFE), bytes.concat(hex"00", assets));
        c.resources.source.byteLength = uint32(assets.length);
        c.resources.source.chunks = new address[](1);
        c.resources.source.chunks[0] = address(0xCAFE);
    }

    function events(string memory text) private pure returns (bytes memory result) {
        bytes memory value = bytes(text);
        result = new bytes(value.length * 4);
        for (uint256 i; i < value.length; ++i) {
            result[i * 4 + 1] = value[i];
            result[i * 4 + 2] = bytes1(uint8(1));
            result[i * 4 + 3] = value[i];
        }
    }

    function row(bytes memory keys, bool fail) external {
        GameContext memory c = context();
        UIState memory u = savedUI;
        InputRuntimeState memory s = savedInput;
        if (started) {
            c.state = savedGame;
            c.map = c.state.map;
        } else {
            InputProtocol.initialize(s);
            u.enabled = true;
        }
        InputProtocol.respond(s, c, u, keys);
        savedGame = c.state;
        savedUI = u;
        savedInput = s;
        started = true;
        if (fail) revert DownstreamFailure();
    }

    function digest() private view returns (bytes32) {
        return keccak256(abi.encode(savedGame, savedUI, savedInput, started));
    }

    function testPersistentSplitCheatHUConsumptionAndSpyOrder() public {
        this.row(events("idd"), false);
        this.row(hex"000d010d00d801d8", false);
        require(savedInput.cheats.sequences[0].cursor == 3, "HUD/spy keydown never enters ST parser");
        this.row(events("qd"), false);
        require(savedGame.players[0].cheats & GameConst.CF_GODMODE != 0 && savedGame.players[0].health == 100);
        require(savedGame.mobjs[0].health == 100, "authoritative actor mutation");
        require(savedInput.gamekeydown == 0, "keyup reaches ordinary keyboard");
    }

    function testArsenalPowersMessagesAndDeferredWarpPersist() public {
        this.row(events("idkfa"), false);
        for (uint256 i; i < 9; ++i) {
            require(savedGame.players[0].weaponowned[i]);
        }
        for (uint256 i; i < 6; ++i) {
            require(savedGame.players[0].cards[i]);
        }
        this.row(events("idclip"), false);
        require(savedGame.players[0].cheats & GameConst.CF_NOCLIP != 0);
        this.row(events("idbeholdi"), false);
        require(savedGame.mobjs[0].flags & GameConst.MF_SHADOW != 0 && savedGame.players[0].powers[2] > 0);
        require(savedInput.cheats.sequences[14].cursor == 1, "final i starts another original recognizer");
        // Original mismatch consumes the key without retrying a new prefix.
        // A separator clears the previous power code's trailing i before IDCLEV.
        this.row(events("xidclev1"), false);
        this.row(events("9"), false);
        require(savedGame.gameaction == 2 && savedInput.flow.deferredSkill == 2, "deferred action and skill");
        require(
            savedInput.flow.deferredEpisode == 1 && savedInput.flow.deferredMap == 9,
            "deferred episode and map"
        );
        require(savedGame.gamemap == 1, "Episode Runtime owns loading");
        require(
            keccak256(bytes(savedGame.players[0].message)) == keccak256("Changing Level..."),
            "warp HUD message"
        );
    }

    function testAMOwnsIDDTAndConsumesPanButNotReleases() public {
        this.row(events("iddt"), false);
        require(savedInput.automap.cheatPos == 0 && savedInput.automap.cheating == 0);
        this.row(hex"00090109", false);
        this.row(events("iddtiddt"), false);
        require(savedInput.automap.cheating == 2 && savedInput.cheats.automapCheating == 0);
        require(savedInput.cheats.sequences[15].cursor == 0, "standalone IDDT parser unused");
        this.row(events("f"), false);
        this.row(hex"00ae", false);
        require(savedInput.automap.panX != 0 && savedInput.gamekeydown == 0, "consumed pan cannot turn");
        this.row(hex"01ae", false);
        require(savedInput.automap.panX == 0 && savedInput.gamekeydown == 0);
        this.row(hex"00090109", false);
        require(
            !savedInput.automap.active && savedInput.automap.viewactive && savedInput.automap.unloads == 1
        );
        this.row(hex"00090109", false);
        require(
            savedInput.automap.cheating == 2 && savedInput.automap.loads == 2, "same-level state retained"
        );
    }

    function testMalformedStopNotificationCompletesRawWarpParameters() public {
        this.row(hex"00090109", false);
        this.row(events("idclev"), false);
        require(savedInput.cheats.sequences[14].cursor == 7);
        this.row(hex"00090109", false);
        require(
            savedInput.cheats.sequences[14].cursor == 0,
            "TAB then original synthetic keydown1 complete parameter capture"
        );
        require(savedGame.gameaction == 0, "original invalid control-byte selection rejected");
        require(
            savedInput.cheats.sequences[14].sequence[7] == 0
                && savedInput.cheats.sequences[14].sequence[8] == 0
        );
    }

    function testRollbackIncludesParserActorRequestAndUIState() public {
        this.row(events("idd"), false);
        bytes32 before = digest();
        (bool ok,) = address(this).call(abi.encodeCall(this.row, (events("qdidclev19"), true)));
        require(!ok && digest() == before, "whole downstream rollback");
        (ok,) = address(this).call(abi.encodeCall(this.row, (bytes.concat(events("qd"), hex"0200"), false)));
        require(!ok && digest() == before, "invalid later event rolls back earlier cheat mutation");
        this.row(events("qd"), false);
        require(savedGame.players[0].cheats & GameConst.CF_GODMODE != 0, "exact prefix retry succeeds");
    }

    function testNativeKeySetPreservesAliasesAndLowestDigitPriority() public {
        GameContext memory c = context();
        UIState memory u;
        InputRuntimeState memory s;
        InputProtocol.initialize(s);
        InputProtocol.respond(s, c, u, hex"00ad007701ad0039003300310131");
        Ticcmd memory cmd = InputProtocol.build(s, c);
        require(cmd.forwardmove == 25 && (cmd.buttons & 4) != 0 && (cmd.buttons >> 3) == 2);
        InputProtocol.respond(s, c, u, hex"017701330139");
        cmd = InputProtocol.build(s, c);
        require(cmd.forwardmove == 0 && cmd.buttons == 0);
    }

    function testLiveProjectionKeepsLinedefFlagsHeightsAndSectorThingOrder() public {
        GameContext memory c = context();
        c.state.players[0].powers[4] = 1;
        AMWorld memory w = DoomGame.automapWorld(c, 0);
        require(w.walls[0].flags == 288 && w.walls[0].frontFloor == 17 && w.walls[0].backFloor == -33);
        require(w.walls[0].back && !w.walls[1].back);
        require(
            w.things.length == 3 && w.things[0].x == 2 * 65536 && w.things[1].x == 0 && w.things[2].x == 65536
        );
        require(w.allmap && w.vertices[0].x == -64 * 65536);
        c.map.sectors[1].ceilingheight = 23;
        c.map.lines[1].flags |= 256;
        w = DoomGame.automapWorld(c, 0);
        require(w.walls[0].backCeiling == 23 && w.walls[1].flags == 256, "refresh uses live world");
    }
}
