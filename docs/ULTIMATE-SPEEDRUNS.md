# Ultimate DOOM Episode One experimental speedrun results

Five authentic DSDA UV Speed recordings are complete at 35 FPS: E1M1, E1M2,
E1M4, E1M7 and E1M9. All nine selected maps finish native/EVM gameplay with
14,475 exact original tics and
14,484 whole DSG1 observations, including startup.
E1M3/E1M5/E1M6/E1M8 have verified partial frames and precisely reproduced
unknown owner-slot-pointer rendering blockers. No full MP4 is claimed for them.

| Map / technical report | Exact gameplay tics | EVM frames / required | Whole frames equal all three native profiles | Virtual sample uses | Outcome |
| --- | ---: | ---: | ---: | ---: | --- |
| [E1M1](ULTIMATE-SPEEDRUN-E1M1.md) | 316 | 316/316 | 316 | 0 | Complete MP4 |
| [E1M2](ULTIMATE-SPEEDRUN-E1M2.md) | 798 | 798/798 | 798 | 0 | Complete MP4 |
| [E1M3](ULTIMATE-SPEEDRUN-E1M3.md) | 1291* | 922/1291 | 922 | 3 | Owner-pointer bounds at 923 |
| [E1M4](ULTIMATE-SPEEDRUN-E1M4.md) | 767 | 767/767 | 767 | 0 | Complete MP4 |
| [E1M5](ULTIMATE-SPEEDRUN-E1M5.md) | 2110* | 1063/2110 | 1062 | 1 | Owner-pointer bounds at 1064 |
| [E1M6](ULTIMATE-SPEEDRUN-E1M6.md) | 3385 | 1735/3385 | 1735 | 1 | Owner-pointer bounds at 1736 |
| [E1M7](ULTIMATE-SPEEDRUN-E1M7.md) | 2572 | 2572/2572 | 2571 | 3 | Complete MP4 |
| [E1M8](ULTIMATE-SPEEDRUN-E1M8.md) | 1638 | 262/1638 | 262 | 0 | Owner-pointer bounds at 263 |
| [E1M9](ULTIMATE-SPEEDRUN-E1M9.md) | 1598 | 1598/1598 | 1597 | 2 | Complete MP4 |

`*` E1M3/E1M5 preserve their failed fresh-allocation-fill diagnostic. Their
strict whole-state comparisons use the independently audited existing native
initial-zero-zone O2/O0/ASan-UBSan profile; no field is masked. Other selected
tapes agree in all four native gameplay profiles. See [native allocation domains](ULTIMATE-NATIVE-DOMAINS.md).

All 10,033 accepted frames were actually rendered inside EVM;
6,051 belong to complete videos. Every frame is
receipt-authenticated and mapped to one exact original tic. The common-native
pixel gate passes for 642,111,990 pixels
outside 10 destinations touched by
10 virtual-pointer draws. Virtual bytes remain
experimental deterministic extensions, including where their pixel values
happen to match native. Source bytes from native host placement are not assumed
universally reproducible. Rendering operates on a temporary memory copy with
saved-state checks; this does not establish production browser/UI acceptance or
continuously persisted renderer history.

[Episode evidence summary](../artifacts/ultimate-speedruns/episode-summary.json)
binds every per-map manifest and extra supported-pixel gate. Each map report
records its original archive/author/URL/demo SHA, exact IWAD/native/EVM outcome,
frame/pixel/provenance counts, gas, runtime configuration, UTC/RPC/session time,
MP4 path and failures. All five videos' actual MP4 packet presentation timestamps
and durations pass [the additional clock gate](../artifacts/ultimate-speedruns/media-clock.json).
Indexed8/PNG preserve pixels; H.264 is lossy.

## Resources, baseline and ownership

Exact classic Ultimate DOOM 1.9 IWAD: MD5
`c4fe9fd920207691a9f493668e0a2083`, SHA-256
`6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f`, supplied
from Steam `~/Downloads/doom-steam/base/DOOM.WAD`. The rerelease is not used.
Freedoom 0.13.0 remains separately authenticated at SHA-256
`7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d`.
[Measured preflight](../artifacts/ultimate-speedruns/preflight.json) confirms the
original C submodule, pinned toolchain link and independent resource profiles.

The active isolated branch is `feat/ultimate-episode-speedruns` in
`~/sandbox/doom-evm-ultimate-speedruns`, relocated after recording from
`/private/tmp/doom-evm-ultimate-speedruns`, based on fetched origin/main
`51e879247bb3d6d809af8a0516a097f71c3d0756`. That baseline contains EVM menu,
experimental virtual memory and Episode One runtime. Five absent speedrun-only
commits were carried forward, without duplicating integrated engine/menu work.
[Reset handoff](../artifacts/ultimate-speedruns/reset-handoff.json) preserves the
commit mapping. The original worktree at
`~/sandbox/doom-evm-speedruns-vptr`, HEAD
`de77c3a033fabbe6511e0db1eca1a53c073fa725`, remains recovery evidence, including
Freedoom's completed E1M1 and partial E1M2 attempts. Main was not modified,
merged or pushed; no other owner's runtime/resources/toolchain were changed.

Commercial IWAD blobs, geometry-bearing world streams, extracted frames/PNG,
MP4s and full receipts stay ignored under this worktree's `artifacts/local`.
Git contains original demo tapes/archives, tools, metadata, hashes and reports.
New support adapters authenticate Ultimate identity; shared Freedoom adapters,
production ABIs, original C, compiler/viaIR/optimizer, Cancun, algorithms,
allocator semantics, draw bounds, provenance checks and goldens stay unchanged.

## Concrete limitations and recovery

[Renderer diagnostics](ULTIMATE-RENDER-BOUNDS.md) identify unknown low bytes of
allocated owner-slot addresses in current native-zone headers. Error-only clones
retain all guards and reproduce the original failed savedDigest. Each rejected
capture has no logs and leaves saved fields/native world/frame counter unchanged.
Full independent gameplay runs continue through genuine exits. Raising gas or
memory cannot establish those addresses; no fabricated bytes or speculative
engine correction is applied. E1M7 completes without MemoryOOG and directly
loads gameplay once, bypassing the menu startup path.

The faster E1M8 Zero-Master demo relies on original C intercept overflow at tic
159. Its tape and precise failure remain; Sedlo's authenticated DOOM 1.9 alternate
passes native gameplay and then encounters the independent render-owner blocker.
One additional authentic E1M3 secret-exit tape reaches native exit but fails the
existing allocation-domain audit with a nonzero uninitialized platform field;
that gate is not broadened. Acquisition is bounded; no inputs are invented,
modified or reconstructed from video.

Resumable streamed chain/receipt checkpoints avoid Node's 512 MiB string ceiling.
Restores use an owned Anvil's load-state file, hash-bound source/input/ABI/resource
identity checks and resource/snapshot/receipt readback. A stopped E1M1 recording
resumes and completes. Checkpoints/maps remain independent; failures do not
invalidate completed recordings. The gameplay-only runner's initial frame-count
checkpoint assertion was corrected, retaining all failed attempts/source.
E1M9's zero-tic sandbox transport failure and failed MP4 edit-list timing file
also remain. Both MP4 clocks now use whole tic units; strict timing gates pass.
[Infrastructure and recovery ledger](../artifacts/ultimate-speedruns/runtime-notes.json)
records these changes without changing the engine.

## Measured cost and host resources

Selected complete/partial recording proof receipts consume
10,573,263,602,286 gas. Separate complete gameplay runs for
blocked maps consume 257,194,469,125 gas. Diagnostics,
additional failed attempts and unmeasured interrupted work are excluded from
these sums and reported separately where measured. They are not a total cost
estimate. Per-map UTC/session/RPC bounds and native-profile execution times are
preserved; native and EVM durations are not inferred from video length. API cost
and Ultimate-specific token attribution are unavailable.

All Anvil endpoints are checked-free localhost ports 18641–18644. Local settings:
1 GiB EVM memory, 10B transaction/block gas, unlimited request bodies, bounded
two-block history, 300-second RPC/receipt deadlines and 900-second dump deadline.
Compiler/hardfork stay pinned. No memory/gas increase beyond those settings is
needed in these selected runs. Completed proof receipts persist independently
from pruned runtime history. All owned Anvil/native/monitor jobs are stopped.

[Host evidence](../artifacts/ultimate-speedruns/host-summary.json) contains
240 actual telemetry samples from 2026-10-10T19:55:04Z through
2026-10-10T21:58:32Z. After the observed disk reclamation, the minimum available
space is 34,726,981,632 bytes and final measurement is
35,281,731,584 bytes (32.86 GiB).
Cleanup removed 346 superseded state/duplicate receipt
files, freeing 3,852,982,399 measured bytes
(3.59 GiB), with SHA/size/reason audits.
Latest restore points, failed evidence, original inputs, final receipts and
fixtures remain. The cleanup gate refuses corrupt heads and protects unpublished
new checkpoints; three focused recovery tests pass. Sampled maximum owned Node
RSS is 3,367,152 KiB and Anvil RSS
202,816 KiB on a host with
38,654,705,664 bytes RAM. These are captured RSS samples, not a
universal execution-memory high-water mark; full native/verifier RSS is not
available. Recorded swap decreases from the initial measurement to the final
measurement; no inferred usage is substituted.

[Durable relocation evidence](../artifacts/ultimate-speedruns/relocation.json)
verifies the pinned submodule/toolchain and repair of checkpoint path metadata.
Actual state/receipt/frame/IWAD/source bytes are unchanged; original pointer
metadata is retained. Historical build paths remain measured history.

## Reproduction and handoff

[Suite instructions](../tools/reference/ultimate_speedruns/README.md) provide
local IWAD packing, pinned builds, authenticated input staging, independent
native/EVM runs, full-rate encoding, gates, resume and cleanup commands. The
coordinator is verified against completed E1M1 and final E1M9; every selected
map's native/EVM/receipt/pixel evidence is independently checked; complete
maps' media gates pass and blocked maps' full-recording gates remain failed.
Affected roots build under the pinned settings. This is feature verification,
not main integration or full inherited Phase 4 acceptance. No inherited gate or
fixture is weakened.

Stop condition is reached: all selected compatible gameplay tapes are fully
verified, five complete recordings are preserved, and the remaining maps have
concrete reproducible unsupported-memory blockers. Further complete recordings
for those maps require another independently admissible authentic route or an
explicitly proven memory-domain capability; this report does not assume either.
No push/main merge is authorized or performed. Preserve this worktree and its
local artifact directory, including commercial files that Git intentionally
cannot recover. Exact handoff source commit is in the final Gitmoji checkpoint.
