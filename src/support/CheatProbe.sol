// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {GameContext, Player, Mobj} from "../doom/p_game_state.sol";
import {GameflowState} from "../doom/g_game.sol";
import {CheatState, ST_Cheats} from "../doom/st_cheats.sol";
import {CheatFixture} from "./CheatFixture.sol";

/// @dev Ordinary-EVM probe for raw-key processing across storage round-trips.
/// This owns no engine/resource/browser ABI and is not the production input adapter.
contract CheatProbe {
    CheatState private cheats;
    GameflowState private flow;
    Player[4] private players;
    Mobj[] private actors;
    int32[8] private config;
    int32 private gameaction;
    uint32 public inputSeq;
    event Observation(uint32 indexed sequence, uint32 indexed eventIndex, bytes32 snapshotSha256);

    function reset(int32[8] calldata cfg) external {
        GameContext memory c = CheatFixture.fresh(cfg);
        CheatState memory s;
        ST_Cheats.initialize(s);
        GameflowState memory f;
        cheats = s;
        flow = f;
        players = c.state.players;
        actors = c.state.mobjs;
        config = cfg;
        gameaction = 0;
        inputSeq = 0;
    }

    function load() private view returns (GameContext memory c) {
        c.state.players = players;
        c.state.mobjs = actors;
        c.state.gamemode = config[0];
        c.state.netgame = config[1] != 0;
        c.state.gameskill = config[2];
        c.state.consoleplayer = config[3];
        c.state.gameaction = gameaction;
    }

    function observe() external view returns (bytes32) {
        return sha256(CheatFixture.snapshot(load(), flow, cheats));
    }

    function rawEvents(uint32 sequence, int32[4][] calldata events, bool revertAfter) external {
        require(sequence == inputSeq + 1, "sequence");
        GameContext memory c = load();
        CheatState memory s = cheats;
        GameflowState memory f = flow;
        for (uint32 i; i < events.length; ++i) {
            int32[4] memory e = events[i];
            require(e[0] >= 0 && e[0] <= 3, "event type");
            ST_Cheats.ST_Responder(c, f, s, uint8(uint32(e[0])), e[1]);
            ST_Cheats.AM_CheckCheat(s, uint8(uint32(e[0])), e[1], e[2] != 0, e[3]);
            emit Observation(sequence, i, sha256(CheatFixture.snapshot(c, f, s)));
        }
        cheats = s;
        flow = f;
        players = c.state.players;
        actors = c.state.mobjs;
        gameaction = c.state.gameaction;
        inputSeq = sequence;
        require(!revertAfter, "downstream revert");
    }
}
