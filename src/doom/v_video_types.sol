// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

/// @custom:source linuxdoom-1.10/v_video.h, v_video.c globals at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @dev Memory references replace C pointers. Screen 0 may alias RenderState.framebuffer.
/// V_Init allocates screens 0..3; screen 4 is supplied by its consumer (ST_Init uses 320*32).
struct VideoState {
    bytes[5] screens;
    int32[4] dirtybox; // BOXTOP, BOXBOTTOM, BOXLEFT, BOXRIGHT
}
