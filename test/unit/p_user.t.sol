// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {LifecycleOracle} from "./p_mobj.t.sol";

contract PUserLifecycleTest is LifecycleOracle {
    function testNative_P_Thrust() public view {
        runOperation(0);
    }

    function testNative_P_CalcHeight() public view {
        runOperation(1);
    }

    function testNative_P_MovePlayer() public view {
        runOperation(2);
    }

    function testNative_P_DeathThink() public view {
        runOperation(3);
    }

    function testNative_P_PlayerThink() public view {
        runOperation(4);
    }
}
