// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {P_Saveg} from "../../src/doom/p_saveg.sol";
import {GameState, Mobj, Thinker, GameSector, Door, ThinkerKind} from "../../src/doom/p_game_state.sol";
import {ZoneBlock} from "../../src/doom/z_zone_types.sol";
import {UIState} from "../../src/evm/DoomUI.sol";
import {InputRuntimeState} from "../../src/evm/InputProtocol.sol";
import {EpisodeState} from "../../src/evm/EpisodeRuntime.sol";

contract SaveArchiveTest {
    GameState internal gameState;
    UIState internal uiState;
    InputRuntimeState internal inputRuntime;
    EpisodeState internal episodeState;

    function configure(uint32 seed) internal {
        gameState.gametic = uint64(seed) << 40;
        gameState.leveltime = int32(seed);
        gameState.prndindex = seed % 256;
        gameState.rndindex = (seed + 97) % 256;
        gameState.players[0].message =
            seed % 2 == 0
            ? "short"
            : "long message beyond the short storage boundary with exact byte contents";
        gameState.mobjs = new Mobj[](16);
        gameState.mobjCount = 9;
        gameState.mobjs[7].health = int32(seed);
        gameState.mobjs[7].target = 8;
        gameState.mobjs[8].tracer = 7;
        gameState.mobjs[8].allocated = false;
        gameState.mobjs[8].momx = -12345;
        gameState.thinkers = new Thinker[](16);
        gameState.thinkerCount = 10;
        gameState.thinkers[0] = Thinker(8, 7, ThinkerKind.cap, 0, 1);
        gameState.thinkers[7] = Thinker(0, 8, ThinkerKind.mobj, 7, 2);
        gameState.thinkers[8] = Thinker(7, 0, ThinkerKind.mobj, 8, 0);
        gameState.sectors = new GameSector[](3);
        gameState.sectors[1].lines = new uint32[](17);
        for (uint32 j; j < 17; j++) {
            gameState.sectors[1].lines[j] = j + seed;
        }
        gameState.doors = new Door[](8);
        gameState.doorCount = 1;
        gameState.doors[0].topheight = int32(seed);
        gameState.nativeZone.blocks = new ZoneBlock[](8);
        gameState.nativeZone.blockCount = 5;
        gameState.nativeZone.blocks[4].payloadExtent = seed + 1000;
        gameState.nativeZone.blocks[4].idKnown = true;
        gameState.nativeZone.blocks[4].offset = 4096;
        gameState.nativeZone.blocks[4].allocated = false;
        gameState.nativeZone.ownerBlocks = new uint32[](19);
        gameState.nativeZone.ownerBlocks[17] = 3;
        gameState.nativeZone.experimentalVirtualPointers = true;
        gameState.nativePayloadBlocks[0] = new uint32[](16);
        gameState.nativePayloadBlocks[0][8] = 4;
        gameState.blockmap.lump = new int16[](19);
        gameState.blockmap.lump[17] = -32768;
        gameState.texturetranslation = new uint32[](9);
        gameState.texturetranslation[8] = seed;
        gameState.rejectmatrix = new bytes(seed % 2 == 0 ? 31 : 65);
        gameState.rejectmatrix[0] = 0xf1;
        gameState.renderFramebuffer = new bytes(64000);
        gameState.renderFramebuffer[63999] = bytes1(uint8(seed));
        gameState.renderPlane.cacheddistance = new int32[](200);
        gameState.renderPlane.cacheddistance[199] = -900;
        gameState.path.intercepts[127].index = seed;
        gameState.move.onground = true;
        uiState.hud.message.lines[3].text = new bytes(81);
        uiState.hud.message.lines[3].text[80] = 0x7f;
        // Deliberately exercise nested dynamic bytes as a codec unit domain.
        // Production releases these borrowed graphics; the codec does not invent them.
        uiState.status.w_arms[5].p = new bytes[](3);
        uiState.status.w_arms[5].p[2] = new bytes(33);
        uiState.status.w_arms[5].p[2][32] = 0x81;
        uiState.hud.title.font = new bytes[](2);
        uiState.hud.title.font[0] = hex"001122";
        uiState.hideMessages = true;
        uiState.status.paletteRGB = new bytes(768);
        uiState.status.paletteRGB[767] = 0xab;
        inputRuntime.gamekeydown = uint256(1) << 175;
        inputRuntime.cheats.sequences[3].sequence = new bytes(35);
        inputRuntime.cheats.sequences[3].cursor = 17;
        episodeState.fastTics = new int32[](13);
        episodeState.fastTics[12] = -1;
        episodeState.projectileSpeeds[2] = 777;
        episodeState.wi.bcnt = int32(seed);
    }

    function archive() external returns (bytes memory) {
        return P_Saveg.P_Archive(gameState, uiState, inputRuntime, episodeState);
    }

    function restore(bytes calldata data) external {
        P_Saveg.P_UnArchive(gameState, uiState, inputRuntime, episodeState, data);
    }

    function abiDigest() public view returns (bytes32) {
        return keccak256(abi.encode(gameState, uiState, inputRuntime, episodeState));
    }

    function testExactNestedRootsHistoryReferencesAndCapacity() public {
        configure(137);
        bytes32 before = abiDigest();
        bytes memory saved = this.archive();
        configure(42);
        require(abiDigest() != before, "fixture did not diverge");
        this.restore(saved);
        require(abiDigest() == before, "full typed value restoration");
        require(
            gameState.mobjs.length == 16 && gameState.nativeZone.blocks[4].payloadExtent == 1137,
            "capacity/history"
        );
        require(gameState.thinkers[0].next == 7 && gameState.mobjs[8].tracer == 7, "order/reference");
        require(keccak256(this.archive()) == keccak256(saved), "canonical archive");
    }

    function testRepeatedGrowShrinkAndShortLongBytes() public {
        configure(42);
        bytes32 first = abiDigest();
        bytes memory a = this.archive();
        configure(137);
        bytes32 second = abiDigest();
        bytes memory b = this.archive();
        for (uint256 n; n < 4; n++) {
            this.restore(a);
            require(abiDigest() == first, "short restore");
            this.restore(b);
            require(abiDigest() == second, "long restore");
        }
    }

    function testRejectMalformedAndRollbackAllRoots() public {
        configure(137);
        bytes32 before = abiDigest();
        bytes memory b = this.archive();
        bytes memory truncated = new bytes(b.length - 32);
        for (uint256 j; j < truncated.length; j++) {
            truncated[j] = b[j];
        }
        (bool ok,) = address(this).call(abi.encodeCall(this.restore, (truncated)));
        require(!ok, "truncated accepted");
        require(abiDigest() == before, "partial restore escaped rollback");
        (ok,) = address(this).call(abi.encodeCall(this.restore, (bytes.concat(b, new bytes(32)))));
        require(!ok, "trailing accepted");
        require(abiDigest() == before, "trailing restore changed state");
        (ok,) = address(this).call(abi.encodeCall(this.restore, (hex"00")));
        require(!ok, "unaligned accepted");
        require(abiDigest() == before, "unaligned restore changed state");
    }
}
