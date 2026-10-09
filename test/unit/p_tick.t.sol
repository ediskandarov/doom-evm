// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {GameContext, ThinkerKind, GameConst} from "../../src/doom/p_game_state.sol";
import {P_Tick} from "../../src/doom/p_tick.sol";

interface VmTick {
    function readFileBinary(string calldata path) external view returns (bytes memory);
}

contract TickTest {
    VmTick constant vm = VmTick(address(uint160(uint256(keccak256("hevm cheat code")))));

    function eventValue(GameContext memory c, uint32 value) private pure {
        c.state.brainTargets[c.state.brainTargetOn++] = value;
    }

    function player(GameContext memory c, uint32 id) private pure {
        eventValue(c, 100 + id);
    }

    function specials(GameContext memory c) private pure {
        eventValue(c, 200);
    }

    function respawn(GameContext memory c) private pure {
        eventValue(c, 201);
    }

    function dispatch(GameContext memory c, uint32 thinkerId) private pure {
        uint32 id = c.state.thinkers[thinkerId].payload;
        eventValue(c, 1000 + id);
        if (id == 1 && c.state.leveltime == 17) {
            P_Tick.P_AddThinker(c.state, ThinkerKind.door, 5);
            P_Tick.P_RemoveThinker(c.state, 4);
        }
        if (id == 1 && c.state.leveltime == 18) {
            c.state.thinkers[2].status = GameConst.THINKER_ACTIVE;
            P_Tick.P_AddThinker(c.state, ThinkerKind.door, 6);
        }
        if (id == 5) P_Tick.P_RemoveThinker(c.state, 5);
    }

    function put(bytes memory b, uint256 offset, uint32 value) private pure returns (uint256) {
        for (uint256 j; j < 4; ++j) {
            b[offset + j] = bytes1(uint8(value >> (24 - j * 8)));
        }
        return offset + 4;
    }

    function snapshot(GameContext memory c, bytes memory b, uint256 offset) private pure returns (uint256) {
        offset = put(b, offset, uint32(c.state.leveltime));
        offset = put(b, offset, c.state.brainTargetOn);
        for (uint32 i; i < c.state.brainTargetOn; ++i) {
            offset = put(b, offset, c.state.brainTargets[i]);
        }
        uint32 count;
        bool[] memory linked = new bool[](c.state.thinkerCount);
        for (uint32 id = c.state.thinkers[0].next; id != 0; id = c.state.thinkers[id].next) {
            ++count;
            linked[id] = true;
        }
        offset = put(b, offset, count);
        for (uint32 id = c.state.thinkers[0].next; id != 0; id = c.state.thinkers[id].next) {
            offset = put(b, offset, id);
            offset = put(b, offset, c.state.thinkers[id].prev);
            offset = put(b, offset, c.state.thinkers[id].next);
            offset = put(b, offset, c.state.thinkers[id].status);
        }
        offset = put(b, offset, c.state.thinkerCount - 1);
        for (uint32 id = 1; id < c.state.thinkerCount; ++id) {
            offset = put(
                b, offset, !linked[id] && c.state.thinkers[id].status == GameConst.THINKER_REMOVE ? 1 : 0
            );
        }
        return offset;
    }

    function testWholeOriginalTickerOrderingAndLiveList() public view {
        bytes memory native = vm.readFileBinary("test/fixtures/phase3_tick/vectors.bin");
        bytes memory actual = new bytes(native.length);
        GameContext memory c;
        P_Tick.P_InitThinkers(c.state);
        c.state.leveltime = 17;
        c.state.playeringame[0] = true;
        c.state.playeringame[2] = true;
        c.state.players[0].viewz = 100;
        c.state.brainTargets = new uint32[](64);
        c.hooks.playerThink = player;
        c.hooks.thinkerDispatch = dispatch;
        c.hooks.updateSpecials = specials;
        c.hooks.respawnSpecials = respawn;
        for (uint32 i = 1; i <= 4; ++i) {
            P_Tick.P_AddThinker(c.state, ThinkerKind.door, i);
        }
        c.state.thinkers[2].status = GameConst.THINKER_STASIS;
        P_Tick.P_RemoveThinker(c.state, 3);
        P_Tick.P_AllocateThinker(c.state, 1);
        uint256 offset = put(actual, 0, 8);
        for (uint32 step; step < 8; ++step) {
            c.state.paused = step == 1;
            c.state.menuactive = step == 2 || step == 3 || step == 4 || step == 6;
            c.state.players[0].viewz = step == 3 ? int32(1) : int32(100);
            c.state.netgame = step == 4;
            c.state.demoplayback = step == 6;
            if (step == 7) c.state.playeringame[2] = false;
            c.state.brainTargetOn = 0;
            P_Tick.P_Ticker(c);
            offset = snapshot(c, actual, offset);
        }
        require(offset == actual.length && keccak256(actual) == keccak256(native), "original p_tick trace");
    }
}
