// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {FrameFixture} from "../../src/support/FrameFixture.sol";

interface FrameVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function prank(address) external;
}

contract FrameEventTest {
    FrameVm private constant vm = FrameVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant FRAME = keccak256("Frame(uint64,uint32,uint16,uint16,bytes)");

    function testCompletePayloadExactlyOneFrameAndSequentialIds() public {
        FrameFixture fixture = new FrameFixture();
        for (uint32 sequence = 1; sequence <= 2; ++sequence) {
            vm.recordLogs();
            fixture.stepAndRender(0, sequence);
            FrameVm.Log[] memory logs = vm.getRecordedLogs();
            require(logs.length == 1, "exactly one log");
            require(logs[0].emitter == address(fixture), "emitter");
            require(logs[0].topics.length == 3 && logs[0].topics[0] == FRAME, "Frame ABI");
            require(uint256(logs[0].topics[1]) == sequence, "frameId");
            require(uint256(logs[0].topics[2]) == sequence, "inputSeq");
            (uint16 width, uint16 height, bytes memory pixels) =
                abi.decode(logs[0].data, (uint16, uint16, bytes));
            require(width == 320 && height == 200 && pixels.length == 64000, "dimensions");
            for (uint256 i; i < pixels.length; ++i) {
                require(uint8(pixels[i]) == uint8((i + sequence) % 256), "all pixels");
            }
            require(fixture.frameId() == sequence && fixture.inputSeq() == sequence, "persistent counters");
        }
    }

    function testInvalidSequenceDriverAndButtonsHaveNoLogsOrStateChange() public {
        FrameFixture fixture = new FrameFixture();
        fixture.stepAndRender(0, 1);
        vm.recordLogs();
        (bool replay,) = address(fixture).call(abi.encodeCall(fixture.stepAndRender, (0, 1)));
        (bool gap,) = address(fixture).call(abi.encodeCall(fixture.stepAndRender, (0, 3)));
        (bool buttons,) = address(fixture).call(abi.encodeCall(fixture.stepAndRender, (1, 2)));
        vm.prank(address(0xBEEF));
        (bool unauthorized,) = address(fixture).call(abi.encodeCall(fixture.stepAndRender, (0, 2)));
        require(!replay && !gap && !buttons && !unauthorized, "must revert");
        require(vm.getRecordedLogs().length == 0, "failed preconditions emit nothing");
        require(fixture.frameId() == 1 && fixture.inputSeq() == 1, "rollback");
    }

    function testRevertAfterFrameRollsBackCounters() public {
        FrameFixture fixture = new FrameFixture();
        (bool ok,) = address(fixture).call(abi.encodeCall(fixture.revertAfterFrame, (1)));
        require(!ok, "intentional revert");
        require(fixture.frameId() == 0 && fixture.inputSeq() == 0, "state rollback after LOG");
        // Foundry recordLogs is an execution trace, not a mined receipt: receipt rollback is tested on Anvil.
        fixture.stepAndRender(0, 1);
        require(fixture.frameId() == 1, "same sequence remains valid");
    }
}
