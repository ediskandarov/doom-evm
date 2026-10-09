// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {P_Info} from "../../src/doom/p_info.sol";
import {GameDefinitions} from "../../src/doom/p_game_state.sol";

interface VmGameInfo {
    function readFileBinary(string calldata path) external view returns (bytes memory);
}

contract GameInfoTest {
    VmGameInfo constant vm = VmGameInfo(address(uint160(uint256(keccak256("hevm cheat code")))));

    function write(bytes memory dst, uint256 offset, uint32 value) private pure {
        for (uint256 j; j < 4; ++j) {
            dst[offset + j] = bytes1(uint8(value >> (24 - j * 8)));
        }
    }

    function row(bytes memory dst, uint256 offset, bytes memory encoded) private pure {
        require(encoded.length % 32 == 0, "static field encoding");
        for (uint256 j; j < encoded.length / 32; ++j) {
            uint256 value;
            assembly ("memory-safe") {
                value := mload(add(add(encoded, 32), mul(j, 32)))
            }
            write(dst, offset + j * 4, uint32(value));
        }
    }

    function testEveryOriginalStateActorAndWeaponField() public view {
        GameDefinitions memory data = P_Info.load();
        bytes memory native = vm.readFileBinary("test/fixtures/gameplay_info/tables.bin");
        bytes memory actual = new bytes(12 + data.states.length * 28 + data.mobjinfo.length * 92 + 9 * 24);
        write(actual, 0, uint32(data.states.length));
        write(actual, 4, uint32(data.mobjinfo.length));
        write(actual, 8, 9);
        uint256 offset = 12;
        for (uint256 i; i < data.states.length; ++i) {
            row(actual, offset, abi.encode(data.states[i]));
            offset += 28;
        }
        for (uint256 i; i < data.mobjinfo.length; ++i) {
            row(actual, offset, abi.encode(data.mobjinfo[i]));
            offset += 92;
        }
        for (uint256 i; i < 9; ++i) {
            row(actual, offset, abi.encode(data.weaponinfo[i]));
            offset += 24;
        }
        require(actual.length == native.length && keccak256(actual) == keccak256(native), "original tables");
    }
}
