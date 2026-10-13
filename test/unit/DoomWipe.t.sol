// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {DoomWipe} from "../../src/evm/DoomWipe.sol";

contract DisplayWipeHost is DoomWipe {
    address private owner = msg.sender;
    uint32 public sequence;
    uint32 public random;
    uint32 public tics;
    bytes public pixels;

    function display(bytes memory screen, int32 state, bool force) external {
        _requireNoWipe();
        ++tics;
        ++sequence;
        pixels = _displayWipe(screen, state, force, random);
    }

    function _wipeDriver() internal view override returns (address) {
        return owner;
    }

    function _wipeSequence() internal view override returns (uint32) {
        return sequence;
    }

    function _wipeCommitRandom(uint32 r) internal override {
        random = r;
    }
    function _wipeOverlay(bytes memory) internal pure override {}

    function _wipePublish(uint32 seq, bytes memory screen) internal override {
        sequence = seq;
        pixels = screen;
    }

    function rejectAfterWipe(uint32 seq) external {
        this.stepWipe(seq); // Host owner can be set to itself for this explicit rollback proof.
        revert("rollback");
    }

    function ownSelf() external {
        owner = address(this);
    }
}

contract DoomWipeTest {
    function testOriginalLevelIntermissionFinaleMatrix() external {
        _matrix(3, [int32(0), 1, 0, 2], 4);
    }

    function testOriginalCommercialAndForcedFinaleMatrix() external {
        _matrix(1, [int32(2), 2, 0, 3], 1);
    }

    function _matrix(int32 initial, int32[4] memory states, uint256 forced) private {
        DisplayWipeHost h = new DisplayWipeHost();
        (bytes memory a, bytes memory b) = screens();
        h.enableMeltWipe();
        h.display(a, initial, false);
        for (uint256 i; i < states.length; ++i) {
            h.display(b, states[i], i == forced);
            (,, bool active,,,) = h.wipeStatus();
            require(active, "original state or forced transition starts wipe");
            uint32 count;
            while (active) {
                h.stepWipe(h.sequence() + 1);
                (,, active,,,) = h.wipeStatus();
                require(++count < 100, "bounded completion");
            }
            require(sha256(h.pixels()) == sha256(b), "matrix exact endpoint");
        }
        require(h.tics() == 5, "only initiating displays advance world");
    }

    function screens() private pure returns (bytes memory a, bytes memory b) {
        a = new bytes(64000);
        b = new bytes(64000);
        for (uint256 i; i < 64000; ++i) {
            a[i] = bytes1(uint8(i));
            b[i] = bytes1(uint8(i + 73));
        }
    }

    function testOptInPersistentProgressFinalAndFrozenTics() external {
        DisplayWipeHost h = new DisplayWipeHost();
        (bytes memory a, bytes memory b) = screens();
        h.enableMeltWipe();
        h.display(a, 3, false);
        h.display(b, 0, false);
        (, bool enabled, bool active, uint32 progress, int32 from, int32 to) = h.wipeStatus();
        require(enabled && active && progress == 1 && from == 3 && to == 0, "initial transition");
        require(h.random() == 64, "320 original M_Random calls");
        uint32 count = 1;
        while (active) {
            h.stepWipe(h.sequence() + 1);
            ++count;
            (,, active, progress,,) = h.wipeStatus();
            require(progress == count && count < 100, "persistent deterministic progress");
            require(h.tics() == 2 && h.random() == 64, "presentation freezes world and RNG");
        }
        require(sha256(h.pixels()) == sha256(b), "exact target frame");
        h.display(a, 0, false);
        (,, active,,,) = h.wipeStatus();
        require(!active, "same state has no wipe");
        h.display(b, 0, true);
        (,, active,,,) = h.wipeStatus();
        require(active, "forced level reload");
    }

    function testLegacyNoOptInAndNoPreviousScreen() external {
        DisplayWipeHost h = new DisplayWipeHost();
        (bytes memory a, bytes memory b) = screens();
        h.display(a, 3, false);
        h.display(b, 0, true);
        (,, bool active,,,) = h.wipeStatus();
        require(!active && h.random() == 0, "legacy unchanged");
        h.enableMeltWipe();
        h.display(a, 0, true);
        (,, active,,,) = h.wipeStatus();
        require(!active, "no invented initial framebuffer");
    }

    function testRollbackDuplicateAndRacingInput() external {
        DisplayWipeHost h = new DisplayWipeHost();
        (bytes memory a, bytes memory b) = screens();
        h.enableMeltWipe();
        h.display(a, 3, false);
        h.display(b, 1, false);
        h.stepWipe(3);
        bytes32 before = sha256(h.pixels());
        (bool ok,) = address(h).call(abi.encodeCall(h.stepWipe, (3)));
        require(!ok && h.sequence() == 3 && sha256(h.pixels()) == before, "duplicate rejected");
        (ok,) = address(h).call(abi.encodeCall(h.display, (a, 0, false)));
        require(!ok && h.tics() == 2, "racing gameplay rejected");
        h.ownSelf();
        (ok,) = address(h).call(abi.encodeCall(h.rejectAfterWipe, (4)));
        require(!ok && h.sequence() == 3 && sha256(h.pixels()) == before, "all progress rolled back");
    }
}
