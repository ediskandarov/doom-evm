// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {AutomapFixture} from "./AutomapFixture.sol";
import {IFrameProtocol} from "../evm/FrameProtocol.sol";

/// Dedicated verification probe; no production adapter modifications.
contract AutomapProbe is IFrameProtocol {
    uint64 public frameId;
    event AutomapEvidence(bytes stateHashes, bytes frameHashes);

    function render(bytes memory geometryAndActions, bytes[10] memory markerPatches, uint32 sequence)
        external
    {
        (bytes memory sh, bytes memory fh, bytes memory pixels) =
            AutomapFixture.replay(geometryAndActions, markerPatches);
        emit AutomapEvidence(sh, fh);
        emit Frame(++frameId, sequence, 320, 200, pixels);
    }
}
