// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {LifecycleOracle} from "./p_mobj.t.sol";

contract GGameLifecycleTest is LifecycleOracle {
    function testNative_G_PlayerReborn() public view {
        runOperation(21);
    }

    function testNative_G_ExitLevel() public view {
        runOperation(22);
    }

    function testNative_G_SecretExitLevel() public view {
        runOperation(23);
    }
}
