# Phase 2B wall rendering

`src/doom/r_segs.sol` ports original `R_StoreWallRange` and `R_RenderSegLoop` from `linuxdoom-1.10/r_segs.c` at `a77dfb96cb91780ca334d0d4cfd86957558007e0`.

The integrated tests execute actual Solidity BSP traversal and its genuine wall callback, resource reads and drawing primitives. No host visibility, projected geometry or native pixels are supplied as renderer inputs. All eight E1M1 ANG45 wall views match the corresponding original C `mode=walls` cases byte for byte over all 64,000 pixels. Every drawseg scalar and active clip/masked-column array, every final floor/ceiling clip entry, and every visplane field/top/bottom byte also match. Tests bind case name, render pass, manifest/reference pixel hashes, camera, dimensions, lighting, map and pinned resource/source identity.

Important source details retained:

- Signed absolute-value conversion for the wrapped angle difference; original `abs(INT_MIN)` inputs explicitly reject.
- Unchecked signed int32 stepping follows the pinned native `-fwrapv` profile; int16 clip/opening/masked-column stores and uint8 visplane stores narrow explicitly.
- Single-column ranges leave both original scalestep fields unchanged. Wall scratch persists between fragments.
- Texture selection uses translation indexes; pegging heights use the original sidedef texture indexes.
- Masked column scratch aliases the current drawseg before count increment. Shared screen-height/minus-one arrays preserve constant clip behavior; independent full-width snapshots replace adjusted interior C pointers.
- Original drawseg exhaustion returns at 256 entries; opening consumption counts original shorts and rejects beyond 320×64.
- Frame-memory linedef `ML_MAPPED` mutation, sky joins, silhouettes, fixed lighting and horizontal/vertical light adjustments remain original.

The production port uses no assembly. Test-only directory loads read allocated fixture words, and allocation probes only read the free-memory pointer. Unit tests etch pinned resource chunks solely for isolated execution; ordinary CREATE/resource-upload and actual-MSIZE measurements pass separately as described below.

```sh
.toolchain/bin/forge test --match-contract RSegsTest -vv
```

The eight full-map wall tests plus 25 synthetic original-C cases and two bounds/capacity tests pass (35 tests). Complete full-map test gas includes fixture setup and bytewise comparisons and remains within the existing 1-billion gas limit. This wall gate does not claim full planes/sprites rendering or Phase 2 completion.

## Synthetic native branch coverage

`tools/reference/phase2_segs/reference.py` reuses the pinned full-renderer builder's original translation units and explicit host adaptations, then mechanically extracts the three original r_segs function bodies. Only the two ported wall functions are invoked; retaining the original masked function satisfies dependency linking. The shared harness is unchanged. An owned host driver initializes synthetic map/view globals and records output; it does not rewrite drawing or geometry algorithms.

All 25 cases produce identical complete output files at O0, O2 and O2 ASan/UBSan under the pinned `-fwrapv` profile. The committed manifest binds extraction positions/hashes, generated source, compiler, WAD, shared builder and owned host/harness. Tests compare full 64,000-byte pixels, all drawsegs/clips/planes, and 33 original scratch/flag/opening fields. The frozen Solidity bool for `segtextured` represents the original integer's truth value: original code assigns a bitwise OR of texture numbers, then uses it only as a condition; the comparison explicitly normalizes only that field.

Cases cover single-sided walls, all pegging combinations, negative offsets, translated texture selection with a different ORIGINAL pegging height (texture1=96 versus translated texture2=128), two-sided tier windows, masked-column bookkeeping, both silhouettes, above/below-eye sectors, both closed-door directions, joined/front-only sky, fixed colormap, light clamps, horizontal/vertical/diagonal lighting and seeded stale scalesteps in a single-column range. Independent invalid cases reject malformed ranges and `abs(INT_MIN)`; drawseg exhaustion preserves the original early return. Opening tests exercise exact 20,480-short exhaustion and the next rejected allocation.

Each synthetic case runs in its own EVM test invocation. Packing several cases into one invocation exceeded the existing gas limit because original setup and monotonic EVM memory allocations accumulated across independent synthetic frames; splitting tests preserves the same per-frame acceptance limit and assertions.

## Ordinary EVM gas and actual memory

```sh
python3 tools/reference/phase2_segs/reference.py --check
.toolchain/bin/forge test --match-contract RSegsTest -vv
node tools/reference/phase2_segs/benchmark.mjs
```

The benchmark checks the pinned canonical bundle identity and all raw resource bytes, ordinarily CREATE-deploys all 1,755 STOP-prefixed chunks, and checks every runtime byte. It ordinarily deploys an unchanged `WallProbe` and a separate measurement copy. The existing source-map instrumentation replaces only GAS instructions inside the explicit `memorySize()` helper with MSIZE; both cost two gas and push one word. Every remaining runtime byte, jump address, operation-gas result, pixel digest and mined transaction gas remains identical. No `etch`/`setCode` is used. A separate literal-MSIZE probe also validates the independent stack-trace decoder at 320 bytes.

| View | BSP + wall gas | Actual memory after walls | Whole transaction gas |
| --- | ---: | ---: | ---: |
| angle0 | 265,055,080 | 15,478,112 | 784,853,746 |
| angle1 | 207,685,149 | 14,497,504 | 727,244,680 |
| angle2 | 80,747,307 | 12,393,216 | 599,791,670 |
| angle3 | 74,948,794 | 12,218,688 | 593,950,906 |
| angle4 | 73,375,230 | 12,142,496 | 592,359,152 |
| angle5 | 77,150,483 | 12,262,496 | 596,164,085 |
| angle6 | 81,898,523 | 12,416,192 | 600,950,088 |
| angle7 | 204,532,352 | 14,492,640 | 724,091,484 |

Resource storage-copy, resource/map/view setup, BSP/wall rendering and final SHA memory boundaries are separate report fields. The setup boundary is 11,291,712 actual touched bytes. All eight ordinary transactions match the original C wall-mode hashes and drawseg/visplane counts. The stage includes genuine resource-access/lookup/composite costs as well as geometry/drawing; it is not a drawing-only microbenchmark.

`test/fixtures/phase2_segs/measurements.json` retains the source/bytecode-bound summary, telemetry patch proof, normal and instrumented receipts, and SHA-256 of the canonical chunk deployment records. Full deployment records are retained in the ignored benchmark output. These numbers bind the Batch2B state layout in the report; subsequent shared-state, plane or sprite changes require fresh measurements before a full-renderer claim.

## Masked-range integration (Batch 2C)

`R_RenderMaskedSegRange` now implements the third original r_segs function through the frozen internal column callback. It preserves current seg/front/back globals, light-row selection, signed scale interpolation, clipping aliases, translated texture height for masked bottom pegging, row offsets, fixed-colormap handling, post-header pointer subtraction, per-column reciprocal scale, MAXSHORT consumption and final scale/x scratch. The for-loop uses `dc_x` itself, including callback mutations before the sentinel write. Empty ranges retain original setup effects without calling the callback. Zero scale and invalid ranges/back-sector/post pointers reject outside the original defined access domain.

Six additional native cases mechanically execute the original masked-range body with an **observation callback** replacing only its `R_DrawMaskedColumn` call. The callback records every passed post-stream byte, the entire selected 256-byte colormap, coordinate/reciprocal/scale/top-screen values and both clip values. One explicit callback-contract test doubles dc_x to prove the caller preserves that side effect; it is not represented as a replacement pixel renderer. Original O0, O2 and ASan/UBSan `-fwrapv` transcripts are byte-identical.

The EVM tests match those observations and final clip/sentinel/global state across complete/repeated ranges, partial then final then empty ranges, pre-consumed columns, fixed lighting, bottom pegging, translated height and diagonal lighting. Pointer equality verifies retained clip-array aliases. Separate bounded fixtures prove the one-byte terminal post with a virtual pixel offset past the allocation is accepted after subtracting three, consumed columns are skipped, and malformed indexes/ranges, absent back sectors and zero scale reject. The suite contains 43 tests. The full world-view integration must supply genuine `R_Things.R_DrawMaskedColumn` and compare original full-frame goldens; callback observation alone does not establish complete masked rendering.

The synthetic native manifest was refreshed for the integrator's added observational plane-snapshot host helper; all 25 preexisting wall fixture files remain byte-identical. The earlier ordinary wall measurement report remains bound to its recorded Batch2B source/context hashes. Full-renderer cost measurements must use the integrated Batch2C sources.
