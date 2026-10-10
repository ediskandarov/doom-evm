// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {WiState, WiInput, WiGraphics} from "../doom/wi_stuff_types.sol";
import {WI_Stuff as WI} from "../doom/wi_stuff.sol";
import {VideoState} from "../doom/v_video_types.sol";
import {ResourceView} from "../doom/r_data_types.sol";
import {IntermissionFixture as F} from "./IntermissionFixture.sol";
import {IFrameProtocol} from "../evm/FrameProtocol.sol";

/// @notice Dedicated verification host, never production Gameflow or Episode Runtime.
/// Script inputs and borrowed named resources drive genuine EVM WI state and pixels.
contract IntermissionProbe is IFrameProtocol {
    address public immutable driver = msg.sender;
    ResourceView internal source;
    WiState internal wi;
    WiInput internal controls;
    bytes internal pixels;
    uint64 public frameId;
    uint32 public inputSeq;
    event IntermissionSnapshots(bytes snapshots);
    error InvalidProbeCall();

    constructor(ResourceView memory resources) {
        source = resources;
    }

    function _authorize(uint32 sequence) private view {
        if (msg.sender != driver || inputSeq == type(uint32).max || sequence != inputSeq + 1) {
            revert InvalidProbeCall();
        }
    }

    function run(bytes memory data, uint32 sequence) external {
        _authorize(sequence);
        WiState memory s;
        WiInput memory p;
        WiGraphics memory a;
        VideoState memory v;
        F.start(data, s, p, a, v, source);
        int32 count = F.word(data, 64);
        if (count < 0 || count > 1000 || data.length != 68 + uint32(count) * 20) revert InvalidProbeCall();
        bytes memory snapshots = new bytes((uint32(count) + 1) * 128);
        F.capture(snapshots, 0, s, p, v);
        for (uint256 i; i < uint32(count); ++i) {
            int32[5] memory q;
            for (uint256 j; j < 5; ++j) {
                q[j] = F.word(data, 68 + i * 20 + j * 4);
            }
            F.action(q, s, p, a, v, source);
            F.capture(snapshots, i + 1, s, p, v);
        }
        wi = s;
        controls = p;
        pixels = v.screens[0];
        wiDirty = v.dirtybox;
        inputSeq = sequence;
        emit IntermissionSnapshots(snapshots);
        emit Frame(++frameId, sequence, 320, 200, v.screens[0]);
    }

    function begin(bytes memory header, uint32 sequence) external {
        _authorize(sequence);
        WiState memory s;
        WiInput memory p;
        WiGraphics memory a;
        VideoState memory v;
        F.start(header, s, p, a, v, source);
        wi = s;
        controls = p;
        pixels = v.screens[0];
        wiDirty = v.dirtybox;
        inputSeq = sequence;
        bytes memory snapshots = new bytes(128);
        F.capture(snapshots, 0, s, p, v);
        emit IntermissionSnapshots(snapshots);
    }

    function act(int32[5] memory command, uint32 sequence, bool emitFrame) external {
        _authorize(sequence);
        if (!wi.started) revert InvalidProbeCall();
        WiState memory s = wi;
        WiInput memory p = controls;
        WiGraphics memory a;
        VideoState memory v;
        v.screens[0] = pixels;
        v.screens[1] = new bytes(64000);
        // Pinned background covers every pixel. Rebinding does not restart WI or consume RNG.
        WI.WI_loadData(a, v, source);
        // Previous draws always marked the full screen; retain the original dirty history.
        // Before any draw, the original box remains M_ClearBox's sentinel values.
        v.dirtybox = wiDirty;
        F.action(command, s, p, a, v, source);
        wi = s;
        controls = p;
        pixels = v.screens[0];
        wiDirty = v.dirtybox;
        inputSeq = sequence;
        bytes memory snapshots = new bytes(128);
        F.capture(snapshots, 0, s, p, v);
        emit IntermissionSnapshots(snapshots);
        if (emitFrame) emit Frame(++frameId, sequence, 320, 200, v.screens[0]);
    }

    int32[4] internal wiDirty;

    function snapshot() external view returns (bytes memory, bytes32) {
        return (F.stateBytes(wi, controls), sha256(pixels));
    }
}
