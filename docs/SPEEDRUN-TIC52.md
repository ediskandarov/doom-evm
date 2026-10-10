# E1M1 full-rate rendering investigation

Tic 52 remains blocked by a process-address-dependent original sprite read.
All three supported EVM memory profiles reject it; no production fix or full-rate
MP4 is claimed. The exact diagnosis and conditional stop requested by the user
are complete.

## Scope and ownership

Started 2026-10-10 17:20:01 UTC. Owner: this goal's agent, existing
`fix/speedrun-tic52` branch and `/Users/eduard/sandbox/doom-evm-speedrun-debug`
worktree. Clean baseline: `67d7ee5a29b24c99282385a84623528d87be2def`.
No main edits, integration, push, other worktree edits or external runtime reuse.

Authorized scope: reproduce the historical tic 52 failure under current supported
memory policies; diagnose a persistent failure; make only a justified minimal
source-faithful correction; replay all 279 gameplay tics and compare established
native pixels; capture a 35 Hz full-rate MP4 and preserve receipts and measurements.
Stop at verified handoff or a precisely identified unsupported native assumption.

Dependencies: pinned original linuxdoom-1.10 at
`a77dfb96cb91780ca334d0d4cfd86957558007e0`, unchanged original demo and 280-state
oracle in `artifacts/speedrun-e1m1`, authenticated Freedoom 0.13.0 WAD, pinned
solc 0.8.37/viaIR/optimizer 200/Cancun/10 billion gas. A local WAD is copied read-only from
the main worktree's download and independently authenticated by the runner.

Gates: existing speedrun evidence verification; fresh 280 native/EVM snapshots;
tic 52 real receipts for strict, legacy initialized and Episode pointer-domain
profiles; every requested frame through genuine exit; 56 sampled hash regression;
native full-rate comparison wherever provenance establishes reference behavior;
focused backing/Episode Forge tests; actual storage persistence/rollback checks;
palette, frame receipt and 35 Hz video verification. No full Phase 0–4 acceptance.

Evidence and generated media: `artifacts/local/speedrun-tic52`. Dedicated ports
start at 18652; each runner refuses occupied ports and stops only its own process.

## Initial inspection

The preserved `SpeedrunVideoProbe` starts through `EpisodeStartup.initialize`
with deterministic initialization enabled. It does **not** select
`canonicalPointerHighBytes`; production `Doom.initializeEpisode` explicitly
enables that opt-in after startup. The new neighboring-composite backing reader
is shared by both. These profiles must be measured separately before proposing
an engine change.

This feature worktree contains test adapters, diagnostic tools, rejection
regressions and this report; production renderer and memory libraries are unchanged.

## Reproduction and exact diagnosis

The failure persists at baseline. All three supported policies reject tic 52:
strict 636,217,514 gas; initialized legacy 641,530,657 gas; Episode 641,534,091 gas.
These are real failed transactions below the 10 billion gas budget, not out-of-gas errors.
The Episode full-rate attempt renders 51 successful frames before its first
revert at 52. No later EVM tic is claimed rendered by that attempt.

The error-only clone identifies `R_Draw._column`,
[`src/doom/r_draw.sol:60`](../src/doom/r_draw.sol#L60), specifically
`dc.sourceTailKnown[tailIndex] != 0x01`. The requested read is one byte:

| Property | Measured value |
|---|---|
| Screen coordinates | x 301, y 155; column yl 155 through yh 166 |
| Source | authenticated `BON1D0`, lump 1552, SHA256 `2bfd9f66618cd1298fb35978d69c78a1de0f094e0e14a6401bcc8fec8e0d5678` |
| Logical lump length | 238 bytes |
| Post source offset / masked sample | 138 / 127; absolute lump offset 265 |
| Tail request / sample | 28 bytes / tail index 27, provenance 0 |
| Source block | 4496; header 12785384; size 280; payload starts 12785424 |
| Physical read | 12785689, inside 64 MiB zone, beyond the source block |
| Current adjacent block | 4497; header 12785664; size 384; owner 1553 (`BON2A0`, 340 bytes) |
| Adjacent header byte | 25: byte 1 of the LP64 `next` pointer at header offset 24 |

The diagnostic ledger follows current links from the sentinel. Retired headers
are retained as initialization exclusions; searching all historical extents as
if they were current blocks would give a misleading overlapping free block.
Native and EVM current allocation offsets/sizes/owners agree at this operation.
The original renderer's fixed-point first fraction is −8: arithmetic shift gives −1,
and the original `&127` selects 127, crossing the sprite lump's logical end.

Classification: **E, unsupported address-dependent backing contents** at an
otherwise modeled neighboring physical header. This is not a screen/framebuffer
coordinate failure, logical-WAD corruption, zone-capacity exhaustion or proven
allocator chronology error. Both backing flags are enabled in the diagnostic
Episode run. Initial-zero policy cannot override a source-written pointer;
Episode provenance 3 covers only pointer bytes 6/7, while this read requires byte 1.

## Original C evidence and stop decision

The corresponding original operation is
`r_draw.c:R_DrawColumn` line 142:
`dc_colormap[dc_source[(frac>>FRACBITS)&127]]`.
`r_things.c:R_DrawMaskedColumn` supplies the post's `column+3` source and original
texture midpoint. Neither loop is changed in the established native captures.
The observation clone inserts a read-only hook before this one existing sample.
The read is physically within the native host's 64 MiB allocation and sanitizers
report no memory fault; the **pointer representation byte depends on actual
process addresses**, so a platform-independent pixel value is not established.

| Native profile | Pointer sample byte | Pixel at (301,155) | Full frame SHA256 |
|---|---:|---:|---|
| O2 | 25 | 73 |`669b3f07ded8f849531f056d760bf88e986da9ade4f1af9003f7b55ed653d42f` |
| O0 | 25 | 73 |same as O2 |
| ASan+UBSan O2 | 97 | 105 |`f356cafddcaaa15a5e309ff7cd0819ffbaed4a11800651be4af7c19a22f60411` |

Native compiler: Apple Clang 17.0.0, arm64-apple-darwin24.6.0, signed char,
`-fwrapv`, O0/O2; LP64 zone alignment 8, memblock 40, memzone 56; original startup,
cache allocation chronology and authenticated resources. The established host
allocates the initial zone with `calloc`. Full flags, original source spans,
hashes and declared disk/pointer-layout adaptations are in the retained build
manifests. No fill override is applied to these rendering captures. Separate
no-render gameplay rechecks include the inherited allocation-fill sanitizer
profile as well.

All 279 independent native post-tic frames were produced under O0, O2 and
ASan+UBSan. Each capture replays the unchanged no-render prefix in a fresh
process, then renders once, matching the EVM recorder's temporary-copy scope.
The pre-render world is exact in every process. Only tic 52 differs between these
native profiles, and only by the one pixel above. This is comparison evidence,
not a portable golden for tic 52 or a continuous persistent native render stream.

No production fix is justified within this goal. Hardcoding 25, treating all
pointer bytes as zero, or disabling bounds would invent output. Deriving the
byte from zone-relative offsets assumes lower address alignment the sanitizer
profile demonstrably does not share. A future goal could explicitly define and
prove a native address/alignment domain and an address-bearing memory model;
that changes supported assumptions and needs an architectural review. The user
requested a stop at unsupported native assumptions, so engine code remains
unchanged and full-rate MP4 completion is blocked at tic 52.

## Verification checkpoint

Existing offline speedrun evidence passes. Fresh native no-render O0/O2 and
both sanitizer profiles execute 279 tics with 280 identical world snapshots and
the genuine original exit at line 407. A fresh baseline sampled EVM run likewise
matches all 280 worlds, reaches `GA_COMPLETED`, and reproduces all 56 historical
indexed frame hashes exactly. Its palette/video proof passes against its exact
executed baseline revision; the check initially detected intentional later
test-adapter edits and was rerun with `--source-revision 67d7ee5a29b24c99282385a84623528d87be2def`.

Test-only additions expose existing memory profiles and a complete saved-state
digest, retain actual receipt/error data, verify persistence and rollback, and
generate source-preserving native/error-only diagnostic clones. The focused
regression recreates the authentic 238/340-byte sprite allocations, offset 265,
fraction −8 and screen location, asserting rejection under all three policies.
It also asserts that the Episode pointer-high-byte extension remains available.
It deliberately introduces no address-dependent native pixel golden.

Final focused checks pass: **44 Forge tests** (23 backing/allocator tests,
3 new rejection regressions, 18 Episode startup/lifecycle tests). The original
missing-chunk failures are retained in `backing-tests.log`; the dependency-fixed
rerun is `backing-tests-recheck.log`. No accepted assertion or fixture changed.
All three error-only policy runs identify the same sample and header byte.
All three ordinary failed transactions prove complete saved-state rollback,
unchanged frame counters, no emitted logs and exact stored native worlds.
The 51 successful full-rate frames and 56 sampled frames match the independent
original-C captures byte for byte. Syntax, Solidity formatting, source-scope
and whitespace checks pass. No whole inherited Phase 0–4 suite was run.

## Reproducible commands

All commands run from the feature worktree. `evm-video.mjs` exits nonzero on the
expected failed render; its JSON and compressed receipts remain the evidence.
The recorder's successful sampled video is explicitly not a full-rate recording.
The `--source-revision` command verifies the retained baseline recording; a fresh
`sampled-replay` recording verifies current source automatically. The commands
are recipes, not a requirement to overwrite the retained checkpoint directories.

```sh
python3 tools/reference/speedrun/verify_evidence.py
node tools/reference/speedrun/record.mjs --port 18652 --sample-every 5 --output-dir artifacts/local/speedrun-tic52/sampled-replay
python3 tools/reference/speedrun/verify_video.py artifacts/local/speedrun-tic52/sampled --source-revision 67d7ee5a29b24c99282385a84623528d87be2def
python3 tools/reference/speedrun/replay.py --output artifacts/local/speedrun-tic52/native-recheck --demo artifacts/speedrun-e1m1/e1m1-easy.lmp --wad artifacts/local/speedrun-e1m1/freedoom1.wad
python3 tools/reference/speedrun/native-frames.py --output artifacts/local/speedrun-tic52/native-frames-recheck
python3 tools/reference/speedrun/native-sample.py
python3 tools/reference/speedrun/diagnostic-clone.py
.toolchain/bin/forge build artifacts/local/speedrun-tic52/diagnostic/src/support/SpeedrunVideoProbe.sol --out artifacts/local/speedrun-tic52/diagnostic/out
node tools/reference/speedrun/evm-video.mjs --port 18656 --capture-tics 52 --memory-profile episode --artifact artifacts/local/speedrun-tic52/diagnostic/out/SpeedrunVideoProbe.sol/SpeedrunVideoProbe.json --output-prefix artifacts/local/speedrun-tic52/diagnostic52/evm
python3 tools/reference/speedrun/decode-diagnostic.py artifacts/local/speedrun-tic52/diagnostic52/evm.json artifacts/local/speedrun-tic52/diagnostic52/decoded.json
.toolchain/bin/forge build src/support/SpeedrunVideoProbe.sol src/evm/ResourceStore.sol --out artifacts/local/speedrun-tic52/final-out --cache-path artifacts/local/speedrun-tic52/final-cache
node tools/reference/speedrun/evm-video.mjs --port 18657 --capture-tics 52 --memory-profile strict --artifact artifacts/local/speedrun-tic52/final-out/SpeedrunVideoProbe.sol/SpeedrunVideoProbe.json --output-prefix artifacts/local/speedrun-tic52/strict-rollback52/evm
node tools/reference/speedrun/evm-video.mjs --port 18658 --capture-tics 52 --memory-profile legacy --artifact artifacts/local/speedrun-tic52/final-out/SpeedrunVideoProbe.sol/SpeedrunVideoProbe.json --output-prefix artifacts/local/speedrun-tic52/legacy-rollback52/evm
node tools/reference/speedrun/evm-video.mjs --port 18659 --capture-tics 52 --memory-profile episode --artifact artifacts/local/speedrun-tic52/final-out/SpeedrunVideoProbe.sol/SpeedrunVideoProbe.json --output-prefix artifacts/local/speedrun-tic52/episode-rollback52/evm
node tools/wad/pack.ts artifacts/local/speedrun-e1m1/freedoom1.wad artifacts/local/wad
python3 tools/reference/phase2_data/prepare_chunks.py
.toolchain/bin/forge test --match-path 'test/unit/{z_zone_backing,z_zone_initialization,z_zone,DoomZoneStartup,p_zone_setup,CompositeBacking,PointerHighBytes}.t.sol'
.toolchain/bin/forge test --match-path test/unit/SpeedrunTic52Backing.t.sol
.toolchain/bin/forge test --match-path 'test/integration/Episode*.t.sol'
python3 tools/reference/speedrun/verify-tic52.py
```

For a new full-rate attempt with the final test adapter, use `--sample-every 1`
without `--capture-tics`, on a fresh available port. It is expected to stop at 52.
The retained earlier attempt is `episode-full/evm.json`; its exact executed
sources are archived under `executed-sources/episode-full`, SHA256-checked against
the report, because later test-observer changes affect gas and source identity.

The baseline sampled run's final wrapper check originally detected source drift
after test-helper edits. The exact baseline-revision verification above passes
all assertions, including every receipt, state, palette expansion and video
metadata. No evidence hash or assertion was changed to override that failure.

## Measurements and handoff

Final test-adapter rollback runs use solc 0.8.37, viaIR, optimizer 200, Cancun,
Anvil 1.8.5, 10 billion transaction/block gas and a 1 GiB execution-memory limit.
All 1755 resource contracts are ordinary CREATE deployments with bytewise runtime
readback. Probe runtime, ABI, source hashes, resource identity, exact server
arguments, startup/deployment receipts, failure receipts, error data and owned
runtime PIDs are retained in each report. Every owned runtime was stopped;
external runtimes and reserved ports 18880/8088 were untouched.

| Final policy | Failed transaction gas | Local transaction elapsed |
|---|---:|---:|
| Strict | 636,189,255 | 450.13 ms |
| Initialized legacy | 641,502,398 | 471.40 ms |
| Episode | 641,505,832 | 450.16 ms |

These costs include the test observer/storage adapter, not only renderer work.
The earlier reproduction costs above bind to its earlier observer source.
Error-only clones have extra diagnostic costs; their Episode failure used
933,666,200 gas and must not be labeled production performance. Peak execution
memory was not measured. The 1 GiB value is a configured limit.

The baseline sampled replay took 45.841 s after startup/deployment, used
21,207,433,393 replay gas and 40,047,467,444 capture gas. Its 56 captures took
32.160 s of local transaction time; video encoding took 0.803 s. Its 279 encoded
frames preserve 35 Hz game pacing and 7.971429 s duration by holding sampled
images. This is **56 scene renders**, not full-rate scene rendering or evidence
of real-time EVM execution. The partial full-rate attempt retained 51 successful
captures and the failed 52nd receipt. No full-rate MP4 was generated.

The three-profile independent native frame check took 120.387 s including builds
and process/file observations. Measured solc durations: final probe build 59.38 s;
initial backing gate 416.19 s; dependency-fixed backing rerun 64.01 s; regression
gate 377.24 s; Episode gate 460.00 s. These overlapping command durations are not
summed as goal time. Verification ended 2026-10-10 17:48:48 UTC, 1727 seconds after
the measured start. Subsequent handoff/commit time is outside that interval.

Available usage attribution is retained under `usage-final`: one root thread,
configured model `gpt-6.1-sol`, sanitized response accounting, snapshot timestamp
and coverage in the certificate. Input totals include repeated/cached context;
they are not unique tokens or an inferred compute duration. Unreported future
usage, approval wait attribution and peak memory are not estimated.

Code/test/tool handoff commit: `97301518654ad1232933d7d965b1d542c9c1fb1b`
(`✅ Diagnose tic 52 sprite pointer backing`). Changes are confined to
`src/support/SpeedrunVideoProbe.sol`, `tools/reference/speedrun`, the new focused
test and its authentic BSD-licensed fixture subset. This report and
[`artifacts/speedrun-tic52/checkpoint.json`](../artifacts/speedrun-tic52/checkpoint.json)
are the separate evidence handoff. The certificate preserves receipt/report/log
hashes and all three decoded diagnostic profiles. Raw data and media remain in
ignored `artifacts/local/speedrun-tic52`; accepted historical artifacts, fixtures,
original C, production libraries, compiler/budget and shared interfaces are intact.

Integration: not performed; no main modification, merge or push. No feature push
was requested. The integrator may reconcile this result into the shared Phase 4
ledger. Remaining dependency: an explicitly authorized native address-domain
design/proof if every-tic pixel rendering is still required. The first unresolved
divergence is tic 52, pixel (301,155), neighboring header `next` pointer byte 1.
The conditional stop requested in Stage C is satisfied; no subsequent goal begins.
