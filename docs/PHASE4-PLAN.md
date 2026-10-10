# Phase 4 progress ledger

Current UI checkpoint: **Goal4.11 Production UI is integrated into main and
verified in the declared E1M1 profile; clients must opt in with productionUI:true.**
Earlier source-only wave records remain historical; broader Phase4 production
lifecycle and final acceptance remain pending. See the latest checkpoint below.

Current integration: **Wave2 source Goals4.4 (Cheats),4.5 (Automap) and4.7a
(Episode resources) are integrated and verified within module/support scope.**
Production integration remains pending. The newest Wave2 checkpoint below is
authoritative; feature handoffs and their earlier no-merge/stop boundaries are
retained as historical records.

## Goal 4.7a — Episode One resources (complete)

Current user-defined milestone: prepare and verify all E1M1–E1M9 resources.
This supersedes the older extra plan's 4.7a startup/frame split for this task.
No gameplay startup, level progression, transition, intermission, renderer
algorithm, browser WAD upload, sound or other-episode support was implemented.

Feature worktree `/Users/eduard/sandbox/doom-evm-multimap`, branch
`feat/phase4-multimap`, baseline `9f98ed1d38e6de3f2577f5d76b07ec136fc70d52`.
The baseline includes the Status Bar integration received during the pause.
Implementation/evidence commit **b6debb2** is verified; this handoff adds the
final ownership/requirements certificate. Nothing is merged into main.

| Deliverable | Implementation | Verification | Remaining |
|---|---|---|---|
| Nine-map parser/packer tooling | Additive v1 catalog and nine map descriptor files, unchanged v0 bundle/palette | Every map file regenerated, repeated packing exact, all ten lump bytes/IDs/names/offsets/checksums verified | None |
| Shared resources and provenance | Original texture/PNAMES precedence, flat/sprite indices and opaque resources preserved | Original bundle identity exact; native shared lookup/composite/flat/sprite fixture exact | None |
| Native C comparisons | Seven verbatim geometry loaders, P_LoadBlockMap, original mapthing_t, raw REJECT/lumps | All nine maps, every runtime geometry field and raw lump; O0/O2/UBSan-except-shift agree | None |
| Focused tests | 18 new episode tests, existing parser/resource tests retained | 69 Node tests (51 existing + 18 new), four targeted Foundry resource tests pass, zero failure/skip | None |
| Packaging and ordinary EVM costs | Three pack runs, isolated full resource CREATE deployment, separate resource-only harness | 1,755 exact runtimes, nine mined native-equal map receipts, one mined other-episode rejection | None |
| Integration contract and boundaries | Versioned schema, packEpisode/verifyEpisode APIs and resource handoff document | 1,622 protected baseline files exact; production adapters/compiler/browser/history unchanged | None |

The resource identity remains the accepted WAD
`7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d`, bundle
`d379076f21645cf7cc5acb056663d0faacc4065489a0ca99738479323c9f7a47`, palette
`fd895921b5d0a394612bb29852ed003d44d69f76dec31c0dc6b5d5fc7d63f7bb` variant zero.
Catalog SHA-256:
`1af6a076fdf0427be1df9beae42c8f87a931058fed89d1f104543eb8b1188c9e`.
All maps share the original 28,741,889-byte blob; their ten-lump payloads total
2,190,770 bytes. Packaging measured 1.67–1.74 seconds across three in-process
runs, excluding writes. RSS snapshots and per-map descriptor/chunk/dependency
costs are recorded without claiming isolated peak memory.

Ordinary full-blob deployment: 6,271,928,016 cumulative gas across 1,755 CREATEs.
Probe CREATE: 3,413,631 gas. Lazy resource initialization: 47,204,473 gas.
Map operation: 102,778,863–538,495,563 gas. Whole map verification receipts:
238,852,926–984,718,924 gas, including calldata/decoding, initialization,
serialization/checksums and event work. These are resource support measurements,
not production storage-backed startup or gameplay/frame costs. The isolated
node used port18747 and was stopped; existing nodes were not reused.

The native reference reuses the accepted explicit disk/allocator/64-bit-pointer
adapter. Original signed negative shifts remain pinned-profile extensions;
UBSan shift checks are excluded for the mixed map/sprite/BLOCKMAP run. THINGS
retain every signed disk field without spawning/filtering. No complete
multi-level gameplay or episode acceptance is claimed. The full inherited
regression suite was not run, as explicitly requested.

Handoff: [resource integration contract](PHASE4-EPISODE-RESOURCES.md),
[native comparison](../artifacts/phase4/episode-native-comparison.json),
[packaging measurements](../artifacts/phase4/episode-packaging.json),
[ordinary EVM evidence](../artifacts/phase4/episode-evm.json),
[requirements and ownership certificate](../artifacts/phase4/episode-verification.json).
Reproduce with the focused commands in the contract; validate current source
bindings with `python3 tools/reference/episode/checkpoint.py --check`.

Remaining Goal4.7a work/blockers: **none**. Future goals own level startup,
native zone setup/reset, collision-state initialization, gameplay spawning and
progression. **Stop after4.7a; do not automatically proceed or merge main.**

Phase 3 is complete and remains accepted. Optional Phase 4 work follows
[the extra plan](04-IMPLEMENTATION-PLAN-EXTRA.md). **Goals 4.0 and 4.1 are complete and verified.
The Goal 4.0a architectural review is complete, accepted and integrated.
Completed Goals 4.2 (Status Bar), 4.3 (HUD) and 4.6 (Gameflow) are merged into
main; the current integration checkpoints are recorded below.**
The checkpoints below are historical; their authorization, ownership and stop
boundaries describe the tasks at the time they were recorded. The latest user
request authorizes integration of the completed Status Bar branch on top of the
accepted HUD, Gameflow and Astra audit work. Only the main worktree is modified.
Production adapter integration remains a separate goal and has not begun.

## Recovery checkpoint

Baseline HEAD38d8a4392b21e2c78a1977d381bedf6e1cd5e6c7; tag
`phase3-accepted-38d8a43`. All accepted engine source fingerprints match
`artifacts/phase3/acceptance.json`. Engine, renderer, gameplay, existing tests,
compiler settings and historical exports are read-only for this task.
User-provided extra plan is preserved at its requested 04 filename; its internal
03 placement suggestion is not used to rename the supplied file.

Goal 4.0 active start: 2026-10-10T05:01:34Z, structured goal createdAt 1791608494.
A new explicit usage window is added without editing Phase 0–3 boundaries.
Only tools/usage/**, new telemetry evidence and documentation are owned.

## Implementation vs verification

| Deliverable | Implementation | Verification/acceptance |
|---|---|---|
| Existing token accounting and historical preservation | Baseline unchanged |20 prior tests PASS; exact legacy/new token rows/totals/model-agent aggregates/segments and all historical Phase 0–3 rows verified |
| Compaction metadata/durations | Implemented side adapter, ID/fork/duplicate guards, unique same-turn interval join |17 explicit compacted and 17 timed ContextCompaction items observed; pair by unique same-thread/same-turn interval. Dedicated before/after context size absent |
| Human approval latency | Implemented explicit lifecycle/provenance parser |No explicit approval lifecycle records in current selected logs; policy/escalation intent is not a human wait |
| Compilation/test/tool duration separation | Implemented compiler/test/stage/envelope separation |Structured completed CommandExecution duration, terminal code and stdout stage summaries available; avoid wrapper/child/stage double counting |
| Goals, JSON/CSV schemas and human report | v2 additive schema, five new CSVs, metadata report and schema/privacy checker implemented |50 focused tests PASS; source/schema/CSV/privacy and exact token comparison verified; article/export handoff committed25ebf8b |
| Historical Phases0–3 recovery | Programmatic first scan complete |Recover only available measurements; old artifacts/boundaries/totals retained |

## Remaining work and blockers

None. Goal 4.0 is complete, verified and published. All implementation,
integration, evidence/schema/privacy tests, preserved-history comparison and
report/export handoff passed. Stop; no memory audit or other Phase 4 work began.

Original Phase 4 forecast remains unchanged: 25h elapsed, 17–38h plausible band,
50h+ adverse tail; separate 4.0a estimate 1–3h. Actual measured goal durations belong
in telemetry, not retrospective edits to that forecast.

## Verified parser checkpoint `f7c360b`

`python3 -m unittest discover -s tools/usage -p 'test_*.py'`:47 passed; all 20
existing cases retained plus 27 new activity cases. `validate.py` reconciles v2
JSON/metadata privacy and every new CSV field. A separate source-loaded 38d8a43
collector comparison proves all closed token records/totals/phase/model/agent
aggregates/segments exact; Phase 0–3 published rows also exact. Sources unchanged
under src/, test/, web/, scripts/ and every prior historical artifact.

New module handles measured compaction intervals, nullable dedicated context
sizes, request input as a separate metric, explicit human/auto/unknown approval
resolver, reported Solc stages including millisecond units, overall test-wall
summaries (not per-suite CPU), compiler-cache skipped zero, explicit nested
process links and concurrent interval unions. No raw messages/objectives/commands/
output exported. No full Forge/native/Chrome rerun needed for this isolated task.

## Focused metadata-hardening checkpoint `06c238a`

49 unique tests pass (20 unchanged accounting tests plus 29 activity tests).
Additional checks cover schema/privacy/CSV reconciliation, invalid dedicated
context sizes/timestamps, sequential stage sum conflicts and matching-turn model
attribution. Mixed shell envelopes remain distinct from direct Forge duration.
Missing/redirected stage output stays unknown; explicit skipped compilation is
known zero. Exact nested parent links exclude extra execution/compile charges;
containment/concurrency alone is not called a parent relationship.

## Final focused recovery status (verified)

50 unique tests pass:20 existing token tests plus30 new telemetry cases. Exact
source-loaded legacy comparison preserves every closed token record, total,
model/agent aggregate and segment. All published Phase0–3 token rows/boundaries
are unchanged. V2 JSON/CSV validation and transcript-key exclusion pass.

Historical recovery:17 compactions/17 matched durations; Phase2=5, Phase3=9,
telemetry=1, gaps=2, Phase0/1=0 observed. Phase3 root=3, input/interface/reference
agents=2 each. Dedicated before/after context sizes missing in all17. Explicit
approval lifecycle absent; actual human/auto waits remain unknown, not zero.
Compilation/test timing is a known subset; invisible/redirected stages remain
missing and per-suite CPU is never summed as wall time.

Current article/report and additive metadata-only exports live at
[CODEX-TELEMETRY-2.md](CODEX-TELEMETRY-2.md) and artifacts/usage/telemetry2/.
All prior exports remain intact. Final tests/baseline/ownership/source checks PASS; publication25ebf8b and
accepted baseline tag are pushed. No further Phase4 goal is authorized.

## Final verification and handoff

[Validation evidence](../artifacts/usage/telemetry2-validation.json) records50
passing tests, new JSON/CSV/privacy validation, exact legacy/new token rows/
totals/phase/model-agent aggregates/segments, unchanged historical boundaries,
and protected source/export fingerprints. Code hardening retains original
reported stage values alongside validated subtotals and a declared0.5s timer
consistency tolerance; no value is adjusted or estimated.

Implementation, integration and verification for Goal4.0 are complete. Implementation checkpoint `f57acd8` and separate report/export checkpoint
`25ebf8b` are verified and published. Observability gaps are
limitations, not blockers or invented measurements. Stop after publication;
Goal4.0a and all other optional Phase4 work remain unstarted.

## Published checkpoint `25ebf8b`

Complete v2 collector,50 focused tests, formal JSON/CSV contracts, unchanged
legacy accounting/historical data, recovered Phase0–3 metadata, human report
and limitations are committed/pushed. Origin/main and baseline tag verified.
No engine, renderer, gameplay, original acceptance test, compiler or prior
export was modified. Goal4.0a and every other optional improvement remain
unstarted. Stop here; no current blocker or remaining implementation work.

## Actual goal completion

Start2026-10-10T05:01:34Z; completion2026-10-10T05:57:49Z, structured tool
updatedAt1791611869. Measured timestamp interval3375s; separate goal counter
3374s (about56m) and566,101 tokens. Counters are never added to response usage.
[Closure record](../artifacts/usage/goal4.0-completion.json). The phase window now
has the actual completion endpoint; previous Phase0–3 windows remain identical.
Published telemetry/report remains an as-of snapshot and is not overwritten;
current unflushed usage or later accounting publication is not estimated.
Stop at4.0. No audit/refactor/other Phase4 task is active.


## Goal 4.1 — Video primitives (complete)

Start 2026-10-10T07:54:16Z (structured createdAt 1791618856).
Baseline `b16c2a4`; clean main confirmed. Historical Phase 0–3 certificates and
post-acceptance DrawBounds evidence remain unchanged. Astra's independent
worktree/branch/audit is outside this goal and has not been inspected or modified.

Ownership: new `src/doom/v_video.sol`, `v_video_types.sol`, video-only support,
new focused unit/integration tests, `tools/reference/video/`,
`test/fixtures/phase4_video/`, new Phase 4 evidence, PORTING.md and this ledger.
One independent native-oracle agent owns only the reference/fixture directories;
the integrator owns shared interfaces, tests, support and documentation.

| Deliverable | Implementation | Integration | Verification | Remaining |
|---|---|---|---|---|
| Eight original V_* functions and header globals | Implemented | Memory-only VideoState, no engine changes | 15 focused tests, 58 native cases pass | Complete |
| Real WAD patch/native oracle | Implemented | Separate original-C host | O0/O2/sanitizers exact; rebuild/check pass | Complete |
| Renderer/frame compatibility | Implemented | Existing resource reader + screen0 alias + frozen Frame | Two Foundry cases, seven ordinary Frame receipts, legacy world case pass | Complete |
| Source mapping/evidence | Implemented | Separate Phase 4 artifacts; frozen history unchanged | Integrity/source mapping check passes | Complete |

Original RANGECHECK patch behavior is retained: normal/direct out-of-box patches
are ignored, flipped patches error; original v_video has no partial clipping or
scaling. The upcoming 320x168 view still uses a 320x200 framebuffer. No status
bar/HUD/automap/intermission or palette/gamma presentation is implemented.
Negative rectangle dimensions, malformed patches, invalid physical backing and
partial overlapping row memcpy are explicitly rejected, not clamped.

Planned gates: focused video/native cases, affected bbox/draw/backing tests,
targeted Frame/resource/renderer integration, one accepted world-frame case,
format/source-evidence integrity. Full inherited Phase 0–3 runs are deferred to
final Phase 4 acceptance per user instruction. No blockers currently.
Stop after verified commit/push and Goal 4.1 handoff; do not enter Goal 4.2.


### Verified video/interface checkpoint

`python3 tools/reference/video/reference.py --check`: 58 cases x three native
profiles agree. Six authentic patches plus synthetic transparency/offset/post
cases; all five native buffers and dirty/GetBlock hashes compared. Native
function spans/source hashes are in the fixture manifest. 15 video unit tests
and two resource/Frame/render-buffer integration tests pass; malformed fuzz
runs256. Command: `forge test --match-path
'test/{unit/v_video,integration/VideoPrimitives}.t.sol' --skip Doom
--skip GameplayProbe --skip RendererProbe --skip WadResourcesProbe -vv`.
The skips exclude unrelated build roots, not any test within this gate.
Pinned compiler/settings remain unchanged. Full logs are ignored local files
under artifacts/local/video; final evidence will bind their numeric summaries.

Initial harness-only failures were corrected without changing native goldens:
unused patchId=-1 now avoids a file lookup; the independent integration
expectation now decodes face offsets as signed shorts. All17 assertions pass
on the current sources. No completed workstream is left as an unverified batch.
Acceptance of Goal4.1 is still pending ordinary receipts/dependency/legacy
world checks and final integrity/source mapping. No actual blocker.


### Goal 4.1 final verification and handoff

Implementation/interface/native checkpoint **498081bd591c64f0aac4785cc1241f881718a250**.
All applicable Goal4.1 gates passed. Source files and fixtures remain at that
verified checkpoint; final publication adds reproducible receipt tooling,
separate verification/mapping evidence and this handoff.

- Native:58 cases x O0/O2/sanitizers agree;48 successful cases compare five
  screen buffers/dirty/GetBlock against Solidity,10 original error cases match
  control/rejection behavior. Six authentic Freedoom patches and synthetic
  transparent/offset/post data; provenance/license preserved.
- Foundry:17 new focused tests (15 unit incl256 malformed fuzz runs;2 integration),
  33 directly affected existing tests (bbox/draw/backing/initialized-zone/WAD
  source/Frame),1 unchanged accepted static full-world angle0 test. **51 pass,
  none fail/skip.** No inherited test/assertion changed.
- Ordinary isolated Anvil:seven complete320x200 Frame receipts, six exact
  original-C patch frames (384,000 pixels), one168-world/status32 composition
  (64,000 pixels), malformed mined revert with no Frame/counter mutation.
  ResourceStore ordinary CREATE and R_Data reads retain byte identity;
  WIMAP0 crosses five chunks. Production UI dispatch is not integrated.
- Source integrity:all eight original function spans/current bindings recorded;
  every existing engine source, accepted test, browser, compiler/budget and
  Phase0–3/DrawBounds certificate is unchanged relative to baseline b16c2a4.
  This is separate Phase4 evidence, not a revision of historical acceptance.
- Measured support transactions25,454,065–47,461,948 gas; probe CREATE1,115,987.
  These include setup/resource/event work and are not production-engine or
  isolated primitive costs. Pinned Solc0.8.37/viaIR/opt200/Cancun and configurable
  10B budget unchanged. Isolated node18694 stopped; original live node untouched.

Evidence: [video verification](../artifacts/phase4/video-verification.json),
[source map](../artifacts/phase4/video-source-map.json),
[ordinary receipts](../artifacts/phase4/video-evm.json),
[behavior and deviations](PHASE4-VIDEO.md).
Rebuild native with `python3 tools/reference/video/reference.py --check`;
validate frozen source/proof bindings with
`python3 tools/reference/video/checkpoint.py --check`.
The receipt runner consumes existing build artifacts and starts/stops only its
own fresh Anvil; no private live-state capture is required.

Full inherited Phase0–3 suite and actual browser UI acceptance are deferred to
final Phase4 acceptance by explicit user instruction. No phase acceptance or
arbitrary-WAD/undefined-C/contiguous-pointer equivalence is claimed. The native
sanitizer's variable column-table array-bounds and unsupported leak-detection
exclusions are documented. Gamma/palette presentation remains for4.2.

Verified publication **db200bdd3b13b9c0063c5138b2f1bd981e2ca38f** is pushed to origin/main,
following implementation checkpoint498081b. Actual structured closure:
2026-10-10T08:13:29Z; elapsed1153s (19m13s),211,052 separate goal-counter tokens.
[Closure record](../artifacts/phase4/goal4.1-completion.json). These counters are
not per-category/session/agent telemetry and must never be added to it.
The worktree was clean at verified publication; this final metadata-only
checkpoint records closure without altering source or proof bindings.

Remaining Goal4.1 work/blockers: **none**. Astra's independent worktree/audit was
not inspected, modified or waited on. All later features remain unstarted.
Recommended4.2 entry: original st_lib widget drawing through VideoState,
consumer-owned320x32 screen4, then st_stuff face/state and explicitly selected
168-row world mode; retain legacy fullscreen and design palette transport
separately. **Stop at4.1; do not automatically proceed.**

Model/agent attribution: root integrator plus one independent inherited-model
native-oracle worker `/root/video_native`; precise runtime model identifier and
per-agent token category totals are not exposed by the goal counter. The actual
structured closure counter is recorded separately and must not be added to
collector input/cached/output/reasoning totals. No session transcript was read.

## Goal 4.0a — Architectural review checkpoint

Goal start: 2026-10-10T07:51:36Z (structured goal createdAt 1791618696).
Review: one Codex agent in this session; no subagents or model comparison.
This checkpoint makes no independently verified model-variant attribution.

Worktree: /Users/eduard/sandbox/doom-evm-memory-audit.
Branch: audit/phase4-memory.
Base: b16c2a49cf40f3952f4d8322b30ac261c9375d29, containing the BLUDA0 fix
79b93e7413bdd2569b108993580e753fbd01252f and its verification ledger.

The user redirected the initial correctness brief to **architectural evaluation**.
Accepted correctness is assumed. Existing reports/evidence are trusted architectural
inputs. Focused verification performed before the redirect is not used as an
argument for architectural superiority; no tests were started after the redirect.

| Deliverable | Implementation/documentation status | Review status |
|---|---|---|
| [Independent memory architecture review](PHASE4-MEMORY-AUDIT.md) | Complete; nine requested sections, alternatives and comparative matrices | Architectural judgment complete; no new engine acceptance or alternative benchmark claimed |
| Recommendation | **B: keep the hybrid, simplify specific components** | Canonical ABI definitions and shared cache ownership operation recommended; full heap replacement not justified |
| Engine / renderer / gameplay / existing tests / historical certificates | No audit changes | Existing acceptance remains unchanged by this task |
| Further Phase 4 implementation | Not started by this audit | No implementation action authorized by this checkpoint |

The current implementation is already a sparse hybrid, not a full native byte heap.
Some allocation geometry and history must remain observable to preserve the chosen
native-profile pixels. Logical-only resources or synthetic padding change that
contract; a complete byte heap adds unnecessary integration cost for present needs.
Separate active topology and compact write-history ranges remain a possible later
representation choice, contingent on a concrete cost reason.

Only the report and this ledger checkpoint are to be committed. Earlier ignored
diagnostic scratch remains local to the isolated worktree and is not delivered.
No cherry-pick, merge, rebase or push is part of this audit. Stop after the
documentation commit and return the recommendation for human review.

Report finalized: 2026-10-10T08:20:51Z.
The documentation commit containing this checkpoint is the audit handoff; no
engine implementation or further goal follows it. Goal-tool closure is recorded
separately after the commit, not inferred from this timestamp.

### Accepted audit documentation integration — 2026-10-10

The user accepted the architectural review and authorized its documentation-only
cherry-pick from audit/phase4-memory into main. Original audit commit:
`28cf8e23bc5d257012b9143720480c85b01837bf`.
Main integration baseline: `084764b9fed601666b5a9d82dcf84325ca6bbfbf`.

The [accepted report](PHASE4-MEMORY-AUDIT.md) is preserved byte-for-byte from
that audit commit, including recommendation **B: keep the hybrid, simplify
specific components**. The ledger conflict is resolved by retaining all existing
Goal 4.0 and Goal 4.1 checkpoint text and appending the original Goal 4.0a handoff.
Its no-integration/no-push boundary applied to the completed audit; this later
request authorizes only publication of the accepted documentation.

Only this ledger and the audit report are included in the integration commit.
Documentation validation covers the file scope, unchanged report, retained
checkpoints, local Markdown targets and source line references. No Foundry,
Solidity compilation, native verification or regression suite is run. No engine,
test, fixture, verification infrastructure or historical acceptance certificate
is changed. The Status Bar, HUD and Gameflow worktrees and branches are untouched.
The commit containing this checkpoint records the integration; no development
or refactoring follows from it.


## Goals 4.3 and 4.6 — Verified main integration (2026-10-10)

Authorized scope: merge the independently verified HUD and Gameflow branches,
preserve their commits and evidence, perform focused integration/dependency
verification, update this ledger, commit and push main. No new feature or
production adapter wiring is part of this checkpoint. Goal 4.2 (Status Bar)
continues independently; its branch and worktree were not modified.

Clean main and remote main were checked before merging: baseline
`9a5da1a0374916e38a2813467a943b2934b1a3b0`, including Astra's accepted memory audit.
A subsequent refresh confirmed origin/main still at that baseline. The audit
commit/report and all earlier progress checkpoint sections remain preserved.
Neither reset nor rebase was used.

| Deliverable | Implementation | Main integration | Verification/acceptance | Remaining |
|---|---|---|---|---|
| Goal 4.3 HUD messages/text widgets | Complete at `2a35bf0851591fc03ec372130a3805b17f09f01c` | Merge `6875795efa050a4cb7292e39c12bc8dd76ba0313`; all 83 changed files exact | 14 focused tests; 209 native scenarios / 575 snapshots; 44 gameplay producer frame comparisons | Production composition deferred |
| Goal 4.6 Episode One gameflow | Complete at `7cc1fd3ca9430597ce7ea84de0ab4c39ac27972a` | Merge `01de4fa8dd9c14e2da7957a59df58e378e69c6e4`; all 22 changed files exact | 14 dedicated tests plus 14 inherited input tests; 219 native cases; E1M1 setup/first-tic native state proof and lifecycle invariants | Production persistence/hooks and later map/presentation goals deferred |
| Combined modules and affected dependencies | No integration source changes needed | Conflict-free; both original commits remain ancestors of main | 86 tests across 14 suites pass, 0 fail/skip; combined pinned Solidity compilation succeeds | No blocker to this merge/publication |
| Historical evidence and audit | Existing contents retained | Separate integration certificate; original feature certificates unchanged | Branch file/certificate hashes, all baseline files except authorized g_game/ledger edits, and all historical ledger sections checked | Complete |

The branches have no overlapping changed paths. `HudState`/`HuSText` are owned by
HUD; `GameflowState`/`GameflowHooks` are owned by gameflow. Existing `GameState`,
`Player`, `VideoState`, renderer/resource layouts, Frame/input ABI, compiler and
execution budget stay unchanged. HUD consumes the existing console
`Player.message`; gameflow calls ST/AM/HU hooks in that order, including paused
level tics. There is no conflicting shared-interface change and no implicit
production dispatch. The existing keyboard builder/rebirth/exit helpers are
retained and pass their affected inherited tests.

Risk-based verification follows section 5 of the extra plan. The combined gate
runs all HUD/gameflow tests and affected keyboard, lifecycle, player, pickup,
ticker, video/resource-composition and Frame tests. **86 pass, none fail/skip**;
HUD capacity and video malformed-patch fuzzing each run 256 cases with fixed
seed `0x4346`. The 89-file compile uses unchanged Solc 0.8.37, viaIR, optimizer
200 and Cancun settings; reported compiler time is 153.04s, test wall time
2.04s. The explicit build of g_game/hu_lib/hu_stuff roots passes with the same
cache (no second compilation). Compiler identifier/shadowing/mutability warnings
remain warnings; no settings or assertions were relaxed.

Original-C HUD and gameflow checks reproduce all three profiles exactly.
The inherited input oracle reproduces 41,007 vectors. Observation-schema and
legacy serializer/fixture provenance checks, focused formatting, original
feature certificate bindings and preserved baseline file checks also pass.
Branch-specific certificate generators enforce their original isolated-branch
ownership and are not rerun to overwrite historical evidence after integration.
The new [integration certificate](../artifacts/phase4/hud-gameflow-integration.json)
records commands, results, source hashes and preservation checks. Original
[HUD evidence](../artifacts/phase4/hud/verification.json),
[gameflow evidence](../artifacts/phase4/gameflow-verification.json),
[HUD handoff](PHASE4-HUD.md) and [gameflow handoff](PHASE4-GAMEFLOW.md) are exact.

Remaining integration dependencies: finish and independently verify Goal 4.2;
then authorize the separate production adapter goal. That goal must persist HUD,
GameState/GameflowState and mutable difficulty definitions atomically; rebind
hooks after load; preserve one command/build/ticker/gametic path; and provide
synchronous setup, status/HUD lifecycle and selected input/UI composition.
Multi-map resources, automap, intermission/finale presentation and final episode
acceptance remain later goals. Full inherited Phase 0–3 and browser/ordinary-RPC
acceptance are deferred; this checkpoint makes no new production/browser proof.

The commit containing this checkpoint and the separate integration certificate
is the integration-specific publication. Stop after committing and pushing
verified main; no Status Bar or production adapter development follows.


## Goal 4.2 — Verified Status Bar main integration (2026-10-10)

Authorized scope: integrate the completed `feat/phase4-statusbar` into latest
main, preserve original commits and accepted work, run focused dependency and
targeted EVM verification, update this ledger, commit and push verified main.
Only this main worktree is modified. No production adapter wiring, new feature,
other agent worktree change, force-push or history rewrite is part of this goal.

Clean main and refreshed origin/main both matched
`6d7630e603efd5f2c596fcc01d91a8521fcc3270` before merging. This includes the
verified HUD/Gameflow integration and Astra's audit `9a5da1a`.
Original feature commit **87d422f059e32b0b43555fc4287efc48488af6fa** is preserved
as the second parent of merge **0729a9276db15df0b2d16a84153146af2a607d0e**.
The merge had no conflicts. All 170 feature files are byte-identical to the
completed branch. Before ledger updates, all 1,452 pre-existing tracked files
were unchanged; all historical checkpoint sections remain exact afterward.

| Deliverable | Implementation | Main integration | Verification/acceptance | Remaining |
|---|---|---|---|---|
| Goal 4.2 original widgets/status bar | Complete at `87d422f` | Conflict-free additive merge; original commit preserved | All 17 original focused tests pass; 1,299 native steps / 11 sequences agree across O0/O2/ASan+UBSan | Module integration complete |
| World/status composition and legacy mode | Existing renderer plus unchanged new consumer | 320x168 world + status32, frozen 320x200 Frame ABI | Exact native complete frame and unchanged legacy fullscreen golden; targeted view modes 10/11 and invalid-domain checks pass | Production view/UI lifecycle deferred |
| HUD, Gameflow and affected dependencies | Existing accepted implementation retained | No shared layout, engine or adapter change | 58 additional tests pass: HUD14, Gameflow14, video17, resources6, Frame3, RNG1, view-size3 | Production callback/persistence binding deferred |
| Ordinary EVM Frame/palette and rollback | Existing dedicated test consumer, no production endpoint | Isolated Anvil port18696; own node stopped | Three native-matching mined frames (192,000 pixels) and palettes; malformed mined revert has no logs/counter mutation | Approved browser palette transport deferred |
| Documentation/evidence | Original reports and certificates retained | Separate integration certificate/receipts; earlier ledger sections preserved | 171 Status Bar source/fixture bindings and 28 native mappings checked; HUD/Gameflow certificate bindings exact | Complete |

Shared-interface review: only `st_lib.sol` and `st_stuff.sol` are added under
src. Their `STState`, `STGraphics` and widget types are consumer-owned.
Existing GameState/Player/GameDefinitions, resource/renderer/video layouts,
Frame/input ABI, compiler, budget and production adapters remain unchanged.
Status uses its own320x32 screen4 backing; HUD uses screen0/screen1. ST_Ticker
uses the existing miscellaneous M_Random stream, not gameplay P_Random.
The gameflow callback order remains P/ST/AM/HU, including paused UI tics.
There is no conflicting interface and no integration source adjustment.

Risk-based verification follows section5 of the extra plan. **75 tests pass,
0 fail/skip:**72 in the combined status/HUD/gameflow/video/resource/RNG/Frame gate
and3 targeted renderer view-size/domain tests. The first gate compiles91 files
with unchanged Solc0.8.37/viaIR/optimizer200/Cancun in110.06s (reported compile
wall time), then runs tests in2.51s. The separate renderer dependency compiles
one test root in43.37s and runs three tests in228.68ms. Two unchanged fuzz tests
run256 cases each with seed0x42. The explicit build of all five ST/HU/gameflow
module roots passes using that cache. Compiler warnings are retained; no
assertion, golden, compiler setting or execution budget was relaxed.

Native status and world rebuild/check, focused formatting, feature byte
identity, preserved baseline files, source mappings, gamma/palette/resource
hashes and original certificate bindings all pass. The branch-specific
checkpoint generator is not rerun on main or used to overwrite its historical
certificate; its source-map/binding calculations are checked read-only.

The ordinary EVM gate deploys authentic resource chunks through ResourceStore
CREATE and uses the unchanged dedicated StatusBarFrame consumer. Base status,
damage flash and hidden fullscreen frames/palettes match the native fixtures.
Measured render receipts use32,667,985–38,679,331 gas, including setup/resources/
events; these are not production gameplay or isolated widget costs. The receipt
upper background is seeded; actual world/status composition is verified by the
separate native/Foundry test. StatusPalette remains a test-consumer event; the
production Frame ABI/browser protocol has not changed.

Evidence: [integration certificate](../artifacts/phase4/statusbar-integration.json)
and [new ordinary receipts](../artifacts/phase4/statusbar-integration-evm.json).
Original [Status Bar handoff](PHASE4-STATUSBAR.md),
[verification](../artifacts/phase4/statusbar-verification.json),
[source map](../artifacts/phase4/statusbar-source-map.json) and
[feature receipts](../artifacts/phase4/statusbar-evm.json) remain byte-identical.
HUD/Gameflow integration evidence, all earlier acceptance artifacts and Astra's
memory audit report are unchanged. Full inherited Phase0–3 and production
browser acceptance were not run; they remain final Phase4 gates.

Remaining production integration dependencies: authorize a separate adapter
goal; retain STState/widget history, HudState, GameState/GameflowState and mutable
difficulty definitions with atomic storage/rollback; bind synchronous setup,
ST/HU start and ordered ticker/draw/input lifecycles; retain correct M_Random
state and one command/ticker/gametic path; alias screen0 to the full framebuffer,
own screen4 and explicitly choose status168 versus legacy200 view/refresh;
select and verify production palette/gamma transport and browser consumption.
Later automap/cheats/multi-map/intermission/finale and full episode acceptance
remain separate goals. **No blocker remains for this Status Bar integration.**

The commit containing this checkpoint and the two new integration artifacts is
the publication. Stop after successful commit/push and main/origin synchronization;
no production adapter or further Phase4 implementation follows.


## Goal 4.4 — Original DOOM cheat codes (feature branch handoff)

Worktree `/Users/eduard/sandbox/doom-evm-cheats`, branch `feat/phase4-cheats`.
Initial source/interface investigation occurred at `6d7630e`; after the user's
pause/resume, authoritative branch baseline is accepted Status Bar integration
`9f98ed1d38e6de3f2577f5d76b07ec136fc70d52`. The task uses that current accepted
ST/HU/gameflow context. No main/other branch changes or independent shared
production adapter/interface changes are part of this task.

| Deliverable | Implementation | Integration | Verification | Remaining |
|---|---|---|---|---|
| Original m_cheat recognition and supported ST cheat effects | Complete in new m_cheat.sol/st_cheats.sol; IDMUS/sound excluded | Accepted GameContext/Player/P_GivePower/GameflowState APIs unchanged | 150 native scenarios / 4,196 event snapshots; 793 native primitive cases; O0/O2/ASan/UBSan exact | Production event dispatch deferred |
| IDDT and IDCLEV | Complete recognition, original gates, reveal cycle, parameter/reset/mode validation and deferred request | Independent AM helper and accepted G_DeferedInitNew call | Native scenarios, ordinary EVM raw-key/storage comparisons | AM rendering, authenticated additional-map setup and production routing deferred |
| Status/HUD/gameplay consumers | Cheat effects feed accepted unchanged modules | Dedicated composition only | 15 exact native full-frame/status-background/palette checkpoints; damage/armor/noclip/power-expiry tests | Production persistence/composition deferred |
| Tests/evidence/commits | Dedicated subsystem/support/oracle/tests/docs complete | No inherited assertions or historic certificates changed | 69 focused Foundry tests pass (20 new, 49 directly affected); 20 ordinary-EVM scenarios / 491 native event hashes across 254 input transactions | Full inherited regression deferred to final Phase 4 |

The implementation preserves mismatch-without-retry, case sensitivity, exact
short-circuit responder order, mutable parameter bytes, raw signed-char warp
parameters, health/weapon/key/power mutations, original messages and unpadded
hex position formatting. Both noclip strings work in every native mode;
nightmare/dead/paused do not independently disable ST cheats. ST's netgame gate,
IDCLEV outside that gate and AM's deathmatch/active-branch gate remain exact.
Original commercial IDCLEV rejects every warp because its computed episode is
zero. Original IDCHOPPERS grants invulnerability one, expiring next player tic.
Early first-NUL warp parameters expose uninitialized C buf[1]; parser changes
are verified, but that undefined gameplay request is safely rejected in Solidity.

All sixteen cursors/sequences and supplemental AM reveal/position state must be
persisted atomically with gameplay/deferred flow; level/UI lifecycle calls must
not reset global recognition. The [cheat handoff](PHASE4-CHEATS.md) specifies
native HU→ST→AM→ordinary-key event ordering, active-AM branch semantics, input
ordering/authorization ownership, next-tic consumers, pending level setup and
required rollback. These APIs are documented for the separate integration goal;
this task does not change browser, input/Frame ABI, map schema or production
adapters. IDDT geometry/pixels and actual multi-map loading are not claimed.

Native source/harness/fixture spans and hashes accompany the fixtures. The
presentation sanitizer uses the accepted variable-column-table array-bounds and
asset leak-detection exclusions; pure recognizer/effect comparisons use full
ASan/UBSan. Ordinary support CREATE costs 5,228,348 gas; input receipt costs and
runtime/source bindings are in [cheat receipts](../artifacts/phase4/cheats-evm.json).
These measure the storage/observation probe, not isolated production performance.
Solc 0.8.37/viaIR/optimizer200/Cancun and 10B budget remain unchanged.

[Cheat verification](../artifacts/phase4/cheats-verification.json) binds the
69-test gate, native counts, 15 presentation checkpoints, ordinary rollback/
retry/sequence proof and preservation of accepted baseline files. Commands live
in the handoff and tools/reference/cheats/README.md. One root agent performed this
goal; no subagents or transcript usage mining. Precise runtime model/category
usage is not exposed; goal-tool counters are separate from telemetry.

Implementation and independent Goal 4.4 feature verification are complete;
production integration is intentionally deferred under the user boundary. No
current blocker or remaining cheat-subsystem work. Commit on this feature branch,
do not merge into main, and stop after Goal 4.4. No later goal or full Phase 4
acceptance starts automatically. Completion/commit metadata follows separately.


### Verified cheat implementation checkpoint

Implementation/native/test commit **1eeed581edb17b7dd2def01d8796a37d10b751f8** is
verified on `feat/phase4-cheats`. The following documentation/evidence commit
publishes source-bound native/Foundry/ordinary-EVM results and the independent
integration API. Native rebuild/check, focused 69-test gate, owned-file formatting,
proof/source preservation and staged diff checks pass. Work remains local on
this feature branch; no merge or remote-main publication is performed.

The resumed structured goal began 2026-10-10T10:15:35Z (createdAt1791627335).
Its counter excludes the earlier cleared investigative goal. Goal-tool closure
will record the actual end/elapsed/token counter separately; these are not
per-category telemetry and are never added to historical/session token totals.

### Goal 4.4 actual closure

Verified handoff commit **939ea99** follows implementation **1eeed58** on the
local feature branch. Structured goal status is **complete**, start
2026-10-10T10:15:35Z, completion2026-10-10T10:39:10Z. Timestamp interval1,415s;
separate goal elapsed counter1,414s (23m34s), token counter132,376. The earlier
cleared investigation is excluded; these counters are not per-category/session
telemetry and must not be added to collector totals. Exact fields are in the
[closure record](../artifacts/phase4/cheats-goal-completion.json).

The following metadata-only commit records closure without changing verified
source, fixtures or proof bindings. All dedicated and affected checks passed,
the feature worktree is clean at handoff, no merge/push to main occurred, and no
later goal starts. Stop after Goal 4.4.


## Phase 4 Wave 2 — Verified source integration (2026-10-10)

Scope: source integration of completed Goals4.4,4.5 and4.7a, preserving feature
history/tests/reports/evidence. No production adapter wiring, level gameplay
loading/progression, Intermission or new gameplay functionality is implemented.
These source/module results do **not** accept production functionality.

Goal start2026-10-10T10:55:10Z. Clean main and refreshed origin/main matched
`d9d00e6558a392fad810c903a2b7acd983712402`. Previous Status/HUD/Gameflow integration
was complete and published (`9f98ed1` and prior merges); Astra audit and Video
Primitives are retained. Only the designated main worktree was modified.

Instruction-only commit **8baa7b78de7a9fd21c25b412a641e3fc01df4725** separately
adds One Goal / One Worktree / One Owner and independent runtime ownership to
AGENTS.md. Original feature messages/history were not rewritten; every new
instruction, merge and publication commit follows Gitmoji.

| Goal | Implementation | Integration | Verification | Source commits | Integration commit | Deferred / production dependency |
|---|---|---|---|---|---|---|
| 4.4 Cheats | Complete original supported recognition/effects | Source integrated | Original69-test gate covered in combined run;4,196 native event snapshots,793 primitives,15 ST/HU presentation checkpoints;491 ordinary snapshots/254 input transactions pass | `1eeed58`, `939ea99`, `9b5f50a` | `b5a857f95d520f0040dcfb02b192d5e8d17b4b7d` | Authenticated raw events, atomic parser/player/flow persistence, unified IDDT ownership, actual IDCLEV loading |
| 4.5 Automap | Complete original geometry/state/drawing | Source integrated | All19 focused tests covered;383 native snapshots/22 scenarios;22 ordinary Frames and rollback pass | `728fa25`, `266d926` | `01fa1993310458a6975348b678c9711428f99ff9` | Live AMWorld projection, state/event notifications, markers, renderer discovery flags and production composition |
| 4.7a Episode resources | Complete E1M1–E1M9 packaging/authentication | Source/schema integrated | 69 Node tests,4 focused resource tests,3 native profiles,9 mined map proofs and1,755 exact resource runtimes pass | `b6debb2`, `ceb35b8` | `d9bc0e57f633cc816403489326e283826f89a14d` | Synchronous P_SetupLevel, native zone/thinker/collision reset, gameplay spawning and resource-backed transitions |

All three workstreams share accepted baseline9f98ed1. The merges were sequential
and preserved all seven original feature commits as ancestors. No conflicts
occurred; Git auto-merged the shared ledger additions. The prior ledger body,
original Cheats append and Episode Resources handoff are retained verbatim.
All feature files except that combined ledger match their branch tips exactly.
All1,622 protected baseline files are unchanged. Only AGENTS.md, this ledger and
tools/wad/README.md differ among pre-existing files; the README is the exact
resource-branch addition. Existing source, tests, fixtures, schemas, production
adapters/browser/configuration and historical acceptance evidence remain exact.

### Executed verification

- **138 Foundry tests pass,0 fail/skip**:134 across21 focused suites covering
  Cheats69, Automap19 and affected Gameflow/video/ST/HU/player/lifecycle/resource/
  RNG/Frame dependencies, then4 targeted R_Data tests. The three unchanged fuzz
  tests run256 cases each with seed0x434844. The integrated108-file compile uses
  pinned Solc0.8.37/viaIR/optimizer200/Cancun, reported220.45s. The additional
  resource test root compiles in5.88s. All three support probes and ResourceStore
  build from that cache. Warnings remain warnings; no settings/assertions change.
- **69 Node tests pass,0 fail/skip**:51 inherited WAD cases plus18 Episode cases.
  An initial run had68 pass/1 failure because its fixed local oracle directory
  lacked generated native inputs. The validated38 oracle outputs were copied
  only into missing paths, with existing-file identity checked; no tests or
  tracked fixtures were modified. The first log is retained separately, and
  the unchanged suite reran successfully.
- Native rebuild/check: Cheats150 scenarios/4,196 snapshots and793 primitives;
  15 status/HUD native pixel/palette checkpoints; Automap22 scenarios/383 state
  and full-frame snapshots; all nine maps under three declared C profiles.
  New disk/native comparison is byte-identical to the original resource report.
  Existing native-profile adaptations/exclusions remain documented unchanged.
- Strict Episode v1 catalog/schema verification, repeated pack exactness, each
  map descriptor and raw lump checks, plus the legacy pack checker pass. The
  canonical catalog, v0 shared28,741,889-byte bundle, palette identity, original
  directory indices and map-relative ABI remain unchanged. Catalog/schema
  shape alone is not authentication; full identity/regeneration checks remain.
- Fresh ordinary EVM gates: Cheats491 native snapshots/254 input transactions
  with storage, mined rollback/retry and duplicate rejection; Automap22 frozen
  Frame receipts/383 snapshots, bottom32 preservation and malformed rollback;
  Episode1,755 ordinary resource CREATEs with exact STOP-prefixed runtime bytes,
  nine native-equal geometry/THINGS/BLOCKMAP/REJECT map receipts and mined E2M1
  rejection. These are support-consumer proofs, not production E2E or gameplay
  startup. Receipt gas includes decoding/setup/hash/events; no production cost
  or new timing estimate is inferred.

Runtimes use fresh ports18941,18945,18947, refuse occupied ports and terminate
only their own children. All runners completed cleanup. The playground ports
18880/8088 and all pre-existing Anvil instances were not used or modified.
Original branch certificate generators retain isolated-branch ownership guards;
they were not changed or rerun to overwrite historical evidence. Source/fixture/
compiler bindings and original certificates were checked directly instead.

New evidence: [Wave2 certificate](../artifacts/phase4/wave2/integration.json),
[Cheats receipts](../artifacts/phase4/wave2/cheats-evm.json),
[Automap receipts](../artifacts/phase4/wave2/automap-evm.json),
[Episode receipts](../artifacts/phase4/wave2/episode-evm.json).
Original handoffs [Cheats](PHASE4-CHEATS.md), [Automap](PHASE4-AUTOMAP.md) and
[Episode Resources](PHASE4-EPISODE-RESOURCES.md), all feature certificates and
source maps, earlier Phase4 evidence and the memory audit remain unchanged.

### Required production APIs and integration decisions

1. Persist CheatState, AutomapState, STState, HudState, GameState/GameflowState
   and mutable difficulty definitions atomically; rebind hooks/live memory
   views after loading. Cheat cursors/sequences survive death, map changes and
   ST/HU/AM lifecycle. Failed downstream setup must roll back requests, parser,
   messages, mutations and input sequence together.
2. Route original authenticated events once, in HUD -> status/cheats -> AM ->
   ordinary keyboard order. Held-key bitmaps cannot replace raw cheat events.
   **IDDT ownership must be resolved before production:** AM_Responder already
   updates AutomapState.cheatPos/cheating; the standalone ST_Cheats AM helper
   maintains a second parser/reveal state. Use one authoritative event/state
   path, preserving entered-active-branch/deathmatch/TAB semantics; do not
   independently route/update two divergent owners. This wave changes neither
   verified implementation and claims no combined production routing proof.
3. Build a live AMWorld from original ordered linedefs/vertices, current
   ML_MAPPED flags, sector heights, players/powers and sector/snext thing order.
   Synchronize AM/flow active/view flags, selected-player messages, marker
   load/unload requests and raw ST notifications after each event. Preserve
   the original malformed AM_Stop notification initializer; any deliberate
   adapter interpretation needs explicit fidelity tests, not oracle edits.
4. Own AMMNUM0..9 resources and render AM into upper168 rows of the existing
   full64,000-byte framebuffer, then compose status/HUD without changing Frame
   ABI. Palette/gamma browser transport and persistence remain separate work.
5. Verify catalog and source identity, construct the existing v0 ResourceView
   and select geometry by marker-relative lump IDs. Episode descriptors do
   not encode gameplay state, spawning, next maps or secret exits. A later
   loader must finish synchronous P_SetupLevel with native zone/thinker/
   collision reset and refreshed context aliases; reject unsupported IDCLEV
   selections atomically rather than substituting E1M1.

### Deferred checks and suggested next order

Full inherited Phase0–3 regression, final Phase4 acceptance, production browser/
Frame readback, direct combined Cheat/AM routing, actual nine-map gameplay
startup/restart, production IDCLEV, level progression/secret-exit routes and
Intermission/Finale remain unexecuted. Native-source and support-probe acceptance
must not be relabeled as any of those production claims.

Suggested separate goals: (1) production adapter foundation for atomic Gameflow/
ST/HU state, hooks, view/palette composition and raw-event contract; (2) resource-
backed synchronous multi-map gameplay loading/rollback, then Cheats/Automap
routing with one IDDT owner and live-world projection; (3) progression/secret
exits plus Intermission/Finale, followed by full regression/production E2E.
No blocker remains for this source merge. The commit containing this checkpoint
and certificate is integration-specific publication. Stop after normal push,
clean main and origin/main synchronization; no later goal starts automatically.


## Goal 4.11 — Verified Production UI main integration (2026-10-10)

The user authorized integration of the completed Production UI implementation
from `feat/phase4-ui-integration`. Scope is merge verification/publication only;
no new functionality, other worktree change or later Phase4 goal follows.
Goal start2026-10-10T12:03:39Z. Clean main and refreshed origin/main matched
`b833ff844aeccc644a9174b63e8229f1dd40d567`, the completed/published Wave2 baseline.

Original commits preserved: `0b65825bd589b9f824ef08172cb780c5b928ab9b`,
`49802693238a51fb24de4e5f206980530809a28b`,
`fe427b0a59deb6f0d4251e14d9cfd3fe60dae389`,
`2bea0ea9f2b7a626fde5b8674c700c8b972216a2`,
`a84afeba63aa8bc54e9f0e9c7a0c36d1e5a340cf`.
Merge **4345a872645c69dee0d9ed3c72c02c6892fb08af** uses Gitmoji/no-ff and has
no conflicts. Every one of29 changed feature files matches the source tip,
including documentation, test extensions, original logs/certificates/screenshots.

| Deliverable | Implementation | Main integration | Verification | Remaining |
|---|---|---|---|---|
| Persistent original ST/HU/video consumer | Complete at `0b65825`; separate UIState/borrowed immutable graphics | Integrated in production Doom/DoomGame/DoomUI without integration source edits |159 focused tests;276 controlled native storage snapshots;210 fresh native-matching production tics |Declared single-player E1M1 UI scope complete |
| View sizes, palettes and browser presentation |Explicit UI startup/fullscreen, upper168+status32, frame-bound EVM gamma palettes |Feature web input/palette implementation retained exactly |50 Node tests;13 fresh native-equal UI Frames/palettes; original210-tic/13-Canvas Chrome evidence preserved and source-bound |Fresh browser rerun deferred at this conflict-free merge |
| Legacy world-only profile |Existing startup/Frame/constructor/input ABI retained; render overload defaults11 |All existing engine modules/layouts/resource identity/config retained |Fresh129-tic legacy replay,6 gameplay+1 static Frames,13 storage rollback checks pass |Full inherited/final Phase4 acceptance deferred |
| History/evidence/publication |All five feature commits and prior Phase4 history retained |Original UI report/evidence remain exact; separate main-integration evidence |Original certificate checker and all29-file identity checks pass;1741 protected baseline files exact before ledger update |No blocker for this merge |

### Executed merge verification

- Original `tools/reference/ui/checkpoint.py --check` passes on the merged main
  source/evidence. This validates preserved proof bindings; executed gates are
  recorded separately below, not inferred from the certificate alone.
- The unchanged focused runner executes159 Foundry tests across18 suites,0
  failure/skip: ProductionUI consumer/storage vectors plus ST/HU/video, actual
  player/pickup/door producers, psprites/weapons, storage, renderer view/draw/
  plane/sprite/pass-order dependencies. Two existing fuzz tests run256 cases.
  The105-file compile uses pinned Solc0.8.37/viaIR/optimizer200/Cancun and reports
  244.56s; test wall time5.31s. The explicit production Doom/ResourceStore build
  compiles2 affected roots in75.79s and passes with unchanged settings/budget.
- 50 Node input/palette/protocol/lifecycle/budget tests pass,0 failure/skip.
  The first sandbox run had49 pass/1 failure because the runtime-cleanup test
  could not bind its owned test socket. The unchanged authorized rerun passes.
  That cleanup test's synthetic-deploy helper temporarily overwrote ignored
  web/config.local.json. Its exact original bytes were recovered from an existing
  local copy matching the pre-test SHA256; palette identity was also checked.
  Both files are now exact, and the fresh runtime gates verify them afterward.
  No existing chain was reset, reconfigured or terminated.
- Original UI oracle rebuild:210 tics/13 Frames, O0/O2/ASan+UBSan/alternate-fill
  profiles agree. The new manifest/build metadata match the preserved feature
  evidence byte-for-byte. Independent legacy native rebuild also passes129 tics.
- Fresh UI Anvil18911: all1755 resource runtimes and updated production Doom
  deployed ordinarily;210 tics match45 native scalar fields and all81 message
  backing bytes each, including197 no-render tics. All13 UI Frames match64,000
  native indexes and768 palette bytes; a pre-start static Frame also matches.
  Six whole-storage driver/startup/sequence/input rejections pass. Fullscreen
  transitions before tics70/101 preserve counters; pickup and HUD expiry pass.
- Fresh legacy Anvil18912: unchanged inherited production runner verifies129
  native tics,6 gameplay+1 static Frames and13 full-storage rollback checks.
  Both owned nodes stop after their runners complete. Browser harnesses were
  not invoked by these replays; the legacy runner disables browser-palette writes.
  Playground18880/8088 are not used by these runtime gates.

No inherited assertion, C oracle, native golden or historical acceptance
certificate was weakened or overwritten. Earlier audit/video/ST/HU/Gameflow/
Cheats/Automap/Episode source and evidence remain exact. Feature-authorized
changes to Doom/DoomGame and web input/presentation are retained exactly; the
web input test change adds UI coverage and preserves existing legacy assertions.

### Required deployment/client configuration

**Deploy the updated Doom contract to a new address.** This merge does not
upgrade code/storage of an existing deployment or redeploy the playground.
Before starting UI gameplay, set these boolean fields in the browser's existing
local configuration, alongside the new address, matching RPC/driver/resource
identity and execution budget:

```json
{
  "gameplay": true,
  "productionUI": true,
  "uiFullscreen": false
}
```

`productionUI:true` is a browser configuration requirement, not a constructor
argument. It selects `initializeGameUI(bool)` and requires the companion
FramePalette event. Optional `uiFullscreen:true` selects320x200 world with HUD/
palette effects; false selects320x168 world plus the original32-row status bar.
`setUIFullscreen(bool)` is driver-only and does not advance tic/input/Frame
counters. Configure the UI profile before startup; a legacy-started deployment
cannot be converted by calling UI initialization again. Configurations without
productionUI:true retain world-only startup/presentation.

Frame stays the frozen indexed8 320x200 ABI. Consumers select Frame by topic
and bind FramePalette by address, transaction, block, frameId and inputSeq;
EVM-selected768-byte gamma RGB data supplies presentation. Receipt/WS/historical
association and stale asynchronous delivery rules remain those verified in the
feature. No new browser drawing or host gameplay logic is introduced.

### Evidence, deferred checks and handoff

Original [Goal4.11 report](PHASE4-UI-INTEGRATION.md),
[certificate](../artifacts/phase4/ui/verification.json),
[Chrome proof](../artifacts/phase4/ui/browser.json) and all screenshots/logs are
preserved byte-for-byte. New [main-integration certificate](../artifacts/phase4/ui-main-integration/integration.json),
[focused log](../artifacts/phase4/ui-main-integration/focused.log),
[Node log](../artifacts/phase4/ui-main-integration/node.log),
[fresh UI receipts](../artifacts/phase4/ui-main-integration/production.json) and
[fresh legacy receipts](../artifacts/phase4/ui-main-integration/legacy.json)
record the executed merged-source checks. The original Chrome Canvas run is
validated/preserved rather than repeated; no new Chrome measurement is claimed.

Full inherited Phase0–3 and final Phase4 suite/production-browser acceptance
remain deferred. Current verified UI covers declared single-player retail E1M1,
default gamma0/showMessages=true; controlled vectors cover broader inventory/
face domains without claiming a whole-episode playthrough. Cheats/Automap/raw
responders, multi-map gameplay, Gameflow lifecycle/progression, Intermission/
Finale and restart UI-stat retention still require their separate integration
goals. No memory-architecture or storage-upgrade claim is added.

Implementation/source/runtime UI integration is complete within that scope.
The commit containing this checkpoint and separate certificate is publication;
stop after normal push and clean main/origin synchronization.
