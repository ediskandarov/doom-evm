# Phase 2A drawing primitives

`src/doom/r_draw.sol` ports the active original `r_draw.c` routines at upstream `a77dfb96cb91780ca334d0d4cfd86957558007e0`. Original file SHA-256: `b19edd950d3d56d2d1d6168677d6345c190f081baa8269bfac3d2f3920a36a96`. This is the drawing-primitives gate, not a complete renderer or Phase 2 acceptance claim.

## Mapping and fidelity

| Original function | Port and verification |
| --- | --- |
| `R_DrawColumn` | Inclusive vertical loop, signed 16.16 accumulation, arithmetic shift and `&127`, source interior offset, original lighting lookup. 17 complete-frame native comparisons. |
| `R_DrawColumnLow` | Doubles `dc_x` **in place**, two physical destinations, same texture sample. 16 native comparisons. |
| `R_DrawTranslatedColumn` | Translation before colormap; deliberately **no** `&127` masking. Signed offset can address bytes before the interior source pointer when still in the source allocation. Four native comparisons. |
| `R_DrawFuzzColumn` | Original 50 signs, colormap six, in-place framebuffer dependency, border adjustments of `dc_yl/dc_yh`, persistent cyclic fuzz position. Eight native comparisons including positions 0/1/24/48/49 and empty clipped columns. |
| `R_DrawSpan` | Inclusive horizontal loop and original `((yfrac>>10)&4032)+((xfrac>>16)&63)` address. 20 native comparisons. |
| `R_DrawSpanLow` | Doubles both endpoint globals **before** deriving count; each resulting iteration writes twice. Preserves original quirky overlong span, including defined cross-row writes within the same physical screen allocation. 20 native comparisons. |
| `R_InitBuffer` | Original physical 320-byte stride, centering and status-bar offset. All lookup entries and offsets checked against native C at five sizes. Does not allocate/change framebuffer, logical dimensions or detail shift. |
| `R_InitTranslationTables` | All 768 output bytes, including unchanged non-green indexes, compared with original C. Solidity allocation supplies bytes rather than a 256-aligned native pointer. |
| `R_VideoErase` | Original same-offset screen copy; whole buffer, final byte, zero and unaligned spans compared. |

Private `_column` and `_span` helpers share the common control flow without changing loop endpoints, sampling, mutations or destination order. `R_FillBackScreen`/`R_DrawViewBorder` are border/UI helpers outside the frozen full-screen M1 primitive scope and remain unported. Disabled `#if 0` unrolled versions are not used.

All 95 fixtures compare SHA-256 over **all 64,000 output bytes**, not sampled pixels; native O0 and O2 outputs also compare every output byte directly. Tests compare the eight observable mutated globals and the complete column/row lookup byte arrays. Native data are deterministic synthetic source, lighting and framebuffer patterns; these are pixel-loop tests, not DOOM frame goldens. Cases include inclusive final pixels, negative texture coordinates/steps, wrapped texture periods, nonzero source offsets, a negative translated offset within its backing allocation, resized views, low-detail side effects and fuzz-position rollover.

## Native oracle and domain audit

`tools/reference/phase2_draw/reference.py` imports the Phase 1 harness's pinned compiler profile and utilities. It mechanically extracts the nine active function bodies and original fuzz-offset initializer from the pinned file. No host drawing algorithm is substituted. Extraction line numbers, body hashes, whole-file hash, generated source hash and harness/adapter hashes are retained in `test/fixtures/phase2_draw/vectors.json`. The compiler is Apple Clang 17.0.0 `(clang-1700.0.13.5)`, `arm64-apple-darwin24.6.0`, with the Phase 1 flags.

One explicit native host adaptation is necessary: the original `R_InitTranslationTables` casts its allocation pointer to 32-bit `int` before aligning it. On this 64-bit host that truncates valid heap pointers. The extractor changes only this alignment expression to use `uintptr_t` and a pointer-width mask. Allocation and every translation-loop statement remain original. Native `Z_Malloc` is a malloc adapter; native screen/source/colormap globals are host arrays. The native driver uses pointers into their actual allocations.

**93 defined-C cases** pass O0/O2 byte equality and AddressSanitizer plus UBSan with `-fwrapv` removed. Arithmetic signed right shift is the pinned implementation behavior. **Two separately labeled `pinned-fwrapv-extension` cases** intentionally overflow column/span accumulators; they agree at O0/O2 with `-fwrapv`, are excluded from defined-C sanitizer claims, and match Solidity's explicit unchecked int32 wrapping. There is no claim that ISO C signed overflow is defined. The unused fuzz `frac` calculation is omitted because it has no observable effect in the defined domain.

The Solidity APIs reject invalid pointers and malformed dimensions with `DrawBounds` rather than reproducing native out-of-bounds behavior. Sixteen independent negative cases cover negative/outside coordinates, short source/lighting/translation buffers, invalid interior pointers, malformed lookup offsets, invalid fuzz position, low-detail physical overrun, inverted spans and erase bounds. Empty ordinary columns return before dereferencing, as in C. Empty spans reject: the original do/while does not safely support them. Supported buffer sizes are physical width 1–320 and height 1–200 at width 320, otherwise height 1–168; actual views are selected by `r_main`.

## Actual EVM cost and memory

`tools/reference/phase2_draw/measure.mjs` starts a temporary Cancun Anvil, ordinarily deploys the compiled test/probe contract, executes each primitive, and decodes stack-only `debug_traceCall` traces. It accounts for every Cancun memory-expanding opcode, including copy source/destination ranges, calls, SHA and return. Zero-length memory ranges do not expand memory. Unexpected nested interpreter frames fail explicitly. A separately deployed 74-byte EVM calibration probe returns actual `MSIZE`: **416 bytes**, equal to the decoder's high-water result. Thus memory evidence measures touched EVM memory, not only the Solidity allocator pointer. No huge per-instruction memory snapshots are requested.

Recorded standalone measurements under solc 0.8.37, viaIR, optimizer 200, Cancun, Anvil 1.8.5:

| Primitive | Pixels written | Draw gas | Actual memory before → after |
| --- | ---: | ---: | ---: |
| Column | 200 | 129,792 | 92,352 → 92,352 bytes |
| Low column | 400 | 170,086 | 92,352 → 92,352 bytes |
| Translated column | 200 | 145,077 | 92,352 → 92,352 bytes |
| Fuzz column | 198 | 169,646 | 94,176 → 94,304 bytes |
| Span | 320 | 176,161 | 92,352 → 92,352 bytes |
| Low span | 318 | 112,524 | 92,352 → 92,352 bytes |

Setup (framebuffer, source patterns, lookup tables and lighting) and final framebuffer SHA are outside the measured primitive gas segment. Gasleft deltas equal opcode-trace gas deltas. The fuzz sign literal advances the free-memory pointer by 96 bytes but touches 128 additional bytes through compiler temporary/padding operations; this distinction is retained in the report. Final full-frame SHA encoding expands whole-call high-water to 156,384 bytes (158,304 for fuzz), also separately reported. These are synthetic primitive costs and must not be represented as whole-renderer performance. Source hashes and deployed-bytecode hash bind the retained `test/fixtures/phase2_draw/evm-measurements.json`; integration changes to shared state require fresh measurements.

The production library uses no assembly. Test-only assembly reads exact in-bounds fixture words or copies allocated pattern bytes with `MCOPY`; every copy length is bounded by both source and destination allocations. Free-pointer reads are read-only. No assembly writes outside allocated byte buffers.

## Reproduction

```sh
python3 tools/reference/phase2_draw/reference.py --check
.toolchain/bin/forge test --match-contract RDrawTest -vv
node tools/reference/phase2_draw/measure.mjs
```

The generator without `--check` deliberately regenerates the committed native fixtures. Normal verification uses `--check` and fails on any drift. The benchmark writes ignored `artifacts/local/phase2-draw-measurements.json` by default and accepts an explicit output path; it requires permission to bind localhost. All 11 drawing tests pass, including all 95 native cases and bounds/cost tests. The integrator must run the unchanged Phase 0/Phase 1 gates and remaining Phase 2 acceptance gates before claiming Phase 2 completion.
