# DOOM II MAP01 performance experiment

`run.mjs` runs the unchanged production launcher in headed Chrome and/or an equivalent sequential Node RPC workload. `browser-instrumentation.mjs` observes browser timestamps and supplies deterministic DOM key events; it preserves the production timer and transaction methods. `analyze.mjs` validates all retained receipts/frame/state identities and recomputes metrics.

Run from the repository root. Supply the genuine pinned DOOM II 1.9 IWAD locally. Never add the IWAD, resource chunks, receipt pixel payloads, or screenshots to Git.

```sh
node artifacts/benchmarks/doom2-map01-performance/run.mjs \
  --mode all --require-ac \
  --doom2-wad /path/to/DOOM2.WAD \
  --toolchain-dir .toolchain/bin \
  --compiler-artifact out/Doom2.sol/Doom2.json \
  --output artifacts/benchmarks/doom2-map01-performance/results/reproduction

node artifacts/benchmarks/doom2-map01-performance/analyze.mjs \
  artifacts/benchmarks/doom2-map01-performance/results/reproduction
```

Use `--mode browser` or `--mode direct` for one mode. Defaults: 3 repetitions, 3 warmup gameplay tics, 50 measured gameplay frames, Anvil port 19880, HTTP port 18088. The runner refuses occupied ports, reserved playground ports and an existing `web/config.local.json`. The `all` order is browser/direct, direct/browser, browser/direct, sequentially. Both single-mode commands still install authenticated resources through the actual browser before measuring. `--mode direct --headless-install` keeps installation invisible and never takes foreground control. Headless installation is rejected for browser measurements.

Without `--output`, a unique ignored directory under `artifacts/local/doom2-map01-performance/` is printed. Explicit output directories must be empty; the runner never overwrites previous evidence.

`--compiler-artifact` must point to a compiler artifact whose bytecode, runtime, immutable references, methods, metadata source hashes, and compiler settings exactly reproduce the shipped `web/doom2-assets/Doom.json`. The measured experiment used an existing matching artifact read-only from another worktree. A fresh setup can install the pinned toolchain using `scripts/install-toolchain.py`, then build `src/evm/Doom2.sol` and `src/evm/ResourceStore.sol` with the repository's pinned compiler/settings. Keep both Forge `out/` and `cache/` directories if reusing a compilation cache. Do not repackage the browser or change engine code to make a mismatching artifact pass.

Each repetition restores a verified isolated snapshot of the deployed, initialized title menu. Browser runs select the original menu's default medium skill through Enter, Enter, then warm up and execute the stored workload. Direct runs use the identical input packets and transaction calldata. Per-block gameplay views are inspected after timing, and full final chain state roots are compared by the analyzer.

The normal production minimum timer period remains 1000/35 ms. Direct transactions have no artificial scheduling delay, retain the production post-packet `gameStarted()` read, and use the shared production receipt waiter (20 ms only after an absent receipt). `--tight-poll` selects the separately identified continuous-poll diagnostic. Direct mode omits browser UI, keyboard/DOM handlers, WebSocket delivery, the presentation-specific extra palette receipt retrieval, event/palette decoding, Canvas, proof/debug updates, and browser timers. Its mined transactions still execute all production gameplay/render/UI code and emit the same Frame and FramePalette events.

Raw JSON contains hashes of commercial frame pixels and palettes, never the pixels. All outliers remain in the data. Browser timestamps use browser `performance.now`; direct and CPU timestamps use Node `performance.now`. The analyzer never subtracts timestamps from different processes. CPU time is sampled using macOS `ps` cumulative process time and RSS, approximately once per second. CPU summaries cover each complete mode workload, including the excluded menu/warmup prefix; they are not presented as perfectly aligned per-frame CPU timings.

Throughput uses all 50 successful measured transactions/frames divided by the full measured cycle window: first browser packet dispatch to the later of final Canvas update or production tick completion; first direct submission to final post-packet RPC completion. Frame intervals are the 49 consecutive Canvas/receipt differences per repetition. Percentiles use linear interpolation at `(n-1)*p`, with every sample retained. Transaction latency ends at the first successful receipt arrival in browser mode (either normal receipt waiter or presentation receipt fetch), or the direct receipt arrival. Canvas completion is not proof of physical display presentation.

The runner waits for observed active compiler/encoding/Anvil/Node jobs before starting each repetition and does not terminate them; it excludes its own controller and Anvil from that test. It records sanitized high-CPU process observations before and after each run. Ordinary background system activity, battery/power management, cache effects, and thermal state can influence results; see the report and environment records. The originally recorded high-CPU Node process was the controller doing untimed verification, not a competing job.

For an assistant-operated run, `--browser-notice-gate` waits before each foreground pass and prints a unique goal-local grant-file path. Notify the user that Chrome needs focus, then create that file with `notice-issued` as its content. Announce release when `RELEASE browser control` appears. Chrome must actually be focused and visible before the workload starts. No control gate or installation pause enters a steady-state denominator. Ctrl-C/SIGTERM triggers owned-child cleanup; future browser failures save sanitized partial probes before cleanup. `--check-clean` checks port release without launching a runtime or measuring anything.

The publication primary dataset is explicitly assembled from the complete earlier AC browser cohort and final matched-poll direct cohort. `assemble.mjs` verifies source/configuration/logical-baseline identity and references every whole run, without selecting fast samples. `analyze.mjs` checks all frame/input/gas/exposed-state identities; a supplemental completed browser run supplies the full storage proof anchor for the three final direct runs. Storage proof capture coverage and separate-instance/run-order limitations are recorded in the primary summary/report. `--diagnostic` analyzes the earlier tight-poll cohort with its narrower proof coverage. `--require-global-root-equality` preserves the intentionally broader failing chain-root check; timestamp-dependent Cancun protocol storage differs between replays.

`sanitize.mjs` removes resource-palette payload fields and corrects the printed-CPU field label without changing any numerical observation or discarding samples. All raw results are JSON; the analyzer exports readable per-frame/transaction and CPU CSVs and evidence hashes. Sanitization is recorded in `results/sanitization.json`. It is not needed for new runner outputs, which omit palette payloads at serialization.

No engine build is needed to run against already authenticated shipped artifacts with matching existing compiler metadata. No engine source changed in this measurement task. The benchmark's verification gates are its real mined/browser execution and exact artifact/workload/frame/state comparisons.
