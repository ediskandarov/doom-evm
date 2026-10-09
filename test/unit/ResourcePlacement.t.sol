// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {StorageResourceFixture, CodeResourceFixture} from "../../src/support/ResourcePlacement.sol";

contract ResourcePlacementTest {
    function testSameBytesAndBounds() public {
        bytes memory payload = new bytes(257);
        for (uint256 i; i < payload.length; ++i) {
            payload[i] = bytes1(uint8(i));
        }
        StorageResourceFixture s = new StorageResourceFixture(payload);
        CodeResourceFixture c = new CodeResourceFixture(payload);
        require(keccak256(s.read(0, 257)) == keccak256(payload));
        require(keccak256(c.read(0, 257)) == keccak256(payload));
        require(keccak256(s.read(31, 33)) == keccak256(c.read(31, 33)));
        require(c.read(257, 0).length == 0 && s.read(257, 0).length == 0);
        (bool ok,) = address(c).call(abi.encodeCall(c.read, (256, 2)));
        require(!ok);
        (ok,) = address(s).call(abi.encodeCall(s.read, (256, 2)));
        require(!ok);
        (ok,) = address(c).call(abi.encodeCall(c.read, (type(uint256).max, 1)));
        require(!ok);
        (ok,) = address(s).call(abi.encodeCall(s.read, (type(uint256).max, 1)));
        require(!ok);
    }

    function testEmptyResource() public {
        StorageResourceFixture s = new StorageResourceFixture(hex"");
        CodeResourceFixture c = new CodeResourceFixture(hex"");
        require(c.read(0, 0).length == 0 && s.read(0, 0).length == 0);
        require(c.source().code.length == 1);
    }
}
