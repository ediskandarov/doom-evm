// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {GameState, Mobj, Thinker, ThinkerKind, GameConst} from "../../src/doom/p_game_state.sol";
import {P_Heap} from "../../src/doom/p_heap.sol";

contract GameHeapTest {
    function testActorAliasSurvivesNestedSpawnGrowth() public pure {
        GameState memory s;
        uint32 first = P_Heap.allocateMobj(s);
        Mobj memory actor = s.mobjs[first];
        actor.x = 7;
        for (uint32 i; i < 40; ++i) {
            uint32 id = P_Heap.allocateMobj(s);
            s.mobjs[id].target = first;
        }
        actor.x = 42;
        s.mobjs[first].y = -9;
        require(actor.x == s.mobjs[first].x && actor.y == -9, "actor alias after nested pool growth");
        require(s.mobjCount == 41 && s.mobjs.length == 64, "population and capacity");
        for (uint32 i = 1; i < s.mobjCount; ++i) {
            require(s.mobjs[i].target == first, "stable ID");
        }
    }

    function testThinkerAliasSurvivesGrowth() public pure {
        GameState memory s;
        uint32 first = P_Heap.allocateThinker(s);
        Thinker memory node = s.thinkers[first];
        node.kind = ThinkerKind.door;
        for (uint32 i; i < 40; ++i) {
            P_Heap.allocateThinker(s);
        }
        node.status = GameConst.THINKER_STASIS;
        s.thinkers[first].payload = 17;
        require(s.thinkers[first].status == GameConst.THINKER_STASIS && node.payload == 17, "thinker alias");
        require(s.thinkerCount == 41 && s.thinkers.length == 64, "population and capacity");
    }
}
