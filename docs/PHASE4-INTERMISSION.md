# Goal 4.14a — Original DOOM intermission

## Scope, ownership and baseline

Owner: this session, only `feat/phase4-intermission` in
`/Users/eduard/sandbox/doom-evm-discovery-intermission`.
Baseline: `9f7d09120a1a250fe38f85b4f4bcba6cc78b5117`.
Measured start: `2026-10-10 12:32:37 UTC`.
Original source: linuxdoom-1.10 at `a77dfb96cb91780ca334d0d4cfd86957558007e0`.

Implement independent single-player Episode One WI state, original counters,
input edges, patch presentation and indexed8 drawing. Own new WI module/types,
dedicated support/tests/native tools/fixtures/evidence and this report only.
Do not modify production adapters, Gameflow, Episode Runtime, browser, shared
types/protocols, original C, inherited fixtures or the shared Phase 4 ledger.
No level loading/progression, finale, wipes, sound/music or renderer changes.
Stop after focused verification and Gitmoji feature commits; no main integration
or push is authorized.

## Reconciliation with discovery and Goal 4.11

Goal 4.11 now provides persistent ST/HU consumer state and `FramePalette`
transport. Its world/UI dispatch is still not a WI/Gameflow lifecycle consumer.
Retain the discovery's signed WI states, canonical completion snapshot, original
fire/use latches, counters, RNG call order and source quirk: the constant
`if (commercial)` in WI_drawAnimatedBack suppresses every animation draw.
E1M8 bypasses WI in Gameflow; E1M9's supplied last/next values drive presentation.
This subsystem neither selects nor loads a next level.

Follow 4.11's declared borrowed immutable UI-resource boundary: reattach raw
graphics for drawing, persist mutable globals, and make no whole-process native
zone allocation/tag-equivalence claim. All WI load dependencies remain named and
source ordered. A completion-request result replaces the original G_WorldDone
cross-module call; a future integrator must consume it at the original boundary.
Palette restoration and full-screen dispatch remain integration requirements.

## Gates and stop condition

1. Original-C state/RNG/full indexed-frame comparisons under O0/O2/sanitizers;
   bind source spans, host adaptations, WAD and fixture hashes.
2. Build affected roots with pinned solc/viaIR/Cancun/optimizer200 and 10B budget.
   Focused Foundry state/drawing/storage/rollback tests plus relevant V/RNG tests.
3. Representative ordinary CREATE / mined EVM Frames with exact native pixels,
   state results, runtime/resource identities and rejection rollback evidence.
   Planned isolated Anvil port 18746; refuse occupied/reserved ports and stop
   only the child started by this goal.
4. Formatting, scope and evidence checks; reproducible handoff and clean tree.

No complete inherited suite or production/browser acceptance is planned.

## Progress

| Checkpoint | Implementation | Integration | Verification | Next |
|---|---|---|---|---|
| Baseline inspected | Not started | Independent boundary agreed | Clean requested baseline; AGENTS and 4.11 read | Port WI and build native oracle |
| Module/native checkpoint | Implemented | Independent explicit WI types; no production wiring | 34 original-C scenarios / 1,215 complete state and pixel snapshots; O0/O2/ASan+UBSan agree | Ordinary EVM verification |
| Focused checkpoint | Implemented | Separate-call storage host verified | 27 Forge tests passed, 0 failed, 0 skipped (11 WI, 15 video, 1 RNG) | Complete receipt evidence and handoff |
| Final verified checkpoint | Complete at `ebca08b` | Independent; production integration deferred | 28 Forge tests, 34 native/EVM scenarios, 1,215 snapshots, 30 separate persistence calls and six mined rollbacks pass | Commit evidence/report and stop after 4.14a |

Usage attribution and measured completion time will be recorded at the verified
checkpoint. No missing timing or cost measurements will be estimated.

## Integration API

`src/doom/wi_stuff_types.sol` defines independent `WiStart`, `WiPlayerStats`,
`WiInput`, `WiState` and borrowed `WiGraphics`. No shared engine type changes.
The main entry points in `WI_Stuff` are:

```solidity
WI_Start(wi, completion, input, assets, video, source);
WI_Ticker(wi, input);
WI_Drawer(wi, assets, video);
WI_loadData(assets, video, source); // rebind borrowed resources for later draws
```

Gameflow integration must copy the existing `GameflowIntermission` fields into
`WiStart`: field names and numeric domains match, including all four player
slots, frags and score. `WI_Start` aliases its memory completion object and
normalizes zero maximum kills/items/secrets to one. Retain this canonical WI
snapshot and reflect those original normalization changes in Gameflow's snapshot
if both representations remain. `epsd`, `last` and `next` are zero based.

`WiInput` carries gamemode, all four playeringame flags, each command's button
byte, original integer attackdown/usedown latches and miscellaneous `rndindex`.
Load it from authoritative engine state, then commit the changed latches and
rndindex after WI_Start/WI_Ticker. No keyboard parser, host skip command, wall
clock, gameplay RNG or pause flag is added. WI tickers advance during pause as
original G_Ticker does. A special pause packet's attack bit still accelerates WI.
Held fire/use does not synthesize another rising edge.

In GS_INTERMISSION, original G_Ticker dispatches WI_Ticker once in place of the
level/ST/AM/HU tickers. Do not also run DoomGame.tick or DoomUI.tick in that tic.
The outer runtime owns command copying and one gametic increment; this library
owns only WI's bcnt/counters. WI_Start initializes statistics, and the same outer
G_Ticker then supplies the first command to WI_Ticker as in the original.

Persist `WiState` through tics and draws. Its counters and animation state do
not restart when reattaching resources. Retain `snl_pointeron`, including drawer
mutations, across later WI_Start calls; preserve player latches. Borrow graphics
afresh per memory call instead of storing duplicate raw assets. The existing
Gameflow hook signatures have no WI context parameter: the integrator must
choose and freeze the explicit state/context extension before wiring callbacks.

Provide separate 64,000-byte screens 0 and 1. Screen 0 may alias the existing
authoritative framebuffer. WI_Start/WI_loadData draws WIMAP0 into screen 1;
WI_Drawer copies it into screen 0 before original overlay patches. The pinned
WIMAP0 covers all 64,000 pixels, so an integration consumer may reconstruct
screen 1 when borrowing assets. Preserve its backing instead for a resource
with transparent background holes. This goal does not certify arbitrary WADs.

`worldDoneRequested` becomes true exactly when the ten-tic NoState delay reaches
zero, at the original WI_End then G_WorldDone boundary. Consume that signal once
through existing G_WorldDone; the following outer G_Ticker owns G_DoWorldDone
and synchronous setup. This library never chooses, loads or advances a map.
No additional WI tick or draw is valid after the signal. Do not clear it merely
because the transaction did not render. WI_Start begins the next intermission.

At the completion boundary, suppress a new WI_Drawer. A rendered-command
transport may emit the retained, previously EVM-generated framebuffer, or use
its agreed no-frame route. Do not execute an extra gameplay tic or load the next
level early to manufacture a new image. The support receipt host publishes the
retained native-defined buffer on that boundary and tests its unchanged pixels.

Production display must select WI_Drawer for GS_INTERMISSION, replacing the
world/status/HUD drawing for that frame, and restore base PLAYPAL through the
existing Goal 4.11 FramePalette transport with the selected original gamma.
Keep Status Bar statics intact. WI returns indexed pixels and does not emit or
select palettes. Episode Runtime owns the map load and per-level resets.

E1M3 secret entry and E1M9 return are presentation of caller-supplied last/next
values, including original cumulative splat placement and didsecret timing.
Do not add a visited-map bitmap. Original Gameflow bypasses WI on E1M8; no
E1M8 statistics/finale/progression endpoint is installed by this goal.

## Source mapping and bounded behavior

The native manifest binds exact original function spans/hashes for 28 WI
functions. All supported functions retain their original names in wi_stuff.sol.
The active single-player E1 branches preserve layout, integer counters, stage
order and miscellaneous RNG consumption. All ten E1 animations have the
original period 35/3=11, three frames, nexttic equality and frame cycling.
`WI_drawAnimatedBack` retains the pinned `if (commercial)` constant-return bug;
animation updates and all resource loads still execute. Unused anim_t
lastdrawn/state fields and other-episode animation tables do not affect this
profile. Network/deathmatch branches and all audio are excluded permanently.

The resource manifest records all 79 original loader dependencies and their
original full-WAD IDs/hashes. Real Freedoom pointer/splat/animation patches are
transparent placeholders; separate synthetic resources prove visible placement,
second-candidate fallback and both-candidate no-draw behavior. Synthetic assets
are never relabeled original-WAD graphics. WI numeric rendering preserves -1
hidden counters, the 1994 sentinel, negative-number minus positioning, integer
percentages above 100, time/par counting and WISUCKS above 3,599 seconds.

Only Episode One, console player 0 and modes shareware/registered/retail are
supported. All nonzero secondary playeringame flags reject. Negative totals or
time, overflowing signed percentage numerators, invalid indexes/RNG and the
counter-overflow boundary reject explicitly. Original abs(INT_MIN) and the
single-pointer splat fallback past &splat reject instead of native undefined
accesses. The existing video primitive supplies malformed-patch/physical bounds
rejection; valid original out-of-screen ignore behavior remains unchanged.

Discovery correction: WI_End frees lnames, so a WI_Drawer after the completion
signal would read freed original memory. The initial native attempt demonstrated
this with O0 SIGSEGV and ASan heap-use-after-free in WI_drawEL. The oracle excludes
that undefined drawing boundary and retains the previously generated framebuffer;
the Solidity drawer rejects it. No original C or accepted fixture was modified,
and no sanitizer check was disabled to hide this finding. The failed checkpoint
is retained locally in artifacts/local/intermission/native-attempt-1.json.

Following Goal 4.11, WI graphics borrow immutable bytes; WI_unloadData is an
explicit lifetime adaptation, not native allocation/tag equivalence. The native
host owns/frees the nine-pointer lnames allocation and keeps borrowed lump bytes
alive; its Z_ChangeTag and audio/platform boundaries are inert. Existing native
zone semantics and production adapters remain untouched. Full screen melts and
their presentation/RNG timeline belong to a later display integration goal.

## Verification and measured checkpoint

Final focused gate: **28 passed, 0 failed, 0 skipped**: 12 WI tests plus the
unchanged 15 video tests and one independent-stream RNG test. The WI tests
compare all 1,215 native observations, including all 113 exported state words,
dirty rectangles and full screen0/screen1 digests. Separate storage calls compare
native state and completion guards; malformed background resources, invalid
input/driver/sequence and post-completion operations roll back. Formatting and
syntax/scope checks pass. The original CRLF Freedoom license is retained byte
for byte; the Git whitespace check uses `core.whitespace=cr-at-eol` for that file. See [focused evidence](../artifacts/phase4/intermission/focused.json)
and [complete log](../artifacts/phase4/intermission/focused.log).

The original-C oracle reproduces **34 scenarios / 1,215 snapshots** under O0,
O2 and ASan/UBSan with exact agreement. It was regenerated and checked against
the committed-to-be fixtures without changing original source. It covers every
finished/entering E1 title, all nodes, zero denominators, counting stage/timing
boundaries, both time-format boundaries, input edge behavior, secret entry/return,
repeated intermission statics/RNG, candidate fallback and the animation quirk.
See [native identity/mapping](../test/fixtures/phase4_intermission/native.json).
These are controlled WI inputs; no actual level completion/playthrough is claimed.

Final ordinary-EVM gate: **44 ResourceStore CREATEs**, four ordinary support-host
CREATEs, **34 exact 64,000-index Frame comparisons**, **1,215 native snapshot
comparisons**, **30 separate persistence calls** (including repeated WI_Start)
and **six mined, full-storage-root rollback checks**. Every resource runtime and
the final compiled WI runtime with actual immutable driver are byte-checked.
The runner owns/stops only its Anvil child on 18746. See
[EVM receipts](../artifacts/phase4/intermission/evm.json).
The earlier successful source checkpoint is preserved separately in
[evm-before-format.json](../artifacts/phase4/intermission/evm-before-format.json).

The final gate ran `2026-10-10T13:07:38.230Z` to
`2026-10-10T13:07:44.842Z`. Support runtime is **37,453 bytes**, under the existing
local code-size policy; this is not a mainnet deployment-size claim. Original
Solc0.8.37/viaIR/optimizer200/Cancun and 10,000,000,000 gas budget are unchanged.

| Measured support operation | Gas |
|---|---:|
| Resource deployment, all four fixture profiles combined | 154,070,054 cumulative |
| Support-host CREATE | 10,267,869–10,449,412 |
| Complete scripted scenario, state observations, storage and Frame | 36,716,143–269,766,699 |
| Separate begin/action persistence call | 31,186,166–77,999,658 |

Scripted scenario receipt latency samples are 52.423–215.179 ms. These include
client/RPC/mining and are not isolated drawing costs or a 35Hz/production claim.
Full-bundle lookup, integrated world/UI storage, peak EVM memory and whole-episode
costs remain unmeasured here. No resource, compiler or execution-budget change
was made to obtain a pass.

Three review PNGs expand **actual receipt pixels** with the WAD base palette:
[statistics](../artifacts/phase4/intermission/statistics.png),
[next-map](../artifacts/phase4/intermission/next-map.png), and
[secret return](../artifacts/phase4/intermission/secret-return.png).
The last uses explicitly synthetic visible markers. PNG RGB is a review aid;
indexed8 bytes are the verified claim. No browser/HTML/CSS/Canvas UI was added.

Initial failed checkpoints remain failed: the native post-free draw described
above; Foundry's default dynamic test-linking artifact read rejection; and an
invalid-RNG test setup that normalized its invalid index before the guarded
entry point. Correcting the test setup and choosing ordinary test CREATEs passed
the gates without weakening assertions. Local network verification initially
failed under the sandbox, then succeeded through the authorized verifier. The
complete inherited suite and production/browser acceptance were not run.

Verified checkpoint measured at `2026-10-10 13:10:59 UTC`. The goal tool reports
192,633 tokens and 2,302 elapsed seconds at that checkpoint. These are available
aggregate counters; no missing dollar, peak-memory or other usage measurement
is estimated. Final handoff timing follows feature/evidence commits in the
session completion record.

## Handoff boundary

Implementation/native-test commit: **`ebca08be66e783019ade6198fb75285215777324`**.
Subsequent evidence/report work remains on `feat/phase4-intermission`; its exact
SHA is recorded in the session handoff. The certificate binds the implementation
commit and final source/evidence hashes. Only new WI module/types, WI-only support/tests/fixtures,
tools/evidence and this report are owned changes. The designated integrator
reconciles this component report into the shared Phase 4 ledger.

Reproduce with [the verification README](../tools/reference/intermission/README.md).
The [certificate](../artifacts/phase4/intermission/verification.json) checker
validates recorded source/evidence identities and
protected-baseline equality; it does not replace executing the native/Forge/EVM
gates. Integration still requires explicit WI context access in Gameflow,
authoritative snapshot/button/latch/RNG copying, completion-signal consumption,
palette/full-screen dispatch and synchronous Episode Runtime loading. Resource
authentication belongs to the existing full-bundle owner; the support fixture
view does not establish a production resource authenticator.

Goal 4.14a implements and verifies independent intermission behavior. Full finale,
screen melts, level progression/loading and production/browser wiring remain
separate future goals. No main change, merge or push is part of this handoff.
