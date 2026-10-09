// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

/// @custom:source linuxdoom-1.10/m_fixed.c at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @dev See tools/tables/NUMERICS.md for binary64 equivalence and undefined-C policy.
library M_Fixed {
    error FixedDivisionError(int32 a, int32 b);

    function FixedMul(int32 a, int32 b) internal pure returns (int32) {
        // Signed arithmetic shift and explicit narrowing preserve the pinned C profile.
        return int32((int64(a) * int64(b)) >> 16);
    }

    function FixedDiv(int32 a, int32 b) internal pure returns (int32) {
        // abs(INT_MIN) is undefined in original C. Widening defines only that extension.
        int64 absA = a < 0 ? -int64(a) : int64(a);
        int64 absB = b < 0 ? -int64(b) : int64(b);
        if ((absA >> 14) >= absB) return (a ^ b) < 0 ? type(int32).min : type(int32).max;
        return FixedDiv2(a, b);
    }

    function FixedDiv2(int32 a, int32 b) internal pure returns (int32) {
        if (b == 0) revert FixedDivisionError(a, b);
        int64 numerator = int64(a) * 65536;
        int64 denominator = int64(b);
        if (denominator < 0) {
            numerator = -numerator;
            denominator = -denominator;
        }
        // Compare BEFORE truncating: -2147483648 minus a fraction must still error.
        if (numerator >= 2147483648 * denominator || numerator < -2147483648 * denominator) {
            revert FixedDivisionError(a, b);
        }
        // Equivalent to the active upstream binary64 path, NOT its disabled #if 0 branch.
        return int32(numerator / denominator);
    }
}
