// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {M_Random} from "../../src/doom/m_random.sol";
import {GameState} from "../../src/doom/p_game_state.sol";

interface VmRandom {
    function readFileBinary(string calldata path) external view returns (bytes memory);
}

contract RandomTest {
    VmRandom constant vm = VmRandom(address(uint160(uint256(keccak256("hevm cheat code")))));

    function word(bytes memory b, uint256 o) private pure returns (uint32 v) {
        for (uint256 j; j < 4; ++j) {
            v = (v << 8) | uint8(b[o + j]);
        }
    }

    function testOriginalIndependentStreamsWrapAndClear() public view {
        bytes memory rows = vm.readFileBinary("test/fixtures/gameplay_info/random.bin");
        GameState memory s;
        M_Random.M_ClearRandom(s);
        require(s.prndindex == 0 && s.rndindex == 0, "clear");
        for (uint256 i; i < word(rows, 0); ++i) {
            int32 p = M_Random.P_Random(s);
            require(s.prndindex == word(rows, 4 + i * 16) && uint32(p) == word(rows, 8 + i * 16), "P_Random");
            if (i % 3 != 0) M_Random.M_RandomValue(s);
            int32 m = M_Random.M_RandomValue(s);
            require(s.rndindex == word(rows, 12 + i * 16) && uint32(m) == word(rows, 16 + i * 16), "M_Random");
            if (i == 511) M_Random.M_ClearRandom(s);
        }
    }
}
