// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;

/// @custom:source linuxdoom-1.10/m_bbox.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
library M_BBox {
    function M_ClearBox(int32[4] memory box) internal pure {
        box[0] = type(int32).min;
        box[3] = type(int32).min;
        box[1] = type(int32).max;
        box[2] = type(int32).max;
    }

    function M_AddToBox(int32[4] memory box, int32 x, int32 y) internal pure {
        // Retain original else-if: the first point does not update both bounds.
        if (x < box[2]) box[2] = x;
        else if (x > box[3]) box[3] = x;
        if (y < box[1]) box[1] = y;
        else if (y > box[0]) box[0] = y;
    }
}
