// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {DoomGame} from "../../src/evm/DoomGame.sol";
import {GameContext, GameState, GameConst, PlayerState} from "../../src/doom/p_game_state.sol";
import {G_Game, GameflowHooks, GameflowState} from "../../src/doom/g_game.sol";
import {P_Setup} from "../../src/doom/p_setup.sol";
import {P_Tick} from "../../src/doom/p_tick.sol";
import {P_Inter} from "../../src/doom/p_inter.sol";
import {R_Data} from "../../src/doom/r_data.sol";
import {Ticcmd} from "../../src/doom/d_ticcmd.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
import {GameflowLegacySnapshot} from "../unit/GameflowLegacySnapshot.sol";

interface GameflowMapVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function etch(address, bytes calldata) external;
    function toString(uint256) external pure returns (string memory);
}

contract GameflowE1M1Test {
    GameflowMapVm constant vm = GameflowMapVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function installChunk(uint256 i) external {
        vm.etch(
            address(uint160(0x100000 + i)),
            vm.readFileBinary(string.concat("artifacts/local/wad/phase2-chunks/", vm.toString(i), ".bin"))
        );
    }

    function setUp() public {
        for (uint256 i; i < 1755; ++i) {
            this.installChunk(i);
        }
    }

    function source() private view returns (ResourceView memory v) {
        v.byteLength = 28741889;
        v.chunks = new address[](1755);
        for (uint256 i; i < 1755; ++i) {
            v.chunks[i] = address(uint160(0x100000 + i));
        }
        bytes memory d = vm.readFileBinary("test/fixtures/phase2_data/directory.bin");
        v.lumps = new LumpDescriptor[](d.length / 16);
        for (uint256 i; i < v.lumps.length; ++i) {
            uint256 p = i * 16;
            bytes8 name;
            assembly ("memory-safe") { name := mload(add(add(d, 32), p)) }
            v.lumps[i] = LumpDescriptor(name, le32(d, p + 8), le32(d, p + 12));
        }
    }

    function le32(bytes memory b, uint256 p) private pure returns (uint32 v) {
        for (uint32 i; i < 4; ++i) {
            v |= uint32(uint8(b[p + i])) << (8 * i);
        }
    }

    function setupLevel(GameContext memory c, GameflowState memory) private view {
        require(c.state.gameepisode == 1 && c.state.gamemap == 1, "E1M1-only test loader");
        P_Setup.P_SetupLevel(c, c.state.gameepisode, c.state.gamemap, 0, c.state.gameskill);
    }

    function level(GameContext memory c, GameflowState memory) private view {
        P_Tick.P_Ticker(c);
    }
    function noOp(GameContext memory, GameflowState memory) private pure {}

    function flat(GameContext memory c, bytes8 name) private pure returns (uint32) {
        return R_Data.R_FlatNumForName(c.resources, name);
    }

    function texture(GameContext memory c, bytes8 name) private pure returns (uint32) {
        return R_Data.R_TextureNumForName(c.resources, name);
    }

    function stopMap(GameContext memory, GameflowState memory f) private pure {
        f.automapactive = false;
    }

    function finale(GameContext memory c, GameflowState memory f) private pure {
        c.state.gamestate = 2;
        c.state.gameaction = 0;
        f.viewactive = false;
        f.automapactive = false;
    }

    function hooks() private pure returns (GameflowHooks memory h) {
        h.setupLevel = setupLevel;
        h.checkHeap = noOp;
        h.levelTicker = level;
        h.statusTicker = noOp;
        h.automapTicker = noOp;
        h.hudTicker = noOp;
        h.automapStop = stopMap;
        h.intermissionStart = noOp;
        h.intermissionTicker = noOp;
        h.finaleStart = finale;
        h.finaleTicker = noOp;
        h.flatNumForName = flat;
        h.textureNumForName = texture;
    }

    function tick(GameContext memory c, GameflowState memory f, uint8 buttons) private view {
        G_Game.G_Ticker(c, f, hooks(), Ticcmd(0, 0, 0, 0, 0, buttons));
        ++c.state.gametic;
    }

    function assertNative(GameContext memory c, uint256 tic) private view {
        bytes memory expected = vm.readFileBinary(
            string.concat("test/fixtures/phase4_gameflow/legacy-idle-", vm.toString(tic), ".bin")
        );
        require(
            sha256(GameflowLegacySnapshot.observe(c.state)) == sha256(expected),
            "full accepted native DSG1 state"
        );
    }

    function testRealE1M1NativeStartupFirstTicPauseDeathRestartAndCompletion() public view {
        ResourceView memory v = source();
        GameContext memory c = DoomGame.initialize(v, false);
        GameflowState memory f;
        // Production setup/hook implementation is reused unchanged; only the gameflow adapter is test-owned.
        G_Game.G_InitNew(c, f, hooks(), 2, 1, 1);
        assertNative(c, 0);
        tick(c, f, 0);
        assertNative(c, 1);
        int32 time = c.state.leveltime;
        uint32 rng = c.state.prndindex;
        uint32 mo = c.state.players[0].mo;
        int32 x = c.state.mobjs[mo].x;
        int32 actorTics = c.state.mobjs[mo].tics;
        tick(c, f, 129);
        tick(c, f, 0);
        require(
            c.state.paused && c.state.leveltime == time && c.state.prndindex == rng
                && c.state.mobjs[mo].x == x && c.state.mobjs[mo].tics == actorTics,
            "paused world frozen"
        );
        tick(c, f, 129);
        require(!c.state.paused && c.state.leveltime == time + 1, "resume advances same tic");
        // Original damage/death and use-to-reborn, not a synthetic playerstate toggle.
        P_Inter.P_DamageMobj(c, mo, GameConst.NULL, GameConst.NULL, 10000);
        require(c.state.players[0].playerstate == PlayerState.dead && c.state.mobjs[mo].health <= 0);
        tick(c, f, 2);
        require(c.state.players[0].playerstate == PlayerState.reborn, "death use only queues rebirth");
        uint64 restartTic = c.state.gametic;
        tick(c, f, 0);
        require(
            c.state.players[0].playerstate == PlayerState.live && c.state.players[0].health == 100
                && c.state.players[0].ammo[0] == 50
        );
        require(
            c.state.leveltime == 1 && f.levelstarttic == restartTic && c.state.gameaction == 0
                && f.initialized,
            "reload then tick"
        );
        require(
            c.state.players[0].killcount == 0 && c.state.players[0].itemcount == 0
                && c.state.players[0].secretcount == 0
        );
        c.state.players[0].armorpoints = 37;
        c.state.players[0].ammo[1] = 11;
        c.state.players[0].cards[0] = true;
        c.state.players[0].powers[1] = 10;
        G_Game.G_ExitLevel(c.state);
        tick(c, f, 0);
        require(c.state.gamestate == 1 && f.wminfo.last == 0 && f.wminfo.next == 1 && !f.viewactive);
        require(
            c.state.players[0].armorpoints == 37 && c.state.players[0].ammo[1] == 11
                && !c.state.players[0].cards[0] && c.state.players[0].powers[1] == 0,
            "completion inventory rules"
        );
        require(
            f.wminfo.maxkills == 29 && f.wminfo.maxitems == 49 && f.wminfo.plyr[0].stime == 1,
            "real map totals"
        );
    }
}
