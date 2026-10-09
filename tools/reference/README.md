# Original C reference bench

The oracle compiles the pinned DOOM algorithms, without a replacement math or BSP implementation. It is a Phase 1 foundation: **there are no renderer goldens yet**.

From the repository root, after installing the pinned local toolchain and downloading the pinned Freedoom archive with `tools/wad`:

```sh
python3 tools/reference/reference.py --check --wad artifacts/local/freedoom/freedoom-0.13.0/freedoom1.wad
python3 tools/reference/test_reference.py
```

Omit `--check` only to intentionally regenerate reviewable fixtures. Without `--wad`, the check covers numeric, synthetic geometry, native tables and undefined-domain audits; the complete Phase 1 gate must supply the WAD to cover real E1M1 geometry and camera configuration. No network access or third-party Python package is needed. Builds live in automatically removed temporary directories. Compilation requires the explicit Apple clang 17 profile in `reference.py`; a different host/compiler must receive a separately reviewed profile rather than silently updating results.

## What is actually compiled

`reference.py` asserts the upstream commit and SHA-256 of `m_fixed.c`, `r_main.c`, `tables.c`, `m_fixed.h` and `tables.h`. It mechanically extracts complete named function definitions with their original signatures, bodies, comments, and preprocessor branches. `extraction-manifest.json` records exact inclusive line spans and hashes. The functions are `FixedMul`, `FixedDiv`, `FixedDiv2`, `R_PointOnSide`, `R_PointToAngle`, `R_PointToAngle2`, and `R_PointInSubsector`. `tables.c` is compiled as an entire original translation unit, supplying `SlopeDiv` and every original table constant. The generated unit hash, source-set hash, harness hash and shim hash are recorded.

`compat.h` supplies the standalone host includes, exact-width assumptions and minimal node/subsector globals needed by these functions. It does not include unused engine structures. Relevant node fields have their original types; no host struct is deserialized from disk. `I_Error` is intercepted with `longjmp`, yielding an `error` row. The trace adapter uses a macro around the unchanged `R_PointInSubsector` function to observe its calls to the unchanged `R_PointOnSide`; it records node indexes and then the raw high-bit subsector child. A traversal-length guard rejects malformed cycles. The one-subsector/no-node special case is explicitly tested.

The WAD adapter decodes original little-endian NODES records and validates every child and cycle before C traversal. Converting signed int16 coordinates to 16.16 uses multiplication by 65536, avoiding the original loader's undefined left shift of negative numbers. This is a host input adapter, not a changed geometry algorithm. It does not compute visibility or render pixels. The retained E1M1 fixture includes the player start, origin, first 128 vertices, and 256 seeded points spread over the entire vertex bounding box (772 rows: subsector and full BSP path for each point). The supplied camera uses the actual spawn sector floor/ceiling, `VIEWHEIGHT=41`, zero bob, original angle quantization, and a fixed 320×200 high-detail configuration. It records that no renderer golden exists.

## Numerical coverage and C domains

3,276 numeric rows cover edge-value Cartesian products, deterministic random int32/uint32 inputs, `FixedDiv` saturation threshold neighbors, `FixedDiv2` range/truncation neighbors, negative right shifts and narrowing, denominator zero, and unsigned wrapping in `SlopeDiv(num << 3)`. 581 synthetic geometry rows cover axes, all octants, coincident points, partition equality and signs, seeded points, and a known BSP partition.

Each defined row is run through separately compiled O0 and O2 executables. A third build removes `-fwrapv`, enables UBSan including float-to-int overflow, and must produce identical outputs without diagnostics. Thus the selected geometry vectors do not quietly rely on signed-overflow extension behavior. The primary ABI asserts 32-bit int, 64-bit long long, binary64 and arithmetic right shift; signed narrowing remains implementation-defined and pinned to the measured compiler. Native binaries independently dump every original table word; `native-table-hashes.json` can be compared with the Solidity table manifest.

`FixedDiv2` retains the original **double** expression; its disabled `#if 0` integer branch is never substituted in the oracle. Nonzero/zero yields infinity and reaches original `I_Error`; zero/zero reaches a NaN-to-int conversion and is undefined. `FixedDiv` invokes `abs(INT_MIN)`, which is undefined even though observed results happen to repeat in this profile. These inputs have no successful oracle outputs. `undefined-audit.json` separately records raw O0/O2 observations and actual sanitizer failures in the extracted original functions. A separate negation audit checks the `abs` representability domain; it is explicitly not the algorithm oracle.

The approved Solidity widened-magnitude handling of `INT_MIN` is a deterministic extension, not native-C equivalence. Native observations here are: `FixedDiv(INT_MIN,1)` reaches `I_Error`; `FixedDiv(1,INT_MIN)` returns `INT_MIN`; `FixedDiv(INT_MIN,INT_MIN)` returns `INT_MAX`; and direct `FixedDiv2(0,0)` returns zero. **None is a portable C result.**

`ReferenceNumericVectors.sol` contains exactly the JSON rows as packed bytes for tests without FFI. `data()` allocates once; `vector(data,index)` decodes `(op,a,b,expected,status)` using int64 to accommodate unsigned slope inputs. Operations 0–3 are FixedMul/FixedDiv/FixedDiv2/SlopeDiv. Status 0 is success, 1 original I_Error, 2 undefined. Non-success expected fields are padding only. Generated Solidity is formatted with pinned Forge. `validate_vectors` adds signature, domain, status, scope and trace semantics to generic JSON-schema checking.

## Golden infrastructure, ready for a later renderer

`pixel_diff.py record` accepts an existing `reference-v0` metadata document and actual pixel bytes, verifies schema, identities, dimensions and frame hash, then records both without replacing an existing directory. It never manufactures a rendered image. `compare` requires expected and actual metadata, enforces equal resource/camera/render settings and map/upstream provenance (builds may differ), verifies each hash and length, and reports exact mismatch count and every `(x,y,expected,actual)` index. Exit status 1 means mismatching pixels; invalid dimensions/settings/hash are errors.

```sh
python3 tools/reference/pixel_diff.py record --pixels path/to/pixels.bin --reference path/to/reference.json --output path/to/new-golden
python3 tools/reference/pixel_diff.py compare --expected path/to/expected.bin --reference path/to/expected-reference.json --actual path/to/actual.bin --actual-reference path/to/actual-reference.json
```

These commands are templates for later renderer fixtures. The twelve infrastructure tests exercise exact mismatch coordinates, dimensions, hash and settings rejection, synthetic-scope protection, recording and CLI exit status, vector semantic mutations, native edge results, empty BSP traversal, and the 32,768-node root-index boundary. Phase 1 never labels a synthetic transport pattern as an original-renderer golden.
