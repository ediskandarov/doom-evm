# Phase 4 progress ledger

Phase 3 is complete and remains accepted. Optional Phase 4 work follows
[the extra plan](04-IMPLEMENTATION-PLAN-EXTRA.md). **Goal 4.0 is complete and verified. Goal 4.1 is now active.**
The Goal 4.0 entries below are historical; their stop/read-only rules applied to that completed task.
The current user authorizes video primitives on main while Astra independently audits a separate worktree.
The pasted user instructions supersede the aborted memory-audit goal. Do not
start 4.0a, gameplay/UI work, refactoring or an Astra benchmark.

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


## Goal 4.1 — Video primitives (active)

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
| Eight original V_* functions and header globals | Implemented | Memory-only VideoState, no engine changes | 15 focused unit tests pass; 58 native cases exact | Dependency/receipt gates |
| Real WAD patch/native oracle | Implemented | Separate original-C host | O0/O2/sanitizers exact; rebuild/check pass | Complete |
| Renderer/frame compatibility | Implemented | Existing resource reader + screen0 alias + frozen Frame | Two Foundry integration cases pass (168/200) | Ordinary receipts + legacy world case |
| Source mapping/evidence | Pending | Separate Phase 4 artifacts | Pending | Final report/bindings |

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
