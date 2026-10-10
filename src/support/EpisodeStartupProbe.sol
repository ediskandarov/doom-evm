// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {EpisodeStartup} from "../evm/EpisodeStartup.sol";
import {WadResources} from "../evm/WadResources.sol";
import {ResourceView} from "../doom/r_data_types.sol";
import {GameState, GameContext} from "../doom/p_game_state.sol";
import {GameflowState} from "../doom/g_game.sol";
import {EpisodeStartupSnapshot as Snapshot} from "./EpisodeStartupSnapshot.sol";

/// @notice Comparison-only ordinary-EVM startup/storage host. No tics or transitions.
contract EpisodeStartupProbe is WadResources {
    error NotDriver();
    error AlreadyInitialized();
    error InjectedPostSetupFailure();
    address public immutable driver = msg.sender;
    bool public initialized;
    GameState private saved;
    GameflowState private flowState;
    bytes private difficultyState;
    bytes32[5] public digests;

    event StartupProof(
        int32 indexed map, bytes32 world, bytes32 collision, bytes32 zone, bytes32 flow, bytes32 difficulty
    );

    constructor(address[] memory chunks, bytes memory directory) WadResources(chunks, directory) {}

    function initialize(int32 episode, int32 map, int32 skill, bool nomonsters, bool deterministic) external {
        guard();
        run(_resourceView(), episode, map, skill, nomonsters, deterministic);
    }

    /// @dev Deliberate test-only corruption/failure routes; no native expected data accepted.
    function initializeFault(uint32 fault) external {
        guard();
        require(fault >= 1 && fault <= 5, "fault domain");
        ResourceView memory source = _resourceView();
        if (fault == 1) source.identity.wadSha256 = bytes32(uint256(source.identity.wadSha256) ^ 1);
        else if (fault == 2) ++source.lumps[15].offset;
        else if (fault == 3) (source.chunks[0], source.chunks[1]) = (source.chunks[1], source.chunks[0]);
        else if (fault == 4) source.chunks[1754] = address(0);
        run(source, 1, 2, 2, false, true);
        revert InjectedPostSetupFailure();
    }

    function guard() private view {
        if (msg.sender != driver) revert NotDriver();
        if (initialized) revert AlreadyInitialized();
    }

    function run(
        ResourceView memory source,
        int32 episode,
        int32 map,
        int32 skill,
        bool nomonsters,
        bool deterministic
    ) private {
        (GameContext memory c, GameflowState memory f) =
            EpisodeStartup.initialize(source, episode, map, skill, nomonsters, deterministic);
        bytes memory difficulty = Snapshot.difficulty(c);
        digests = [
            sha256(Snapshot.observe(c.state)),
            sha256(Snapshot.collision(c.state)),
            sha256(Snapshot.zone(c.state.nativeZone)),
            sha256(Snapshot.flow(c.state, f)),
            sha256(difficulty)
        ];
        saved = c.state;
        flowState = f;
        difficultyState = difficulty;
        initialized = true;
        emit StartupProof(map, digests[0], digests[1], digests[2], digests[3], digests[4]);
    }

    function status()
        external
        view
        returns (
            int32 episode,
            int32 map,
            int32 skill,
            uint64 gametic,
            int32 leveltime,
            uint32 actors,
            uint32 thinkers,
            uint32 sectors,
            bool deterministic,
            bool complete
        )
    {
        return (
            saved.gameepisode,
            saved.gamemap,
            saved.gameskill,
            saved.gametic,
            saved.leveltime,
            saved.mobjCount,
            saved.thinkerCount - (initialized ? 1 : 0),
            uint32(saved.sectors.length),
            saved.nativeZone.deterministicInitialization,
            flowState.initialized
        );
    }

    /// @dev Observe the actual persisted typed world, not only its initial memory digest.
    function persistedDigests() external view returns (bytes32[5] memory result) {
        require(initialized, "not initialized");
        GameState memory s = saved;
        GameflowState memory f = flowState;
        result = [
            sha256(Snapshot.observe(s)),
            sha256(Snapshot.collision(s)),
            sha256(Snapshot.zone(s.nativeZone)),
            sha256(Snapshot.flow(s, f)),
            sha256(difficultyState)
        ];
    }
}
