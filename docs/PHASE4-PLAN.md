# Phase 4 progress ledger

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
