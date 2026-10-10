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
