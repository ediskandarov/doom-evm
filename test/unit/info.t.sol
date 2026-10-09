// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {Info, InfoData} from "../../src/doom/info.sol";

interface InfoVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
}

contract InfoTest {
    InfoVm constant vm = InfoVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testAllOriginalNativeRenderingFields() public view {
        InfoData memory data = Info.load();
        bytes memory packed = abi.encodePacked(
            Info.NUMSPRITES, Info.NUMSTATES, Info.NUMMOBJTYPES, data.spriteNames, data.states, data.mobjInfo
        );
        require(
            sha256(packed) == sha256(vm.readFileBinary("test/fixtures/info/tables.bin")),
            "original info.c fields"
        );
        for (uint32 i; i < Info.NUMSTATES; ++i) {
            require(Info.word(data.states, uint256(i) * 8) < Info.NUMSPRITES, "state sprite domain");
        }
        for (uint32 i; i < Info.NUMMOBJTYPES; ++i) {
            require(Info.word(data.mobjInfo, uint256(i) * 20 + 4) < Info.NUMSTATES, "spawn state domain");
        }
    }
}
