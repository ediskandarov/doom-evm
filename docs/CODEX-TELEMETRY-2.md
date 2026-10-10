# Codex Telemetry 2.0 — Goal 4.0 report

Goal 4.0 extends the existing local collector without changing the accepted
DOOM implementation or any engine test. The Phase 3 baseline is 38d8a43,
preserved by tag `phase3-accepted-38d8a43`. The original Phase 4 forecast in the
supplied extra plan is unchanged. This report is an observation snapshot for a
future technical article, not a bill or proof that all activity was recorded.

## Principal findings

- 17 compactions are visible across 14 selected project threads: Phase 2 has 5,
 Phase 3 has 9, the earlier telemetry window has 1 and phase gaps have 2. None is
 observed in Phase 0/1. All 17 match one same-thread, same-turn timing interval;
 their durations are measured metadata. Proximity alone never creates a match.
- Phase 3's 9 compactions are 3 root and 2 each for input, interface and reference
 agents. Summed compaction duration across agents is not elapsed goal time.
- Compaction request input usage is available from a matching response ID, but
 dedicated before/after context token counts are absent for all 17. Cumulative
 token usage, context-window capacity, message order and summary length are not
 substituted for context occupancy. No tokenizer estimate is used.
- No explicit approval lifecycle records are visible. User/auto-review policy
 contexts exist, but they do not prove a human request or wait. Request/resolution
 intervals and human/automatic/unknown provenance are implemented and tested;
 actual historical human waiting time is **unavailable**, not zero.
- Solc stage summaries, direct compiler process duration, Forge envelopes and
 overall test-suite wall summaries are kept distinct. Per-suite CPU time is not
 summed as wall time. Some compiler output is redirected, hidden by wrappers or
 ambiguous; compiler subtotals below are only the recoverable subset.
- All previously verified Phase 0–3 token rows are exactly unchanged. The 20
 original accounting tests pass alongside 30 new activity/parser/export tests.
 No compaction or goal counters are added again to response token totals.

## Data and provenance

[Aggregate JSON](../artifacts/usage/telemetry2/usage.json) retains source hashes,
metadata event pointers, goal/agent attribution and measurement availability.
[Token CSV](../artifacts/usage/telemetry2/metrics.csv),
[phase tokens](../artifacts/usage/telemetry2/phase-totals.csv),
[compactions](../artifacts/usage/telemetry2/compactions.csv),
[approvals](../artifacts/usage/telemetry2/approvals.csv),
[command executions](../artifacts/usage/telemetry2/executions.csv),
[goals](../artifacts/usage/telemetry2/goals.csv) and
[activity phase totals](../artifacts/usage/telemetry2/activity-phase-totals.csv)
are metadata-only. Empty CSV cells/JSON null mean unavailable. Existing historical
exports are preserved separately; this v2 snapshot does not overwrite them.

The JSON contract and CSV column/units contract are under
`tools/usage/schemas/`. `validate.py` checks the documented schema subset,
forbidden transcript fields and exact JSON/CSV row-value reconciliation.
No messages, compaction summaries, reasoning, objectives, commands, arguments,
patches or tool-output bodies enter exports or model context. Raw JSONL was read
programmatically; exploration emitted only field names/types and numeric metadata.

## Interpretation boundaries

Recorded command execution sum is process-wall resource time across observed
commands. Concurrent agents overlap, so it may exceed elapsed wall time. The
interval union counts observed command coverage once; neither is CPU time, model
inference time, exclusive human waiting or total goal elapsed time. Explicit
parent process links suppress nested execution double-counting; Solc/test stage
values annotate their command and are never added to it a second time.
Temporal containment alone cannot distinguish nesting from concurrency.

Reported stdout stage values remain available separately. Different timer origins
and rounded summaries can differ slightly; 0.5s is a consistency tolerance, not
an adjustment or estimated duration. Larger inconsistent values are withheld
from subtotals, with diagnostics, while original reported values are retained.
Recognized shell compiler stages can be recovered without labeling the entire
shell envelope as a direct Forge process. Log readers, quoted script text and
heredoc bodies cannot manufacture compiler invocations.

Goal elapsed wall time uses audited start/end metadata; goal `timeUsedSeconds`
and `tokensUsed` keep their separate semantics. Open or paused goals have no
invented completion duration. Intervals crossing goal/phase boundaries are
ambiguous and never prorated. Models are configured turn/resume metadata;
unreported backend routing is unmeasured. Fork history and duplicate/conflicting
identities are excluded without changing token accounting.

The input files are private evolving CLI logs, not a stable public API guarantee.
Absent/rotated/unflushed logs, unrecorded approvals, unknown resolver provenance,
context occupancy and compiler subprocesses hidden in complex scripts remain
explicit coverage gaps. Missing classified compiler durations do not count all
invisible compiler work. A recorded zero compilation time means explicit cache
skip; a missing duration is unknown.

## Reproduce locally

```sh
python3 -m unittest discover -s tools/usage -p 'test_*.py'
python3 tools/usage/collect.py --phases tools/usage/phases.json \
  --aggregate-only --output artifacts/local/codex-telemetry2
python3 tools/usage/validate.py artifacts/local/codex-telemetry2
```

Standard library only; no service, daemon, network telemetry, credentials or
engine dependency. All prior collector flags and legacy CSV columns remain.
The additive JSON report is version 2; phase configuration remains version 1.
Goal 4.0 stops after this verified checkpoint. Goal 4.0a and all other Phase 4
work remain unstarted.

---

# Codex Telemetry 2.0 — observed local measurements

Snapshot: 2026-10-10T05:48:36.155Z. No transcripts, commands, objectives or tool output are exported.

Cached input is included in input; reasoning is included in output. Neither is added a second time.

| Phase | Responses | Input | Cached input | Output | Reasoning | Total |
|---|---:|---:|---:|---:|---:|---:|
| phase0 | 154 | 11,909,177 | 11,620,608 | 69,292 | 8,895 | 11,978,469 |
| phase1 | 191 | 13,954,577 | 13,629,696 | 88,519 | 14,701 | 14,043,096 |
| phase2 | 868 | 99,331,154 | 97,628,672 | 477,186 | 135,777 | 99,808,340 |
| phase3 | 1,902 | 332,256,311 | 326,402,688 | 1,397,046 | 625,089 | 333,653,357 |
| phase4-goal4.0 | 45 | 14,639,590 | 14,193,280 | 82,366 | 51,544 | 14,721,956 |
| telemetry | 37 | 5,034,184 | 4,793,600 | 51,157 | 19,753 | 5,085,341 |
| unattributed | 28 | 3,540,305 | 3,496,448 | 17,571 | 3,852 | 3,557,876 |

## Compaction and approval observations

| Phase | Compactions | Compaction seconds | Missing duration | Before/after context unavailable | Approval requests | Human wait seconds | Automatic wait seconds |
|---|---:|---:|---:|---:|---:|---:|---:|
| phase0 | 0 | unavailable | 0 | 0/0 | 0 | unavailable | unavailable |
| phase1 | 0 | unavailable | 0 | 0/0 | 0 | unavailable | unavailable |
| phase2 | 5 | 799.764 | 0 | 5/5 | 0 | unavailable | unavailable |
| phase3 | 9 | 1,363.734 | 0 | 9/9 | 0 | unavailable | unavailable |
| phase4-goal4.0 | 0 | unavailable | 0 | 0/0 | 0 | unavailable | unavailable |
| telemetry | 1 | 158.416 | 0 | 1/1 | 0 | unavailable | unavailable |
| unattributed | 2 | 236.036 | 0 | 2/2 | 0 | unavailable | unavailable |

Zero observed approval requests is not zero actual human waiting. Policy context alone proves no lifecycle or resolver.

Compaction request input tokens are model-request usage, not a measurement of context occupancy before/after compaction.

## Compactions by goal and agent

| Goal ID | Phase | Agent | Observed compactions |
|---|---|---|---:|
| 01a11fdf-1d25-7201-abb8-1afdaaab6b9c:1791544307 | phase2 | /root | 2 |
| 01a11fdf-1d25-7201-abb8-1afdaaab6b9c:1791544307 | phase2 | /root/p2_data | 1 |
| 01a11fdf-1d25-7201-abb8-1afdaaab6b9c:1791544307 | phase2 | /root/p2_draw | 1 |
| 01a11fdf-1d25-7201-abb8-1afdaaab6b9c:1791544307 | phase2 | /root/p2_geometry | 1 |
| 01a11fdf-1d25-7201-abb8-1afdaaab6b9c:1791555028 | phase3 | /root | 3 |
| 01a11fdf-1d25-7201-abb8-1afdaaab6b9c:1791555028 | phase3 | /root/p3_input | 2 |
| 01a11fdf-1d25-7201-abb8-1afdaaab6b9c:1791555028 | phase3 | /root/p3_interface_audit | 2 |
| 01a11fdf-1d25-7201-abb8-1afdaaab6b9c:1791555028 | phase3 | /root/p3_reference_audit | 2 |
| unknown | telemetry | /root | 1 |
| unknown | unattributed | /root | 2 |

## Compiler, test and execution measurements

| Phase | Command records | Execution sum seconds | Interval union seconds | Reported compiler seconds | Missing compiler stages | Overall test-suite seconds | Forge invocation seconds | Other command seconds |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phase0 | 115 | 112.842 | 101.110 | 0.009 | 0 | unavailable | unavailable | 79.340 |
| phase1 | 144 | 232.092 | 226.355 | 79.510 | 0 | 0.476 | unavailable | 146.358 |
| phase2 | 759 | 3,842.262 | 3,186.166 | 1,137.434 | 5 | 27.708 | 999.060 | 2,638.147 |
| phase3 | 1,592 | 7,668.157 | 6,803.907 | 1,479.104 | 19 | 16.604 | 2,527.461 | 4,873.144 |
| phase4-goal4.0 | 53 | 16.672 | 16.678 | unavailable | 0 | unavailable | unavailable | 11.701 |
| telemetry | 52 | 2.461 | 2.470 | unavailable | 0 | unavailable | unavailable | 2.296 |
| unattributed | 19 | 6.281 | 6.284 | unavailable | 0 | unavailable | unavailable | 3.287 |

Compiler and test stage measurements are annotations inside command duration, not additional execution time. Per-suite CPU times are never summed as wall time.

Execution sum can exceed elapsed wall time because concurrent commands/agents overlap. The interval union counts overlapping command coverage once; it is not goal time, CPU time, or time spent reasoning.

## Goal elapsed and separate accounting

| Goal ID | Phase | Status | Goal wall seconds | Reported goal seconds | Separate goal tokens |
|---|---|---|---:|---:|---:|
| 01a11fdf-1d25-7201-abb8-1afdaaab6b9c:1791537022 | phase0 | complete | 2,511.387 | 2,511 | 357,861 |
| 01a11fdf-1d25-7201-abb8-1afdaaab6b9c:1791541952 | phase1 | complete | 2,088.915 | 2,088 | 412,801 |
| 01a11fdf-1d25-7201-abb8-1afdaaab6b9c:1791544307 | phase2 | complete | 7,421.925 | 7,421 | 2,139,054 |
| 01a11fdf-1d25-7201-abb8-1afdaaab6b9c:1791555028 | phase3 | complete | 26,465.000 | 26,155 | 6,818,723 |
| 01a11fdf-1d25-7201-abb8-1afdaaab6b9c:1791608319 | unattributed | paused | unavailable | 0 | 0 |
| 01a11fdf-1d25-7201-abb8-1afdaaab6b9c:1791608494 | phase4-goal4.0 | active | unavailable | 2,553 | 471,699 |

Separate goal counters retain their own semantics and are never added to response-token totals. Open/paused goals have no invented completion or elapsed duration.

## Coverage and limitations

- No raw messages, compaction summaries, objectives, commands or tool output exported.
- Compaction request input usage is not an exact before-context size; cumulative usage and context-window capacity are not context occupancy.
- Approval policy/escalation intent/tool delay does not prove a request or human wait; missing lifecycle/resolver fields stay unknown.
- Human-wait means a logged human-resolved approval interval; human thinking, delivery and routing cannot be isolated from those endpoints.
- Execution sum is not goal elapsed/CPU time. Concurrent agents overlap; interval union is wall coverage, not an additive task budget.
- Forge duration includes overhead/possible tests. Solc-reported stage and overall suite wall are separate annotations, never added again to execution totals.
- Reported stage values are preserved separately. Inconsistent stages are withheld from subtotals with a0.5s tolerance for different timers/rounded stdout; no durations are adjusted to fit.
- Compound commands and wrapper-hidden compiler/test subprocesses stay unclassified; redirected compiler output may be unavailable. Missing stage durations are not zero.
- Inherited/duplicate/conflicting events are excluded; reset window numbers do not create duplicate token charges.
- Timing intervals crossing a phase/goal boundary remain ambiguous; they are never prorated.
- Exact compaction start/end matching requires one same-thread, same-turn containing interval. Proximity alone is insufficient.
- Missing before/after context sizes, unresolved approvals, absent resolver provenance and hidden subprocess stages stay null/blank.
- Logs can be unavailable, rotated or unflushed. These are observed measurements, not proof of complete activity or a final bill.

Activity diagnostics (numeric metadata only): `{"duplicate_activity_copies_excluded": 0}`.

## Goal 4.0 completion accounting

The completed goal interval is2026-10-10T05:01:34Z–05:57:49Z (3375 wall seconds,
second precision). The tool reports3374 goal seconds, about56 minutes, and
**566,101 separate goal tokens**. These retain different semantics from session
response usage and are never summed with it.
[Structured closure record](../artifacts/usage/goal4.0-completion.json) and the
current phase ledger preserve the actual endpoint. The dataset above remains
the as-of snapshot before completion, with open-goal values truthful at that
time. Unflushed current usage and later bookkeeping remain unavailable/outside
the closed goal window; no estimate is substituted.
