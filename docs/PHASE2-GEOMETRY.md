# Phase 2 geometry port

`src/doom/r_main.sol` implements the frozen Batch 2A geometry and setup API. This is a prerequisite, **not completion of Phase 2**: no BSP renderer, wall frame, planes, sprites or final M1 claim belongs to this delivery.

## Original source mapping

All mappings refer to unmodified `id-Software/DOOM` commit `a77dfb96cb91780ca334d0d4cfd86957558007e0`, `linuxdoom-1.10/r_main.c`. Original source/function hashes and extraction line ranges are retained in [the native manifest](../test/fixtures/phase2_geometry/manifest.json).

| Port function | Original mapping and adaptation |
| --- | --- |
| `R_PointOnSide` | Same axis branches, sign shortcut and truncated fixed multiplies |
| `R_PointOnSegSide` | Same vertex differences and partition calculation; delegates identical calculation through a temporary `Node` |
| `R_PointToAngle` / `R_PointToAngle2` | Same octants, one-unit fenceposts and `SlopeDiv`; explicit angle wrapping; `Angle2` still mutates view origin |
| `R_PointToDist` | Same absolute differences, swap, fixed slope and table-driven hypotenuse |
| `R_ScaleFromGlobalAngle` | Same **signed** fine-angle indices, fixed multiplies, division threshold and 256/64-FRACUNIT clamps |
| `R_PointInSubsector` | Same last-node root and raw child encoding; explicit malformed-child/cycle checks |
| `R_InitTextureMapping` | Same tangent projection, repeated lowest-index inverse scan and fencepost handling; original final-loop dead `t` assignments removed |
| `R_InitLightTables` | Same 16×128 light-level calculation; pointers become colormap indexes |
| `R_ExecuteSetViewSize` | Original menu-supported blocks 3–11, detail 0/1; centers/projection, psprite scales, screen heights, slopes, distance scales and 16×48 lights |
| `R_SetupFrame` | Camera/player values passed directly; native view angle offset is already included in supplied angle; trig/light state, frame/valid counts and subsector count retained |

`R_ExecuteSetViewSize` calls the integrated `R_Draw.R_InitBuffer`; the temporary freeze adapter has been removed. Original draw function-pointer selection is represented by `detailshift` and later explicit dispatcher calls. Original fixed light pointer selection is represented by `fixedcolormap != -1`; its 48-entry array is preserved. Initialize `validcount=1` in the eventual renderer lifecycle, matching the original global initializer. Counter increment wraps uint32; signed C overflow is a compiler-profile extension after its positive domain.

## Oracle and domains

The extension [reference.py](../tools/reference/phase2_geometry/reference.py) imports Phase 1's compiler/source pin checks and build harness, then mechanically extracts additional original bodies. It compiles original `tables.c` whole. Host shims supply globals, trivial ABI structures, screen storage, and inert draw-function addresses; none replaces a tested numerical algorithm. Every native output records exact upstream, source, shim and generator hashes.

- All **581 existing synthetic** and **772 existing E1M1** rows are consumed by the Solidity tests. Every recorded BSP node and leaf in `BSPPath` is compared, not only the final subsector. E1M1 native node bytes are transported unchanged, then decoded with signed LE16×65536 semantics.
- **1,027 additional scalar rows** cover segment sides, distances, global-angle scale and frame setup. All match native O0/O2 and full undefined-behavior/float-cast sanitizers.
- Every supported **18 blocks/detail configuration** has a canonical big-endian uint32 SHA-256 of every observable setup array and scalar: dimensions, centers/projection, window offsets, clip angle, psprite scales, viewangletox, xtoviewangle, yslope, distscale, columnofs, ylookup offsets, screenheightarray, scalelight and zlight. Solidity compares all words through the same serialization. Native O0/O2 outputs agree.
- The existing compiler profile is Apple Clang 17.0.0, arm64-apple-darwin24.6.0, C99/O2/`-fwrapv`/no fast math. Other platforms are deliberately not silently certified.

Explicit boundaries:

1. Original `R_PointToDist(viewx,viewy)` calls `FixedDiv(0,0)`, then reads `tantoangle[67108863]`: undefined native memory access. Solidity rejects it with `UndefinedGeometry`.
2. Original `abs(INT_MIN)` and negative `INT_MIN` in angle octant normalization are undefined. Solidity rejects these geometry inputs. No such case is labeled original-C equality.
3. Original subtraction overflow follows the pinned `-fwrapv` profile; Solidity uses explicit unchecked int32 wrap. Equality of existing fixtures is checked in the non-overflow defined domain.
4. `R_ScaleFromGlobalAngle` stores angle expressions in signed `int`, then performs arithmetic shifts. A negative value gives an invalid original sine index. Solidity rejects it, rather than changing it into a valid unsigned sine lookup. Intended visible wall angles and both positive sines are covered; malformed detail shifts are rejected. Signed-shift wrap outside valid renderer setup values is only an extension, not a defined-C claim.
5. Original view setup performs a negative signed left shift in its `yslope` loop. [The separate audit](../test/fixtures/phase2_geometry/undefined-audit.json) retains the exact UBSan failure. The port uses multiplication by 65536, with representable results for supported view sizes. View configurations agree with the pinned O0/O2 original executable; all remaining sanitizer checks stay enabled (`-fno-sanitize=shift-base` only for this classified view path). They are **compiler-profile equivalence**, not falsely labeled ISO-C-defined execution.
6. View sizes outside original menu-supported blocks 3–11 and detail 0/1 are rejected. Setup accepts 34 available colormap indexes, with `-1` replacing original NULL. Index 0 explicitly selects colormap 0 in this adapter; original player field 0 maps to -1 in native comparison.
7. Invalid BSP children, traversed cycles, missing subsectors and more than 32,768 nodes reject. Zero nodes selects the first subsector as in C. A valid root index 32,767 must remain usable. Unvisited malformed graph branches belong to whole-map validation; this function validates its actual traversal.

No new assembly exists in the geometry implementation. The initial isolated build used the Phase 1 aligned-word table loader; integrated Phase 2 now uses [verified scalar packed-word access](PHASE2-TABLES.md) with the same original integers and API. No trigonometry is regenerated. The only test assembly reads Solidity's free-memory pointer for allocation telemetry.

## Verification and cost

Run from repository root:

```sh
python3 tools/reference/phase2_geometry/reference.py --check
.toolchain/bin/forge test --match-contract RMainTest --fuzz-seed 0x44 -vv
```

The isolated branch passes all **57 Foundry tests**, including **24 geometry tests** and the **33 existing tests** (fuzz seed `0x44`, 256 runs). The 32,768-node and 32,769-node boundary cases allocate real nested arrays and pass under the configured billion-gas test limit.

The existing full Phase 0 and Phase 1 gates remain required at integration; this extension changes none of their fixtures, scripts or source functions.

For full-screen high detail, the measured setup region (`R_InitLightTables` and `R_ExecuteSetViewSize`) consumes **179,632,219 gas**, with free-memory pointer **1,312 → 4,853,632 bytes** in the initial isolated build. The enclosing test costs 194,884,169 gas because it also serializes and verifies all output words. This allocation marker is **not a direct MSIZE/high-water measurement**; the integrator's execution probe must supply actual EVM memory measurements. Measurements can move with combined compiler inlining/code layout and must be refreshed in final evidence.

The first implementation deliberately retains the original repeated inverse-table search and Phase 1 per-lookup table chunks. These allocate roughly 4.8 MB during setup and have a measurable cost. Source-equivalent optimizations can be assessed against the complete native array oracle; this document does not claim acceptable full-frame cost from a setup-only measurement. Resource-read and complete-renderer costs are separate integration gates.
