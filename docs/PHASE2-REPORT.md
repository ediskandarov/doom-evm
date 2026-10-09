# Phase 2 — renderer work in progress

Phase 2 is **not complete**. The acceptance scope is implementation-plan section 5 in full: geometry/resources/drawing, BSP and textured walls, floors/ceilings and sprites, integrated static world-view rendering, original-C comparison, and Frame-event-to-browser delivery. Gameplay is Phase 3.

## Acceptance ledger

| Requirement | Current evidence | Status |
| --- | --- | --- |
| Freeze geometry, render-state and resource-access interfaces before parallel ports | `80c7506`, reviewed amendments in [PHASE2-INTERFACES.md](PHASE2-INTERFACES.md) | Passed |
| Parallel independent r_main/r_data/r_draw workstreams in isolated worktrees | Geometry `9f698b1`, drawing `9085eb6`, resources `f24e090` | Integrated |
| Geometry numerical equivalence and bounds | 2,380 C scalar/path vectors; all arrays for 18 original view configurations; [geometry report](PHASE2-GEOMETRY.md) | Passed; final regression still required |
| Resource addressing, lookups and original column semantics | 963 lookup tables, 853 sprite metadata records, 338 composites, 2,889 native column comparisons, complete represented E1M1 map fields; [data report](PHASE2-DATA.md) | Passed, including native/EVM signed-short boundary corrections; final regression still required |
| Indexed8 columns/spans and bounds | 95 original-C cases, including 93 defined cases and two explicit profile extensions; [drawing report](PHASE2-DRAW.md) | Passed; final regression still required |
| Native full renderer goldens | 16 wall/full cases across eight spawn headings, exact pixels and intermediate clipping state, O0/O2/sanitizer/allocation-fill agreement | Native reference passed; not EVM rendering evidence |
| BSP traversal/clipping, front/back and NF_SUBSECTOR | Eight native ordered traces, 1,120 clipping operations, deep trees and DAG/cycle tests; all 16 BSP tests and both native/instrumentation checks pass on the integrated tree | Passed; final regression pending |
| Textured wall pipeline and exact C wall pixels | All eight real EVM wall scenes match all 64,000 pixels and every drawseg/clipping/visplane record; 25 synthetic wall cases and six masked callback cases; eight ordinary wall measurements with equal normal/MSIZE outputs and gas | Passed; final regression pending |
| Visplanes/floors/ceilings, lighting and sky | All eight native wall+plane snapshots, 117 original-C synthetic vectors and 16 module tests; integrated full-frame pixels pass | Passed; final regression pending |
| Masked walls, sprite projection/sorting/clipping | Original sprite definitions, 209 static spawns, all eight projections/sorts, native pixel edge cases and masked callback proofs; integrated full-frame pixels pass | Passed; final regression pending |
| R_RenderPlayerView orchestration and thin Doom adapter | Genuine original pass sequence wired through DoomRenderer; all eight full native frames match all 64,000 bytes; authenticated concrete Doom emits the frozen Frame ABI | Full renderer unit gate passed; ordinary contract/event/browser gate pending |
| Actual EVM memory, gas and resource-access costs | Drawing opcode traces calibrated against literal MSIZE; ordinary-deployment resource benchmark verifies all 1,755 runtimes and six resource operations, with actual MSIZE and equal normal/instrumented transaction gas | Resource evidence integrated; final source refresh and full-frame measurement missing |
| Production resource identity | `WadResources` authenticates every ordered chunk and packed directory; six unit tests plus ordinary CREATE/runtime verification and mined corruption rejections; [source report](PHASE2-SOURCE.md) | Passed on authenticated probe; final Doom deployment pending |
| All Phase 0 and Phase 1 gates preserved | All 211 integrated Foundry tests pass, including eight complete EVM frames; existing acceptance assertions retained | Full final regression run missing |
| Ordinary Anvil deployment and one genuine Frame event per render | Complete EVM pixels verified in integration tests; ordinary production Frame receipt evidence pending | Not achieved |
| Browser displays transaction pixels; exact reference diff and screenshot | Native reference images exist; real renderer browser gate pending | Not achieved |
| Function-by-function C mapping, deviations and completion audit | [Porting map](../PORTING.md), module reports and explicit native adaptations reviewed; independent production assembly bounds audit found no unsafe blocks | Final acceptance audit pending |

## Native reference scope

The original full renderer executes in a separately compiled native host; see [its README](../tools/reference/renderer/README.md) and [fixture manifest](../test/fixtures/renderer/manifest.json). The selected scene is the existing pinned Freedoom E1M1 player start at stationary floor+41 camera height, high detail, full-screen 320x200, tic zero. Eight ANG45 headings cover different visibility. Medium-skill single-player world things use original spawn-state rendering fields. No player weapon overlay, HUD, gameplay action or tick is supplied. The final claim will be a complete static **world view** for this declared scene, not an implemented game or every DOOM feature.

The native host records LP64 disk/pointer adaptations, signed-C profile limits and a strict UBSan failure instead of claiming universal ISO C semantics. Original arrays' deliberate visplane sentinel pad access is expressed through the enclosing byte object without changing byte addresses. Goldens include exact pixels, BSP/range traces, clipping arrays, drawseg records and visplane records. Every EVM verifier must bind the manifest case and `mode`; matching generic reference-v0 metadata alone cannot distinguish wall-only from full passes. M1 requires `full`.

## Measurements guiding integration

Initial eager resource initialization cost roughly 894 million gas, before exact-name indexing. A later isolated snapshot measured roughly 540 million gas for eager initialization and 53 million for lazy initialization. Lazy lookup generation executes the same original function on first texture access. Per-frame lump caching preserves original cache reuse. All original texture/composite output comparisons remain required. Static translation arrays were subsequently added for wall integration, so these historical isolated metrics do not describe the final source.

Initial full-screen geometry setup cost roughly 180 million gas and advanced the allocator to 4.85 MB. That snapshot used allocation-based table accessors. The original repeated inverse scans remain, but current table lookups use stack constants. The complete combined frame may cost more than the sum of isolated regions because EVM memory expansion is quadratic; no full-frame feasibility claim follows from the historical figures.

Integration subsequently replaced temporary per-lookup table allocations with generated scalar packed-word switches, preserving all original integers and numerical fixtures. At that checkpoint 149 integrated tests passed; ordinary wall probes used 391–443 million transaction gas and 6.79–7.94 MB after walls. [The table-access report](PHASE2-TABLES.md) retains source-bound measurements and the unchanged all-index proof. The current 211-test suite also passes. Full-frame ordinary costs remain unverified.

The drawing benchmark measures actual interpreter memory expansion using stack-only opcode traces and validates its decoder against an ordinarily deployed literal-MSIZE probe. Resource and full-frame telemetry must likewise distinguish allocator positions from actual EVM memory. Ordinary resource deployment is mandatory for end-to-end evidence; unit tests' fixture-only `vm.etch` shortcut does not satisfy that gate.
