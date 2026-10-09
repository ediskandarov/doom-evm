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
    int32 viewcos;
    int32 viewsin;
    int32 centerx;
    int32 centery;
    int32 centerxfrac;
    int32 centeryfrac;
    int32 projection;
    uint8 detailshift;
    uint16 scaledviewwidth;
    int32 viewwindowx;
    int32 viewwindowy;
    uint32[] ylookup;
    uint32[] columnofs;
    int32[] viewangletox;
    uint32[] xtoviewangle;
    uint32 clipangle;
    int32[] yslope;
    int32[] distscale;
    bytes scalelight; // 16 * 48 colormap indexes, not pointers
    bytes zlight; // 16 * 128 colormap indexes
    int32 extralight;
    int32 fixedcolormap; // -1 is NULL; otherwise a colormap index
    uint32 fuzzpos;
    int32 pspritescale;
    int32 pspriteiscale;
    int32[] screenheightarray;
    bytes scalelightfixed;
    uint32 framecount;
    uint32 validcount;
    uint32 sscount;
}

/// @notice Original dc_* globals passed by memory reference, including original side effects.
struct DrawColumn {
    int32 x;
    int32 yl;
    int32 yh;
    int32 iscale;
    int32 texturemid;
    bytes source;
    uint32 sourceOffset;
    bytes colormap; // precisely 256 palette indexes
    bytes translation; // translated column only
}

struct DrawSpan {
    int32 y;
    int32 x1;
    int32 x2;
    int32 xfrac;
    int32 yfrac;
    int32 xstep;
    int32 ystep;
    bytes source; // 4096-byte flat
    bytes colormap;
}
