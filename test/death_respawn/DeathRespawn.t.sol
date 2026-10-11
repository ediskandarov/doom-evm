// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {DeathRespawnProbe} from "../../src/support/DeathRespawnProbe.sol";
import {PlayerState} from "../../src/doom/p_game_state.sol";

interface DeathVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function readFileBinary(string calldata) external view returns (bytes memory);
    function getCode(string calldata) external view returns (bytes memory);
    function etch(address, bytes calldata) external;
    function toString(uint256) external pure returns (string memory);
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function prank(address) external;
}

contract DeathRespawnTest {
    error NativeFramebuffer(uint256 nativeSeq, bytes32 actual, bytes32 expected);
    DeathVm constant vm = DeathVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    DeathRespawnProbe game;
    uint32 seq;

    function setUp() public {
        address[] memory chunks = new address[](1755);
        for (uint256 i; i < 1755; ++i) {
            chunks[i] = address(uint160(0x100000 + i));
            vm.etch(
                chunks[i],
                vm.readFileBinary(string.concat("artifacts/local/wad/phase2-chunks/", vm.toString(i), ".bin"))
            );
        }
        bytes memory initcode = abi.encodePacked(
            vm.getCode("DeathRespawnProbe.sol:DeathRespawnProbe"),
            abi.encode(chunks, vm.readFileBinary("test/fixtures/phase2_data/directory.bin"))
        );
        address deployed;
        assembly ("memory-safe") { deployed := create(0, add(initcode, 32), mload(initcode)) }
        require(deployed != address(0), "probe deployment");
        game = DeathRespawnProbe(deployed);
        game.initializeMenuWithPolicy(false, 3);
        step(hex"000d010d");
        step(hex"000d010d");
        step(hex"00af01af000d010d");
    }

    function step(bytes memory events) private {
        game.stepEvents(events, ++seq);
    }

    function state() private view returns (PlayerState s) {
        (s,,,,,) = game.playerLifecycle();
    }

    function resetInventory(int32 expectedTime) private view {
        (int32[4] memory ammo, int32[4] memory maxammo, bool[6] memory cards, bool[9] memory weapons) =
            game.playerInventory();
        require(ammo[0] == 50 && ammo[1] == 0 && ammo[2] == 0 && ammo[3] == 0, "original ammo reset");
        require(
            maxammo[0] == 200 && maxammo[1] == 50 && maxammo[2] == 300 && maxammo[3] == 50,
            "backpack maxima reset"
        );
        for (uint256 i; i < 6; ++i) {
            require(!cards[i], "cards reset");
        }
        for (uint256 i; i < 9; ++i) {
            require(weapons[i] == (i < 2), "weapons reset");
        }
        (,,,,, bool backpack) = game.playerLifecycle();
        require(!backpack, "backpack reset");
        (uint64 tic, int32 time, int32 health, int32 armor, int32 weapon) = game.gameStatus();
        require(
            tic > 0 && time == expectedTime && health == 100 && armor == 0 && weapon == 1,
            "reload then first world tic"
        );
    }

    function goldenWord(bytes memory data, uint256 offset) private pure returns (bytes32 result) {
        require(offset + 32 <= data.length);
        assembly ("memory-safe") { result := mload(add(add(data, 32), offset)) }
    }

    function compareNative(bytes memory hashes, uint256 nativeSeq, bool render) private {
        uint256 offset = (nativeSeq - 1) * 96;
        require(sha256(game.snapshot()) == goldenWord(hashes, offset), "whole native world snapshot");
        if (render) {
            DeathVm.Log[] memory logs = vm.getRecordedLogs();
            require(logs.length == 2, "one palette/frame");
            (,,, bytes memory rgb) = abi.decode(logs[0].data, (uint32, int32, uint8, bytes));
            (,, bytes memory pixels) = abi.decode(logs[1].data, (uint16, uint16, bytes));
            if (sha256(pixels) != goldenWord(hashes, offset + 32)) {
                revert NativeFramebuffer(nativeSeq, sha256(pixels), goldenWord(hashes, offset + 32));
            }
            require(sha256(rgb) == goldenWord(hashes, offset + 64), "all native palette bytes");
        }
    }

    function nativeStep(bytes memory hashes, uint256 nativeSeq, bytes memory events, bool render) private {
        if (render) {
            vm.recordLogs();
            game.stepEventsAndRender(events, ++seq);
        } else {
            step(events);
        }
        compareNative(hashes, nativeSeq, render);
    }

    function testNativeFullWorldFramesInventoryMovingDeathAndTwoRebirths() public {
        bytes memory hashes = vm.readFileBinary("test/fixtures/death_respawn/environment-display-hashes.bin");
        compareNative(hashes, 1, false);
        game.configure(3);
        nativeStep(hashes, 2, hex"", false);
        game.configure(2);
        nativeStep(hashes, 3, hex"00ad", true);
        nativeStep(hashes, 4, hex"01ad", true);
        nativeStep(hashes, 5, hex"009d", false);
        nativeStep(hashes, 6, hex"019d", true);
        nativeStep(hashes, 7, hex"0020", true);
        nativeStep(hashes, 8, hex"0120", true);
        nativeStep(hashes, 9, hex"00ad", true);
        game.configure(3);
        nativeStep(hashes, 10, hex"01ad", false);
        game.configure(2);
        nativeStep(hashes, 11, hex"", true);
        nativeStep(hashes, 12, hex"0020", true);
        nativeStep(hashes, 13, hex"0120", true);
        nativeStep(hashes, 14, hex"00ad009d", true);
    }

    function testNativeMonsterDeathAttackerViewAndRebirth() public {
        bytes memory hashes = vm.readFileBinary("test/fixtures/death_respawn/monster-hashes.bin");
        compareNative(hashes, 1, false);
        game.configure(1);
        nativeStep(hashes, 2, hex"00ad", false);
        for (uint256 i = 3; i <= 5; ++i) {
            nativeStep(hashes, i, hex"", false);
        }
        for (uint256 i = 6; i <= 74; ++i) {
            nativeStep(hashes, i, i == 6 ? bytes(hex"01ad") : bytes(hex""), i == 39 || i == 40 || i == 74);
            if (i == 39) require(state() == PlayerState.dead, "actual monster attack lethality");
        }
        (,,, int32 height,,) = game.playerLifecycle();
        require(height == 6 * 65536, "native corpse view floor");
        nativeStep(hashes, 75, hex"009d", true);
        require(state() == PlayerState.dead, "attack stays dead");
        nativeStep(hashes, 76, hex"019d0020", true);
        require(state() == PlayerState.reborn);
        nativeStep(hashes, 77, hex"0120", true);
        require(state() == PlayerState.live);
        nativeStep(hashes, 78, hex"00ad", true);
    }

    function testOptionsPreferencesSurviveOriginalRebirth() public {
        step(hex"001b011b006f016f000d010d");
        step(hex"006d016d000d010d0073017300ae01ae001b011b");
        (bool messages, int32 blocks, bool usergame) = game.optionsStatus();
        require(!messages && blocks == 11 && usergame, "selected original Options");
        game.configure(2);
        step(hex"");
        require(state() == PlayerState.dead);
        step(hex"0020");
        step(hex"0120");
        require(state() == PlayerState.live);
        (messages, blocks, usergame) = game.optionsStatus();
        require(!messages && blocks == 11 && usergame, "Options remain authoritative after rebirth");
        (, bool fullscreen,,,,,,,,,) = game.uiStatus();
        require(fullscreen, "same viewport after ST/HU restart");
    }

    function testMovingInventoryDeathAutomapAttackUseMenuRepeatedRollback() public {
        step(hex"00090109");
        game.configure(3);
        game.configure(2);
        step(hex"00ad");
        require(state() == PlayerState.dead, "environment lethality during movement");
        (bool ok, bytes memory am) = address(game).staticcall(abi.encodeWithSignature("automapStatus()"));
        require(ok && !abi.decode(am, (bool)), "death immediately closes automap");
        (,,, int32 face,,,,,,,) = game.uiStatus();
        require(face == 41, "original dead face");
        bytes32 frozen = keccak256(game.snapshot());
        step(hex"001b011b");
        step(hex"00200120");
        require(
            state() == PlayerState.dead && keccak256(game.snapshot()) == frozen, "menu owns use while dead"
        );
        step(hex"001b011b");
        step(hex"009d");
        require(state() == PlayerState.dead, "attack does not rebirth");
        step(hex"019d01ad0020");
        require(state() == PlayerState.reborn, "new use defers rebirth");
        vm.recordLogs();
        game.stepEventsAndRender(hex"001b011b", ++seq);
        DeathVm.Log[] memory logs = vm.getRecordedLogs();
        require(
            logs.length == 2
                && logs[0].topics[0] == keccak256("FramePalette(uint64,uint32,uint32,int32,uint8,bytes)")
                && logs[1].topics[0] == keccak256("Frame(uint64,uint32,uint16,uint16,bytes)"),
            "rebirth palette/frame pair"
        );
        require(state() == PlayerState.live, "queued rebirth precedes menu freeze");
        resetInventory(0);
        (int32 map, int32 skill,,,,,,,,,) = game.episodeStatus();
        require(map == 1 && skill == 3, "same authoritative map/skill");
        bytes32 digest = game.stateDigest();
        (ok,) = address(game).call(abi.encodeWithSignature("stepEvents(bytes,uint32)", hex"00ad", seq));
        require(!ok && game.stateDigest() == digest, "stale sequence whole-state rollback");
        (ok,) = address(game).call(abi.encodeWithSignature("stepEvents(bytes,uint32)", hex"0200", seq + 1));
        require(!ok && game.stateDigest() == digest, "malformed packet rollback");
        vm.prank(address(99));
        (ok,) = address(game).call(abi.encodeWithSignature("stepEvents(bytes,uint32)", hex"0020", seq + 1));
        require(!ok && game.stateDigest() == digest, "driver rollback");
        step(hex"001b011b");
        step(hex"");
        resetInventory(1);
        for (uint256 cycle; cycle < 3; ++cycle) {
            game.configure(2);
            step(hex"0020");
            require(state() == PlayerState.dead, "repeated lethal sector");
            step(hex"");
            require(state() == PlayerState.reborn, "held use rebirth");
            step(hex"0120");
            require(state() == PlayerState.live, "repeated reload");
            resetInventory(1);
        }
        step(hex"00ad009d");
        require(state() == PlayerState.live, "continued movement/fire");
        require(game.zoneSnapshot().length > 0, "original zone remains active");
    }
}
