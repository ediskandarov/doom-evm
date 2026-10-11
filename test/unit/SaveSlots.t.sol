// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {SaveArchiveTest} from "./p_saveg.t.sol";
import {DoomSave, SaveSlot, SaveSlotMetadata} from "../../src/evm/DoomSave.sol";

contract SaveSlotsTest is SaveArchiveTest {
    SaveSlot[6] private slots;
    bytes32 constant RESOURCE = keccak256("test-only immutable identity");

    function prepare() private {
        configure(137);
        gameState.menuactive = false;
        inputRuntime.gamekeydown = 0;
        inputRuntime.flow.initialized = true;
        inputRuntime.flow.usergame = true;
    }

    function save(uint8 slot, uint64 revision) external {
        DoomSave.save(
            slots[slot], gameState, uiState, inputRuntime, episodeState, bytes("SAVE"), revision, RESOURCE, 3
        );
    }

    function load(uint8 slot, uint64 revision) external {
        DoomSave.load(slots[slot], gameState, uiState, inputRuntime, episodeState, revision, RESOURCE, 3);
    }

    function testSixIndependentSlotsAndOverwriteRevisions() public {
        prepare();
        bytes32 original = abiDigest();
        for (uint8 slot; slot < 6; ++slot) {
            this.save(slot, 0);
            SaveSlotMetadata memory m = DoomSave.metadata(slots[slot], RESOURCE, 3);
            require(m.occupied && m.compatible && m.revision == 1 && m.byteLength > 0, "metadata");
        }
        configure(42);
        inputRuntime.gamekeydown = 0;
        this.load(4, 1);
        require(abiDigest() == original, "independent restore");
        this.save(4, 1);
        require(slots[4].revision == 2 && slots[3].revision == 1, "overwrite revision");
    }

    function testEmptyIncompatibleCorruptAndStaleRejection() public {
        prepare();
        bytes32 before = abiDigest();
        (bool ok,) = address(this).call(abi.encodeCall(this.load, (0, 0)));
        require(!ok, "empty accepted");
        this.save(0, 0);
        (ok,) = address(this).call(abi.encodeCall(this.save, (0, 0)));
        require(!ok, "stale overwrite");
        (ok,) = address(this).call(abi.encodeCall(this.load, (0, 2)));
        require(!ok, "stale load");
        slots[0].resource = bytes32(uint256(1));
        (ok,) = address(this).call(abi.encodeCall(this.load, (0, 1)));
        require(!ok, "IWAD mismatch");
        slots[0].resource = RESOURCE;
        slots[0].schema = bytes32(uint256(1));
        (ok,) = address(this).call(abi.encodeCall(this.load, (0, 1)));
        require(!ok, "schema mismatch");
        slots[0].schema = slots[1].schema;
        this.save(1, 0);
        slots[0].schema = slots[1].schema;
        slots[0].engine = bytes32(uint256(1));
        (ok,) = address(this).call(abi.encodeCall(this.load, (0, 1)));
        require(!ok, "engine mismatch");
        slots[0].engine = address(this).codehash;
        slots[0].memoryPolicy = 0;
        (ok,) = address(this).call(abi.encodeCall(this.load, (0, 1)));
        require(!ok, "policy mismatch");
        slots[0].memoryPolicy = 3;
        slots[0].data[32] ^= 0x01;
        (ok,) = address(this).call(abi.encodeCall(this.load, (0, 1)));
        require(!ok, "corrupt accepted");
        require(abiDigest() == before, "rejection changed authoritative roots");
    }

    function testPendingActionAndUninitializedStateCannotSave() public {
        prepare();
        gameState.gameaction = 6;
        (bool ok,) = address(this).call(abi.encodeCall(this.save, (0, 0)));
        require(!ok, "pending transition accepted");
        gameState.gameaction = 0;
        inputRuntime.flow.initialized = false;
        (ok,) = address(this).call(abi.encodeCall(this.save, (0, 0)));
        require(!ok, "incomplete setup accepted");
    }
}
