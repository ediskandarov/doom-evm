# Phase 0 stack-pressure experiment

This is a **synthetic shape spike, not a renderer, an `r_segs` port, or evidence of C/pixel equivalence**. The source reference is `original/DOOM/linuxdoom-1.10/r_segs.c:R_StoreWallRange`, pinned at `a77dfb96cb91780ca334d0d4cfd86957558007e0`. The eventual port still belongs in `src/doom/r_segs.sol`; no implementation has been added there.

## Reproduction and measured result

From the repository root with the pinned project toolchain installed:

```sh
python3 scripts/stack-pressure.py
.toolchain/bin/forge test --match-contract StackPressureTest --fuzz-seed 0x44 -vv
.toolchain/bin/forge fmt --check src/support/StackPressure.sol test/unit/StackPressure.t.sol
```

Compiler: `0.8.37+commit.f401782d.Darwin.appleclang`; Foundry: `1.8.5`. Both compiler pipelines use optimizer enabled, 200 runs, Cancun. The Python driver compiles only this contract from identical source using standard JSON and changes only `viaIR`; it checks diagnostic severity because solc can exit 0 with a compiler error. The script writes fresh measurements and source SHA-256 to `artifacts/local/stack/stack-compile.json` and full diagnostics to `stack-via-ir.log` / `stack-legacy.log` there. The recorded baseline is retained under `artifacts/phase0/`.

| Pipeline | Observed compile wall time | Initcode / runtime | Result |
|---|---:|---:|---|
| via-IR + optimizer | 156.778 ms | 4,196 / 4,170 bytes | Compiles without diagnostics |
| legacy + optimizer | 12.507 ms | No bytecode | `Stack too deep` |

Times are a single local macOS arm64 observation, including compiler process startup; they are not a cross-machine benchmark. Re-running refreshes the JSON artifact. The legacy diagnostic points at the one-sided/two-sided texture branch. No assembly, helper decomposition for stack relief, or locals-to-scratch rewrite was needed under the selected baseline. The input `Scene` and output `Trace` structures model dependency/context boundaries from the outset, as required by the architecture.

Foundry tests deploy the spike via `new StackPressure()` and execute the branches, including a full 320-column masked case. Nine tests pass, including 256 deterministic fuzz runs; output is retained in `artifacts/phase0/stack-tests.log`. No deployment, EVM stack, or memory exception occurred in these cases. The contract is below ordinary runtime/initcode limits; this experiment does not establish limits for the future inlined engine or measure host peak memory. Separate Phase 0 Anvil probes validate relaxed limits.

## How the shape maps to C

| Upstream portion of `R_StoreWallRange` | Spike behavior |
|---|---|
| drawseg capacity and range check | Early return at capacity, explicit range rejection |
| normal/distance/endpoint scale setup | Live angle, distance, sine, endpoint and scale-step values with stubbed geometry |
| one-sided wall | Middle texture, floor/ceiling marks, bottom pegging, silhouette |
| two-sided wall | Height silhouettes, closed doors, joined sky, upper/lower pegging, masked allocation |
| textured offset and wall lights | Offset/sine dependency, light orientation and clamp branches |
| invisible planes and edge preparation | View-plane suppression; top/bottom/high/low stepping values |
| `R_CheckPlane` / `R_RenderSegLoop` calls | Plane check counter; column recurrence consumes texture/scale/light values in a checksum |
| sprite clip storage | Abstract opening counts and masked silhouette completion |

The function retains the ordering of these stages and keeps numerous live scalar intermediates (`hyp`, angles, sine, world heights, scale, texture IDs, marks, edge values), so the compiler must handle meaningful liveness across branches and the loop. It is more than an artificial list of unrelated arguments. The tests assert exact synthetic trace outcomes and recurrences rather than merely asserting a call succeeds.

## Deliberate differences and limits

- Standalone support contract and local `Scene`/`Trace` types isolate the spike from frozen engine interfaces. Several C globals are local variables to stress compiler liveness; the trace carries observable outputs.
- Bounded synthetic test inputs use checked `int256` arithmetic. This is **not** `fixed_t`, `angle_t`, C overflow, `FixedMul`, or trig fidelity. The `MulStub` is plain multiplication and must not migrate into `m_fixed.sol`.
- Geometry, sine, scale, texture heights and plane lookup are explicitly named stubs. There are no WAD resources, texture lookup, drawsegs, clipping arrays, actual visplanes, pointers, framebuffer, or game state.
- Sector comparisons omit floor/ceiling texture IDs and light identity. Angles use toy degrees; sky is a single flag. Silhouette heights and closed-door clip pointer short-circuits are omitted. Opening counts are abstract and must not be read as exact C allocations.
- The render-loop dependency only consumes state and increments edges; it does not execute original clipping, light tables, or draw pixels. A checksum makes the calculations observable, but is not a C reference hash.
- The capacity check does not allocate/increment an actual drawseg. Full-width tests validate this synthetic loop, not BSP recursion or the EVM's full stack capacity.
- Assembly usage: none. C comparison: intentionally not applicable until real ports and pinned C fixtures exist in Phase 1 and renderer phases.

## Decision

Keep the frozen optimizer/via-IR/Cancun settings. Legacy compilation demonstrably fails on this representative structure; via-IR removes the immediate compiler blocker. Keep ordinary locals when beginning the real port, put original frame globals in the agreed render context, and measure again as real dependencies replace stubs. Only on a reproduced via-IR failure reduce live ranges, then introduce a documented function-specific memory scratch structure, then consider same-module helpers. This experiment gives no reason to scatter the original function across modules or introduce Yul now.
