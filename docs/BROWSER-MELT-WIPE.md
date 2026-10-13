# Production browser melt wipe

Goal started 2026-10-13 13:53:59 UTC. Owner: the primary Codex agent, worktree
`doom-evm-browser-melt`, branch `feat/browser-melt-wipe`, baseline
`2e0a7db94e9abcaa1a5d982e1b080d4348e268b2` (clean). No delegation or main writes.

Scope: reuse `f_wipe.sol` in Doom/Doom2 display orchestration and the production
menu browser; persistent presentation transactions, focused tests, generated
deployment packages and this report. Engineering essay and historical evidence
are outside scope. Shared additions are additive wipe control/status methods;
Frame/FramePalette and existing gameplay ABI remain unchanged.

Dependencies: pinned original DOOM source, solc 0.8.37/viaIR/Cancun, authenticated
IWADs, local Anvil and Chrome. Owning cache/out were absent; both were copied
read-only from `../doom-evm` into this worktree for Forge validation. Toolchain,
original source and permitted Freedoom resources were also copied locally.

Verification gates: affected production roots; original-C wipe reference; focused
persistence, rollback, sequencing, palette, frozen-world and browser scheduling
tests; real Chrome Canvas transition using the EVM menu; relevant Node/Forge
regressions; package metadata/source authentication. Reserved ports 18880/8088
will not be used. Stop after verified feature commit and clean handoff; no push
or merge to main, no historical full-video rerun.

Implementation and focused acceptance are complete on the owned feature branch.
The historical pause/failure checkpoint below remains part of the record; final
frozen-source results supersede its pending status. No main merge or push occurred.

## Paused checkpoint

Paused at the user's request for benchmarking, 2026-10-13. No commits or pushes
have been made; implementation, generated packages and the test runner remain
uncommitted on the owned branch. A process inventory at pause found no remaining
goal-owned Anvil, Chrome or melt runner processes.

Completed checks (local evidence under `artifacts/local/browser-melt/`):

- Production build: 86 files / 240.44 seconds initially; final changed-root build
  3 files / 253.31 seconds. Warm build skipped compilation. Both successful.
- Focused Forge: 11 tests passed, including seven native wipe cases plus storage
  rollback and three production-adapter tests (`unit.log`).
- Native oracle regenerated under O0/O2/ASan+UBSan; accepted fixture bytes were
  unchanged. Retained the new manifest locally and restored the historical one.
- Node: 84 tests passed (`node.log`).
- Inherited Forge gameflow/menu: 31 tests passed (`regression.log`); Options and
  SaveMenu were unintentionally excluded by filename filters and still need their
  focused run before completion.
- Doom and Doom2 browser packages regenerated with authenticated source metadata.
- Chrome test reached original menu New Game and an active EVM wipe. Browser
  acceptance is **not passed**: the current run failed an expected-sequence
  assertion (`4 !== 5`, runner line 161) before completing recovery/native/Canvas
  verification. Earlier runner failure was a missing `expandPalette` import,
  since corrected. Preserve these failed attempts; investigate the sequence
  assumption on resume, then run Freedoom, Ultimate and DOOM II focused checks.

Next actions: complete browser verification/recovery and native production-frame
comparisons, measure an uninterrupted wipe, add the transition-matrix adapter
cases and remaining regression checks, finish this report with demonstrated
scope/limits and deployment steps, authenticate final packages, commit only the
owned files, and return the handoff. Do not claim verified integration yet.

## 1. Architecture and reused EVM implementation

`DoomWipe` is a shared transaction adapter inherited by `Doom` and `Doom2`.
It calls the unchanged `F_Wipe.wipe_StartScreen`, `wipe_EndScreen` and
`wipe_ScreenWipe(..., 1)` functions. It introduces no alternate pixel algorithm.
`FullSpeedrunProbe` and historical recording consumers are unchanged.

The production adapter follows `d_main.c:D_Display`: remember the last displayed
indexed framebuffer; capture it before a gamestate change or forced wipe; render
and retain the destination once; publish the first melt update rather than the
destination; finish the blocking presentation before allowing further game tics.
`EpisodeRuntime` still owns gameflow, ST/HU/WI/finale drawing and palette choice.
The adapter redraws the frozen `M_Menu.M_Drawer` over each melt update, matching
D_Display's menu overlay order. Ordinary menu open/close is not a gamestate change.

The integration points in both contracts are `_emitFrame` (display decision),
`_publishFrame` (unchanged Frame/FramePalette emission), `_wipeCommitRandom`
(the shared original miscellaneous RNG), and `_wipeOverlay` (original menu).
Legacy controllers do not opt in, so they retain their existing simulation and
wipe-marker semantics. Exact EVM Snapshot Save/Load keeps its instantaneous
cached-frame display; it cannot save or load during an active wipe.

## 2. Supported transitions

| Transition | Original trigger and existing EVM domain | Verification scope |
|---|---|---|
| Title/menu → gameplay | GS_DEMOSCREEN → GS_LEVEL; E1 Freedoom/Ultimate, DOOM II MAP01–32 | Real Chrome New Game gates below |
| Gameplay → intermission | GS_LEVEL → GS_INTERMISSION via existing G_DoCompleted | Original-C inherited gameflow + adapter matrix |
| Intermission → next level | GS_INTERMISSION → GS_LEVEL, including existing secret routing | Original-C inherited gameflow + adapter matrix |
| E1M8 gameplay → E1 finale text | GS_LEVEL → GS_FINALE via existing GA_VICTORY | Original-C inherited gameflow + adapter matrix |
| E1 finale text → art | F_Ticker sets wipegamestate=-1 within GS_FINALE | Forced adapter case + inherited finale implementation |
| DOOM II intermission → text | MAP06/11/20/30 and supported MAP15/31 secret exits, GS_INTERMISSION → GS_FINALE | Original-C commercial gameflow + adapter matrix |
| Supported DOOM II text → next level | GS_FINALE → GS_LEVEL via existing G_DoWorldDone; excludes MAP30 cast | Original-C commercial gameflow + adapter matrix |
| New Game/Select Level/rebirth/restart within gameplay | G_DoLoadLevel forces wipegamestate=-1 within GS_LEVEL | Real Chrome same-state New Game + forced adapter test |
| Confirmed End Game → bounded title | GS_LEVEL → GS_DEMOSCREEN in existing menu adapter | State matrix + inherited End Game responder tests; title-only host adaptation |
| Menu/Options, pause, automap toggles, ordinary gameplay | No state change and no forced wipe | Real Chrome menu/gameplay regression; no wipe |
| Exact EVM Snapshot Save/Load | Instantaneous archived framebuffer, an existing extension | Guarded during wipes; no original melt claim |

Wipes do not extend content support. E2–E4 presentation, attract/demo playback,
network play, DOOM II cast (including MAP30 text-to-cast), unsupported finales,
color-transform wipes and arbitrary rectangles remain outside the implementation.
There is no invented finale-to-intermission transition. The browser gates exercise
New Game and forced New Game, not an exhaustive browser replay of every exit/finale;
other matrix rows rely on the unchanged gameflow implementation and focused adapter
checks, not a new claim of whole-game native equivalence.

## 3. Browser orchestration

The normal production menu profile probes additive `wipeStatus()` protocol v1.
An empty result or empty execution revert identifies an older deployment; network
errors and malformed/future protocols fail explicitly. For v1 it calls
`enableMeltWipe()` once, reads status under the existing transaction lock, and
switches the serialized GameplayLoop to `stepWipe(nextInputSequence)` while active.
It consumes ordinary authenticated Frame events and associated FramePalette through
FramePresentation and the existing indexed8-to-RGBA Canvas path. No wipe columns,
CSS animation, host visibility, precomputed frames, GIF or video are used.

While active, keyboard binding rejects new player/menu input. Pending keydowns are
discarded, keyup events for previously held keys are retained for the first ordinary
packet after completion. A reload reads the authoritative held-key bitmap and queues
original keyups; it does not tick them in presentation transactions. Gameplay,
menu, Save/Load, restart/pause and UI-size calls also revert at the contract boundary.

A visible notice explains transaction-paced playback and provides Pause transition
and Continue transition. Explicit pause is respected across focus changes within
that document. Blur/hidden stops future scheduling; a submitted transaction can
still finish. Reload reconciles pending work and continues the persisted transition.
There is no automatic or optional skip in this release.

## 4. Wipe state and transaction boundaries

Storage retains the start and end buffers (after original column-major conversion),
current screen, all 320 column positions, `go`, miscellaneous RNG, displayed/from
state, progress count and enabled/active flags. UI storage retains target palette
bank, RGB bytes, revision and gamma for every matching FramePalette. The start
image is intentionally displayed using the destination palette, as in D_Display;
this is not a palette crossfade. Gameplay's renderer framebuffer remains the
unmelted destination, preserving render histories for subsequent ordinary frames.

The transaction that changes game state performs its normal one simulation tic,
renders once, initializes the wipe and performs the first presentation tic.
Each `stepWipe` thereafter consumes one input sequence and increments Frame ID,
while calling neither G_Ticker/P_Ticker nor the renderer, ST/HU/WI/F tickers,
M_Ticker or input responders. Only wipe storage, display counters and the original
miscellaneous RNG synchronization are written. Initialization makes 320 M_Random
calls and commits the resulting index to `gameState.rndindex`; `prndindex` is
untouched. Further presentation steps consume no RNG. The original extra done
update is retained. Completion releases the transient wipe buffers/columns and
retains the displayed endpoint. All writes and logs roll back on transaction revert.

Driver authentication and the shared strictly increasing uint32 input sequence
reject duplicates, stale retries and races. Browser storage journals sender nonce,
submission block, calldata and known hash before/after submission. Web Locks exclude
concurrent browser tab sends. A timeout/lost response blocks further sends. Reload
finds the original sender/nonce in canonical blocks, checks canonical receipt and
transaction ownership, reads on-chain counters/status and backfills emitted frames.
Known unmined operations are never resubmitted. If an unknown-hash operation cannot
be proven mined, recovery remains blocked; the browser does not guess that it failed.

## 5. Original-C fidelity and adaptations

Reference: linuxdoom-1.10 at `a77dfb96cb91780ca334d0d4cfd86957558007e0`.
Original f_wipe.c SHA256:
`eafbc10e5a56ded32deb9e9cd2d25fae4b7ecea16c1a2dc0ed380c8f2d2b2a22`.
The unchanged Solidity port retains two-byte columns, short-copy semantics, 320
initial RNG draws although only 160 columns melt, negative startup delays,
nonlinear first rows, eight-row progression and original completion timing.

The native oracle compiles verbatim original wipe functions with declared libc
allocation and I_ReadScreen/V_DrawBlock copy adapters. O0, O2 and ASan/UBSan agree
on seven seed/batch cases. Production comparisons feed actual EVM endpoints to that
native oracle solely for comparison, then compare every emitted EVM intermediate
frame. No native pixels or state are provided to production contracts.

Host adaptations are explicit: persistent transaction-owned buffers replace C
pointers/zone lifetimes; one original presentation tic per transaction replaces
I_GetTime's variable elapsed-tic batches; simulation does not catch up to wall clock;
input suspension/release reconciliation and pause controls serve the browser's
transaction boundary. Pixel/state fidelity at the declared sampling is distinct
from original 35-Hz timing, continuous event polling or complete DOOM coverage.

## 6. Focused tests

Final focused checks all passed. The committed [manifest](../artifacts/browser-melt/manifest.json)
records source, runtime, ABI, resource and evidence hashes.

| Check | Result | Evidence |
|---|---|---|
| Production affected-root build | 3 files, solc 0.8.37, 247.64 seconds; success. Warm unchanged build skipped compilation. | [build](../artifacts/browser-melt/build.log), [warm build](../artifacts/browser-melt/build-warm.log) |
| Wipe/native + persistent display adapter | 13 passed; initialization, seven native seed/batch cases, exact endpoints, shared RNG, state/forced matrix, no world tics, rollback, duplicate/racing input, legacy opt-out | [Forge](../artifacts/browser-melt/forge-wipe.log), [command](../artifacts/browser-melt/forge-wipe-command.json) |
| Inherited original gameflow/menu | 31 passed; 83 compiler files, 64.13 seconds | [Forge](../artifacts/browser-melt/forge-gameflow-menu.log), [command](../artifacts/browser-melt/forge-gameflow-menu-command.json) |
| Inherited Options/Save menu | 8 passed; 78 compiler files, 4.39 seconds | [Forge](../artifacts/browser-melt/forge-options-save-menu.log), [command](../artifacts/browser-melt/forge-options-save-menu-command.json) |
| Browser modules/installer/transport | 86 passed, `node --test web/*.test.mjs`; includes capability, stale/pending sends, concurrent tabs, orphaned receipts, reload keyups and presentation scheduling | [Node](../artifacts/browser-melt/node.log) |
| Original-C oracle regeneration | O0/O2/ASan+UBSan agree; accepted fixture bytes unchanged | [native manifest](../artifacts/browser-melt/native-oracle.json) |
| Release packaging/ABI | Source metadata, pinned compiler settings and artifact hashes authenticated; all prior methods retained plus exactly three additive methods | [manifest](../artifacts/browser-melt/manifest.json) |
| Scope/format | Forge formatting, `git diff --check`, report local-link and evidence-hash checks passed | Goal handoff below |

Tests were scoped to affected roots and existing gameflow/menu dependencies;
no global Phase 4 completion or exhaustive historical acceptance is claimed.
Historical acceptance artifacts, fixtures and native goldens are unchanged.
The inherited 18,175-frame recording suite was not rerun.

The initially combined eight-wipe matrix exceeded the existing 10B per-test budget;
it was split into two four-wipe tests with the same endpoint/tic assertions.
The execution budget was not increased. Early browser attempts caught runner
mistakes (missing import, checking before mining, observing an old document during
reload, and a tap rather than held movement). Failed attempts remain under ignored
`artifacts/local/browser-melt/`; the final source-frozen gates below passed.

## 7. Browser E2E

The focused runner `tools/transport/melt-browser-check.mjs` uses ordinary authenticated
ResourceStore/Doom CREATE transactions on a goal-owned Anvil and fresh headless
Chrome. It controls only the input timer; DOM handlers, menu responders, transaction
controller and Canvas path remain production code. It compares indexed bytes and
all 256,000 Canvas RGBA bytes with each observed Frame/FramePalette receipt, and
compares all wipe emissions (including uncertain-response recovery frames) with
original-C output. Final results:

| Profile | Native melt frames | Canvas readbacks | Complete-storage rollback cases | Result |
|---|---:|---:|---:|---|
| Freedoom 0.13.0 E1M1 | 84 (two wipes) | 92 | 8 | [passed](../artifacts/browser-melt/freedoom.json) |
| Pinned Ultimate DOOM E1M1 | 84 | 92 | 8 | [passed](../artifacts/browser-melt/ultimate.json) |
| Classic DOOM II 1.9 MAP01 | 84 | 91 | 8 | [passed](../artifacts/browser-melt/doom2.json) |

All six wipes used 42 original presentation updates at seed 1. Every emitted wipe
frame, including final exact endpoint, matched native C. Each observed Canvas
readback matched its Frame/FramePalette receipt. Normal menu open/close emitted
no wipe; held movement resumed after completion. The first destination was also
byte-identical to a fresh same-source deployment with wipes disabled.

Each profile verified Pause/Continue, lost confirmed-mining response with an
unknown hash, known unmined transaction across reload, canonical recovery with no
resubmission, and frozen gameStatus/playerView/episodeStatus/uiStatus throughout
presentation-only steps. Eight deliberately failed transactions (duplicate, input
race, UI resize, save, load, restart, wrong driver, insufficient gas) retained the
complete contract storage root and emitted no logs.

Chrome: 155.0.8059.40; Anvil: 1.8.5, Cancun, 1-GiB memory limit, unchanged 10B gas
budget and existing relaxed code/block limits. Isolated ports 19121/19122/19123
were checked unoccupied; all goal-owned runtimes stopped. Reserved 18880/8088 were
untouched. No commercial IWAD, raw commercial pixels or recording is committed.

Reproduce after preparing the existing authenticated resource bundles:

```sh
node tools/transport/melt-browser-check.mjs --profile freedoom --port 19121
node tools/transport/melt-browser-check.mjs --profile ultimate --port 19122
node tools/transport/melt-browser-check.mjs --profile doom2 --port 19123
```

Use `artifacts/local/wad`, `artifacts/local/ultimate/wad`, and
`artifacts/local/doom2/wad`, respectively, containing the established resources.bin,
bundle.json and palette.json. Run sequentially because the harness temporarily
owns browser config files. The runner verifies source hashes at both start and end.
Native comparisons require the pinned original checkout and Clang. Other transition
matrix rows have source/adapter/inherited proofs, not these browser end-to-end proofs.

## 8. Gas and wall-clock measurements

The uninterrupted gate measures real
menu New Game → forced same-state wipe through final Canvas delivery. It includes
the one necessary gameplay startup/render transaction and subsequent presentation
transactions, plus observation RPC/Canvas verification overhead; it excludes IWAD
upload and contract deployment. Presentation-only gas is also recorded separately.
The interruption exercise includes pause, rollback checks, reloads and deliberate
mining control and is not a typical playback time.

| Profile | Uninterrupted forced New Game wipe | Total gas including startup/render | First cold title → gameplay total gas | Presentation-only continuation gas (cold wipe) |
|---|---:|---:|---:|---:|
| Freedoom | 5.488 s / 42 updates | 5,558,949,315 | 6,001,486,856 | 1,530,566,205 |
| Ultimate | 4.149 s / 42 updates | 3,322,377,864 | 3,606,719,923 | 1,343,482,935 |
| DOOM II | 5.273 s / 42 updates | 3,964,018,837 | 4,414,519,720 | 1,422,583,665 |

Presentation-only transaction medians in the uninterrupted runs were 56.52,
53.53 and 56.37 milliseconds respectively; these include the browser test's Canvas
settling check, not merely EVM execution. Cold first target/render transactions
plus wipe initialization used 4,470,920,651 / 2,263,236,988 / 2,991,936,055 gas.
Same-source opt-out first New Game used 4,060,274,214 / 1,921,109,259 /
2,635,878,060 gas, with identical endpoint pixels. Wipe initialization added
410,646,437 / 342,127,729 / 356,057,995 gas to that first transaction, followed by
41 presentation-only transactions. The complete cold transition thus added
1.69–1.94 billion gas over the opt-out first-frame path: a material increase.

These are actual local measurements, not real-time or public-network guarantees.
42 updates at original 35-Hz sampling represent 1.2 seconds of logical presentation;
observed local wall-clock playback took longer. Continued play also persists the
last displayed 64-KiB screen for future captures. No rendering was moved off EVM.

Final runtime sizes grew from 927,930 to 933,187 bytes for Doom and from 905,156 to
913,213 for Doom2. ABI/runtime/artifact hashes and per-transaction timings/gas are
in the committed manifest and profile evidence. Compiler, optimizer, viaIR, hardfork,
resource pins, memory-policy defaults and execution budgets are unchanged.

## 9. User-visible limitations

Playback is genuinely EVM computed and transaction paced. Each step emits 64,000
indexed bytes plus 768 palette bytes and requires a mined transaction. Local Anvil
measurements do not predict public-chain throughput or wallet/RPC latency. Existing
relaxed local limits, 10-billion gas budget, pinned compiler and memory policies
are retained; no claim of standard-mainnet deployability is introduced.

Secure-context Chrome localStorage and Web Locks are required for the new browser
controller. An unresolved/evicted transaction, unavailable/pruned canonical history
or unknown-hash recovery beyond 4,096 blocks requires operator reconciliation;
there is no blind retry or automatic nonce replacement. Keep the browser journal.
Explicit pause lasts for the current document; reload continues an active wipe after
recovery. Unsupported original content remains unsupported as listed in section 2.

## 10. Deployment and update instructions

Affected contracts: `Doom` (Freedoom and pinned Ultimate E1), `Doom2`, and their
new inherited `DoomWipe`; ResourceStore/WAD schemas, EpisodeRuntime, f_wipe and
Frame/FramePalette ABIs are unchanged. Additive ABI methods are `wipeStatus()`,
`enableMeltWipe()` and `stepWipe(uint32)`; generated method selectors and bytecode
live in `web/install-assets/Doom.json` and `web/doom2-assets/Doom.json`. Matching
source/artifact hashes are in `web/install-pins.mjs` and `web/doom2-pins.mjs`.

Build and authenticate packages using the existing processes:

```sh
.toolchain/bin/forge build src/evm/Doom.sol src/evm/Doom2.sol --skip test script --no-lint
node tools/browser-deployment/package.mjs
node tools/reference/doom2/package.mjs .
```

The Freedoom packager needs the authenticated ignored local Freedoom IWAD. DOOM II
packaging ships no commercial IWAD. Keep the source tree, packages and pins together.
Update the browser modules along with the generated packages, including
`wipe-input.mjs`, `menu-input.mjs`, `menu-app.mjs`, `input-loop.mjs` and `protocol.mjs`.

**Redeployment is required to add wipes to an existing game contract.** These
contracts have no upgrade mechanism. The installer keys journals by authenticated
artifact hash and verifies the exact deployed runtime; the new release does not
reinterpret an old contract as upgraded. It can reuse authenticated resource
contracts while deploying a fresh game contract. Preserve the old installation and
its save slots; there is no automatic cross-deployment save migration. Use the
existing explicit profile-3 initializers and runtime limits; do not weaken runtime
identity/memory-policy validation. The normal menu browser opts in automatically
only after detecting v1. Existing config-based browser sessions against older
contracts remain playable without wipes; the new installer expects the new pinned
runtime. Legacy diagnostic menuMode=false controllers retain opt-out behavior.


## Verified goal handoff

Completed on `feat/browser-melt-wipe`; no main worktree modification, merge or push.
The feature commit owns Doom/Doom2/DoomWipe, browser orchestration and recovery,
focused tests/runner, two regenerated Doom deployment packages and pins, the source
mapping row, this report and `artifacts/browser-melt/` evidence. Integration owners
must preserve these commits/evidence and redeploy matching game contracts before
claiming the feature on an existing installation. Shared Frame/WAD schemas and
accepted historical evidence remain intact. No further feature work is authorized.

Measured goal start: 2026-10-13 13:53:59 UTC. User-requested benchmark pause recorded
at 14:12:17 UTC; the work resumed only after the user's “proceed.” Final three-profile
verification ended at 15:43:07.815 UTC. Primary Codex agent only, no subagents. Available
goal-service counters at the paused checkpoint: 164,433 tokens and 1,098 seconds;
no complete resumed-run billing attribution is available, and none is estimated.
Final handoff time and commit are supplied in the completion response.
