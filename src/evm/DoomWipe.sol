// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {F_Wipe, WipeState} from "../doom/f_wipe.sol";
import {VideoState} from "../doom/v_video_types.sol";

/// @dev Transaction adapter for D_Display's blocking melt. No second wipe algorithm.
abstract contract DoomWipe {
    error WipeInProgress();
    error WipeUnavailable();
    error WipeBadSequence();
    error WipeNotDriver();

    bool private wipesEnabled;
    bool private wiping;
    uint32 private wipeStep;
    int32 private displayedState = 3; // D_Display: GS_DEMOSCREEN
    int32 private fromState;
    bytes private displayedScreen;
    WipeState private wipe;

    /// @notice Additive protocol v1; old contracts have no such method.
    function wipeStatus()
        external
        view
        returns (uint32 version, bool enabled, bool active, uint32 progress, int32 from, int32 to)
    {
        return (1, wipesEnabled, wiping, wipeStep, fromState, displayedState);
    }

    /// @notice Explicit browser opt-in; legacy controllers keep their existing display path.
    function enableMeltWipe() external {
        if (msg.sender != _wipeDriver()) revert WipeNotDriver();
        wipesEnabled = true;
    }

    /// @notice One original presentation tic, no G_Ticker, renderer or menu ticker.
    function stepWipe(uint32 sequence) external {
        if (msg.sender != _wipeDriver()) revert WipeNotDriver();
        uint32 previous = _wipeSequence();
        if (previous == type(uint32).max || sequence != previous + 1) revert WipeBadSequence();
        if (!wiping) revert WipeUnavailable();
        _wipePublish(sequence, _advanceWipe());
    }

    function _requireNoWipe() internal view {
        if (wiping) revert WipeInProgress();
    }

    function _meltEnabled() internal view returns (bool) {
        return wipesEnabled;
    }

    /// @dev Exact EVM snapshot controls retain their instantaneous cached-frame contract.
    function _restoreWipeDisplay(bytes memory screen, int32 state) internal {
        _requireNoWipe();
        if (!wipesEnabled) return;
        displayedState = state;
        displayedScreen = screen;
    }

    function _displayWipe(bytes memory target, int32 state, bool force, uint32 random)
        internal
        returns (bytes memory pixels)
    {
        _requireNoWipe();
        bool transition =
            wipesEnabled && displayedScreen.length == 64000 && (state != displayedState || force);
        fromState = displayedState;
        displayedState = state;
        if (!transition) {
            // Save only when opted in: legacy paths retain their resource costs.
            if (wipesEnabled) displayedScreen = target;
            return target;
        }
        WipeState memory w;
        w.rndindex = random;
        VideoState memory v;
        v.screens[0] = displayedScreen;
        F_Wipe.wipe_StartScreen(w, v);
        v.screens[0] = target;
        F_Wipe.wipe_EndScreen(w, v);
        wipe = w;
        wipeStep = 0;
        wiping = true;
        // D_Display's first visible update is the first melt step, not the endpoint.
        return _advanceWipe();
    }

    function _advanceWipe() private returns (bytes memory pixels) {
        WipeState memory w = wipe;
        VideoState memory v;
        bool done = F_Wipe.wipe_ScreenWipe(w, v, 1);
        pixels = v.screens[0];
        // Original D_Display redraws the frozen menu over every wipe update.
        _wipeOverlay(pixels);
        _wipeCommitRandom(w.rndindex);
        ++wipeStep;
        wiping = !done;
        if (done) {
            displayedScreen = pixels;
            delete wipe;
        } else {
            wipe = w;
        }
    }

    function _wipeDriver() internal view virtual returns (address);
    function _wipeSequence() internal view virtual returns (uint32);
    function _wipeCommitRandom(uint32 random) internal virtual;
    function _wipeOverlay(bytes memory pixels) internal view virtual;
    function _wipePublish(uint32 sequence, bytes memory pixels) internal virtual;
}
