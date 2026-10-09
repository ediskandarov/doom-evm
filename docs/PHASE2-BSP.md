# Phase 2 BSP traversal and clipping

`R_BSP` ports every function in original `linuxdoom-1.10/r_bsp.c` at `a77dfb96cb91780ca334d0d4cfd86957558007e0`. It is the Batch 2B prerequisite for genuine wall drawing; its test callbacks observe wall fragments and sprite requests, without painting substitute pixels. This delivery does not claim a wall frame or complete Phase 2.

## Source behavior and adaptations

- `R_ClearDrawSegs` rewinds the drawseg count and preserves existing slot contents; allocation of the original 256 slots happens only when missing.
- `R_ClearClipSegs` retains the original signed sentinels and two-slot starting list. Existing inactive slots retain their prior contents.
- `R_ClipSolidWallSegment` preserves insertion, adjacency, fragments, extension and **the original counted stale tail in its crunch loop**. The native `while(next++ != newend)` copies the slot at old `newend`, and `newend=start+1` retains that slot in the counted list. Normalizing it away changes original state even where pixels stay identical. C struct copies are explicit field copies, avoiding Solidity memory-reference aliasing.
- `R_ClipPassWallSegment` invokes the same visible fragments without changing the clip list.
- `R_AddLine` preserves angle wrap, backface rejection, view clipping, fencepost projection, single-sided/closed/window classification, and rejection of otherwise identical trigger lines. `curline`, `backsector` and `rw_angle1` update at their original positions. A window uses the subsector's current front sector, exactly as the original globals do.
- `R_CheckBBox` retains all original checkcoord constants, corner decisions, inside-box/sitting-on-line cases, angular clipping and solid-span rejection.
- `R_Subsector` retains floor/ceiling height tests, sky exception, plane lookup, sprite callback, sequential seg calls and subsector count.
- `R_RenderBSPNode` uses an explicit per-traversal memory stack for original recursive **enter → front child → bounding-box check → possible back child → leave** execution. The bounding-box check occurs after front-side clipping updates. This is a C recursion/EVM stack adapter, not a visibility algorithm replacement. Active-path bytes detect cycles while allowing the same DAG node to be visited again after leaving its previous path. Original `-1` and `0x8000` leaf encodings select subsector zero.

Original source functions retain explicit names; callbacks replace `R_StoreWallRange` and `R_AddSprites` cross-module references to avoid circular imports. Integration must connect `R_Segs.R_StoreWallRange`, then the genuine sprite collector. Plane allocation is the integrator's `R_Plane` implementation.

The current clip adapter accepts the frustum-clipped logical range supplied by original `R_AddLine` (`0 <= first <= last < viewwidth`); direct out-of-view calls are rejected, even where the standalone original helper could clip such a span safely. This is an explicit adapter input restriction, not a claim that all out-of-view C inputs are undefined. Malformed children and subsector spans reject before out-of-bounds memory access. More than 32,768 nodes cannot be represented by the original child encoding. More than 32 clip slots and the crunch read at old count 32 reject with `ClipOverflow`: the latter is an original out-of-array read, not defined C to emulate. Tests exercise 1,024-deep valid trees, valid DAG revisits, traversed cycles, both leaf-zero forms, backfaces, closed doors, height-changing and masked windows, empty lines, sky/height plane decisions and independent clip-slot copies. Unvisited unreachable graph errors belong to whole-map validation. No new assembly is used in the production BSP port.

## Original-C proof

[reference.py](../tools/reference/phase2_bsp/reference.py) mechanically extracts original solid/pass/clear clipping functions and records exact source/function hashes. Its **1,045 operation sequence** covers single pixels, full-width spans, adjacent spans, bridge merges, containment, repeated clips and seeded mixed solid/pass sequences. Every emitted wall range and every counted clip-list entry is compared in Solidity. Native O0/O2 and ASan/UBSan **without `-fwrapv`** agree for these defined-domain cases. The scalar clipping oracle contains no ported algorithm.

The existing original full-renderer harness supplies eight `full-angle0` through `full-angle7` ordered traces. Each is bound to the renderer manifest's **case name, mode=full, angle, trace SHA and file SHA** before packing. The fixture records upstream identity and the renderer-manifest hash. Every event at all five hook sites is compared: BSP node entry, subsector entry, solid clip, pass clip and wall-range call.

Production is trace-free. [instrument.py](../tools/reference/phase2_bsp/instrument.py) mechanically derives a test-only copy from the exact current `r_bsp.sol`, inserts five precisely checked entry observations, changes only the library name/import paths, and appends an observation writer. `--check` rejects any stale or modified generated source. Its manifest hashes the source, generator, generated copy and all hooks. The explicit traversal's `_enter` maps to original recursive node entry; `_storeWall` maps to the original cross-module function entry.

The test-only observer writes bytes 0–29999 of an otherwise unused mock framebuffer and uses `fuzzpos` as its byte cursor. Callback observations occupy disjoint framebuffer regions and use counters unused by BSP. These are verification scaffolding, never renderer inputs. For each angle, the uninstrumented production implementation runs first. Then the instrumented copy runs from reset state. Tests compare callback arguments/order, active clip list, current line/sectors/angle scratch, subsector count, plane IDs/count/contents, drawseg count, floor/ceiling clipping, before comparing the complete instrumented trace with native C. Thus full internal traces prove the mechanically instrumented copy, while direct production evidence proves its observable results and state agree. Neither result is presented as direct production instrumentation.

## Commands and costs

```sh
python3 tools/reference/phase2_bsp/reference.py --check
python3 tools/reference/phase2_bsp/instrument.py --check
.toolchain/bin/forge test --match-contract RBspTest -vv
python3 tools/reference/phase2_bsp/measure.py
```

All **16 BSP tests pass**; the complete isolated tree passes **103 Foundry tests** with fuzz seed `0x44` and 256 runs. Every real-map test builds resources through genuine `R_InitDataLazy`, loads through `R_LoadMap`, and prepares the view through `R_Main`. Unit setup installs immutable resource bytes with the explicitly approved Foundry `etch` adapter; ordinary deployment/end-to-end upload remains a separate integration gate. No native trace, projected range, or frame is an input to production rendering.

The isolated high-detail setup region costs about **515.23 million gas** including resources, map and view setup. Actual production BSP plus observation callbacks costs **6.24–46.98 million gas** across the eight angles; it includes plane construction and excludes wall drawing. Entire production+instrumented proof tests cost **554.75–648.21 million gas**, within the configured billion-gas limit. The 1,024-deep tree test costs 10.74 million gas.

[Retained measurements](../test/fixtures/phase2_bsp/costs.json) include source hashes and all eight regions. `allocatorAfter` (12.24–13.84 MB) is the free-memory pointer after **both** traversals plus state and trace verification, not a direct EVM MSIZE measurement or a single production frame footprint. Instrumented gas follows the production run at a higher memory watermark, so its difference cannot be interpreted solely as instrumentation overhead. Full-frame gas, actual memory high-water and resource-read measurements remain integration requirements.
