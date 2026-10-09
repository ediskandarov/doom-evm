// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {M_Fixed} from "../../src/doom/m_fixed.sol";
import {Tables} from "../../src/doom/tables.sol";
import {ReferenceNumericVectors} from "../fixtures/reference/ReferenceNumericVectors.sol";

contract MFixedTest {
    function evaluate(uint8 op, int64 a, int64 b) external pure returns (int64) {
        if (op == 0) return M_Fixed.FixedMul(int32(a), int32(b));
        if (op == 1) return M_Fixed.FixedDiv(int32(a), int32(b));
        if (op == 2) return M_Fixed.FixedDiv2(int32(a), int32(b));
        require(op == 3, "unknown oracle operation");
        return int64(uint64(Tables.SlopeDiv(uint32(uint64(a)), uint32(uint64(b)))));
    }

    function testEveryDefinedOriginalCNumericVector() public view {
        bytes memory packed = ReferenceNumericVectors.data();
        uint256 successes;
        uint256 errors;
        uint256 undefinedRows;
        for (uint256 i; i < ReferenceNumericVectors.count(); ++i) {
            (uint8 op, int64 a, int64 b, int64 expected, uint8 status) =
                ReferenceNumericVectors.vector(packed, i);
            if (status == 2) {
                ++undefinedRows;
                continue;
            }
            try this.evaluate(op, a, b) returns (int64 actual) {
                require(status == 0, "C error accepted by Solidity");
                require(actual == expected, "C numeric mismatch");
                ++successes;
            } catch (bytes memory reason) {
                require(status == 1, "defined C result rejected");
                require(
                    keccak256(reason)
                        == keccak256(
                            abi.encodeWithSelector(M_Fixed.FixedDivisionError.selector, int32(a), int32(b))
                        ),
                    "wrong division error"
                );
                ++errors;
            }
        }
        require(successes > 2500 && errors > 20 && undefinedRows > 20, "incomplete oracle domains");
    }

    function testUndefinedCIntMinMagnitudeExtension() public pure {
        int32 minimum = type(int32).min;
        // Deliberately differs from undefined native abs(INT_MIN), not an equivalence test.
        require(M_Fixed.FixedDiv(minimum, minimum) == 65536);
        require(M_Fixed.FixedDiv(1, minimum) == 0);
        require(M_Fixed.FixedDiv(minimum, 1) == minimum);
        require(M_Fixed.FixedDiv(minimum, -1) == type(int32).max);
        require(M_Fixed.FixedDiv(minimum, 65536) == minimum);
        require(M_Fixed.FixedDiv(type(int32).max, minimum) == -65535);
    }

    function testDirectZeroDivisionIncludesUndefinedNaNExtension() public view {
        for (int32 a = -1; a <= 1; ++a) {
            try this.evaluate(2, a, 0) returns (int64) {
                revert("zero denominator accepted");
            } catch (bytes memory reason) {
                require(
                    keccak256(reason)
                        == keccak256(
                            abi.encodeWithSelector(M_Fixed.FixedDivisionError.selector, a, int32(0))
                        ),
                    "wrong division error"
                );
            }
        }
        // FixedDiv's saturation test catches zero first, including original defined (0,0).
        require(M_Fixed.FixedDiv(0, 0) == type(int32).max);
        require(M_Fixed.FixedDiv(-1, 0) == type(int32).min);
    }

    function testFixedMulArithmeticShiftAndWrapping() public pure {
        require(M_Fixed.FixedMul(-1, 1) == -1);
        require(M_Fixed.FixedMul(type(int32).min, type(int32).min) == 0);
        require(M_Fixed.FixedMul(type(int32).max, 65536) == type(int32).max);
    }

    function testFuzzFixedDiv2ExactRationalRange(int32 a, int32 b) public view {
        if (b == 0) return;
        // Independent widened rational specification verifies range BEFORE truncation.
        int256 n = int256(a) * 65536;
        int256 d = int256(b);
        if (d < 0) {
            n = -n;
            d = -d;
        }
        bool valid = n >= int256(type(int32).min) * d && n < 2147483648 * d;
        try this.evaluate(2, a, b) returns (int64 actual) {
            require(valid && actual == n / d, "rational result/range mismatch");
        } catch (bytes memory reason) {
            require(!valid, "valid rational rejected");
            require(
                keccak256(reason)
                    == keccak256(abi.encodeWithSelector(M_Fixed.FixedDivisionError.selector, a, b)),
                "wrong error"
            );
        }
    }
}
