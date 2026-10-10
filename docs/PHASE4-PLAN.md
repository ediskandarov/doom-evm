# Phase 4 progress ledger

Phase3 is complete and remains accepted. Optional Phase4 work follows
[the extra plan](04-IMPLEMENTATION-PLAN-EXTRA.md). This run is **Goal4.0 only**.
The pasted user instructions supersede the aborted memory-audit goal. Do not
start4.0a, gameplay/UI work, refactoring or an Astra benchmark.

## Recovery checkpoint

Baseline HEAD38d8a4392b21e2c78a1977d381bedf6e1cd5e6c7; tag
`phase3-accepted-38d8a43`. All accepted engine source fingerprints match
`artifacts/phase3/acceptance.json`. Engine, renderer, gameplay, existing tests,
compiler settings and historical exports are read-only for this task.
User-provided extra plan is preserved at its requested04 filename; its internal
03 placement suggestion is not used to rename the supplied file.

Goal4.0 active start:2026-10-10T05:01:34Z, structured goal createdAt1791608494.
A new explicit usage window is added without editing Phase0–3 boundaries.
Only tools/usage/**, new telemetry evidence and documentation are owned.

## Implementation vs verification

| Deliverable | Implementation | Verification/acceptance |
|---|---|---|
| Existing token accounting and historical preservation | Baseline unchanged |20 prior tests PASS; exact legacy/new token rows/totals/model-agent aggregates/segments and all historical Phase0–3 rows verified |
| Compaction metadata/durations | Implemented side adapter, ID/fork/duplicate guards, unique same-turn interval join |17 explicit compacted and17 timed ContextCompaction items observed; pair by unique same-thread/same-turn interval. Dedicated before/after context size absent |
| Human approval latency | Implemented explicit lifecycle/provenance parser |No explicit approval lifecycle records in current selected logs; policy/escalation intent is not a human wait |
| Compilation/test/tool duration separation | Implemented compiler/test/stage/envelope separation |Structured completed CommandExecution duration, terminal code and stdout stage summaries available; avoid wrapper/child/stage double counting |
| Goals, JSON/CSV schemas and human report | v2 additive schema, five new CSVs, metadata report and schema/privacy checker implemented |47 tests PASS; final article report/export handoff pending |Goal IDs from structured metadata; no objectives/messages/commands/output exported |
| Historical Phases0–3 recovery | Programmatic first scan complete |Recover only available measurements; old artifacts/boundaries/totals retained |

## Remaining work and blockers

No blocker. Side adapter and47 focused tests pass; token ledger exact baseline
comparison passes. Finish bounded historical exports/article report and limitations,
run final schema/CSV/privacy/ownership checks, produce checkpoint evidence,
update this ledger, commit/push and stop. Raw JSONL is processed programmatically;
only schema keys, IDs, times and numeric summaries enter model context.

Original Phase4 forecast remains unchanged:25h elapsed,17–38h plausible band,
50h+ adverse tail; separate4.0a estimate1–3h. Actual measured goal durations belong
in telemetry, not retrospective edits to that forecast.

## Verified parser checkpoint (commit hash recorded after creation)

`python3 -m unittest discover -s tools/usage -p 'test_*.py'`:47 passed; all20
existing cases retained plus27 new activity cases. `validate.py` reconciles v2
JSON/metadata privacy and every new CSV field. A separate source-loaded38d8a43
collector comparison proves all closed token records/totals/phase/model/agent
aggregates/segments exact; Phase0–3 published rows also exact. Sources unchanged
under src/, test/, web/, scripts/ and every prior historical artifact.

New module handles measured compaction intervals, nullable dedicated context
sizes, request input as a separate metric, explicit human/auto/unknown approval
resolver, reported Solc stages including millisecond units, overall test-wall
summaries (not per-suite CPU), compiler-cache skipped zero, explicit nested
process links and concurrent interval unions. No raw messages/objectives/commands/
output exported. No full Forge/native/Chrome rerun needed for this isolated task.
