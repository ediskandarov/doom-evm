# Phase 4 progress ledger

Phase 3 is complete and remains accepted. Optional Phase 4 work follows
[the extra plan](04-IMPLEMENTATION-PLAN-EXTRA.md). This run is **Goal 4.0 only**.
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
| Goals, JSON/CSV schemas and human report | v2 additive schema, five new CSVs, metadata report and schema/privacy checker implemented |50 focused tests PASS; goals use structured metadata; no objective/command text exported. Final article/export handoff pending |
| Historical Phases0–3 recovery | Programmatic first scan complete |Recover only available measurements; old artifacts/boundaries/totals retained |

## Remaining work and blockers

No blocker. Side adapter and 50 focused tests pass; token ledger exact baseline
comparison passes. Finish bounded historical exports/article report and limitations,
run final schema/CSV/privacy/ownership checks, produce checkpoint evidence,
update this ledger, commit/push and stop. Raw JSONL is processed programmatically;
only schema keys, IDs, times and numeric summaries enter model context.

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
All prior exports remain intact. Final test/baseline/ownership/source checks and
publication commit/push are next; no further Phase4 goal is authorized.

## Final verification and handoff

[Validation evidence](../artifacts/usage/telemetry2-validation.json) records50
passing tests, new JSON/CSV/privacy validation, exact legacy/new token rows/
totals/phase/model-agent aggregates/segments, unchanged historical boundaries,
and protected source/export fingerprints. Code hardening retains original
reported stage values alongside validated subtotals and a declared0.5s timer
consistency tolerance; no value is adjusted or estimated.

Implementation, integration and verification for Goal4.0 are complete. Implementation checkpoint `f57acd8` is verified; human report and metadata
exports are ready for their separate publication checkpoint. Observability gaps are
limitations, not blockers or invented measurements. Stop after publication;
Goal4.0a and all other optional Phase4 work remain unstarted.
