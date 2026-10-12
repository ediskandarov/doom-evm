// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {ProductionWadResources} from "../evm/ProductionWadResources.sol";
import {EpisodeStartup} from "../evm/EpisodeStartup.sol";
import {GameState, GameContext} from "../doom/p_game_state.sol";
import {DoomUI, UIState} from "../evm/DoomUI.sol";
import {InputProtocol, InputRuntimeState} from "../evm/InputProtocol.sol";
import {EpisodeRuntime, EpisodeState} from "../evm/EpisodeRuntime.sol";
import {P_Saveg} from "../doom/p_saveg.sol";
import {ResourceStore} from "../evm/ResourceStore.sol";

/// @notice Measurement only. Actual authenticated EVM startup, no fixture-state injection.
contract SaveCostProbe is ProductionWadResources {
    GameState internal gameState;
    UIState internal uiState;
    InputRuntimeState internal inputRuntime;
    EpisodeState internal episodeState;

    struct Copy {
        GameState g;
        UIState u;
        InputRuntimeState i;
        EpisodeState e;
    }
    Copy private copied;
    bytes private packed;
    bytes private encoded;
    address[] private immutableChunks;
    uint256 private immutableSize;
    bool private initialized;
    event Measurement(uint8 kind, uint256 bytesLength, uint256 gasUsed, bytes32 digest);

    constructor(address[] memory chunks, bytes memory directory) ProductionWadResources(chunks, directory) {}

    function initialize(int32 map) external {
        require(!initialized);
        (GameContext memory c,) = EpisodeStartup.initialize(_resourceView(), 1, map, 2, false, true);
        c.state.nativeZone.canonicalPointerHighBytes = true;
        c.state.nativeZone.experimentalVirtualPointers = true;
        UIState memory u;
        DoomUI.initialize(u, c, false);
        InputRuntimeState memory i;
        InputProtocol.initialize(i);
        EpisodeState memory e;
        EpisodeRuntime.saveDifficulty(c, e);
        gameState = c.state;
        uiState = u;
        inputRuntime = i;
        episodeState = e;
        initialized = true;
    }

    function measure(uint8 kind) external {
        require(initialized);
        uint256 started = gasleft();
        uint256 length;
        bytes32 digest;
        if (kind == 0) {
            copied.g = gameState;
            copied.u = uiState;
            copied.i = inputRuntime;
            copied.e = episodeState;
        } else if (kind == 1) {
            bytes memory b = abi.encode(gameState, uiState, inputRuntime, episodeState);
            length = b.length;
            digest = sha256(b);
            encoded = b;
        } else if (kind == 2) {
            bytes memory b = P_Saveg.P_Archive(gameState, uiState, inputRuntime, episodeState);
            length = b.length;
            digest = sha256(b);
            packed = b;
        } else if (kind == 3) {
            bytes memory b = P_Saveg.P_Archive(gameState, uiState, inputRuntime, episodeState);
            length = b.length;
            digest = sha256(b);
            immutableSize = length;
            for (uint256 p; p < b.length; p += 16384) {
                uint256 n = b.length - p;
                if (n > 16384) n = 16384;
                bytes memory part = new bytes(n);
                for (uint256 j; j < n; j += 32) {
                    // Both offsets are word-aligned. The last partial word lies
                    // inside each bytes allocation's Solidity-padded final word.
                    assembly ("memory-safe") { mstore(
                        add(add(part, 32), j),
                        mload(add(add(b, 32), add(p, j)))
                    ) }
                }
                immutableChunks.push(address(new ResourceStore(part)));
            }
        } else {
            revert();
        }
        emit Measurement(kind, length, started - gasleft(), digest);
    }

    function restore(uint8 kind) external {
        uint256 started = gasleft();
        if (kind == 0) {
            gameState = copied.g;
            uiState = copied.u;
            inputRuntime = copied.i;
            episodeState = copied.e;
        } else if (kind == 1) {
            (GameState memory g, UIState memory u, InputRuntimeState memory i, EpisodeState memory e) =
                abi.decode(encoded, (GameState, UIState, InputRuntimeState, EpisodeState));
            gameState = g;
            uiState = u;
            inputRuntime = i;
            episodeState = e;
        } else if (kind == 2) {
            P_Saveg.P_UnArchive(gameState, uiState, inputRuntime, episodeState, packed);
        } else if (kind == 3) {
            bytes memory b = new bytes(immutableSize);
            for (uint256 p; p < b.length; p += 16384) {
                uint256 n = b.length - p;
                if (n > 16384) n = 16384;
                address chunk = immutableChunks[p / 16384];
                // Destination p..p+n is inside b; authenticated self-created
                // chunk runtime contains STOP followed by exactly n payload bytes.
                assembly ("memory-safe") { extcodecopy(chunk, add(add(b, 32), p), 1, n) }
            }
            P_Saveg.P_UnArchive(gameState, uiState, inputRuntime, episodeState, b);
        } else {
            revert();
        }
        emit Measurement(kind, 0, started - gasleft(), 0);
    }

    function digest() external returns (bytes32) {
        return sha256(P_Saveg.P_Archive(gameState, uiState, inputRuntime, episodeState));
    }

    function corrupt() external {
        gameState.players[0].health = 7;
        gameState.prndindex = 137;
        gameState.map.sectors[0].floorheight += 65536;
    }
}
