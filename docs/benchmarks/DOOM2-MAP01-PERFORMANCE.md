# DOOM II MAP01 performance

## Goal record

- Scope: measure unchanged production browser gameplay and equivalent mined direct RPC transactions; no engine, renderer, resource, article, or historical evidence changes.
- Owner/worktree: this goal, `research/doom2-browser-fps`, `/Users/eduard/sandbox/doom-evm-browser-fps`.
- Measured goal start: 2026-10-13T13:57:28Z (goal tool).
- Baseline: `2e0a7db94e9abcaa1a5d982e1b080d4348e268b2`, clean tree; remote main independently checked equal.
- Owned paths: this report and `artifacts/benchmarks/doom2-map01-performance/`; temporary runtime files under ignored `artifacts/local/doom2-map01-performance/`.
- Dependencies: user-supplied exact DOOM II 1.9 IWAD, pinned shipped browser artifacts, Anvil 1.8.5, solc 0.8.37 metadata, Chrome, Node.
- Interface freeze: unchanged production launcher, raw-keyboard loop, `stepEventsAndRender(bytes,uint32)`, Frame/FramePalette ABI, virtual memory profile 3, Cancun, 10 billion gas, 1 GiB EVM memory.
- Runtime ownership: refuse occupied ports 19880 and 18088; never use reserved playground ports 18880/8088. Stop only children started by the runner.
- Gates: authenticate IWAD/artifacts/source/compiler metadata; restore and verify baseline; successfully deliver 50 consecutive gameplay Frames to Canvas per browser repetition; same mined calldata and game-tic advancement in direct mode; match frame/palette/gas/state identities; retain outliers and CPU samples; inspect statistics and sanitized artifacts.
- Stop: commit benchmark code, verified results and report on this branch; no main integration or push.

## Verified result

On this Apple M3 Pro, the tested DOOM II MAP01 workload delivered **0.5495 browser-visible Canvas frames/sec**. Equivalent direct mined RPC execution delivered **0.5482 frames/sec** with the production receipt polling policy. Each measured transaction advanced one gameplay tic and emitted one new Frame plus its FramePalette, so FPS, successful TPS, and simulation tics/sec coincide in this particular workload.

This is local Anvil performance under the existing relaxed execution configuration, using the genuine DOOM II 1.9 IWAD and unchanged production engine. It is not a Mainnet/L2 benchmark or a measurement of confirmed physical display presentation.

The primary comparison retains all three successful AC-power browser repetitions from the first complete AC cohort and all three repetitions from the final matched-polling direct cohort. The browser path was unchanged throughout the experiment. These cohorts ran sequentially on the same machine in separate, identically configured isolated Anvil processes. Their authenticated engine/resources, transaction hashes/calldata, gas, Frame pixels/palettes and exposed gameplay states match. The final direct cohort ran later, so this comparison does not eliminate ordering, thermal, cache or background-system variation. It is not a precise causal estimate of browser overhead.

### Primary comparison table

| Metric | Production browser | Direct RPC, matched receipt polling |
|---|---:|---:|
| Gameplay Frame throughput | **0.549523 FPS** | **0.548165 FPS** |
| Successful transactions/sec | **0.549523 TPS** | **0.548165 TPS** |
| Simulation tics/sec | 0.549523 | 0.548165 |
| Measured frames / transactions | 150 / 150 | 150 / 150 |
| Total measured cycle time | 272.964100 s | 273.640461 s |
| Mean consecutive frame interval | 1,822.321 ms | 1,826.897 ms |
| Median consecutive frame interval | 1,854.600 ms | 1,869.538 ms |
| p95 consecutive frame interval | 2,151.590 ms | 2,143.674 ms |
| Median submission-to-receipt latency | 1,838.250 ms | 1,867.121 ms |
| p95 submission-to-receipt latency | 2,134.170 ms | 2,143.250 ms |
| Median packet-dispatch-to-Canvas latency | 1,839.350 ms | N/A |
| p95 packet-dispatch-to-Canvas latency | 2,135.615 ms | N/A |
| Average gas / gameplay frame | 1,645,383,449.42 | 1,645,383,449.42 |
| Median gas / gameplay frame | 1,671,347,753 | 1,671,347,753 |
| Gas/frame range | 1,077,967,244–1,965,156,700 | Identical |
| Mean Anvil CPU, complete mode workload¹ | 96.976% | 99.038% |
| Peak sampled interval Anvil CPU¹ | 101.017% | 101.031% |
| Peak observed Anvil RSS | 354,992 KiB (346.672 MiB) | 348,880 KiB (340.703 MiB) |
| Slowdown relative to original 35-tic/sec cadence | 63.692× | 63.849× |

¹ CPU windows include the menu/startup packet prefix and three warmup gameplay frames, unlike the steady-state throughput window. They are not exactly aligned per-frame CPU measurements. On macOS, 100% process CPU corresponds to one core's time; multiple active threads can exceed 100%. Means use cumulative `ps` CPU time divided by Node monotonic elapsed time; peaks use differences between approximately one-second samples. The raw printed `ps` percentage is retained separately and is not used for these means. Centisecond CPU-time quantization and sampling jitter affect peaks.

All percentiles use linear interpolation at `(n−1)×p`. There are 150 transaction/input latency samples per mode and 147 frame intervals (49 within each of three repetitions). Every accepted sample, including the slowest, remains in the data.

### Exact throughput arithmetic and repetitions

Each repetition has 50 consecutive successful gameplay transactions and 50 unique new EVM frames. Each also has 50 different indexed-pixel hashes. No frame was fabricated, repeated as a new frame, or obtained from an offline rendering path.

| Repetition | Browser measured seconds | Browser FPS = 50 / seconds | Direct measured seconds | Direct FPS = 50 / seconds |
|---|---:|---:|---:|---:|
| 1 | 90.883700 | 0.550154 | 91.013518 | 0.549369 |
| 2 | 91.029500 | 0.549272 | 90.721592 | 0.551137 |
| 3 | 91.050900 | 0.549143 | 91.905350 | 0.544038 |

Browser FPS and TPS are both `150 / 272.96410000038147 s`. Direct FPS and TPS are both `150 / 273.640460834 s`. These are pooled count/time ratios, not averages of the three FPS values. Tics/sec use the same verified 150-tic numerators and denominators. The slowdown is `35 / measured tics/sec`.

The browser window starts at dispatch/sampling of the first measured input packet and ends at the later of the final Canvas API update completion and production tick completion. The direct window starts at the first measured transaction submission and ends after the final receipt and production post-packet `gameStarted()` read. Deployment, installation, title/menu navigation, game creation, warmup, state inspection, hashes, screenshots and report generation are excluded. The direct metric denotes newly emitted EVM Frames verified from successful receipts; it has no Canvas endpoint.

## Environment and frozen identities

| Item | Actual measured configuration |
|---|---|
| Hardware | MacBook Pro, Mac15,7, Apple M3 Pro |
| CPU | Native arm64; 12 cores: 6 performance + 6 efficiency |
| Physical memory | 36 GiB, 38,654,705,664 bytes (`system_profiler` labels it “36 GB”) |
| macOS | 15.7.9, build 24G830 |
| Anvil | 1.8.5, commit `51a52c59cffd940f76eddd0b4bb1791aa4b5ac7f`, dist, native arm64 |
| Solc | `0.8.37+commit.f401782d.Darwin.appleclang` |
| Compiler | viaIR=true; optimizer=true, runs=200; Cancun |
| Browser | Headed Google Chrome 155.0.8059.40; V8 15.5.35.20 |
| Node | v24.11.0, arm64 |
| Source commit | `2e0a7db94e9abcaa1a5d982e1b080d4348e268b2` (remote main checked equal at freeze) |
| Engine release payload SHA-256 | `3f9065a4aa169004ceaeb1716b41cb6f4e53ac9d31458e77147708d36ff47d3b` |
| Engine runtime length | 905,156 bytes, with production driver immutable binding verified by installer |
| DOOM II IWAD | 14,604,584 bytes; MD5 `25e1459ca71d321525f84628f45ca8cd` |
| IWAD SHA-256 | `10d67824b11025ddd9198e8cfc87ca335ee6e2d3e63af4180fa9b8a471893255` |
| Packed resource bundle SHA-256 | `775bc8b01d44c2fb1c3a68a79b9864c2f36ebbb29746d31e9ca600ae226af5ad` |
| Resources | 889 authenticated immutable chunks; 2,919 lumps; genuine MAP01 |
| Memory policy | Explicit production virtual-pointer profile 3, `initializeMenuWithMemoryProfile(bool,uint8)` |
| Gameplay | Medium skill (2), monsters enabled, original menu, status bar/HUD, 320×200 indexed8 Frames |
| Transaction/block gas | 10,000,000,000; unchanged |
| Anvil EVM memory limit | 1,073,741,824 bytes (1 GiB); unchanged |
| Mining | Default ordinary automining, serialized dependent transactions; no fork |
| Owned endpoints | Anvil `127.0.0.1:19880`; HTTP `127.0.0.1:18088` |

All 81 pinned Solidity source hashes match the worktree. Existing compiler metadata independently binds those sources through their keccak hashes and reproduces the shipped bytecode/runtime/immutable references/method identifiers exactly. No Solidity source changed and no Forge build was necessary: zero compiler files rebuilt. The compatible compiler artifact was read only from the main worktree's existing `artifacts/local/death-save-main/production/out/Doom2.sol/Doom2.json`; no writing compiler/cache was shared.

The complete Anvil command arguments were identical for the primary cohorts:

```text
--host 127.0.0.1 --port 19880 --chain-id 31337 --hardfork cancun
--disable-code-size-limit --no-request-size-limit
--memory-limit 1073741824 --gas-limit 10000000000
--allow-origin http://127.0.0.1:18088 --silent
```

Browser measurements used a fresh owned Chrome profile with `--no-first-run --no-default-browser-check --disable-background-networking --remote-debugging-port=0`. The final direct cohort used headless Chrome only to install resources through the unchanged production launcher/File API; during timed direct execution it stayed on a blank page, with no gameplay subscriptions or Canvas work. No browser CPU/scheduling flags accelerated the measured browser path.

All primary run power checks before and after execution reported **AC Power**. Low Power Mode was off. Both cohorts had no recorded thermal/performance warning before or after their sessions. Actual temperatures, core frequencies and core affinity were not measured or fixed. The initial battery-power attempt was stopped when the author plugged in the laptop and requested a restart; none of its timing contributes to the primary result.

Available-memory observations are retained verbatim. Before the browser cohort, `vm_stat` reported 147,424 free 16-KiB pages (2.250 GiB) and 794,605 inactive pages (12.125 GiB); before the final direct cohort it reported 24,582 free pages (0.375 GiB) and 872,067 inactive pages (13.307 GiB). `memory_pressure -Q` reported system-wide free percentages of 75% and 76%, respectively. Those OS accounting categories are not interchangeable estimates of immediately allocatable RAM. Ordinary macOS/WindowServer activity remained; sanitized high-CPU observations appear in each run. No engine build or competing benchmark was launched during timed execution. Pre/post process observations cannot rule out every transient background task.

## Production transaction path and deterministic workload

The unchanged [production menu client](../../web/menu-app.mjs), [menu transactions](../../web/menu-input.mjs), [serialized gameplay loop](../../web/input-loop.mjs), [Frame transport](../../web/protocol.mjs), and [palette presentation](../../web/ui-palette.mjs) execute this steady-state path:

1. Sample raw keyboard events once; maintain held-key state in the EVM.
2. Submit `stepEventsAndRender(bytes,uint32)` (`0x9a5b61ba`) as an ordinary mined transaction.
3. Advance one logical gameplay tic, persist gameplay/UI/render state, emit one Frame and one matching FramePalette. No separate render or palette transaction is needed.
4. Receive the Frame over WebSocket or receipt fallback, deduplicate its identity, obtain its authenticated palette from a companion receipt, expand indexed8 into RGBA, and call Canvas `putImageData`.
5. Confirm the transaction receipt and input/frame sequence, read `gameStarted()`, acknowledge input, then schedule the next tic using the unchanged minimum period `1000/35 ms`.

There is one successful transaction per measured tic and per measured frame. There is no tic/frame batching. Dependent gameplay transactions never overlap. Palette/receipt/status reads are RPC calls, not transactions. Menu navigation and stop-time release-only transactions can have other relationships to gameplay; they are outside this measured window. The final workload packet releases all held keys, so stopping adds no release transaction to the measurement.

Every repetition restores the isolated snapshot taken after genuine browser resource installation and explicit menu initialization: menu open, game not started, input counter zero, selected memory profile 3. Before each run the runner asserts that the complete baseline fingerprint, including chain state root/block hash and nonce, exactly matches its saved snapshot. No external node or developer state is restored.

Through the original commercial menu, Enter/Enter starts MAP01 at medium skill. Three gameplay frames warm up the mode. The 50 measured frames are input sequences 7–56 and game tics 5–54:

| Measured frame indices | Held input / transition |
|---|---|
| 1–12 | Forward (`ArrowUp`) |
| 13–24 | Forward + turn right |
| 25–32 | Turn right, release forward |
| 33–40 | Forward + turn left |
| 41–49 | Forward + fire (`ControlLeft`) |
| 50 | Release all held keys; ordinary gameplay tic still advances |

Events go through the same DOM keyboard binding as human play. Empty packets between key transitions retain EVM held-key state and still execute full gameplay/render transactions. The client computes no movement, visibility or pixels. All 50 frames have distinct pixel hashes; player coordinates and angle change; gameplay tic and level time advance. This tests approximately 1.43 seconds of original 35-Hz simulation near MAP01's start, repeated from the same state. It does not characterize an entire map, a speedrun, combat generally, or other levels.

Direct mode serializes the identical packets with the shared production encoder, uses the same calldata/gas/from/to, waits for mined receipts with the **production receipt waiter** (20 ms between absent-receipt polls), and performs the same post-packet `gameStarted()` read. It submits the next dependent transaction immediately after completion. The receipt wait is readiness polling, not an added delay between completed gameplay transactions. DOM/keyboard handlers, WebSocket presentation, the palette-specific extra receipt retrieval, decoding, Canvas, proof/debug updates and browser timers are omitted. All EVM gameplay, rendering and UI work remains.

## Comparability and state proofs

The analyzer verifies all 56 setup/warmup/measured transaction operations in every primary repetition against the same reference, including transaction hashes, input/frame sequence, gas, pixel SHA-256, palette SHA-256 and all recorded `gameStatus()`, `playerView()` and `episodeStatus()` values. Every counted receipt succeeds; every counted browser frame has a Canvas completion timestamp. The final browser Canvas was read back and byte-hashed against the RGBA expansion of its authenticated EVM Frame/FramePalette.

A supplementary complete browser repetition and all three final direct repetitions also captured `eth_getProof` storage/code hashes. Their entire final DOOM storage hash is identical:

```text
0xba224fa32fb4295f56e5ec0bb5c4a0596528bae0e5c9c2394b2a93999431c4d0
```

The three original primary browser runs predate this extra proof instrumentation; their full storage roots were not captured. Their per-frame identities and exposed state match the supplemental browser and direct runs exactly. **The full storage proof covers one supplemental browser run and three primary direct runs, not all six primary runs.** This coverage is explicit in `summary.json`.

Whole-chain final state roots differ despite identical transactions. DOOM code/storage and driver balance match in the captured proofs, while the Cancun beacon-root contract storage hashes differ. [EIP-4788](https://eips.ethereum.org/EIPS/eip-4788) stores each block timestamp in protocol contract storage, so wall-clock-timestamp differences can change the broader chain root without changing DOOM. The original broader root-equality check remains a failed diagnostic, retained as `results/ac/global-root-check.failed.log` and reproducible with `--require-global-root-equality`; it is not represented as passed. The baseline snapshot restoration check still requires exact chain-root equality before every run.

## Where time goes and the principal bottleneck

The following browser timings are measured means across the primary frames. Several spans overlap; do not sum them as mutually exclusive accounting:

| Observed browser span | Mean |
|---|---:|
| Packet dispatch/sampling → transaction submission | 0.031 ms |
| Submission → send RPC response (transaction hash) | 0.658 ms |
| Send response → first successful receipt arrival | 1,804.451 ms |
| Frame decoding/inbox synchronous work | 3.425 ms |
| Frame presentation entry → palette ready | 1.459 ms |
| Palette expansion + Canvas reset/ImageData construction | 1.041 ms |
| `putImageData` API execution | 0.014 ms |
| Production callback after painting (proof/debug/status) | 2.158 ms |
| Canvas completion → next animation-frame callback | 2.176 ms |

The submit RPC returns before expensive mining finishes. Its sub-millisecond response is not transaction execution latency. Most cycle time is spent awaiting successful mined output, with Anvil consuming approximately one core and approximately 1.65 billion gas per frame. The evidence points to **CPU-bound Anvil processing of the full gameplay/render transaction** as the principal bottleneck. Canvas and palette expansion are on the millisecond scale, while a frame takes roughly 1.8 seconds. No opcode-level or server-internal profiler separated EVM computation, mining, locks, receipt serialization and transport; receipt/RPC wait must not be called pure EVM execution time.

The pooled direct throughput is **0.247% lower**, and its mean complete cycle is **4.509 ms longer**, than the browser's. Indexed pair differences range from direct −0.930% to +0.339%. Given only three repetitions, different cohort times/processes, untuned CPU scheduling and normal background activity, this session does not establish a statistically reliable browser overhead percentage. It supports no clear throughput gain from removing the browser for this workload. It does not claim browser overhead is zero or universally negligible.

### Retained tight-poll diagnostic

The first direct client continuously polled absent receipts, whereas production waits 20 ms between polls. Its three 50-frame runs produced 0.458446 FPS/TPS (`150 / 327.192336208 s`), median/p95 receipt latency 2,219.826/2,580.677 ms, and mean/peak Anvil CPU 124.610%/142.387%. Gas/frame and frame/state identities remained identical.

Those results are retained separately, and are **not used to estimate browser overhead**. Changing only the direct receipt-wait policy to production polling yielded the final 0.548165 FPS/TPS and 99.038% Anvil CPU. That association is consistent with receipt-request contention consuming additional Anvil CPU in the tight-poll client. The experiments occurred at different times, so this is not an isolated proof of every millisecond's cause. The final client records per-transaction receipt poll counts; the earlier tight-poll client did not, so no tight-poll request-count estimate is invented.

Gameplay-only `stepEvents` exists, but no separate gameplay-only throughput campaign was run. `renderFrame()` routes through a gameplay step in this production profile; it is not a pure-render endpoint. Isolated render FPS would require a different accessible workload or engine changes, and is omitted. All primary numbers cover full production gameplay/render transactions.

## Raw data, reproduction and limitations

The [primary summary](../../artifacts/benchmarks/doom2-map01-performance/results/primary/summary.json), [frames/transactions CSV](../../artifacts/benchmarks/doom2-map01-performance/results/primary/frames.csv), [CPU time series CSV](../../artifacts/benchmarks/doom2-map01-performance/results/primary/cpu.csv), [workload](../../artifacts/benchmarks/doom2-map01-performance/results/primary/workload.json), [provenance manifest](../../artifacts/benchmarks/doom2-map01-performance/results/primary/manifest.json), and [SHA-256 evidence list](../../artifacts/benchmarks/doom2-map01-performance/results/primary/SHA256SUMS) identify every primary observation and its source. Per-run JSON lives in `results/ac/browser-{1,2,3}.json` and `results/matched-direct-ac/direct-{1,2,3}.json`. The complete original AC cohort, intermediate corrected cohort, failed preflight and interrupted battery attempt remain under `results/`; the [sanitization record](../../artifacts/benchmarks/doom2-map01-performance/results/sanitization.json) documents payload removal and the corrected printed-CPU field label. No measurement numbers were changed and no slow accepted samples were removed.

Browser frame/transaction timestamps use browser `performance.now()`. Direct and CPU observations use Node `performance.now()`. No latency subtracts different processes' clocks. CPU time series use their own Node clock and whole-mode windows; no unsynchronized browser/Node alignment is implied. Packet latency starts at DOM injection/sampling, including packets for previously held input; it does not include physical keyboard/OS dispatch time or the age of the first held-key press. Canvas API completion and a subsequent animation callback do not prove physical screen presentation. Some very small spans are below browser timer resolution.

One intermediate aligned-cohort browser pass aborted when the loop unexpectedly stopped. Its partial probe was not saved by that runner version, so no timing from it is counted; the exact trigger cannot be independently distinguished from its failure record. The runner now waits for an actually focused/visible page before starting, preserves sanitized partial probes on later failure, and supports notice gates before foreground browser passes. No additional interactive browser campaign was needed: all three already valid AC browser repetitions were retained as a complete cohort. The supplemental complete browser run is used only for storage-proof coverage. All failed and incomplete attempts remain identified in [the attempt ledger](../../artifacts/benchmarks/doom2-map01-performance/results/attempts.json).

From a clean worktree, install the pinned toolchain if necessary, obtain the exact IWAD locally, and obtain a matching compiler artifact using the pinned source/settings. Preserve both `out/` and `cache/` if reusing a Forge cache. Do not point a writing compiler at another owner's cache.

```sh
python3 scripts/install-toolchain.py
.toolchain/bin/forge build src/evm/Doom2.sol src/evm/ResourceStore.sol --skip test script --offline --no-lint

node artifacts/benchmarks/doom2-map01-performance/run.mjs \
  --mode all --require-ac \
  --doom2-wad /path/to/DOOM2.WAD \
  --compiler-artifact out/Doom2.sol/Doom2.json \
  --output artifacts/benchmarks/doom2-map01-performance/results/reproduction

node artifacts/benchmarks/doom2-map01-performance/analyze.mjs \
  artifacts/benchmarks/doom2-map01-performance/results/reproduction
```

`--mode browser`, `--mode direct`, and `--mode all` are supported. Direct-only installation can be invisible with `--headless-install`; this is rejected for any measured browser mode. `--tight-poll` reproduces the separate direct receipt-policy diagnostic. `--browser-notice-gate` makes each foreground pass wait for the operator to announce control and create the printed grant file containing `notice-issued`; measured windows begin later, after warmup. Keep Chrome focused and visible during browser measurement. The runner refuses occupied/reserved ports or an existing `web/config.local.json`, starts only owned runtimes, and cleans them up. No IWAD is added to Git.

For the retained primary cohorts, regenerate the selection and statistics without executing any benchmark:

```sh
node artifacts/benchmarks/doom2-map01-performance/assemble.mjs
node artifacts/benchmarks/doom2-map01-performance/analyze.mjs artifacts/benchmarks/doom2-map01-performance/results/primary
node artifacts/benchmarks/doom2-map01-performance/analyze.mjs artifacts/benchmarks/doom2-map01-performance/results/ac --diagnostic
node artifacts/benchmarks/doom2-map01-performance/run.mjs --check-clean
```

Sanitized data contains frame/palette hashes rather than commercial pixels, IWAD bytes, resource chunks or screenshots. Source, raw-data and workload identities are reproducible without redistributing commercial assets. No engine optimization, renderer change, execution-budget change, Melt Wipe integration, article edit, historical speedrun edit, or main push/merge occurred.

## Publication-ready statements

**Human experience:** “On my Apple M3 Pro on AC power, DOOM II MAP01 managed about 0.55 browser-visible frames per second for this short movement-and-turning workload.”

**EVM/browser comparison:** “Executing the same one-tic gameplay-and-render transactions directly against local Anvil produced 0.548 transactions per second, compared with 0.550 through the browser, using the production receipt polling policy.”

## Handoff and verification

Implementation is complete; measurement and comparison gates passed within the coverage stated above. The original full-chain root-equality diagnostic remains failed for the documented protocol-state reason. Validation includes the real mined/Canvas runs, authenticated compiler/source/resource identities, all per-frame operation/gas/pixel/palette/exposed-state comparisons, four captured full DOOM storage roots, independent statistical checks, 33 focused existing Node input/menu/palette tests, syntax/format/link/payload checks and verification that owned ports 19880/18088 have no listeners. No engine/native rebuild was needed for this measurement-only change.

All work belongs to this feature branch/worktree. Exact committed files and evidence hashes are recoverable from Git and `SHA256SUMS`. Goal start/end and available root-agent usage telemetry are stored in `results/goal-record.json`; no subagents or unmeasured cost estimates were used. The stop condition is this report, scripts, sanitized data and focused Gitmoji commit. No later goal begins here.
