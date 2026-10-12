// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {DeathRespawnProbe} from "../../src/support/DeathRespawnProbe.sol";
import {P_Saveg} from "../../src/doom/p_saveg.sol";
import {PlayerState} from "../../src/doom/p_game_state.sol";
import {SaveSlotMetadata} from "../../src/evm/DoomSave.sol";
import {DeathVm} from "./DeathRespawn.t.sol";

/// @dev Observation/invalid-binding methods only. Never packaged as production.
contract CombinedSaveRespawnProbe is DeathRespawnProbe {
    constructor(address[] memory chunks, bytes memory directory) DeathRespawnProbe(chunks, directory) {}

    function roots() external returns (bytes32) {
        return sha256(P_Saveg.P_Archive(gameState, uiState, inputRuntime, episodeState));
    }

    function incompatible(uint8 slot) external {
        saveSlots[slot].memoryPolicy = 0;
    }

    function failureDigest() external view returns (bytes32) {
        return keccak256(abi.encode(gameState, uiState, inputRuntime, episodeState,
            menuState, saveSlots, inputSeq, frameId));
    }
}

contract CombinedSaveRespawnTest {
    DeathVm constant vm = DeathVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    CombinedSaveRespawnProbe game;
    uint32 seq;

    function setUp() public {
        address[] memory chunks = new address[](1755);
        for (uint256 i; i < 1755; ++i) {
            chunks[i] = address(uint160(0x100000 + i));
            vm.etch(chunks[i], vm.readFileBinary(string.concat(
                "artifacts/local/wad/phase2-chunks/", vm.toString(i), ".bin")));
        }
        bytes memory code = abi.encodePacked(vm.getCode("CombinedSaveRespawn.t.sol:CombinedSaveRespawnProbe"),
            abi.encode(chunks, vm.readFileBinary("test/fixtures/phase2_data/directory.bin")));
        address deployed;
        assembly ("memory-safe") { deployed := create(0, add(code, 32), mload(code)) }
        require(deployed != address(0), "combined probe CREATE");
        game = CombinedSaveRespawnProbe(deployed);
        game.initializeMenuWithPolicy(false, 3);
        step(hex"000d010d", false);
        step(hex"000d010d", false);
        step(hex"00af01af000d010d", true); // UV, original menu, cached full frame.
    }

    function step(bytes memory events, bool draw) private {
        if (draw) game.stepEventsAndRender(events, ++seq);
        else game.stepEvents(events, ++seq);
    }

    function state() private view returns (PlayerState s) { (s,,,,,) = game.playerLifecycle(); }
    function save(uint8 slot) private returns (SaveSlotMetadata memory m) {
        m = game.readSaveSlot(slot);
        game.saveGame(slot, bytes("EXACT SNAPSHOT"), m.revision, ++seq);
        m = game.readSaveSlot(slot);
        require(m.occupied && m.compatible && m.memoryPolicy == 3, "exact slot binding");
        require(m.digest == game.roots(), "complete four-root payload");
    }
    function load(uint8 slot) private {
        SaveSlotMetadata memory m = game.readSaveSlot(slot);
        game.loadGame(slot, m.revision, ++seq);
        require(game.roots() == m.digest, "exact restore including RNG/thinkers/allocator/UI");
    }
    function monsterContinuation() private {
        for (uint256 i; i < 60; ++i) step(hex"", i == 30 || i == 59);
        require(state() == PlayerState.dead, "original monster lethal damage");
    }

    function testSaveDieLoadNativeWorldAndCompleteContinuation() public {
        game.configure(1); // Original P_SpawnMobj, real geometry, explicit native fixture.
        step(hex"", true);
        require(state() == PlayerState.live);
        SaveSlotMetadata memory alive = save(0);
        bytes32 world = keccak256(game.snapshot());
        bytes32 zone = keccak256(game.zoneSnapshot());
        monsterContinuation();
        SaveSlotMetadata memory dead = save(1);
        bytes32 terminal = game.roots();
        load(0);
        require(state() == PlayerState.live && keccak256(game.snapshot()) == world, "alive saved world");
        require(keccak256(game.zoneSnapshot()) == zone, "complete allocation chronology");
        require(game.roots() == alive.digest, "saved full roots");
        monsterContinuation();
        require(game.roots() == terminal, "exact active monster replay and pixels");
        require(game.readSaveSlot(1).digest == dead.digest, "death cannot overwrite slots");
    }

    function testSaveDieRespawnLoadRetainsMapSkillRngAndSlots() public {
        game.configure(1); step(hex"", true);
        SaveSlotMetadata memory alive = save(0);
        monsterContinuation(); save(1);
        step(hex"0020", true); require(state() == PlayerState.reborn);
        step(hex"0120", true); require(state() == PlayerState.live);
        (int32 map, int32 skill,,,,,,,,,) = game.episodeStatus();
        require(map == 1 && skill == 3, "same map and original skill on rebirth");
        require(game.readSaveSlot(0).digest == alive.digest, "rebirth leaves prior save intact");
        load(0); require(state() == PlayerState.live && game.roots() == alive.digest);
        monsterContinuation();
        require(game.roots() == game.readSaveSlot(1).digest, "post-rebirth loaded world replays exactly");
    }

    function testDeadAndQueuedRebornSavesRestoreBeforeDeferredMenuReload() public {
        game.configure(2); step(hex"", true); require(state() == PlayerState.dead);
        SaveSlotMetadata memory dead = save(0);
        step(hex"0020", true); require(state() == PlayerState.reborn);
        SaveSlotMetadata memory queued = save(1); // Product extension: no-tic snapshot includes queued rebirth.
        step(hex"001b011b", true); require(state() == PlayerState.live);
        (, int32 time,,,) = game.gameStatus(); require(time == 0, "original menu freeze after reload");
        load(0); require(state() == PlayerState.dead && game.roots() == dead.digest);
        load(1); require(state() == PlayerState.reborn && game.roots() == queued.digest);
        step(hex"001b011b", true); require(state() == PlayerState.live);
        (, time,,,) = game.gameStatus(); require(time == 0);
        require(game.readSaveSlot(0).digest == dead.digest && game.readSaveSlot(1).digest == queued.digest);
    }

    function testSixSlotsOverwriteEmptyAndIncompatibleRollback() public {
        bytes32 before = game.failureDigest();
        (bool ok,) = address(game).call(abi.encodeWithSignature("loadGame(uint8,uint64,uint32)", 5, 0, seq + 1));
        require(!ok && game.failureDigest() == before, "empty whole-contract rollback");
        for (uint8 i; i < 6; ++i) save(i);
        SaveSlotMetadata memory m = save(5); require(m.revision == 2);
        for (uint8 i; i < 5; ++i) require(game.readSaveSlot(i).revision == 1, "isolated revision");
        game.incompatible(0);
        require(!game.readSaveSlot(0).compatible, "unsupported binding rejected");
        before = game.failureDigest();
        vm.recordLogs();
        (ok,) = address(game).call(abi.encodeWithSignature("loadGame(uint8,uint64,uint32)", 0, 1, seq + 1));
        require(!ok && game.failureDigest() == before && vm.getRecordedLogs().length == 0, "incompatible atomic rollback");
        (ok,) = address(game).call(abi.encodeWithSignature("saveGame(uint8,bytes,uint64,uint32)", 1, bytes(""), 1, seq + 1));
        require(!ok && game.failureDigest() == before, "invalid save atomic rollback");
    }
}
