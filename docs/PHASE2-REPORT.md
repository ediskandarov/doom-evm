# Phase 2 — complete static renderer

**Phase 2 is accepted, 2026-10-09.** All implementation-plan section 5 requirements are verified for the declared static E1M1 world view. Gameplay remains Phase 3.

The frozen integrated run at `82e24e1c3f742a528dbbd63bdfb16e2d0d585774` passed all **24 Phase 2 commands**, documentation presence, all **13 Phase 1 gates**, all **12 Phase 0 gates**, and **196 Solidity tests in 18 suites**. Sources and the pristine pinned upstream were checked before and after each command. The run took 570.048 seconds. See the [complete summary](../artifacts/phase2/final-verification/summary.json), [test log](../artifacts/phase2/final-verification/foundry-tests.log), and [evidence index](../artifacts/phase2/README.md).

Completion documentation was reconciled after the successful run. [The final audit](../artifacts/phase2/final-audit.json) proves that only the named documentation files changed; implementation, tests, tools, fixtures, schemas and compiler settings remain byte-identical to the passing snapshot. Archived evidence preserves its original hashes and paths.

## Acceptance ledger

| Requirement | Authoritative evidence | Result |
| --- | --- | --- |
| Freeze interfaces before parallel geometry/resources/drawing | `80c7506`, reviewed 2B/2C amendments in [interfaces](PHASE2-INTERFACES.md); isolated workstreams integrated as `9f698b1`, `f24e090`, `9085eb6` | Passed |
| Geometry numerical equivalence and bounds | 2,380 original-C vectors, every setup array for 18 original view configurations; [mapping and domains](PHASE2-GEOMETRY.md); fresh native and Forge gates | Passed |
| Resource addressing and original column semantics | 963 lookup tables, 853 sprite metadata records, 338 composites, 2,889 column comparisons and E1M1 map fields; [data report](PHASE2-DATA.md); fresh ordinary access measurements | Passed |
| Indexed8 columns/spans and bounds | 95 original-C cases, including 93 defined cases and two explicit profile extensions; [draw report](PHASE2-DRAW.md); calibrated memory traces | Passed |
| BSP order/clipping/front-back/NF_SUBSECTOR | Eight ordered native traces, 1,120 clipping operations, deep trees and DAG/cycle cases; [BSP report](PHASE2-BSP.md) | Passed |
| Textured walls and intermediate Frame | Eight exact wall images and intermediate records, 25 synthetic wall cases, six masked callback cases; [wall report](PHASE2-SEGS.md); ordinary wall-only Frame receipt and zero diff | Passed |
| Visplanes/floors/ceilings/sky | Eight native plane-stage images, 117 original-C cases and 16 module tests; [plane report](PHASE2-PLANES.md) | Passed |
| Masked walls and sprites | Original definitions, 209 static spawns, eight projection/sort results, clipping/translation/fuzz/active-psprite edge images; [sprite report](PHASE2-SPRITES.md) | Passed |
| Original R_RenderPlayerView orchestration | Original setup/clear/BSP/plane/masked sequence through internal callbacks; sequence test and eight bytewise full-frame tests | Passed |
| Complete static native comparison | Eight `mode=full` EVM views, each matching all 64,000 bytes; native O0/O2/sanitizer/allocation-fill agreement; [fresh images and diffs](../artifacts/phase2/final-verification/renderer.frames/) | Passed; zero differences |
| Ordinary resource and production deployment | All 1,755 STOP-prefixed runtimes exact; authenticated directory and ordered runtime commitment; actual Doom runtime and driver verified; [deployment report](PHASE2-E2E.md) | Passed |
| Genuine production Frame delivery | stepAndRender and renderFrame each emit one sequential Frame; WS payload equals receipt; four mined invalid-input rejections have no logs/counter changes; [raw receipts](../artifacts/phase2/final-verification/renderer.receipts/) | Passed |
| Browser displays transaction pixels | Real WAD palette, WS delivery, receipt fallback and deduplication; final Canvas readback matches every receipt pixel; [browser evidence](../artifacts/phase2/final-verification/renderer.browser.json) and [screenshot](../artifacts/phase2/final-verification/renderer.browser.png) | Passed |
| Actual gas, EVM memory and resource costs | Fresh calibrated drawing/resource/source/wall/full measurements; normal and instrumented outputs and gas equal; [full measurements](../artifacts/phase2/final-verification/renderer.json) | Passed |
| Preserve all Phase 0/1 gates | Archived [Phase 0](../artifacts/phase2/final-verification/inherited-phase0/summary.json) and [Phase 1](../artifacts/phase2/final-verification/inherited-phase1/summary.json), every command passed | Passed |
| Source mapping, deviations and assembly audit | [PORTING.md](../PORTING.md), linked function-level reports, independent review of production memory bounds, native adapters and scope | Passed |

The inherited acceptance assertions are intact. The Phase 0 forced-build timeout increased from 180 to 600 seconds because a successful integrated compile took 207 seconds. No test or runtime gate was removed.

## Scene and fidelity boundary

The target is pinned Freedoom 0.13.0 E1M1, player-one start, stationary floor+41 camera clamped to ceiling−4, medium-skill single-player spawn states, tic zero, full-screen 320×200 and high detail. Eight ANG45 headings exercise different visibility. Walls, floors, ceilings, sky, masked textures and world sprites are included. The separate probe exercises all eight headings; production Doom renders the original angle-zero view. No native visibility, projection or pixel data is supplied as renderer input.

The reference scene has no active weapon/HUD overlay. Original active-psprite drawing has separate C pixel tests; gameplay actions, movement, weapon simulation and HUD remain outside this static milestone. This is a complete static **world view**, not an implemented game or a claim of every original DOOM feature.

Upstream remains `a77dfb96cb91780ca334d0d4cfd86957558007e0`. The native host explicitly records LP64 disk/pointer/alignment adaptations, enclosing-object visplane sentinel access and its pinned signed-C profile. Strict undefined-C domains and Solidity safety extensions are documented per module. The EVM uses checked indexes in place of pointers, memory contexts in place of globals, bounded explicit BSP traversal, original static spawn fields, lazy texture lookup and cached resource slices. Original numerical values and rendering quirks are retained. Packed scalar table switches remove temporary lookup allocations; [all-index proof](PHASE2-TABLES.md) confirms unchanged constants and results.

Production memory-safe assembly was reviewed: table lookups use stack operations only; resource and composite copies remain within allocated source/destination ranges; colormap copies are bounded; directory tail reads remain within allocated padding; chunk scratch and digest writes stay inside their objects. There are no free-pointer rewinds or production opcode patches. NetUpdate's platform networking is omitted inside static EVM transactions; pass ordering remains original.

## Measured costs

These are fresh measurements from the archived integrated run, using pinned Cancun Anvil with documented relaxed local code/block limits and a 1-billion-gas transaction budget.

| Operation | Gas / size |
| --- | ---: |
| Ordinary upload of 1,755 resource chunks | 6,271,928,016 gas cumulatively |
| Authenticated production Doom deployment | 175,935,017 gas |
| Production runtime | 165,797 bytes |
| First production full Frame | 590,974,330 gas |
| Subsequent renderFrame | 590,957,053 gas |
| Eight full-view probe transactions | 493,302,483–590,075,082 gas |
| Intermediate wall-only Frame | 529,844,189 gas |
| Indexed payload / ABI event data | 64,000 / 64,128 bytes |

At angle zero the separate full-renderer probe measures literal MSIZE of 1,088 bytes at entry, 462,752 after the stored resource view copy, 6,825,728 after initialization, and 9,027,840 after rendering. Final render checkpoints across the eight views range from 7,294,144 to 9,027,840 bytes. These are actual EVM memory checkpoints, **not free-pointer estimates, exact production memory, or whole-call peaks**; return encoding follows the final checkpoint. Source-mapped GAS→MSIZE replacements exist only in the separate measured probe, with equal normal/measured gas and outputs and independent literal-MSIZE calibration.

Production eth_call took 360–367 ms and send-to-receipt 518–520 ms in this run. Browser input-to-Canvas took 524.4 ms through WS and 518.7 ms through receipt fallback. These durations include local RPC/client overhead; they are not isolated interpreter CPU measurements or sustained FPS claims. Canvas-only writes rounded to zero at this browser clock's resolution. Sampled host RSS peaked at 447,725,568 bytes for Anvil and 451,362,816 for Node; host RSS is distinct from EVM memory. Four production frames do not establish a long-running reset interval.

Historical isolated measurements in module reports remain tied to their original source snapshots; they are not substituted for these integrated figures. Invalid-input receipt checks cover early validation reverts, not a forced mid-render out-of-gas experiment.

## Reproduce

```sh
python3 scripts/verify-phase2.py
```

The runner prepares checksum-pinned resources and unit-test chunks before inherited gates, records fresh logs/artifacts, and fails on command errors, stale evidence, source changes or incomplete frame/browser proof. It does not offer a skip/resume shortcut. Prerequisites and toolchain installation are in the [README](../README.md).

To use the verified real renderer interactively, run `node tools/renderer/verify.mjs --keep-alive`, then `node tools/transport/serve.mjs` in another terminal and open `http://127.0.0.1:8080`. Each click sends a new static-render transaction. The [end-to-end report](PHASE2-E2E.md) documents deployment, shutdown and artifact details. Freedoom images retain [their BSD attribution](../test/fixtures/wad/COPYING.txt).
