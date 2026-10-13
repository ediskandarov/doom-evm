# Benchmark and browser Melt Wipe integration

Integration started 2026-10-13 16:25:48 UTC. Owner: technical integration agent,
main worktree `/Users/eduard/sandbox/doom-evm`. Baseline and refreshed origin/main:
`2e0a7db94e9abcaa1a5d982e1b080d4348e268b2`, clean and synchronized.

Authorized scope: review and preserve `research/doom2-browser-fps` at
`c4905b3e34d661be661e9adcb1dcd45611a8bd4d` and `feat/browser-melt-wipe` at
`ed1f5c27328b4809e57aec50d0bfdea997aebcec`, merge locally, verify fresh deployed
combined source, publish this technical report and reconcile the Phase 4 ledger.
Both merge bases equal the baseline; both owning feature worktrees were clean.
No essay/media edits, original-C edits, remote push, historical evidence rewrite,
or later feature development is authorized.

Dependencies and frozen interfaces: original pinned C, solc 0.8.37/optimizer 200/
viaIR/Cancun, Anvil 1.8.5, Chrome 155, authenticated IWAD bundles, existing
Frame/FramePalette ABI and 10B gas/1-GiB memory budgets. New wipe methods are
additive. Verification uses isolated goal-owned runtime ports 19221–19223 and
19881/18089; reserved playground ports 18880/8088 and external runtimes are untouched.

Gates: independent evidence/hash/source review; metadata-authenticated affected
build; focused Forge/native/Node checks; real Chrome startup/menu/gameplay/wipe/
palette/rollback/reload proofs for Freedoom, Ultimate E1 and DOOM II MAP01;
separate focused performance comparison because opt-in gameplay now persists its
last displayed framebuffer. Preserve historical benchmark and recording evidence.
Stop after successful local integration, verification, committed report and clean
tree; report failures without claiming success if an essential gate fails.

Status: **local source integration and focused combined acceptance passed**.
Evidence commit: `8a2ef53d153df55acd358696491172bef0610eea`.
The final documentation commit records this report and the Phase 4 ledger.

## Integration and review checkpoint

Benchmark merge: `8f7ae377749f6dc76832dc52a41c5a447943c581`.
Main source integration merge: `f8d33781d2d3cd456d6a28016062b0328c23afd1`.
Both feature commits remain ancestors; no conflict or feature replacement occurred.
Refreshed origin/main equaled the baseline before merging. A subsequent read-only
remote check still returned only baseline main for the three requested refs; no
push occurred.

Independent review authenticated every hash in the Melt Wipe evidence manifest
and inspected its actual Forge, Node and three-profile Chrome results. The historical
benchmark verifier independently recalculated all 300 primary measured observations,
count/time ratios, percentiles and hashes. The broader historical chain-root equality
failure remains recorded; it is not reclassified as passed.

`DoomWipe` calls unchanged `F_Wipe` functions inside the EVM. Browser modules submit
serialized transactions, recover authoritative receipts and paint authenticated
indexed pixels with FramePalette. No browser/CSS wipe simulation exists. Continuation
transactions call no gameplay, UI or menu ticker and leave the renderer's target
framebuffer intact. The first transition transaction advances its normal simulation
tic, renders the destination and starts the wipe. Original miscellaneous RNG advances
320 calls at initialization; gameplay RNG is untouched. Strict input sequence and
driver guards, browser Web Locks and durable transaction journaling prevent blind
retry/duplicate acceptance. Save/Load remains an instantaneous EVM snapshot extension
and is guarded while a wipe is active.

Implementation changes comprise the additive shared DoomWipe adapter and Doom/Doom2
hooks/guards; browser input, presentation pause and recovery modules; native-backed
adapter tests and Chrome runner; authenticated Doom deployment packages/pins; source
mapping/report/evidence. The benchmark branch adds only its report, infrastructure
and measurements. Integration adds a separate focused performance harness, fresh
evidence, this report and a Phase 4 ledger checkpoint. No Solidity integration fix,
original C change, unrelated refactor, essay/media edit or historical recording/native
certificate change was needed.

A verification setup issue was resolved by serving a goal-owned copy of the website
for the follow-up benchmark: the existing ignored main browser configuration was
preserved. The unchanged melt runner explicitly saves/restores that configuration.
The first benchmark preflight refused the existing config; the second refused battery
power under its AC-only flag. Neither attempted gameplay. Both failures are retained.
The completed comparison records actual power state rather than presenting a new AC
baseline. Historical benchmark files and values remain byte-for-byte unchanged.


## Combined verification

Fresh production build compiled 87 files with solc 0.8.37 in 275.14 compiler
seconds (275.451 command seconds); it passed with existing warnings. The subsequent
warm build reported `No files changed, compilation skipped`. Both cache and out
were copied read-only from the feature worktree into an integration-owned directory
before Forge validation; no other owner's cache was written. The freshly built
Doom/Doom2 bytecode, runtime, methods and immutable references exactly reproduce
both shipped packages. Metadata authenticates 83 Doom and 82 Doom2 source files.
Goal-owned compiled artifacts were staged for the unchanged browser runner, with
previous main artifacts retained under ignored goal-local evidence.

| Focused gate | Actual result | Compiler files / seconds |
|---|---|---|
| Wipe/native + persistent adapter | 13 passed, 0 failed | 11 / 3.03 |
| Original gameflow/menu | 31 passed, 0 failed | 83 / 69.70 |
| Options/Save menu | 8 passed, 0 failed | 78 / 4.85 |
| Status Bar/HUD | 26 passed, 0 failed | 80 / 7.04 |
| Browser modules, installer, input and transport | 86 passed, 0 failed | Node; 473.994 ms |
| Original-C wipe oracle | Seven cases agree under O0/O2/ASan+UBSan; existing fixture bytes unchanged | Comparison-only, goal-local outputs |
| Historical benchmark audit | 300 measured rows; counts, timing, percentiles, hashes, payload scope, links and syntax pass | No EVM replay |

The 78 Forge tests retain original budgets and assertions. This is focused integration
acceptance, not final Phase 0–4 release acceptance. The 18,175-frame historical
recording suite was not rerun. No accepted fixture, recording or certificate changed.

### Actual Chrome coverage

All three gates used newly deployed contracts from authenticated integrated-source
artifacts and Chrome 155.0.8059.40 / Anvil 1.8.5, Cancun, 1-GiB memory and existing
10B gas/relaxed code and block limits. Resource contracts were created normally and
every deployed resource/runtime byte was checked. The runner controls only the
input timer; DOM input, original menu responders, transaction controller, rendering,
Frame transport and Canvas remain production code.

| Profile | Native-equal wipe updates | Canvas readbacks (unique observed receipts) | Full-storage revert checks |
|---|---:|---:|---:|
| Freedoom 0.13.0 E1M1 | 84, two wipes | 92 (89) | 8 |
| Pinned Ultimate DOOM E1M1 | 84, two wipes | 92 (89) | 8 |
| Original DOOM II 1.9 MAP01 | 84, two wipes | 91 (88) | 8 |

252 wipe updates matched original C, including exact endpoints. 275 Canvas readbacks
cover 266 distinct observed Frame receipts; repeated observations are not counted as
new frames. Every readback compares all 64,000 indexed pixels, the 768-byte palette
and 256,000 RGBA bytes with the specific transaction's Frame/FramePalette receipt.
Native comparisons also cover recovered wipe emissions not individually observed
as Canvas updates. Destination pixels match a fresh same-source opt-out deployment.

The browser gates exercise automatic opt-in/title startup, original New Game menu
navigation, active title-to-gameplay wipe, Pause/Continue, completion, held movement
resumption, ordinary menu open/close without wipe, and a second forced same-GS_LEVEL
New Game wipe. Continuations check frozen gameStatus/playerView/episodeStatus/uiStatus;
world/UI/menu simulation does not advance during presentation-only steps. HUD/Status
Bar are present in production composition; detailed widget/palette/message semantics
have the 26 component tests above. No new browser pickup-message or exhaustive menu/
map-route campaign is claimed.

Recovery tests deliberately lose a confirmed-mining response with unknown hash,
reload and recover the original sender/nonce without resubmission; they also reload
with a known unmined transaction, refuse retry, mine the original and recover. Strict
sequence checks reject duplicate presentation and racing ordinary input. Wrong driver,
UI resize, save, load, restart and insufficient gas also revert. All 24 deliberate
reverts preserve the complete contract storage root and emit no logs. Node tests add
concurrent-tab exclusion, canonical/orphaned receipt checks, keyup reconciliation and
capability probing. Gameplay and menu input resume after wipe completion.

This proves the stated three profiles and two transition types, not all levels,
skills, commercial editions or arbitrary IWADs.

## Supported, partial and unsupported capabilities

**Verified in the real browser:** title/menu → gameplay and forced same-level New
Game → gameplay on Freedoom E1M1, pinned Ultimate E1M1 and DOOM II MAP01; complete
EVM pixel computation, receipt/Canvas delivery, pause/reload recovery, frozen world
and resumed gameplay. Ordinary menu/Options/pause/automap state handling does not
introduce a wipe solely from toggling UI; the new browser gate directly checks
ordinary menu open/close.

**Implemented with partial integration evidence:** gameplay → intermission;
intermission → next level (including existing secret routing); E1M8 → E1 finale
text; forced E1 finale text → art; supported DOOM II intermission → text and
text → next level; Select Level/rebirth/restart/forced same-state loading;
confirmed End Game → bounded title. These are wired by the shared state/force
adapter and unchanged inherited gameflow. The native-backed adapter matrix and
31 inherited tests cover state, force, endpoint and flow behavior, but this goal
has no real-browser exit/finale/rebirth/Select Level campaign. DOOM II startup
content remains MAP01–32; that is not a claim of browser wipe verification on all
32 maps. E1 is the supported Ultimate episode presentation scope.

**Unsupported:** Ultimate E2–E4 presentation, attract/demo playback, multiplayer,
DOOM II MAP30 text → cast and other unsupported finales, color-transform wipes,
arbitrary rectangles, arbitrary IWADs. A wipe does not add content support. Snapshot
Save/Load remains instantaneous and cannot run during an active wipe; it is not an
original melt transition. No automatic skip is offered.

## Runtime deployment and user-visible limits

Redeploy **Doom** for Freedoom/Ultimate E1 or **Doom2** for DOOM II, with matching
new browser packages, pins and modules. These contracts have no upgrade mechanism:
source changes do not modify any previous deployment. Authenticated ResourceStore
contracts may be reused. Installer journals are keyed by authenticated artifact
hash/runtime; preserve old contracts, journals and save slots. No automatic
cross-deployment save migration exists. Explicit memory-profile-3 initializers,
compiler settings and existing runtime budgets remain required.

Additive methods: `wipeStatus()`, `enableMeltWipe()`, `stepWipe(uint32)`. Shared
Frame/FramePalette, resources and existing gameplay ABI stay unchanged. New menu
browser sessions opt in only after v1 capability detection; older configured game
contracts remain playable without wipes, while the new installer requires the new
pinned runtime. Legacy menuMode=false controllers remain opt-out.

Each wipe update requires a mined transaction and emits a 64,000-byte Frame plus
palette. Presentation is transaction paced, not original real-time 35-Hz playback.
Secure-context Chrome localStorage/Web Locks and canonical history are needed for
recovery. Unresolved/evicted transactions or unknown-hash history beyond 4,096 blocks
remain blocked for operator reconciliation; no blind retry is sent. Pause lasts
within the current document; reload recovers and continues. Existing relaxed local
runtime limits do not establish standard-mainnet deployability or public-chain speed.

## Historical benchmark provenance

The historical benchmark is unchanged and describes baseline
`2e0a7db94e9abcaa1a5d982e1b080d4348e268b2`, **before production browser Melt Wipe**.
It used Apple M3 Pro, Anvil 1.8.5, Chrome 155, original DOOM II 1.9 MAP01, three
repetitions of 50 genuine EVM gameplay frames per mode. Each measured frame was one
successful transaction and one game tic.

- Browser: 0.549523 FPS and TPS; direct mined RPC: 0.548165 FPS and TPS.
- Median browser packet-dispatch/input-to-Canvas latency: 1839.350 ms.
- Mean gameplay-frame gas: 1,645,383,449.42.
- Mean Anvil CPU: 96.976% browser, 99.038% direct.

Removing browser presentation showed no demonstrated throughput improvement;
CPU-bound Anvil transaction processing was the principal observed bottleneck.
Sequential cohorts, limited repetitions, broad CPU windows, matched polling policy,
partial historical storage-proof capture and the retained broader chain-root failure
remain part of its limitations. None of these values is a measurement of integrated
Melt Wipe or the newly deployed contracts.

## New browser wipe observations

Fresh integrated-source measurements below include the initiating New Game/render
transaction and 41 presentation-only continuation transactions through final Canvas
delivery. They exclude IWAD upload/deployment, include observation RPC/Canvas-check
overhead, and are not public-network or real-time guarantees. The interrupted first
wipe also includes pause, reverts and reload tests and is not used as a typical playback
duration. Each uninterrupted forced New Game wipe used seed 1 and 42 updates, or 1.2
seconds of logical original 35-Hz sampling.

| Profile | New uninterrupted browser duration | Transactions | Total gas with startup/render |
|---|---:|---:|---:|
| Freedoom E1M1 | 5.848135 s | 42 | 5,558,949,315 |
| Ultimate E1M1 | 4.698969 s | 42 | 3,322,377,864 |
| DOOM II MAP01 | 5.611842 s | 42 | 3,964,018,837 |

The corresponding first cold title→gameplay transitions used 6,001,486,856 /
3,606,719,923 / 4,414,519,720 total gas. Their continuation-only gas was
1,530,566,205 / 1,343,482,935 / 1,422,583,665. Wipe initialization added
410,646,437 / 342,127,729 / 356,057,995 gas over fresh same-source opt-out first
New Game frames with identical endpoints. These reproduce the feature's deterministic
gas results; the separately measured wall-clock times differ. Runtime sizes remain
933,187 bytes (Doom) and 913,213 bytes (Doom2), exactly as in the accepted feature.

Ordinary opted-in gameplay **does change**: it retains the last 64-KiB displayed
screen and transition state. Browser sends also use durable nonce journaling and
read wipe status. Renderer/gameplay algorithms, shared frame ABI and execution budgets
are unchanged. Therefore the original benchmark is a valid immutable historical
baseline, but cannot be presented as a measurement of this version or assumed to
have identical costs. A separate focused comparison follows.

## Focused gameplay performance comparison

A separate runner derived from the accepted infrastructure uses the identical
50-tic MAP01 route, medium skill, three gameplay warmups, authenticated browser
installation, ordinary mined transactions and production 20-ms absent-receipt waiter.
It measures one sequential direct run per arm on newly deployed integrated-source
contracts: opt-out, then opt-in. Startup's 41 wipe continuation transactions are
recorded separately and excluded from gameplay throughput. Both arms read authoritative
inputSeq before each timed submission; intervening reads still enter the pooled
cycle window. Browser journal/wipe-status RPC overhead is not measured by these
direct runs. No new steady-state browser FPS campaign is claimed.

| Current integrated-source direct arm | Frames / game tics | Measured seconds | FPS / TPS | Mean gas/frame |
|---|---:|---:|---:|---:|
| Wipes disabled | 50 / 50 | 97.662761 | 0.511966 | 1,645,386,253.82 |
| Wipes enabled | 50 / 50 | 96.295215 | 0.519237 | 1,654,653,543.76 |

Opt-in adds **9,267,289.94 mean gas/frame, or 0.563229%**, over same-source
opt-out in this workload. This is a measured opted-in path cost, encompassing
framebuffer persistence and RNG-dependent UI behavior; it is not isolated opcode
accounting. Opt-out is 2,804.40 gas/frame above the historical mean. All 50 measured
world-view hashes, palettes and exposed gameStatus/playerView/episodeStatus values
match between the new arms, including gameplay RNG; every measured transaction
advances one game tic and emits a unique Frame. Input packets match after ignoring
sequence numbers consumed by presentation. Full contract storage roots intentionally
differ because enabled/presentation/display state differs.

13 full-frame/status-bar hashes match; 37 differ within the bottom 320×32 status-bar
region while the entire 320×168 world view remains identical. This is consistent
with original wipe initialization advancing miscellaneous RNG, which drives face
selection. No smaller-region diff was captured, so the evidence does not establish
that every changed pixel is a face pixel or that complete Frames are identical
between opt-in and opt-out after the wipe.

Anvil CPU means for complete setup/warmup/measurement windows were 98.242% and
98.096%. Both arms ran on battery (92→91%, then 90→89%), sequentially, with one
repetition each. The observed opt-in throughput was 1.420160% higher, but this small
uncontrolled pair demonstrates neither a reliable gain nor a throughput regression.
It must not be compared causally with the three-run AC historical cohort. A modest
gas cost increase is established; a statistically controlled post-integration
browser throughput result remains unmeasured.

## Reproduction and evidence

Affected build and fresh Chrome commands (prepare the authenticated local bundles
specified in `docs/BROWSER-MELT-WIPE.md`; these do not publish commercial IWADs):

```sh
.toolchain/bin/forge build src/evm/Doom.sol src/evm/Doom2.sol src/evm/ResourceStore.sol --skip test script --no-lint
node --test web/*.test.mjs
python3 artifacts/benchmarks/doom2-map01-performance/verify.py
node tools/transport/melt-browser-check.mjs --profile freedoom --port 19221 --output-prefix artifacts/local/integration-reproduction/freedoom
node tools/transport/melt-browser-check.mjs --profile ultimate --port 19222 --output-prefix artifacts/local/integration-reproduction/ultimate
node tools/transport/melt-browser-check.mjs --profile doom2 --port 19223 --output-prefix artifacts/local/integration-reproduction/doom2
```

Run browser commands sequentially, await process exit, and refuse occupied ports.
The committed `forge-*-command.json` files retain exact focused test/skip/output
arguments and start/end/exit results. Native O0/O2/sanitizer regeneration redirected
only output to a goal-local directory and compared all seven existing fixture bytes;
its committed manifest records compiler commands and source/fixture hashes.

For the direct comparison, make a goal-owned copy of `web/` excluding existing
`config.local.json`/`palette.local.json`. Set `--web-root` to that copy. Use a matching
fresh compiler artifact, an empty evidence output directory and free ports:

```sh
node artifacts/benchmarks/doom2-map01-melt-followup/run.mjs --mode direct --headless-install --repetitions 1 --frames 50 --warmup 3 --port 19881 --http-port 18089 --web-root artifacts/local/integration-reproduction/website --compiler-artifact out/Doom2.sol/Doom2.json --output artifacts/local/integration-reproduction/optout
node artifacts/benchmarks/doom2-map01-melt-followup/run.mjs --mode direct --headless-install --enable-wipe-in-direct --repetitions 1 --frames 50 --warmup 3 --port 19881 --http-port 18089 --web-root artifacts/local/integration-reproduction/website --compiler-artifact out/Doom2.sol/Doom2.json --output artifacts/local/integration-reproduction/optin
node artifacts/benchmarks/doom2-map01-performance/analyze.mjs artifacts/local/integration-reproduction/optout
node artifacts/benchmarks/doom2-map01-performance/analyze.mjs artifacts/local/integration-reproduction/optin
```

Use `--require-ac` only when AC is available; retain actual power records. Analysis
checks one arm independently, not equality of intentionally different enabled state.
New raw measurements, failed preflights, test logs, metadata identities, deployment
receipts and hashes are in `artifacts/integration-benchmark-melt/`. Published evidence
contains no commercial pixels/IWAD or private keys. Only trailing empty-line
normalization of the new build log was needed; its raw hash/location are recorded.

## Commit-pinned GitHub/source links

No remote push is authorized or performed. Origin/main remained at the historical
baseline, and the requested feature heads were not listed on origin. The new local
commit URLs below will become accessible only after separately authorized publication;
this report does not claim they are currently public.

- [Integrated historical benchmark](https://github.com/ediskandarov/doom-evm/blob/f8d33781d2d3cd456d6a28016062b0328c23afd1/docs/benchmarks/DOOM2-MAP01-PERFORMANCE.md)
- [Historical raw measurements/provenance](https://github.com/ediskandarov/doom-evm/tree/c4905b3e34d661be661e9adcb1dcd45611a8bd4d/artifacts/benchmarks/doom2-map01-performance)
- [Integrated Melt Wipe handoff and transition matrix](https://github.com/ediskandarov/doom-evm/blob/f8d33781d2d3cd456d6a28016062b0328c23afd1/docs/BROWSER-MELT-WIPE.md)
- [EVM display/persistence adapter](https://github.com/ediskandarov/doom-evm/blob/f8d33781d2d3cd456d6a28016062b0328c23afd1/src/evm/DoomWipe.sol)
- [Unchanged original-derived EVM wipe algorithm](https://github.com/ediskandarov/doom-evm/blob/f8d33781d2d3cd456d6a28016062b0328c23afd1/src/doom/f_wipe.sol)
- [DOOM II frame orchestration](https://github.com/ediskandarov/doom-evm/blob/f8d33781d2d3cd456d6a28016062b0328c23afd1/src/evm/Doom2.sol)
- [Browser transaction recovery](https://github.com/ediskandarov/doom-evm/blob/f8d33781d2d3cd456d6a28016062b0328c23afd1/web/wipe-input.mjs)
- [Browser scheduling/automatic opt-in](https://github.com/ediskandarov/doom-evm/blob/f8d33781d2d3cd456d6a28016062b0328c23afd1/web/menu-input.mjs)
- [Chrome verification runner](https://github.com/ediskandarov/doom-evm/blob/f8d33781d2d3cd456d6a28016062b0328c23afd1/tools/transport/melt-browser-check.mjs)
- [Fresh combined verification certificate](https://github.com/ediskandarov/doom-evm/blob/8a2ef53d153df55acd358696491172bef0610eea/artifacts/integration-benchmark-melt/integration.json)
- [Fresh three-profile Chrome evidence](https://github.com/ediskandarov/doom-evm/tree/8a2ef53d153df55acd358696491172bef0610eea/artifacts/integration-benchmark-melt)
- [Separate performance comparison](https://github.com/ediskandarov/doom-evm/blob/8a2ef53d153df55acd358696491172bef0610eea/artifacts/integration-benchmark-melt/performance-comparison.json)
- [Focused follow-up harness](https://github.com/ediskandarov/doom-evm/blob/8a2ef53d153df55acd358696491172bef0610eea/artifacts/benchmarks/doom2-map01-melt-followup/run.mjs)

## Exact publication facts

The essay's statement that Melt Wipe is available in recordings but not the ordinary
browser is **outdated for the integrated browser paired with newly deployed matching
contracts**. Existing old deployments are not upgraded by this merge.

The writer may safely cite:

1. Production Chrome now displays original-derived **EVM-computed** melt transitions
   for title/menu→gameplay and same-level New Game on the three tested profiles.
2. JavaScript orchestrates transactions/recovery and paints EVM receipts; the EVM
   computes all transition pixels. There is no CSS or host-side melt simulation.
3. Each tested uninterrupted wipe used 42 transactions; the fresh DOOM II MAP01
   observation took 5.612 seconds including the initiating render and test observation
   overhead. The other measured durations and costs have the precise table above.
4. Presentation-only continuation steps preserve gameplay/UI state. Normal gameplay
   and ordinary menu navigation resume; duplicate/racing/reverted submissions and
   reload recovery have the stated focused tests.
5. Exit/intermission/E1 finale/supported commercial-text routes are implemented with
   adapter and inherited evidence, **not exhaustive new browser verification**.
   E2–E4 presentation, demos, multiplayer and MAP30 cast remain unsupported.
6. The 0.549523 browser / 0.548165 direct FPS results and 1839.350-ms browser median
   are the immutable **pre-integration** MAP01 baseline. They are not current wipe
   timing or post-integration browser throughput.
7. The focused battery-powered direct pair measured 0.563229% more gas/frame with
   wipes enabled; it does not establish a reliable throughput change. The pair had full-Frame
   differences confined to the status bar, consistent with original wipe RNG.
8. Redeployment is required. The work is locally committed; nothing was pushed,
   published, or edited in the essay or editorial media.

No essential acceptance blocker remains in the declared focused scope. Limitations
are the partial transition/browser coverage, unmeasured controlled browser throughput,
transaction-paced/local-limit execution, bounded recovery and unsupported content
listed above. All goal-owned ports were confirmed released: 19221/19222/19223 and
19881/18089; external runtimes and reserved playground ports were preserved.

Measured start: 2026-10-13 16:25:48 UTC. Functional/performance results were complete
by 17:13:49 UTC; cleanup/source/evidence checks completed before the documentation
checkpoint at 17:17:53 UTC. Available goal-service counters at 17:13:49 were 174,999
tokens and 2,880 elapsed seconds; these are a checkpoint, not complete billing
attribution. No missing usage or dollar cost is estimated. Stop after the report
and ledger commit; no next development goal or remote publication is started.
