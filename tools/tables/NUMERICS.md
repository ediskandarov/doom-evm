# Original DOOM numeric foundation

Source: pinned `linuxdoom-1.10/m_fixed.c`, `m_fixed.h`, `tables.c` and
`tables.h`. The Solidity file and function names retain their C mapping.
No renderer or Phase 2 geometry is implemented here.

`FixedMul` widens both operands to signed 64 bits, multiplies, shifts right
arithmetically by 16, and explicitly narrows to 32 bits. Products fit int64.
Negative right shift and out-of-range signed narrowing are implementation-defined
C behavior; this port matches the pinned Apple Clang profile (arithmetic shift,
low 32 bits), which the native oracle checks. Solidity never performs an
overflowing int32 multiplication here.

`FixedDiv` preserves the saturation test, sign decision, and call to `FixedDiv2`.
The sole extension is the magnitude of `INT_MIN`: C `abs(INT_MIN)` is undefined.
The integrator explicitly approved mathematical magnitude 2147483648 in a widened
int64 intermediate. Tests for those operands are extension tests, not C-equivalence
claims. The reference metadata retains separate original-profile observations.
Original defined inputs, including `(0,0)` returning MAXINT from the saturation
branch, retain original control flow.

## Why integer division equals the active C binary64 branch

This is a domain proof, not an assumption that the disabled upstream `#if 0`
integer implementation is equivalent. For int32 `a`, nonzero int32 `b`, let
`N = a * 65536`. Both C conversions to double are exact. Binary64 division is
correctly rounded to nearest, ties to even in the frozen native profile. All
nonzero intermediates are normal and finite: the smallest absolute ratio is
at least 2^-31; the greatest is 2^31. Multiplication by 2^16 shifts the exponent
exactly, without underflow or overflow. Thus the C expression is the correctly
rounded binary64 representation of `N/b`.

`|N| <= 2^47`, so its rounding error is at most
`|N/b| * 2^-53 <= 1/(64*|b|)`. For a noninteger rational `N/b`, its distance to
every integer is at least `1/|b|`. Rounding therefore cannot reach or cross an
integer boundary. If `N/b` is an in-range integer, that int32 is exactly
representable in binary64. Consequently truncation toward zero gives exactly
signed integer division throughout the valid range. The same distance argument
preserves the comparisons against the exactly representable bounds -2^31 and
+2^31, including invalid values near a bound. Large out-of-range quotients
remain clearly outside, even where their integer part is not representable.

The Solidity code normalizes the denominator sign, compares the exact rational
numerator against both scaled bounds **before** truncating, then divides. All
these intermediates fit int64 (bound products are at most 2^62). The negative
bound is inclusive, positive bound exclusive, exactly as C. In particular a
negative fraction below INT_MIN errors even if its integer truncation would
be INT_MIN. Direct division by zero errors explicitly. C nonzero/zero reaches
`I_Error`; C `0/0` reaches an undefined NaN-to-int conversion and receives the
same deterministic Solidity error without claiming C equivalence.

## Tables

Run `python3 tools/tables/generate.py --write` to generate; run without arguments
to verify. The generator requires the exact source SHA, parses only literal
integer initializers, compiles the complete original `tables.c` with the native
profile flags, emits all 16,385 words from native C, and compares every byte.
No trigonometric function or floating-point table generator is used.

`manifest.json` hashes all words as little-endian uint32, including signed
two's-complement patterns. `finecosine` is exactly the 8,192-word sine slice
starting at 2,048. Foundry iterates **every** valid Solidity lookup and hashes
its little-endian result against those native-checked digests. Invalid indices
revert explicitly. The first sine sample being 25 rather than zero is intentional.

Generated Solidity keeps the words in 256-entry big-endian byte chunks and
extracts the requested word using a single memory-safe read. This preserves the
pure frozen API with bounded memory allocation per call (up to 1 KiB), avoiding
a whole-table allocation. Internal pure calls still advance caller memory; a
renderer must measure that behavior before choosing its adapter. No placement
performance claim is made here. `SlopeDiv` preserves the unsigned 32-bit
left-shift wrap, denominator cutoff, and saturation in original order.
