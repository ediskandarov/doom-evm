// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

/// @notice Minimal per-frame memory context. Extended only by the integrator before dependent ports.
/// @custom:source linuxdoom-1.10/r_state.h, r_main.c globals at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @dev Solidity memory-to-memory assignment aliases this struct and its byte buffer.
struct RenderState {
    int32 viewx;
    int32 viewy;
    int32 viewz;
    uint32 viewangle;
    uint16 width;
    uint16 height;
    bytes framebuffer;
}
